extends RefCounted

const RadarRules = preload("res://modules/progression/radar_rules.gd")
const Rules = preload("res://modules/progression/upgrade_rules.gd")
const Store = preload("res://infrastructure/persistence/profile_store.gd")
const Contracts = preload("res://modules/progression/contract_progress.gd")
var model: RefCounted
var catalog: Dictionary = {}
var profile: Dictionary = {}
var store: RefCounted
var contracts := Contracts.new()
var dirty := false
var _save_wait := 0.0
var _generation := -1
var _passive_timer := 0.0
var _draft: Array[Dictionary] = []
var _core_done := false
var _selected_sidegrades: Dictionary = {}

func _init(profile_path: String = "user://iron-caravan-profile.json") -> void:
	store = Store.new(profile_path)
	profile = store.load_profile()
	var file := FileAccess.open("res://data/game_catalogs.json", FileAccess.READ)
	if file:
		catalog = JSON.parse_string(file.get_as_text())
	profile.unlockedSidegradeIds = profile.unlockedSidegradeIds.filter(func(id: String) -> bool: return catalog.get("sidegrades", {}).has(id))
	contracts.setup(profile, catalog.get("contracts", {}))

func setup(combat_model: RefCounted) -> void:
	model = combat_model
	reset_run()

func reset_run() -> void:
	if contracts.active:
		contracts.record({"kind": "result", "won": false, "elapsed": 0})
	contracts.active = false
	contracts.ended = false
	_generation = model.generation
	_core_done = false
	_draft.clear()
	_passive_timer = 0
	var p: Dictionary = model.player
	var defaults := {"weight": 12.0, "modules": [], "carriers": [], "core_upgrades": {"motor": 0, "armor": 0, "fuel": 0}, "speed_mult": 1.0, "motor_speed_mult": 1.0, "motor_acceleration_mult": 1.0, "fuel_burn_mult": 1.0, "weapon_capacity": 4, "base_weapon_capacity": 4, "replacement_cursor": 0, "unlocked_weapons": ["assaultRifle", "bazooka"], "protocols": [], "active_protocols": [], "selected_sidegrades": _selected_sidegrades.duplicate(), "pending_upgrades": 0, "mobility_upgrades": 0, "momentum_decay_mult": 1.0, "evolution_tier": 1, "radar_range": 0.0, "radar_level": 0, "growth_total": 0}
	for key: String in defaults:
		p[key] = defaults[key]
	for weapon: Dictionary in model.weapons:
		weapon.mount = _next_mount(weapon.type)
		p.modules.append(weapon)
	_refresh_protocols()

func begin_run() -> void:
	if not contracts.active and not contracts.ended:
		contracts.begin_run()
		_mark_dirty()

func step(delta: float) -> void:
	if model.generation != _generation:
		reset_run()
	if dirty:
		_save_wait -= maxf(delta, 0)
		if _save_wait <= 0:
			flush()
	if not model.running or model.status in ["dead", "complete"]:
		return
	begin_run()
	var p: Dictionary = model.player
	while p.xp >= p.xp_next:
		p.xp -= p.xp_next
		p.level += 1
		p.xp_next = floor(p.xp_next * 1.46 + 40)
		p.pending_upgrades += 1
		p.max_hp += 24
		p.hp = minf(p.max_hp, p.hp + 42)
		p.evolution_tier = mini(4, 1 + int((p.level - 1) / 2))
	_passive_timer += maxf(delta, 0)
	if _passive_timer >= 4:
		_passive_timer = 0
		var workshops := 0
		for module: Dictionary in p.modules:
			workshops += int(module.type == "workshop")
		p.hp = minf(p.max_hp, p.hp + workshops * 2)
	_refresh_protocols()

func _mark_dirty() -> void:
	dirty = true
	_save_wait = 0.4

func flush() -> bool:
	if not dirty:
		return store.status in ["ready", "default"]
	if store.save_profile(profile):
		dirty = false
		return true
	_save_wait = 2
	return false

func _next_mount(type: String) -> Dictionary:
	var p: Dictionary = model.player
	if type == "bumper":
		for module: Dictionary in p.modules:
			if module.type == "bumper":
				return {}
		return {"carrierId": "crawler", "slot": 12}
	var carriers: Array = p.carriers.duplicate()
	carriers.append({"id": "crawler", "slotCount": 12})
	for carrier: Dictionary in carriers:
		for slot: int in int(carrier.slotCount):
			var occupied := false
			for module: Dictionary in p.modules:
				occupied = occupied or module.get("mount", {}) == {"carrierId": carrier.id, "slot": slot}
			if not occupied:
				return {"carrierId": carrier.id, "slot": slot}
	return {}

func _installed(type: String) -> bool:
	for module: Dictionary in model.player.modules:
		if module.type == type:
			return true
	return false

func _valid_mount(type: String, mount: Dictionary, replacing: Dictionary = {}) -> bool:
	if mount.is_empty() or not mount.has("carrierId") or not mount.has("slot"):
		return false
	var carrier_id := str(mount.carrierId)
	var slot := int(mount.slot)
	if type == "bumper":
		return carrier_id == "crawler" and slot == 12 and not _installed(type)
	var slots := 12 if carrier_id == "crawler" else 0
	for carrier: Dictionary in model.player.carriers:
		if str(carrier.id) == carrier_id:
			slots = int(carrier.slotCount)
	if slot < 0 or slot >= slots:
		return false
	for module: Dictionary in model.player.modules:
		if module != replacing and module.get("mount", {}) == mount:
			return false
	return true

func _add_module(type: String, requested_mount: Dictionary = {}) -> bool:
	if not catalog.modules.has(type):
		return false
	var definition: Dictionary = catalog.modules[type]
	if definition.get("unique", false) and _installed(type):
		return false
	var mount := _next_mount(type) if requested_mount.is_empty() else requested_mount
	if not _valid_mount(type, mount):
		return false
	var module := {"type": type, "level": 1, "cooldown": 0.0, "def": definition.duplicate(true), "mount": mount}
	model.player.modules.append(module)
	model.player.weight += definition.weight
	if definition.has("projectile"):
		model.weapons.append(module)
		if not model.player.unlocked_weapons.has(type):
			model.player.unlocked_weapons.append(type)
	match type:
		"armor":
			model.player.max_hp += 55
			model.player.hp += 55
			model.player.armor = minf(0.6, model.player.armor + 0.05)
		"bumper": model.player.has_bumper = true
		"radar":
			model.player.radar_level = 1
			model.player.radar_range = RadarRules.range_at(1)
			module.def.range = model.player.radar_range
		"counterDroneJammer": model.player.counter_drone_jammer = true
	_refresh_protocols()
	return true

func _equip(type: String, requested_mount: Dictionary = {}) -> bool:
	var definition: Dictionary = catalog.modules.get(type, {})
	var p: Dictionary = model.player
	if not definition.has("projectile") or not p.unlocked_weapons.has(type) or _installed(type):
		return false
	var cost := 18 + roundi(definition.weight * 4)
	if p.coins < cost:
		return false
	var mount := _next_mount(type) if requested_mount.is_empty() else requested_mount
	if model.weapons.size() < p.weapon_capacity and not mount.is_empty():
		if not _add_module(type, mount):
			return false
	else:
		if model.weapons.is_empty():
			return false
		var index := posmod(int(p.replacement_cursor), model.weapons.size())
		var old: Dictionary = model.weapons[index]
		if not requested_mount.is_empty() and not _valid_mount(type, requested_mount, old):
			return false
		var module_index: int = p.modules.find(old)
		var next := {"type": type, "level": 1, "cooldown": 0.1, "def": definition.duplicate(true), "mount": old.mount.duplicate() if requested_mount.is_empty() else requested_mount.duplicate()}
		p.modules[module_index] = next
		model.weapons[index] = next
		p.weight += definition.weight - old.def.weight
		p.replacement_cursor = (index + 1) % model.weapons.size()
	p.coins -= cost
	_refresh_protocols()
	return true

func _remove(index: int) -> bool:
	if index < 0 or index >= model.weapons.size() or model.weapons.size() <= 1:
		return false
	var weapon: Dictionary = model.weapons[index]
	model.player.modules.erase(weapon)
	model.weapons.remove_at(index)
	model.player.weight = maxf(1, model.player.weight - weapon.def.weight)
	model.player.coins += maxi(4, roundi((18 + weapon.level * 9) * 0.4))
	model.player.replacement_cursor = posmod(int(model.player.replacement_cursor), model.weapons.size())
	_refresh_protocols()
	return true

func _refresh_protocols() -> void:
	model.player.active_protocols = []
	for id: String in model.player.protocols:
		if Rules.protocol_available(catalog.protocols[id], model.player.modules, catalog.moduleBuildProfiles):
			model.player.active_protocols.append(id)
	model.player.treasury_count = model.player.modules.filter(func(module: Dictionary) -> bool: return module.type == "treasury").size()

func _row(id: String, label: String, description: String, cost: int, reason: String = "") -> Dictionary:
	return {"id": id, "label": label, "title": label, "description": description, "cost": cost, "enabled": reason.is_empty(), "disabled_reason": reason}

func _draft_row(id: String, label: String, description: String) -> void:
	_draft.append(_row(id, label, description, 0))

func _shuffle(values: Array) -> Array:
	var result := values.duplicate()
	for index: int in range(result.size() - 1, 0, -1):
		var other: int = model.random.randi_range(0, index)
		var value: Variant = result[index]
		result[index] = result[other]
		result[other] = value
	return result

func _ensure_draft() -> void:
	if not _draft.is_empty():
		return
	var p: Dictionary = model.player
	for id: String in _shuffle(catalog.protocols.keys()):
		if not p.protocols.has(id) and Rules.protocol_available(catalog.protocols[id], p.modules, catalog.moduleBuildProfiles):
			_draft_row("protocol:" + id, catalog.protocols[id].name, catalog.protocols[id].description)
			break
	if _draft.size() < 2 and model.random.randf() < 0.72:
		for type: String in _shuffle(catalog.modules.keys()):
			if catalog.modules[type].has("projectile") and not p.unlocked_weapons.has(type):
				_draft_row("blueprint:" + type, catalog.modules[type].name + " Blueprint", catalog.modules[type].desc)
				break
	for type: String in _shuffle(catalog.modules.keys()):
		var definition: Dictionary = catalog.modules[type]
		if not definition.has("projectile") and not definition.get("purchasable", false) and p.modules.size() < 12 + p.carriers.size() * 3 and (not definition.get("unique", false) or not _installed(type)) and _draft.size() < 3:
			_draft_row("draft_module:" + type, definition.name, definition.desc)
			break
	for index: int in _shuffle(range(model.weapons.size())):
		var weapon: Dictionary = model.weapons[index]
		if weapon.level < weapon.def.get("maxLevel", 5) and _draft.size() < 3:
			_draft_row("draft_weapon:" + str(index), weapon.def.name + " MK " + str(weapon.level + 1), "Raise damage and range while reducing reload time.")
			break
	var traits: Array = _shuffle(catalog.levelUpgrades)
	if p.mobility_upgrades < 3 and _draft.size() < 3:
		for definition: Dictionary in traits:
			if definition.get("category", "") == "mobility":
				_draft_row("trait:" + Rules.trait_id(0, definition), definition.title, definition.desc)
				break
	for definition: Dictionary in traits:
		var id: String = Rules.trait_id(0, definition)
		if _draft.size() >= 3:
			break
		if definition.get("category", "") != "mobility" and Rules.trait_available(id, p):
			_draft_row("trait:" + id, definition.title, definition.desc)
	_draft.assign(_shuffle(_draft))

func _choices() -> Array:
	if model.player.pending_upgrades <= 0:
		return []
	var choices: Array = []
	if not _core_done:
		for id: String in ["motor", "armor", "fuel"]:
			if model.player.core_upgrades[id] < 5:
				choices.append(_row("core:" + id, catalog.coreUpgrades[id].title + " LV " + str(model.player.core_upgrades[id] + 1), catalog.coreUpgrades[id].description, 0))
	if not choices.is_empty():
		return choices
	_core_done = true
	_ensure_draft()
	return _draft

func buy_upgrade(id: String) -> bool:
	var p: Dictionary = model.player
	var parts := id.split(":", true, 1)
	var kind := parts[0]
	var value := parts[1] if parts.size() > 1 else ""
	var choice := false
	for row: Dictionary in _choices():
		choice = choice or row.id == id
	if kind in ["core", "trait", "protocol", "blueprint", "draft_module", "draft_weapon"]:
		if not choice:
			return false
		var applied := false
		match kind:
			"core": applied = Rules.apply_core(value, p)
			"trait": applied = Rules.apply_trait(value, p, model.weapons)
			"protocol":
				p.protocols.append(value)
				applied = true
			"blueprint":
				p.unlocked_weapons.append(value)
				applied = true
			"draft_module": applied = _add_module(value)
			"draft_weapon": applied = Rules.upgrade_weapon(model.weapons[int(value)])
		if not applied:
			return false
		if kind == "core":
			_core_done = true
		else:
			p.pending_upgrades -= 1
			_core_done = false
			_draft.clear()
		_refresh_protocols()
		return true
	if p.pending_upgrades > 0:
		return false
	if kind == "radar":
		return value.is_valid_int() and RadarRules.upgrade(p, int(value))
	if kind == "module":
		var mount: Dictionary = {}
		var target := value.split(":")
		if target.size() != 1:
			if target.size() != 3 or not target[2].is_valid_int():
				return false
			mount = {"carrierId": target[1], "slot": int(target[2])}
			value = target[0]
		if not catalog.modules.has(value):
			return false
		var definition: Dictionary = catalog.modules[value]
		if definition.has("projectile"):
			return _equip(value, mount)
		if not definition.get("purchasable", false) or _installed(value) or p.coins < definition.get("cost", 0):
			return false
		if _add_module(value, mount):
			p.coins -= definition.cost
			return true
	if kind == "weapon" and value.is_valid_int():
		var index := int(value)
		if index >= 0 and index < model.weapons.size():
			var cost := 22 + int(model.weapons[index].level) * 18
			if p.coins >= cost and Rules.upgrade_weapon(model.weapons[index]):
				p.coins -= cost
				return true
	if kind == "remove" and value.is_valid_int():
		return _remove(int(value))
	if kind == "trailer" and p.carriers.size() < 2 and p.level >= (2 if p.carriers.is_empty() else 4) and p.coins >= 90:
		p.carriers.append({"id": "trailer-" + str(p.carriers.size() + 1), "type": "walkerTrailer", "slotCount": 3})
		p.weight += 8
		p.fuel_burn_mult *= 1.12
		p.coins -= 90
		return true
	return false

func set_sound_enabled(enabled: bool) -> void:
	profile.settings.soundEnabled = enabled
	_mark_dirty()

func select_contracts(ids: Array) -> bool:
	if contracts.active:
		return false
	var selection: Array = []
	for id: Variant in ids:
		if id is String and catalog.contracts.has(id) and not profile.completedContractIds.has(id) and not selection.has(id) and selection.size() < 3:
			selection.append(id)
	profile.selectedContractIds = selection
	_mark_dirty()
	return true

func select_sidegrade(bucket: String, id: String) -> bool:
	if contracts.active:
		return false
	if id.is_empty():
		_selected_sidegrades.erase(bucket)
	elif catalog.sidegrades.has(id) and catalog.sidegrades[id].bucket == bucket and profile.unlockedSidegradeIds.has(id):
		_selected_sidegrades[bucket] = id
	else:
		return false
	if model:
		model.player.selected_sidegrades = _selected_sidegrades.duplicate()
	return true

func on_combat_event(event: Dictionary) -> bool:
	if event.has("generation") and event.generation != model.generation:
		return false
	var decorated := event.duplicate()
	if decorated.get("kind", "") == "result":
		decorated.module_types = []
		for module: Dictionary in model.player.modules:
			decorated.module_types.append(module.type)
	if decorated.get("kind", "") == "pickup" and decorated.get("pickup_kind", "") == "salvage":
		model.player.growth_total += int(decorated.get("amount", 0))
	var accepted := contracts.record(decorated)
	if accepted:
		_mark_dirty()
	return accepted

func get_shop_state() -> Dictionary:
	var p: Dictionary = model.player
	var rows: Array = []
	for type: String in catalog.modules:
		var definition: Dictionary = catalog.modules[type]
		var cost := int(definition.get("cost", 0))
		var reason := ""
		if definition.has("projectile"):
			cost = 18 + roundi(definition.weight * 4)
			if not p.unlocked_weapons.has(type):
				reason = "Find a blueprint in supplies or level-up choices"
			elif _installed(type):
				reason = "Already equipped"
		elif not definition.get("purchasable", false):
			reason = "Available as a level-up choice"
		elif _installed(type):
			reason = "Already installed"
		elif _next_mount(type).is_empty():
			reason = "No open module mount"
		if reason.is_empty() and p.coins < cost:
			reason = "Need " + str(cost) + " salvage"
		if p.pending_upgrades > 0:
			reason = "Finish the level-up choices"
		rows.append(_row("module:" + type, definition.name, definition.desc, cost, reason))
	var weapons: Array = []
	for index: int in model.weapons.size():
		var weapon: Dictionary = model.weapons[index]
		var cost := 22 + int(weapon.level) * 18
		var reason := "Maximum tier" if weapon.level >= weapon.def.get("maxLevel", 5) else "Need " + str(cost) + " salvage" if p.coins < cost else ""
		if p.pending_upgrades > 0:
			reason = "Finish the level-up choices"
		var row := _row("weapon:" + str(index), weapon.def.name + " MK " + str(weapon.level), "Damage %s | Range %.1f | Reload %.2fs" % [weapon.def.damage, weapon.def.range, weapon.def.cooldown], cost, reason)
		row.remove_id = "remove:" + str(index)
		row.remove_enabled = model.weapons.size() > 1 and p.pending_upgrades == 0
		row.refund = maxi(4, roundi((18 + weapon.level * 9) * 0.4))
		row.mount = weapon.mount.duplicate()
		weapons.append(row)
	var trailer_reason := ""
	if p.carriers.size() >= 2:
		trailer_reason = "Maximum two trailers"
	elif p.level < (2 if p.carriers.is_empty() else 4):
		trailer_reason = "Requires level " + str(2 if p.carriers.is_empty() else 4)
	elif p.coins < 90:
		trailer_reason = "Need 90 salvage"
	if p.pending_upgrades > 0:
		trailer_reason = "Finish the level-up choices"
	var protocols: Array = []
	for id: String in catalog.protocols:
		var definition: Dictionary = catalog.protocols[id]
		var reason := "Active" if p.active_protocols.has(id) else "Prerequisites lost" if p.protocols.has(id) else "Select from a level-up draft" if Rules.protocol_available(definition, p.modules, catalog.moduleBuildProfiles) else "Required modules missing"
		protocols.append(_row("protocol:" + id, definition.name, definition.description, 0, reason))
	var contract_rows: Array = []
	for id: String in catalog.contracts:
		var definition: Dictionary = catalog.contracts[id]
		var completed: bool = profile.completedContractIds.has(id)
		var row := _row(id, definition.title, definition.description, 0, "Completed" if completed else "Changes apply before a run" if contracts.active else "")
		row.selected = profile.selectedContractIds.has(id)
		row.completed = completed
		row.progress = definition.target if completed else contracts.progress.get(id, 0) if definition.scope == "run" else profile.contractProgress.get(id, 0)
		row.target = definition.target
		row.reward = definition.rewardSidegradeId
		contract_rows.append(row)
	var sidegrade_rows: Array = []
	for id: String in catalog.sidegrades:
		var definition: Dictionary = catalog.sidegrades[id]
		var row := _row(id, definition.name, definition.tradeoff, 0, "Complete a reward contract" if not profile.unlockedSidegradeIds.has(id) else "Select before a run" if contracts.active else "")
		row.bucket = definition.bucket
		row.selected = _selected_sidegrades.get(definition.bucket, "") == id
		sidegrade_rows.append(row)
	var choices := _choices()
	return {"modules": rows, "radar_upgrade": RadarRules.shop_row(p), "weapons": weapons, "choices": choices, "trailer": _row("trailer", "Wheeled Trailer", "Three module mounts, +8 weight, +12% fuel use", 90, trailer_reason), "protocols": protocols, "contracts": contract_rows, "sidegrades": sidegrade_rows, "pending_upgrades": p.pending_upgrades, "choice_stage": "draft" if _core_done else "core", "storage_status": store.status, "dirty": dirty}

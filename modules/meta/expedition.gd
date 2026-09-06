extends RefCounted

const CaravanRoster = preload("res://modules/caravan/caravan_roster.gd")
const Catalog = preload("res://modules/meta/expedition_catalog.gd")
const MissionProgress = preload("res://modules/meta/mission_progress.gd")
const MissionTracker = preload("res://modules/meta/mission_tracker.gd")
var progression: RefCounted
var caravan: RefCounted
var active := false
var backpack: Dictionary = {}
var last_result: Dictionary = {}
var notice := ""
var _seen: Dictionary = {}
var _raid_xp := 0
var missions := MissionTracker.new()
var _mission_result: Dictionary = {}
var _player: Dictionary = {}
var _loot_index := 0
var _weapon_improved := false
var _pending_result: Variant = null

func _init(owner: RefCounted) -> void:
	progression = owner
	progression.profile.expedition = Catalog.normalize(progression.profile.get("expedition"))
	caravan = CaravanRoster.new(progression)

func _data() -> Dictionary:
	return progression.profile.expedition

func _commit(before: Dictionary) -> bool:
	progression._mark_dirty()
	if progression.flush():
		return true
	progression.profile.expedition = before
	progression._mark_dirty()
	notice = "Не удалось сохранить профиль. Действие отменено."
	return false

func base_capacity() -> int:
	return 12 + 4 * int(_data().upgrades.cargo)

func capacity() -> int:
	var total := base_capacity()
	if active:
		for wagon: Dictionary in caravan.cargo_containers():
			total += int(wagon.cargo_capacity)
	return total

func cargo_inventory() -> Dictionary:
	var result := backpack.duplicate(true)
	if active:
		for wagon: Dictionary in caravan.cargo_containers():
			for id: String in wagon.cargo:
				result[id] = int(result.get(id, 0)) + int(wagon.cargo[id])
	return result

func _remove_cargo(id: String) -> bool:
	if int(backpack.get(id, 0)) > 0:
		backpack[id] -= 1
		if backpack[id] == 0:
			backpack.erase(id)
		return true
	for wagon: Dictionary in caravan.cargo_containers():
		if int(wagon.cargo.get(id, 0)) > 0:
			wagon.cargo[id] -= 1
			if wagon.cargo[id] == 0:
				wagon.cargo.erase(id)
			return true
	return false

func begin_run(player: Dictionary) -> bool:
	if active:
		return false
	var before := _data().duplicate(true)
	var carried: Dictionary = _data().loadout.duplicate(true)
	var staged: Dictionary = caravan.stage_begin()
	_data().loadout.clear()
	if not _commit(before):
		return false
	backpack = carried
	active = true
	caravan.activate(staged, player)
	last_result.clear()
	_seen.clear()
	_mission_result.clear()
	_player = player
	_raid_xp = 0
	_loot_index = 0
	_weapon_improved = false
	_pending_result = null
	var armor := 20 * int(_data().upgrades.armor)
	player.max_hp = float(player.get("max_hp", 250)) + armor
	player.hp = minf(player.max_hp, float(player.get("hp", player.max_hp)) + armor)
	player.motor_speed_mult = float(player.get("motor_speed_mult", 1.0)) * (1.0 + 0.03 * int(_data().upgrades.engine))
	missions.reset(player)
	notice = "Добыча останется с вами только после эвакуации."
	return true

func collect_loot(source: String, count: int = 1) -> bool:
	if not active or _pending_result != null or count <= 0:
		return false
	var id := source
	if not Catalog.ITEMS.has(id):
		match source:
			"convoy", "raiderSupplyConvoy", "scavengerRoute": id = "weapon_parts"
			"fort", "foundry", "garrison", "stronghold", "boss": id = "relic"
			"settlement", "settlementDistress": id = "repair_kit"
			_: id = "circuit" if _loot_index % 5 == 4 else "scrap"
	var accepted := count
	var item_size := int(Catalog.ITEMS[id].size)
	var containers: Array = [{"cargo": backpack, "cargo_capacity": base_capacity()}]
	containers.append_array(caravan.cargo_containers())
	var free_units := 0
	for container: Dictionary in containers:
		free_units += maxi(0, int((int(container.cargo_capacity) - Catalog.used(container.cargo)) / item_size))
	if accepted > free_units:
		notice = "Рюкзак заполнен. Используйте припасы или эвакуируйтесь."
		return false
	var remaining := accepted
	for container: Dictionary in containers:
		var amount := mini(remaining, maxi(0, int((int(container.cargo_capacity) - Catalog.used(container.cargo)) / item_size)))
		if amount > 0:
			container.cargo[id] = int(container.cargo.get(id, 0)) + amount
			remaining -= amount
	_loot_index += 1
	_raid_xp += accepted * (12 if id == "relic" else 5)
	missions.loot(id, accepted)
	notice = "+%d %s" % [accepted, Catalog.ITEMS[id].name]
	return true

func sample_run(player: Dictionary, delta: float, weather: String) -> void:
	if active and _pending_result == null:
		missions.sample(player, delta, weather)

func record_event(event: Dictionary) -> void:
	if not active or _pending_result != null:
		return
	if event.has("generation") and progression.model and event.generation != progression.model.generation:
		return
	var kind: String = event.get("kind", "")
	if kind == "result":
		_mission_result = event.duplicate(true)
		finish_run(bool(event.get("won", false)) or bool(event.get("extracted", false)) or event.get("outcome", "") == "extracted")
		return
	missions.record(event)
	if kind not in ["death", "activity_completed"] or not event.has("id"):
		return
	var key := kind + ":" + str(event.id)
	if _seen.has(key) or _seen.size() >= 8192:
		return
	_seen[key] = true
	if kind == "death" and event.get("rewarded", true):
		_raid_xp += 3
	elif kind == "activity_completed":
		_raid_xp += 30

func finish_run(success: bool) -> bool:
	if not active:
		return false
	if _pending_result != null:
		success = bool(_pending_result)
	var final_cargo := cargo_inventory()
	missions.finalize(_player, final_cargo, Catalog.ITEMS, _mission_result if not _mission_result.is_empty() else {"extracted": success})
	var before := _data().duplicate(true)
	var caravan_result: Dictionary = caravan.stage_finish(success)
	var gained_xp := 60 + _raid_xp if success else int(_raid_xp / 4)
	var overflow := 0
	if success:
		for id: String in final_cargo:
			var amount: int = final_cargo[id]
			var stored := mini(amount, 9999 - int(_data().stash.get(id, 0)))
			_data().stash[id] = int(_data().stash.get(id, 0)) + stored
			overflow += (amount - stored) * int(Catalog.ITEMS[id].sell)
		MissionProgress.commit(_data().quests, Catalog.quests(), missions.metrics)
	_data().credits = mini(1000000000, int(_data().credits) + overflow)
	_data().xp = mini(1000000000, int(_data().xp) + gained_xp)
	if not _commit(before):
		_pending_result = success
		return false
	last_result = {"success": success, "items": final_cargo.duplicate(true) if success else {}, "lost": {} if success else final_cargo.duplicate(true), "xp": gained_xp, "credits": overflow, "overflow_credits": overflow, "caravan": caravan_result}
	caravan.end_run()
	backpack.clear()
	active = false
	_pending_result = null
	notice = "Добыча перенесена в хранилище." if success else "Машина потеряна. Всё в рюкзаке потеряно."
	return true

func abandon_run() -> void:
	if active:
		last_result = {"success": false, "items": {}, "lost": cargo_inventory(), "xp": 0, "credits": 0, "overflow_credits": 0}
		caravan.end_run()
		backpack.clear()
		active = false
		_pending_result = null
		notice = "Рейд прерван. Всё в рюкзаке потеряно."

func action(kind: String, id: String) -> bool:
	if kind == "retry_save" and _pending_result != null:
		return finish_run(bool(_pending_result))
	if _pending_result != null:
		return false
	if active and kind == "discard" and _remove_cargo(id):
		notice = "Предмет выброшен."
		return true
	if active:
		notice = "Торговец и хранилище доступны между рейдами."
		return false
	var before := _data().duplicate(true)
	var changed := false
	match kind:
		"buy", "sell", "equip", "unequip": changed = _item_action(kind, id)
		"accept":
			var definitions := Catalog.quests()
			if definitions.has(id) and not _data().quests.has(id) and MissionProgress.active_count(_data().quests) < MissionProgress.LIMIT and Catalog.account(_data().xp).level >= int(definitions[id].min_level):
				_data().quests[id] = {"status": "active", "progress": 0.0, "counts": MissionProgress.counts({}, definitions[id])}
				changed = true
		"abandon", "abandon_quest":
			if _data().quests.has(id) and _data().quests[id].status == "active":
				_data().quests.erase(id)
				changed = true
		"claim": changed = _claim(id)
		"upgrade": changed = _upgrade(id)
	if not changed:
		notice = "Недостаточно ресурсов или действие недоступно."
		return false
	if not _commit(before):
		return false
	notice = "Сохранено."
	return true

func _move_one(from: Dictionary, into: Dictionary, id: String) -> bool:
	if int(from.get(id, 0)) <= 0 or int(into.get(id, 0)) >= 9999:
		return false
	from[id] -= 1
	if from[id] == 0:
		from.erase(id)
	into[id] = int(into.get(id, 0)) + 1
	return true

func _item_action(kind: String, id: String) -> bool:
	if not Catalog.ITEMS.has(id):
		return false
	var item: Dictionary = Catalog.ITEMS[id]
	match kind:
		"buy":
			if _data().credits < item.buy or int(_data().stash.get(id, 0)) >= 9999:
				return false
			_data().credits -= item.buy
			_data().stash[id] = int(_data().stash.get(id, 0)) + 1
			return true
		"sell":
			if int(_data().stash.get(id, 0)) <= 0 or int(_data().credits) + int(item.sell) > 1000000000:
				return false
			_data().stash[id] -= 1
			if _data().stash[id] == 0:
				_data().stash.erase(id)
			_data().credits += item.sell
			return true
		"equip":
			return item.usable and Catalog.used(_data().loadout) + int(item.size) <= capacity() and _move_one(_data().stash, _data().loadout, id)
		"unequip": return _move_one(_data().loadout, _data().stash, id)
	return false

func _claim(id: String) -> bool:
	var definitions := Catalog.quests()
	if not definitions.has(id) or not _data().quests.has(id):
		return false
	var quest: Dictionary = _data().quests[id]
	var definition: Dictionary = definitions[id]
	if quest.status != "active" or not MissionProgress.objectives_met(definition, MissionProgress.counts(quest, definition)) or not MissionProgress.delivery_ready(definition, _data().stash):
		return false
	for item: String in definition.get("delivery", {}):
		_data().stash[item] -= int(definition.delivery[item])
		if _data().stash[item] == 0:
			_data().stash.erase(item)
	_data().quests[id] = {"status": "claimed", "progress": MissionProgress.total(MissionProgress.counts(quest, definition))}
	_data().credits = mini(1000000000, int(_data().credits) + int(definition.credits))
	_data().xp = mini(1000000000, int(_data().xp) + int(definition.xp))
	return true

func _upgrade(id: String) -> bool:
	if not Catalog.UPGRADES.has(id):
		return false
	var current: int = _data().upgrades[id]
	var definition: Dictionary = Catalog.UPGRADES[id]
	var required_level := current + 1
	var cost := int(definition.base_cost) * (current + 1)
	if current >= int(definition.max_level) or Catalog.account(_data().xp).level < required_level or _data().credits < cost:
		return false
	_data().credits -= cost
	_data().upgrades[id] += 1
	return true

func consume(id: String, player: Dictionary) -> bool:
	if not active or _pending_result != null or int(cargo_inventory().get(id, 0)) <= 0:
		return false
	match id:
		"repair_kit":
			if player.hp >= player.max_hp or player.hp <= 0:
				return false
			player.hp = minf(player.max_hp, player.hp + 90)
		"fuel_cell":
			if player.fuel >= player.max_fuel:
				return false
			player.fuel = minf(player.max_fuel, player.fuel + 45)
		"weapon_parts":
			if _weapon_improved:
				return false
			player.damage_mult = float(player.get("damage_mult", 1.0)) * 1.2
			_weapon_improved = true
		_: return false
	_remove_cargo(id)
	missions.consumable(id)
	notice = "Использовано: " + str(Catalog.ITEMS[id].name)
	return true

func active_missions() -> Array:
	var rows: Array = []
	var definitions := Catalog.quests()
	var pending := missions.current_metrics(cargo_inventory(), Catalog.ITEMS)
	var account_level: int = Catalog.account(_data().xp).level
	var count := MissionProgress.active_count(_data().quests)
	for id: String in _data().quests:
		if _data().quests[id].status == "active" and definitions.has(id):
			rows.append(MissionProgress.row(definitions[id], _data().quests[id], pending, account_level, active, count, _data().stash))
	return rows

func snapshot() -> Dictionary:
	var account := Catalog.account(_data().xp)
	var quests: Array = []
	var count := MissionProgress.active_count(_data().quests)
	var pending := missions.current_metrics(cargo_inventory(), Catalog.ITEMS)
	var definitions := Catalog.quests()
	for id: String in definitions:
		quests.append(MissionProgress.row(definitions[id], _data().quests.get(id, {}), pending, account.level, active, count, _data().stash))
	var upgrades: Array = []
	for id: String in Catalog.UPGRADES:
		var row: Dictionary = Catalog.UPGRADES[id].duplicate(true)
		row.id = id
		row.title = row.name
		row.level = _data().upgrades[id]
		row.required_level = row.level + 1
		row.cost = row.base_cost * (row.level + 1)
		row.cost_label = "%d кредитов · ур. аккаунта %d" % [row.cost, row.required_level]
		row.enabled = not active and row.level < row.max_level and account.level >= row.required_level and _data().credits >= row.cost
		upgrades.append(row)
	return {"active": active, "pending_result": _pending_result != null, "credits": _data().credits, "xp": account.xp, "total_xp": _data().xp, "xp_next": account.xp_next, "level": account.level, "capacity": capacity(), "used": Catalog.used(cargo_inventory() if active else _data().loadout), "stash": _data().stash.duplicate(true), "loadout": _data().loadout.duplicate(true), "backpack": cargo_inventory(), "caravan": caravan.snapshot(), "items": Catalog.ITEMS.duplicate(true), "quests": quests, "active_quest_count": count, "quest_limit": MissionProgress.LIMIT, "upgrades": upgrades, "last_result": last_result.duplicate(true), "notice": notice, "storage_status": progression.store.status}

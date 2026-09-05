extends RefCounted

const Catalog = preload("res://modules/meta/expedition_catalog.gd")
var progression: RefCounted
var active := false
var backpack: Dictionary = {}
var last_result: Dictionary = {}
var notice := ""
var _seen: Dictionary = {}
var _raid_xp := 0
var _raid_progress: Dictionary = {}
var _loot_index := 0
var _weapon_improved := false
var _pending_result: Variant = null

func _init(owner: RefCounted) -> void:
	progression = owner
	progression.profile.expedition = Catalog.normalize(progression.profile.get("expedition"))

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

func capacity() -> int:
	return 12 + 4 * int(_data().upgrades.cargo)

func begin_run(player: Dictionary) -> bool:
	if active:
		return false
	var before := _data().duplicate(true)
	var carried: Dictionary = _data().loadout.duplicate(true)
	_data().loadout.clear()
	if not _commit(before):
		return false
	backpack = carried
	active = true
	last_result.clear()
	_seen.clear()
	_raid_progress.clear()
	_raid_xp = 0
	_loot_index = 0
	_weapon_improved = false
	_pending_result = null
	var armor := 20 * int(_data().upgrades.armor)
	player.max_hp = float(player.get("max_hp", 250)) + armor
	player.hp = minf(player.max_hp, float(player.get("hp", player.max_hp)) + armor)
	player.motor_speed_mult = float(player.get("motor_speed_mult", 1.0)) * (1.0 + 0.03 * int(_data().upgrades.engine))
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
	if accepted > int((capacity() - Catalog.used(backpack)) / int(Catalog.ITEMS[id].size)):
		notice = "Рюкзак заполнен. Используйте припасы или эвакуируйтесь."
		return false
	backpack[id] = int(backpack.get(id, 0)) + accepted
	_loot_index += 1
	_raid_xp += accepted * (12 if id == "relic" else 5)
	_progress("scrap", accepted if id == "scrap" else 0)
	notice = "+%d %s" % [accepted, Catalog.ITEMS[id].name]
	return true

func _progress(event: String, amount: int) -> void:
	if amount <= 0:
		return
	for id: String in _data().quests:
		if _data().quests[id].status == "active" and Catalog.QUESTS[id].event == event:
			_raid_progress[id] = int(_raid_progress.get(id, 0)) + amount

func record_event(event: Dictionary) -> void:
	if not active or _pending_result != null:
		return
	if event.has("generation") and progression.model and event.generation != progression.model.generation:
		return
	var kind: String = event.get("kind", "")
	if kind == "result":
		finish_run(bool(event.get("won", false)) or bool(event.get("extracted", false)) or event.get("outcome", "") == "extracted")
		return
	if kind not in ["death", "activity_completed"] or not event.has("id"):
		return
	var key := kind + ":" + str(event.id)
	if _seen.has(key) or _seen.size() >= 8192:
		return
	_seen[key] = true
	if kind == "death" and event.get("rewarded", true):
		_raid_xp += 3
		_progress("kills", 1)
	elif kind == "activity_completed":
		_raid_xp += 30
		if event.get("activity_type", "") == "settlementDistress":
			_progress("rescues", 1)

func finish_run(success: bool) -> bool:
	if not active:
		return false
	if _pending_result != null:
		success = bool(_pending_result)
	var before := _data().duplicate(true)
	var gained_xp := 60 + _raid_xp if success else int(_raid_xp / 4)
	var overflow := 0
	if success:
		for id: String in backpack:
			var amount: int = backpack[id]
			var stored := mini(amount, 9999 - int(_data().stash.get(id, 0)))
			_data().stash[id] = int(_data().stash.get(id, 0)) + stored
			overflow += (amount - stored) * int(Catalog.ITEMS[id].sell)
		for id: String in _raid_progress:
			var amount: int = _raid_progress[id]
			if id == "first_delivery":
				amount = mini(amount, int(backpack.get("scrap", 0)))
			_data().quests[id].progress = mini(Catalog.QUESTS[id].target, int(_data().quests[id].progress) + amount)
	_data().credits = mini(1000000000, int(_data().credits) + overflow)
	_data().xp = mini(1000000000, int(_data().xp) + gained_xp)
	if not _commit(before):
		_pending_result = success
		return false
	last_result = {"success": success, "items": backpack.duplicate(true) if success else {}, "lost": {} if success else backpack.duplicate(true), "xp": gained_xp, "credits": overflow, "overflow_credits": overflow}
	backpack.clear()
	active = false
	_pending_result = null
	notice = "Добыча перенесена в хранилище." if success else "Машина потеряна. Всё в рюкзаке потеряно."
	return true

func abandon_run() -> void:
	if active:
		last_result = {"success": false, "items": {}, "lost": backpack.duplicate(true), "xp": 0, "credits": 0, "overflow_credits": 0}
		backpack.clear()
		active = false
		_pending_result = null
		notice = "Рейд прерван. Всё в рюкзаке потеряно."

func action(kind: String, id: String) -> bool:
	if kind == "retry_save" and _pending_result != null:
		return finish_run(bool(_pending_result))
	if _pending_result != null:
		return false
	if active and kind == "discard" and int(backpack.get(id, 0)) > 0:
		backpack[id] -= 1
		if backpack[id] == 0:
			backpack.erase(id)
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
			if Catalog.QUESTS.has(id) and not _data().quests.has(id):
				_data().quests[id] = {"status": "active", "progress": 0}
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
	if not Catalog.QUESTS.has(id) or not _data().quests.has(id):
		return false
	var quest: Dictionary = _data().quests[id]
	var definition: Dictionary = Catalog.QUESTS[id]
	if quest.status != "active" or quest.progress < definition.target:
		return false
	if id == "first_delivery":
		if int(_data().stash.get("scrap", 0)) < int(definition.target):
			return false
		_data().stash.scrap -= definition.target
		if _data().stash.scrap == 0:
			_data().stash.erase("scrap")
	quest.status = "claimed"
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
	if not active or _pending_result != null or int(backpack.get(id, 0)) <= 0:
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
	backpack[id] -= 1
	if backpack[id] == 0:
		backpack.erase(id)
	notice = "Использовано: " + str(Catalog.ITEMS[id].name)
	return true

func snapshot() -> Dictionary:
	var account := Catalog.account(_data().xp)
	var quests: Array = []
	for id: String in Catalog.QUESTS:
		var row: Dictionary = Catalog.QUESTS[id].duplicate(true)
		var state: Dictionary = _data().quests.get(id, {"status": "available", "progress": 0})
		row.id = id
		row.title = row.name
		row.status = "ready" if state.status == "active" and state.progress >= row.target else state.status
		row.progress = state.progress
		row.raid_progress = int(_raid_progress.get(id, 0)) if active else 0
		row.can_claim = not active and state.status == "active" and state.progress >= row.target and (id != "first_delivery" or int(_data().stash.get("scrap", 0)) >= row.target)
		row.reward_label = "%d кредитов · %d XP" % [row.credits, row.xp]
		quests.append(row)
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
	return {"active": active, "pending_result": _pending_result != null, "credits": _data().credits, "xp": account.xp, "total_xp": _data().xp, "xp_next": account.xp_next, "level": account.level, "capacity": capacity(), "used": Catalog.used(backpack if active else _data().loadout), "stash": _data().stash.duplicate(true), "loadout": _data().loadout.duplicate(true), "backpack": backpack.duplicate(true), "items": Catalog.ITEMS.duplicate(true), "quests": quests, "upgrades": upgrades, "last_result": last_result.duplicate(true), "notice": notice, "storage_status": progression.store.status}

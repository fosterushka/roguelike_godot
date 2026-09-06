extends RefCounted
const Catalog = preload("res://modules/caravan/wagon_catalog.gd")
const Factory = preload("res://modules/caravan/wagon_factory.gd")
const Save = preload("res://modules/caravan/caravan_save.gd")
const CrewFactory = preload("res://modules/crew/crew_factory.gd")
const CrewCatalog = preload("res://modules/crew/crew_catalog.gd")
var progression: RefCounted
var active := false
var locked := false
var wagons: Array[Dictionary] = []
var crew: Array[Dictionary] = []
var events: Array[Dictionary] = []
var notice := ""
var _player: Dictionary = {}
var _next_rescue_id := 0
var _rescue_id_limit := 0
var _rescued_sources := {}

func _init(owner: RefCounted) -> void:
	progression = owner

func data() -> Dictionary:
	return progression.profile.expedition.caravan

func _commit(before: Dictionary) -> bool:
	progression._mark_dirty()
	if progression.flush():
		return true
	progression.profile.expedition = before
	progression._mark_dirty()
	notice = "Не удалось сохранить состав. Действие отменено."
	return false

func buy_wagon(type: String) -> bool:
	if active or not Catalog.TYPES.has(type) or data().wagons.size() >= Catalog.MAX_WAGONS or data().next_id >= 999999900:
		return false
	var cost: int = Catalog.TYPES[type].cost
	if progression.profile.expedition.credits < cost:
		return false
	var before: Dictionary = progression.profile.expedition.duplicate(true)
	var id := "wagon-%d" % int(data().next_id)
	data().next_id += 1
	data().wagons[id] = Factory.save(Factory.create(type, id))
	data().selected_wagon_ids.append(id)
	progression.profile.expedition.credits -= cost
	return _commit(before)

func select_wagon(id: String, selected: bool = true) -> bool:
	if active or not data().wagons.has(id):
		return false
	var before: Dictionary = progression.profile.expedition.duplicate(true)
	data().selected_wagon_ids.erase(id)
	if selected:
		data().selected_wagon_ids.append(id)
	return _commit(before)

func select_crew(id: String, selected: bool = true) -> bool:
	if active or not data().crew.has(id):
		return false
	var before: Dictionary = progression.profile.expedition.duplicate(true)
	data().selected_crew_ids.erase(id)
	if selected:
		data().selected_crew_ids.append(id)
	return _commit(before)

func assign(id: String, carrier_id: String, seat: int) -> bool:
	if locked or seat < 0 or seat >= 2:
		return false
	var person: Dictionary = find_crew(id) if active else data().crew.get(id, {})
	var carrier: Dictionary = find_wagon(carrier_id) if active else data().wagons.get(carrier_id, {})
	if person.is_empty() or (carrier_id != "crawler" and (carrier.is_empty() or carrier.get("dead", false) or not carrier.get("attached", true))):
		return false
	var people: Array = crew if active else data().crew.values()
	for other: Dictionary in people:
		if other.id != id and not other.get("dead", false) and other.get("carrier_id", "") == carrier_id and int(other.get("seat", -1)) == seat:
			return false
	if active:
		if person.dead or person.get("airborne", false) or absf(float(_player.get("speed", 0))) > 1.5:
			return false
		var destination: Vector3 = _player.get("position", Vector3.ZERO) if carrier_id == "crawler" else carrier.position
		if not person.boarded and person.position.distance_to(destination) > 6.0:
			return false
		person.carrier_id = carrier_id
		person.seat = seat
		# A nearby survivor walks the final distance; they are never teleported aboard.
		if not person.boarded:
			person.recall = true
			person.state = "returning"
		return true
	var before: Dictionary = progression.profile.expedition.duplicate(true)
	person.carrier_id = carrier_id
	person.seat = seat
	return _commit(before)

func install_attachment(wagon_id: String, slot: int, type: String) -> bool:
	if active:
		return _install_raid_attachment(wagon_id, slot, type)
	if not data().wagons.has(wagon_id) or not Catalog.ATTACHMENTS.has(type) or slot < 0 or slot >= 3:
		return false
	var saved: Dictionary = data().wagons[wagon_id]
	var definition: Dictionary = Catalog.ATTACHMENTS[type]
	if progression.profile.expedition.credits < int(definition.cost) or float(definition.mass) > float(Catalog.mounts()[slot].max_mass):
		return false
	for module: Dictionary in saved.modules:
		if int(module.mount.slot) == slot:
			return false
	for entry: Dictionary in saved.attachments:
		if int(entry.slot) == slot or entry.type == type:
			return false
	var before: Dictionary = progression.profile.expedition.duplicate(true)
	saved.attachments.append({"type": type, "slot": slot})
	saved.hp += float(definition.get("armor_hp", 0))
	progression.profile.expedition.credits -= int(definition.cost)
	return _commit(before)

func remove_attachment(wagon_id: String, slot: int) -> bool:
	if active:
		return _remove_raid_attachment(wagon_id, slot)
	if not data().wagons.has(wagon_id):
		return false
	var wagon: Dictionary = data().wagons[wagon_id]
	for entry: Dictionary in wagon.attachments:
		if int(entry.slot) != slot:
			continue
		var before: Dictionary = progression.profile.expedition.duplicate(true)
		wagon.attachments.erase(entry)
		wagon.hp = minf(wagon.hp, Factory.create(wagon.type, wagon_id, wagon).max_hp)
		progression.profile.expedition.credits += int(Catalog.ATTACHMENTS[entry.type].cost) / 2
		return _commit(before)
	return false

# Called inside Expedition's existing start/result transaction, before its single flush.
func stage_begin() -> Dictionary:
	var staged := {"wagons": [], "crew": [], "unpaid": [], "next_rescue_id": int(data().next_id), "rescue_limit": int(data().next_id) + 64}
	data().next_id += 64
	for id: String in data().selected_wagon_ids.duplicate():
		if data().wagons.has(id):
			staged.wagons.append(Factory.create(data().wagons[id].type, id, data().wagons[id]))
			data().wagons.erase(id)
	data().selected_wagon_ids.clear()
	var occupied := {}
	var allowed := {"crawler": true}
	for wagon: Dictionary in staged.wagons:
		allowed[wagon.id] = true
	for id: String in data().selected_crew_ids.duplicate():
		var saved: Dictionary = data().crew.get(id, {})
		if saved.is_empty():
			continue
		var person := CrewFactory.restore(saved)
		var carrier_id := str(person.carrier_id)
		if not allowed.has(carrier_id):
			continue
		var seat := int(person.seat)
		if seat < 0 or occupied.has(carrier_id + ":" + str(seat)):
			seat = 0 if not occupied.has(carrier_id + ":0") else 1 if not occupied.has(carrier_id + ":1") else -1
		if seat < 0:
			continue
		if int(progression.profile.expedition.stash.get("scrap", 0)) < int(person.wage):
			staged.unpaid.append(id)
			continue
		progression.profile.expedition.stash.scrap -= int(person.wage)
		if progression.profile.expedition.stash.scrap == 0:
			progression.profile.expedition.stash.erase("scrap")
		person.seat = seat
		occupied[carrier_id + ":" + str(seat)] = true
		staged.crew.append(person)
		data().crew.erase(id)
		data().selected_crew_ids.erase(id)
	return staged

func activate(staged: Dictionary, player: Dictionary) -> void:
	wagons.assign(staged.wagons)
	crew.assign(staged.crew)
	_player = player
	player.carriers = wagons
	player.crew = crew
	_next_rescue_id = staged.next_rescue_id
	_rescue_id_limit = staged.rescue_limit
	_rescued_sources.clear()
	events.clear()
	active = true
	locked = false
	for person: Dictionary in crew:
		person.position = player.get("position", Vector3.ZERO)
	notice = "%d сотрудников остались в убежище без оплаты." % staged.unpaid.size() if not staged.unpaid.is_empty() else ""

func capture_modules() -> void:
	for wagon: Dictionary in wagons:
		if not wagon.attached or wagon.dead:
			continue
		wagon.modules.clear()
		for module: Dictionary in _player.get("modules", []):
			var mount: Dictionary = module.get("mount", {})
			if mount.get("carrierId", "") == wagon.id:
				wagon.modules.append({"type": module.type, "level": module.get("level", 1), "mount": {"carrierId": wagon.id, "slot": mount.slot}})

func stage_finish(success: bool) -> Dictionary:
	locked = true
	capture_modules()
	var result := {"wagons_returned": [], "crew_returned": [], "wagons_lost": [], "crew_lost": []}
	for wagon: Dictionary in wagons:
		if success and wagon.attached and not wagon.dead and wagon.hp > 0:
			data().wagons[wagon.id] = Factory.save(wagon)
			if not data().selected_wagon_ids.has(wagon.id):
				data().selected_wagon_ids.append(wagon.id)
			result.wagons_returned.append(wagon.id)
		else:
			result.wagons_lost.append(wagon.id)
	for person: Dictionary in crew:
		if success and not person.dead and person.hp > 0 and person.boarded and (person.carrier_id == "crawler" or result.wagons_returned.has(person.carrier_id)):
			data().crew[person.id] = CrewFactory.save(person)
			if not data().selected_crew_ids.has(person.id):
				data().selected_crew_ids.append(person.id)
			result.crew_returned.append(person.id)
		else:
			result.crew_lost.append(person.id)
	return result

func end_run() -> void:
	active = false
	locked = false
	wagons.clear()
	crew.clear()
	_rescued_sources.clear()

func find_wagon(id: String) -> Dictionary:
	for wagon: Dictionary in wagons:
		if wagon.id == id:
			return wagon
	return {}

func find_crew(id: String) -> Dictionary:
	for person: Dictionary in crew:
		if person.id == id:
			return person
	return {}

func free_seat(carrier_id: String = "") -> Dictionary:
	var candidates := ["crawler"]
	for wagon: Dictionary in wagons:
		if wagon.attached and not wagon.dead:
			candidates.append(wagon.id)
	if not carrier_id.is_empty():
		candidates = [carrier_id] if candidates.has(carrier_id) else []
	for id: String in candidates:
		for seat in 2:
			var occupied := false
			for person: Dictionary in crew:
				occupied = occupied or (not person.dead and person.carrier_id == id and person.seat == seat)
			if not occupied:
				return {"carrier_id": id, "seat": seat}
	return {}

func rescue(npc: Dictionary, carrier_id: String = "") -> bool:
	if not active or locked or npc.get("faction", "") != "neutral" or npc.get("dead", false) or float(npc.get("hp", 0)) <= 0 or not CrewCatalog.ROLES.has(npc.get("role", "")) or _next_rescue_id >= _rescue_id_limit or data().crew.size() + crew.size() >= Catalog.MAX_CREW:
		return false
	var source := str(npc.get("id", ""))
	if source.is_empty() or _rescued_sources.has(source) or absf(float(_player.get("speed", 0))) > 1.5 or npc.position.distance_to(_player.get("position", Vector3.ZERO)) > 6.0:
		return false
	var seat := free_seat(carrier_id)
	if seat.is_empty():
		return false
	_rescued_sources[source] = true
	npc.source_id = source
	npc.id = "crew-%d" % _next_rescue_id
	_next_rescue_id += 1
	npc.faction = "ally"
	npc.rescued = true
	npc.boarded = true
	npc.state = "boarded"
	npc.carrier_id = seat.carrier_id
	npc.seat = seat.seat
	crew.append(npc)
	events.append({"kind": "crew_rescued", "id": npc.id, "source_id": source, "role": npc.role})
	return true

func damage_crew(id: String, amount: float) -> bool:
	var person := find_crew(id)
	if not active or locked or person.is_empty() or person.dead or not is_finite(amount) or amount <= 0:
		return false
	person.hp = maxf(0, person.hp - amount)
	if person.hp <= 0:
		person.dead = true
		person.boarded = false
		person.state = "dead"
		events.append({"kind": "crew_died", "id": id, "role": person.role, "position": person.position})
	return true

func damage_wagon(id: String, amount: float) -> Dictionary:
	var wagon := find_wagon(id)
	if not active or locked or wagon.is_empty() or wagon.dead or not is_finite(amount) or amount <= 0:
		return {}
	wagon.hp = maxf(0, wagon.hp - amount * (1.0 - clampf(float(wagon.get("armor", 0)), 0, 0.6)))
	if wagon.hp > 0:
		return {"destroyed": false, "id": id}
	capture_modules()
	wagon.dead = true
	var detached: Array = []
	for index in range(wagons.find(wagon), wagons.size()):
		wagons[index].attached = false
		detached.append(wagons[index].id)
	var drops := {}
	for item: String in wagon.cargo:
		var amount_dropped := int(int(wagon.cargo[item]) / 2)
		if amount_dropped > 0:
			drops[item] = amount_dropped
	wagon.cargo.clear()
	for person: Dictionary in crew:
		if person.carrier_id == id and not person.dead and person.boarded:
			damage_crew(person.id, person.hp)
	var result := {"kind": "wagon_destroyed", "id": id, "destroyed": true, "detached_ids": detached, "drops": drops, "position": wagon.position}
	events.append(result)
	return result

func recouple(id: String) -> bool:
	var wagon := find_wagon(id)
	if not active or locked or wagon.is_empty() or wagon.dead or wagon.attached or absf(float(_player.get("speed", 0))) > 1.5 or wagon.position.distance_to(_player.get("position", Vector3.ZERO)) > 8.0:
		return false
	for index in range(wagons.find(wagon), wagons.size()):
		if wagons[index].dead:
			break
		wagons[index].attached = true
	events.append({"kind": "wagon_recoupled", "id": id})
	return true

func cargo_containers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for wagon: Dictionary in wagons:
		if wagon.attached and not wagon.dead:
			result.append(wagon)
	return result

func snapshot() -> Dictionary:
	return {"active": active, "locked": locked, "wagons": wagons.duplicate(true) if active else data().wagons.values().duplicate(true), "crew": crew.duplicate(true) if active else data().crew.values().duplicate(true), "selected_wagon_ids": data().selected_wagon_ids.duplicate(), "selected_crew_ids": data().selected_crew_ids.duplicate(), "types": Catalog.TYPES.duplicate(true), "attachments": Catalog.ATTACHMENTS.duplicate(true), "roles": CrewCatalog.ROLES.duplicate(true), "max_wagons": Catalog.MAX_WAGONS, "wage_currency": "stash_scrap", "notice": notice, "player_position": _player.get("position", Vector3.ZERO) if active else Vector3.ZERO, "player_speed": float(_player.get("speed", 0)) if active else 0.0}

func drain_events() -> Array[Dictionary]:
	var result := events.duplicate(true)
	events.clear()
	return result

func _slot_free(wagon: Dictionary, slot: int) -> bool:
	for entry: Dictionary in wagon.attachments:
		if int(entry.slot) == slot:
			return false
	for module: Dictionary in _player.get("modules", []):
		var mount: Dictionary = module.get("mount", {})
		if mount.get("carrierId", "") == wagon.id and int(mount.get("slot", -1)) == slot:
			return false
	return true

func _refresh_wagon(wagon: Dictionary, hp_gain: float = 0.0) -> void:
	var rebuilt := Factory.create(wagon.type, wagon.id, {"hp": wagon.hp, "attachments": wagon.attachments})
	for key: String in ["max_hp", "mass", "weight", "cargo_capacity", "hitch_strength"]:
		wagon[key] = rebuilt[key]
	for module: Dictionary in _player.get("modules", []):
		if module.get("armor_applied", false) and module.get("mount", {}).get("carrierId", "") == wagon.id:
			wagon.max_hp += 55
	wagon.hp = minf(wagon.max_hp, wagon.hp + hp_gain)
	events.append({"kind": "wagon_equipment_changed", "id": wagon.id})

func _install_raid_attachment(wagon_id: String, slot: int, type: String) -> bool:
	var wagon := find_wagon(wagon_id)
	if locked or wagon.is_empty() or wagon.dead or not wagon.attached or slot < 0 or slot >= 3 or not Catalog.ATTACHMENTS.has(type) or not _slot_free(wagon, slot):
		return false
	for entry: Dictionary in wagon.attachments:
		if entry.type == type:
			return false
	var definition: Dictionary = Catalog.ATTACHMENTS[type]
	var cost := maxi(18, roundi(float(definition.cost) * 0.35))
	if float(_player.get("coins", 0)) < cost:
		return false
	_player.coins -= cost
	wagon.attachments.append({"type": type, "slot": slot})
	_refresh_wagon(wagon, float(definition.get("armor_hp", 0)))
	return true

func _remove_raid_attachment(wagon_id: String, slot: int) -> bool:
	var wagon := find_wagon(wagon_id)
	if locked or wagon.is_empty() or wagon.dead or not wagon.attached:
		return false
	for entry: Dictionary in wagon.attachments:
		if int(entry.slot) != slot:
			continue
		var definition: Dictionary = Catalog.ATTACHMENTS[entry.type]
		if Catalog.cargo_used(wagon.cargo) > int(wagon.cargo_capacity) - int(definition.get("cargo", 0)):
			return false
		wagon.attachments.erase(entry)
		_player.coins += int(maxi(18, roundi(float(definition.cost) * 0.35)) / 2)
		_refresh_wagon(wagon)
		return true
	return false

func attachment_rows(carrier_id: String) -> Array:
	var wagon := find_wagon(carrier_id) if active else Factory.create(str(data().wagons.get(carrier_id, {}).get("type", "")), carrier_id, data().wagons.get(carrier_id, {}))
	if wagon.is_empty():
		return []
	var result: Array = []
	for type: String in Catalog.ATTACHMENTS:
		var definition: Dictionary = Catalog.ATTACHMENTS[type]
		var slot := -1
		var installed := false
		for entry: Dictionary in wagon.attachments:
			installed = installed or entry.type == type
		for candidate in 3:
			var occupied := false
			for entry: Dictionary in wagon.attachments:
				occupied = occupied or int(entry.slot) == candidate
			for module: Dictionary in (_player.get("modules", []) if active else wagon.modules):
				var mount: Dictionary = module.get("mount", {})
				occupied = occupied or (mount.get("carrierId", "") == carrier_id and int(mount.get("slot", -1)) == candidate)
			if not occupied and slot < 0:
				slot = candidate
		var cost := maxi(18, roundi(float(definition.cost) * 0.35)) if active else int(definition.cost)
		var funds := int(_player.get("coins", 0)) if active else int(progression.profile.expedition.credits)
		result.append({"id": "attachment:%s:%s:%d" % [type, carrier_id, slot], "type": type, "carrier_id": carrier_id, "slot": slot, "label": definition.name, "name_en": definition.name_en, "description": "Масса +%.1f" % definition.mass, "cost": cost, "currency": "salvage" if active else "credits", "enabled": not locked and not wagon.dead and wagon.attached and slot >= 0 and not installed and funds >= cost, "disabled_reason": "Установлено" if installed else "Нет свободного крепления" if slot < 0 else "Недостаточно средств" if funds < cost else ""})
	return result

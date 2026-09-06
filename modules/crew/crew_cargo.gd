extends RefCounted
# A claimed parcel belongs to one person until they reach their boarding seat.
# It deliberately never enters save data: death or extraction while outside loses it.
var parcel: Dictionary = {}

func collect_loot(source: String, count: int = 1) -> bool:
	if not parcel.is_empty() or count != 1:
		return false
	parcel = {"kind": "cargo", "source": source, "count": count}
	return true

static func claim(person: Dictionary, pickup: Dictionary, loot: Node3D, model: RefCounted) -> bool:
	if person.get("dead", false) or person.has("carried_parcel") or pickup.get("dead", false):
		return false
	if pickup.has("crate_id"):
		var receiver: RefCounted = load("res://modules/crew/crew_cargo.gd").new()
		if not loot.claim(str(pickup.crate_id), receiver):
			return false
		person.carried_parcel = receiver.parcel
		pickup.count = maxi(0, int(pickup.count) - 1)
		return true
	if pickup.has("combat_id"):
		for original: Dictionary in model.pickups:
			if int(original.id) != int(pickup.combat_id) or original.dead:
				continue
			person.carried_parcel = {"kind": "combat", "pickup": original.duplicate(true)}
			original.dead = true
			pickup.dead = true
			return true
	return false

static func deliver(person: Dictionary, expedition: RefCounted, model: RefCounted) -> bool:
	if person.get("dead", false):
		return false
	if not person.has("carried_parcel"):
		return true
	var held: Dictionary = person.carried_parcel
	if held.kind == "cargo":
		if not expedition.collect_loot(str(held.source), int(held.count)):
			return false
	else:
		var pickup: Dictionary = held.pickup.duplicate(true)
		if not model.running or model.status in ["dead", "complete", "extracted"]:
			return false
		if pickup.kind == "fuel":
			if float(model.player.max_fuel) - float(model.player.fuel) < float(pickup.value):
				expedition.notice = "Сборщик ждёт у борта: топливный бак полон."
				return false
		elif not expedition.collect_loot("salvage", 1):
			return false
		# Reuse the authoritative pickup transaction without respawning a world object.
		pickup.dead = false
		pickup.position = person.position
		var previous: Array = model.pickups.filter(func(entry): return int(entry.id) == int(pickup.id))
		for entry: Dictionary in previous:
			model.pickups.erase(entry)
		model.pickups.append(pickup)
		model.collect_pickup(int(pickup.id))
		model.pickups.erase(pickup)
		for event: Dictionary in model.events:
			if event.get("kind", "") == "pickup" and int(event.get("id", -1)) == int(pickup.id):
				event.cargo_delivered = true
				event.crew_id = person.id
	person.erase("carried_parcel")
	return true

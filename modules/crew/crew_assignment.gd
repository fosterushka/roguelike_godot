extends RefCounted
const Encounter = preload("res://modules/crew/crew_encounter.gd")

static func plan(people: Array, wagons: Array, budget: int = 2147483647) -> Dictionary:
	var result := {}
	var occupied := {}
	# Reserve profession matches before filling remaining general seats.
	for person: Dictionary in people:
		if budget < int(person.get("wage", 0)):
			continue
		for wagon: Dictionary in wagons:
			if wagon.get("type", "") == Encounter.PREFERRED.get(person.role, ""):
				if _take(person.id, wagon.id, occupied, result):
					budget -= int(person.get("wage", 0))
					break
	for person: Dictionary in people:
		if result.has(person.id) or person.role == "civilian" or budget < int(person.get("wage", 0)):
			continue
		if _take(person.id, "crawler", occupied, result):
			budget -= int(person.get("wage", 0))
			continue
		for wagon: Dictionary in wagons:
			if _take(person.id, wagon.id, occupied, result):
				budget -= int(person.get("wage", 0))
				break
	return result

static func _take(id: String, carrier: String, occupied: Dictionary, result: Dictionary) -> bool:
	for seat in 2:
		var key := carrier + ":" + str(seat)
		if not occupied.has(key):
			occupied[key] = true
			result[id] = {"carrier_id": carrier, "seat": seat}
			return true
	return false

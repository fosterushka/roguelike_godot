extends RefCounted
const Wagons = preload("res://modules/caravan/wagon_catalog.gd")
const Factory = preload("res://modules/caravan/wagon_factory.gd")
const Crew = preload("res://modules/crew/crew_catalog.gd")
const CrewFactory = preload("res://modules/crew/crew_factory.gd")

static func defaults() -> Dictionary:
	return {"next_id": 1, "wagons": {}, "crew": {}, "selected_wagon_ids": [], "selected_crew_ids": []}

static func number(value: Variant, maximum: float, fallback: float = 0.0) -> float:
	return clampf(float(value), 0.0, maximum) if (value is int or value is float) and is_finite(float(value)) else fallback

static func valid_id(id: Variant, prefix: String) -> bool:
	return id is String and id.begins_with(prefix + "-") and id.trim_prefix(prefix + "-").is_valid_int() and int(id.trim_prefix(prefix + "-")) > 0 and int(id.trim_prefix(prefix + "-")) <= 1000000000

static func normalize(value: Variant) -> Dictionary:
	var result := defaults()
	if not value is Dictionary:
		return result
	result.next_id = maxi(1, int(number(value.get("next_id", 1), 1000000000, 1)))
	var wagons: Variant = value.get("wagons", {})
	if wagons is Dictionary:
		for id: Variant in wagons:
			if result.wagons.size() >= Wagons.MAX_WAGONS:
				break
			var raw: Variant = wagons[id]
			if not valid_id(id, "wagon") or not raw is Dictionary or not Wagons.TYPES.has(raw.get("type", "")):
				continue
			var saved := {"modules": [], "attachments": []}
			var occupied := {}
			for field: String in ["modules", "attachments"]:
				var entries: Variant = raw.get(field, [])
				if not entries is Array:
					continue
				for entry: Variant in entries:
					if not entry is Dictionary or not entry.get("type") is String:
						continue
					var mount: Variant = entry.get("mount", {})
					var slot_value: Variant = entry.get("slot", mount.get("slot", -1) if mount is Dictionary else -1)
					if not (slot_value is int or slot_value is float) or not is_finite(float(slot_value)) or float(slot_value) != floor(float(slot_value)) or int(slot_value) < 0 or int(slot_value) >= 3 or occupied.has(int(slot_value)):
						continue
					var slot := int(slot_value)
					if field == "attachments":
						if not Wagons.ATTACHMENTS.has(entry.type):
							continue
						saved.attachments.append({"type": entry.type, "slot": slot})
					else:
						if entry.type.length() > 80 or entry.type.is_empty():
							continue
						saved.modules.append({"type": entry.type, "level": maxi(1, int(number(entry.get("level", 1), 5, 1))), "mount": {"carrierId": id, "slot": slot}})
					occupied[slot] = true
			var wagon := Factory.create(raw.type, id, saved)
			wagon.hp = number(raw.get("hp", wagon.max_hp), wagon.max_hp, wagon.max_hp)
			if wagon.hp <= 0:
				continue
			result.wagons[id] = Factory.save(wagon)
			result.next_id = maxi(result.next_id, int(id.trim_prefix("wagon-")) + 1)
	var assigned := {}
	var people: Variant = value.get("crew", {})
	if people is Dictionary:
		for id: Variant in people:
			if result.crew.size() >= Wagons.MAX_CREW:
				break
			var raw: Variant = people[id]
			if not valid_id(id, "crew") or not raw is Dictionary or not Crew.ROLES.has(raw.get("role", "")):
				continue
			var person := CrewFactory.create(raw.role, id)
			person.identity = clampi(int(number(raw.get("identity", person.identity), 7, person.identity)), 0, 7)
			person.hp = number(raw.get("hp", person.max_hp), person.max_hp, person.max_hp)
			if person.hp <= 0:
				continue
			person.carrier_id = str(raw.get("carrier_id", "crawler"))
			if person.carrier_id != "crawler" and not result.wagons.has(person.carrier_id):
				person.carrier_id = "crawler"
			var seat: Variant = raw.get("seat", -1)
			person.seat = int(seat) if (seat is int or seat is float) and is_finite(float(seat)) and float(seat) == floor(float(seat)) and int(seat) in [-1, 0, 1] else -1
			var assignment: String = str(person.carrier_id) + ":" + str(person.seat)
			if person.seat >= 0:
				if assigned.has(assignment):
					person.seat = -1
				else:
					assigned[assignment] = true
			result.crew[id] = CrewFactory.save(person)
			result.next_id = maxi(result.next_id, int(id.trim_prefix("crew-")) + 1)
	for field: String in ["selected_wagon_ids", "selected_crew_ids"]:
		var entries: Variant = value.get(field, [])
		var source: Dictionary = result.wagons if field == "selected_wagon_ids" else result.crew
		if entries is Array:
			for id: Variant in entries:
				if id is String and source.has(id) and not result[field].has(id):
					result[field].append(id)
	return result

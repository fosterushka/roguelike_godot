extends RefCounted
const Catalog = preload("res://modules/crew/crew_catalog.gd")

static func create(role: String, id: String, position: Vector3 = Vector3.ZERO, neutral: bool = false) -> Dictionary:
	if not Catalog.ROLES.has(role):
		return {}
	var definition: Dictionary = Catalog.ROLES[role]
	return {"id": id, "role": role, "name": definition.name, "name_en": definition.name_en, "hp": definition.hp, "max_hp": definition.hp, "wage": definition.wage, "position": position, "heading": 0.0, "radius": 0.65, "height": 1.7, "faction": "neutral" if neutral else "ally", "targetable": true, "dead": false, "boarded": not neutral, "carrier_id": "crawler", "seat": -1, "state": "stranded" if neutral else "boarded", "cooldown": 0.0, "rescued": false, "work_total": 0.0}

static func create_neutral(role: String, id: String, position: Vector3) -> Dictionary:
	return create(role, id, position, true)

static func restore(value: Dictionary) -> Dictionary:
	var person := create(value.role, value.id)
	if not person.is_empty():
		person.hp = clampf(float(value.get("hp", person.max_hp)), 0, person.max_hp)
		person.dead = person.hp <= 0
		person.carrier_id = str(value.get("carrier_id", "crawler"))
		person.seat = int(value.get("seat", -1))
	return person

static func save(person: Dictionary) -> Dictionary:
	return {"id": person.id, "role": person.role, "hp": person.hp, "carrier_id": person.carrier_id, "seat": person.seat}

extends RefCounted
const Catalog = preload("res://modules/caravan/wagon_catalog.gd")

static func create(type: String, id: String, saved: Dictionary = {}) -> Dictionary:
	if not Catalog.TYPES.has(type):
		return {}
	var definition: Dictionary = Catalog.TYPES[type]
	var wagon := {"id": id, "type": type, "name": definition.name, "name_en": definition.name_en, "hp": definition.max_hp, "max_hp": definition.max_hp, "mass": definition.mass, "weight": definition.mass, "cargo_capacity": definition.cargo_capacity, "crew_slots": definition.crew_slots, "slotCount": 3, "mounts": Catalog.mounts(), "attachments": saved.get("attachments", []).duplicate(true), "modules": saved.get("modules", []).duplicate(true), "cargo": {}, "attached": true, "dead": false, "position": Vector3.ZERO, "heading": 0.0, "radius": 2.2, "height": 2.0, "faction": "ally", "targetable": true, "hitch_strength": 1.0}
	for installation: Dictionary in wagon.attachments:
		var attachment: Dictionary = Catalog.ATTACHMENTS.get(installation.get("type", ""), {})
		wagon.mass += float(attachment.get("mass", 0))
		wagon.max_hp += float(attachment.get("armor_hp", 0))
		wagon.cargo_capacity += int(attachment.get("cargo", 0))
		wagon.hitch_strength = maxf(wagon.hitch_strength, float(attachment.get("hitch_strength", 1.0)))
	wagon.unhydrated_armor_hp = 0.0
	for module: Dictionary in wagon.modules:
		if module.get("type", "") == "armor":
			wagon.unhydrated_armor_hp += 55.0
	wagon.max_hp += wagon.unhydrated_armor_hp
	wagon.weight = wagon.mass
	wagon.hp = clampf(float(saved.get("hp", wagon.max_hp)), 0.0, wagon.max_hp)
	wagon.dead = wagon.hp <= 0.0
	return wagon

static func save(wagon: Dictionary) -> Dictionary:
	return {"id": wagon.id, "type": wagon.type, "hp": wagon.hp, "attachments": wagon.get("attachments", []).duplicate(true), "modules": wagon.get("modules", []).duplicate(true)}

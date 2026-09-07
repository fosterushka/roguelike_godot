extends RefCounted

## Inventory uses the same cached Blender palette meshes as the world gallery.
const Equipment = preload("res://presentation/vehicles/equipment_model.gd")
const Models = preload("res://presentation/world/world_quality_models.gd")
const WEAPON_PARTS := "weapon_parts"
const FALLBACK := "loot_scrap"

static func build(item: String) -> Node3D:
	if item == WEAPON_PARTS:
		return Equipment.build("ammo_feed")
	var model := "loot_" + item
	var root := Node3D.new()
	root.name = "LootModel_" + item
	root.add_child(Models.create(model if Models.has_model(model) else FALLBACK))
	return root

extends RefCounted

const Equipment = preload("res://presentation/vehicles/equipment_model.gd")
const Catalog = preload("res://modules/caravan/wagon_catalog.gd")

static func build(type: String) -> Node3D:
	var node := Equipment.build(type)
	node.name = "Attachment_" + type
	node.set_meta("attachment_type", type)
	return node

static func prepare() -> void:
	Equipment.prepare()

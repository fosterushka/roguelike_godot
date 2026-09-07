extends RefCounted

## Authored role equipment follows the same torso pivot in gameplay and gallery.
const People = preload("res://presentation/combat/military_people.gd")
const KIT_NODE := "RoleEquipment"
const ROOT_PREFIX := "MODEL_CREW_"
static var _kits: Dictionary = {}

static func apply(root: Node3D, role: String, seated: bool = false) -> void:
	var anchor := root.get_node_or_null("Torso")
	if not seated:
		for part in root.get_children():
			if part.has_meta("source_part") and part.get_meta("source_part").get("rig", {}).get("role", "") == "body":
				anchor = part
				break
	if anchor == null:
		return
	var old := anchor.get_node_or_null(KIT_NODE)
	if old != null:
		if str(old.get_meta("role", "")) == role:
			return
		anchor.remove_child(old)
		old.queue_free()
	_prepare()
	if not _kits.has(role):
		return
	var kit := MeshInstance3D.new()
	kit.name = KIT_NODE
	kit.mesh = _kits[role]
	kit.material_override = People._material()
	kit.set_meta("role", role)
	anchor.add_child(kit)

static func _prepare() -> void:
	if not _kits.is_empty():
		return
	var library := People.LIBRARY.instantiate()
	for kit_root in library.get_children():
		var label := str(kit_root.name)
		if label.begins_with(ROOT_PREFIX) and kit_root.get_child_count() > 0:
			var visual := kit_root.get_child(0) as MeshInstance3D
			if visual != null:
				_kits[label.trim_prefix(ROOT_PREFIX).to_lower()] = visual.mesh
	library.free()

extends RefCounted

const MODEL_PATH := "res://assets/vehicles/military_equipment.glb"
const Library = preload(MODEL_PATH)
const MODEL_ALIASES := {"armor_panels": "armor"}
static var _parts: Dictionary = {}

static func prepare() -> void:
	if not _parts.is_empty():
		return
	var scene: Node3D = Library.instantiate()
	for model: Node in scene.get_children():
		if not str(model.name).begins_with("EQUIPMENT_"):
			continue
		var parts: Array = []
		for child: Node in model.get_children():
			if child is MeshInstance3D:
				parts.append({"mesh": child.mesh, "moving": str(child.name).begins_with("MOVING"), "transform": child.transform})
		_parts[str(model.name).trim_prefix("EQUIPMENT_")] = parts
	# Gameplay IDs remain separate while equivalent models share one GLB root.
	for alias: String in MODEL_ALIASES:
		var canonical: String = MODEL_ALIASES[alias]
		if _parts.has(canonical):
			_parts[alias] = _parts[canonical]
	scene.free()

static func build(type: String) -> Node3D:
	prepare()
	var root := Node3D.new()
	root.name = "Equipment_" + type
	root.set_meta("equipment_type", type)
	root.set_meta("model_path", MODEL_PATH)
	for part: Dictionary in _parts.get(type, []):
		var node := MeshInstance3D.new()
		node.name = "WeaponAssembly" if part.moving else "MountBase"
		node.mesh = part.mesh
		node.transform = part.transform
		if part.moving:
			var pivot := Node3D.new()
			pivot.name = "ElevationPivot"
			pivot.position.y = 0.52
			root.add_child(pivot)
			pivot.add_child(node)
			node.position.y -= 0.52
			root.set_meta("elevation", pivot)
		else:
			root.add_child(node)
	return root

static func animate(model: Node3D, pitch: float, recoil: float = 0.0) -> void:
	if not model.has_meta("elevation"):
		return
	var pivot: Node3D = model.get_meta("elevation")
	if is_instance_valid(pivot):
		pivot.rotation.x = clampf(pitch, -PI * 0.27, PI * 0.27)
		pivot.position.z = -0.14 * recoil

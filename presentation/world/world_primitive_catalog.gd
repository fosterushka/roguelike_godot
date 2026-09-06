extends RefCounted
const Source = preload("res://presentation/combat/source_model.gd")
const Palette = preload("res://presentation/world/military_environment_palette.gd")
static var meshes: Dictionary = {}

static func prepare() -> void:
	if not meshes.is_empty():
		return
	Source._prepare("world_primitives")
	for part: Dictionary in Source._templates.world_primitives:
		meshes[part.name] = part.mesh

static func create(shape: String, dimensions: Array, material: String, position := Vector3.ZERO, rotation := Vector3.ZERO, size := Vector3.ONE) -> MeshInstance3D:
	prepare()
	var key := shape
	for dimension in dimensions:
		key += ":%.6f" % float(dimension)
	key += ":" + material
	assert(meshes.has(key), "Missing source primitive " + key)
	var result := MeshInstance3D.new()
	result.name = material + "_" + shape
	result.mesh = meshes.get(key)
	result.material_override = Palette.material_for(Palette.role_for(material))
	result.rotation_order = EULER_ORDER_XYZ
	result.position = position
	result.rotation = rotation
	result.scale = size
	return result

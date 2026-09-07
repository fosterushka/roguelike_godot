extends RefCounted

const PaintedMaterials = preload("res://presentation/style/painted_materials.gd")
const BUNKER_COLOR := Color("4b5350")
const BARRACKS_COLOR := Color("6b6955")
const FACTORY_COLOR := Color("5b4b43")
const ROOF_COLOR := Color("302f2b")
static var _cache: Dictionary = {}

static func templates(model_name: String) -> Array:
	if _cache.has(model_name):
		return _cache[model_name]
	var result: Array = []
	match model_name:
		"garrison_1": result = _bunker()
		"garrison_2": result = _barracks()
		"garrison_3": result = _factory()
	_cache[model_name] = result
	return result

static func _bunker() -> Array:
	return [_authored("BunkerAuthored")]

static func _barracks() -> Array:
	return [_authored("BarracksAuthored")]

static func _authored(name: String) -> Dictionary:
	var library = preload("res://presentation/world/world_quality_models.gd")
	return _part(name, library.mesh_for(name), Vector3.ZERO)

static func _factory() -> Array:
	return [
		_box("FactoryRoof", Vector3(8.6, 0.48, 7.0), Vector3(0, 4.1, 0), FACTORY_COLOR),
		_box("FactoryLoadingDoor", Vector3(2.4, 2.4, 0.2), Vector3(0, 1.35, 3.28), ROOF_COLOR),
	]

static func _box(name: String, size: Vector3, position: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> Dictionary:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	return _part(name, mesh, position, rotation)

static func _cylinder(name: String, radius: float, height: float, position: Vector3, color: Color) -> Dictionary:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = _material(color)
	return _part(name, mesh, position)

static func _part(name: String, mesh: Mesh, position: Vector3, rotation: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"name": name, "mesh": mesh, "transform": Transform3D(Basis.from_euler(rotation), position), "animation": "", "rig": {}, "bindings": [], "instances": null, "cast_shadow": true}

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.91
	material.metallic = 0.14
	PaintedMaterials.apply(material, {"name": "", "painted_outline": true})
	return material

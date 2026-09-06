extends RefCounted

## Authored infantry meshes.  The rest rig deliberately matches SourceAnimation
## so standing, walking, firing and death poses use the existing combat timing.
const LIBRARY := preload("res://assets/actors/military_people.glb")
const PALETTE_TEXTURE := preload("res://assets/actors/military_people_palette.png")
const MODELS := ["rifleman", "ak", "bazooka", "bomber"]
const PARTS := ["BODY", "HEAD", "LEG_L", "LEG_R", "ARM_L", "ARM_R", "WEAPON"]
const REST := {
	"BODY": {"role": "body", "position": [0.0, 1.08, 0.0], "rotation": [0.0, 0.0, 0.0]},
	"HEAD": {"role": "head", "position": [0.0, 1.68, 0.015], "rotation": [0.0, 0.0, 0.0]},
	"LEG_L": {"role": "leg", "side": -1.0, "position": [-0.17, 0.74, 0.0], "rotation": [0.0, 0.0, 0.0]},
	"LEG_R": {"role": "leg", "side": 1.0, "position": [0.17, 0.74, 0.0], "rotation": [0.0, 0.0, 0.0]},
	"ARM_L": {"role": "arm", "side": -1.0, "position": [-0.39, 1.4, 0.0], "rotation": [0.0, 0.0, -0.10]},
	"ARM_R": {"role": "arm", "side": 1.0, "position": [0.39, 1.4, 0.0], "rotation": [0.0, 0.0, 0.10]},
	"WEAPON": {"role": "weapon", "side": 1.0, "position": [-0.46, 1.23, 0.24], "rotation": [0.0, 0.0, -0.08]},
}
static var _cache: Dictionary = {}
static var _palette_material: StandardMaterial3D

static func _material() -> StandardMaterial3D:
	if _palette_material != null:
		return _palette_material
	_palette_material = StandardMaterial3D.new()
	_palette_material.albedo_texture = PALETTE_TEXTURE
	_palette_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_palette_material.roughness = 0.88
	_palette_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	_palette_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _palette_material

static func has_model(name: String) -> bool:
	return name in MODELS

static func templates(name: String) -> Array:
	if not has_model(name):
		return []
	if _cache.has(name):
		return _cache[name]
	var scene := LIBRARY.instantiate()
	var root := scene.get_node_or_null(NodePath("MODEL_" + name.to_upper())) as Node3D
	var output: Array = []
	if root == null:
		push_error("Military people GLB is missing " + name)
		scene.free()
		_cache[name] = output
		return output
	for key in PARTS:
		var visual := root.get_node_or_null(NodePath(name.to_upper() + "_" + key)) as MeshInstance3D
		if visual == null or visual.mesh == null:
			push_error("Military people GLB is missing " + name + " " + key)
			continue
		var rig: Dictionary = REST[key].duplicate()
		rig.kind = name
		if name == "bomber" and key == "WEAPON":
			rig.position = [0.0, 1.13, 0.30]
		visual.mesh.surface_set_material(0, _material())
		output.append({"name": visual.name, "mesh": visual.mesh, "transform": visual.transform,
			"animation": "", "rig": rig, "bindings": [], "instances": null, "cast_shadow": true})
	scene.free()
	_cache[name] = output
	return output

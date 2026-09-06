extends RefCounted

const LIBRARY = preload("res://assets/actors/military_field_props.glb")
const MODELS := ["garrison_1", "garrison_2", "garrison_3", "mine_enemy", "mine_friendly", "mine_unarmed", "pickup_fuel", "pickup_salvage", "heal_cart", "airdrop"]
static var _cache: Dictionary = {}

static func has_model(name: String) -> bool:
	return name in MODELS

static func templates(name: String) -> Array:
	if _cache.has(name):
		return _cache[name]
	var scene := LIBRARY.instantiate()
	var model := scene.get_node("FIELD_" + name)
	var result: Array = []
	for node: Node in model.get_children():
		if not node is MeshInstance3D:
			continue
		var bindings: Array = []
		var label := str(node.name)
		if label.begins_with("Wheel_") or label.begins_with("Canopy"):
			bindings.append({"role": "wheel" if label.begins_with("Wheel_") else "airdrop_canopyRig", "position": node.position, "rotation": Vector3.ZERO, "scale": Vector3.ONE, "rest_inverse": node.transform.affine_inverse(), "parent_transform": Transform3D.IDENTITY, "initial_visible": true})
		result.append({"name": label, "mesh": node.mesh, "transform": node.transform, "animation": "", "rig": {}, "bindings": bindings, "instances": null, "cast_shadow": true})
	if name.begins_with("mine_"):
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.name < b.name)
	scene.free()
	_cache[name] = result
	return result

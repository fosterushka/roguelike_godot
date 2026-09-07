extends RefCounted

const LIBRARY = preload("res://assets/actors/military_field_props.glb")
const BaseVariants = preload("res://presentation/combat/base_variants.gd")
const MODELS := ["garrison_1", "garrison_2", "garrison_3", "mine_enemy", "mine_friendly", "mine_unarmed", "pickup_fuel", "pickup_salvage", "heal_cart", "airdrop"]
const CANONICAL_MINE := "mine"
static var _cache: Dictionary = {}

static func has_model(name: String) -> bool:
	return name in MODELS

static func templates(name: String) -> Array:
	if name == "airdrop":
		return preload("res://presentation/world/airdrop_model.gd").templates()
	if name in ["garrison_1", "garrison_2"]:
		return BaseVariants.templates(name)
	if _cache.has(name):
		return _cache[name]
	var scene := LIBRARY.instantiate()
	var library_name := CANONICAL_MINE if name.begins_with("mine_") else name
	var model := scene.get_node("FIELD_" + library_name)
	var result: Array = []
	for node: Node in model.get_children():
		if not node is MeshInstance3D:
			continue
		var bindings: Array = []
		var label := str(node.name)
		if label.begins_with("Wheel_") or label.begins_with("Canopy"):
			bindings.append({"role": "wheel" if label.begins_with("Wheel_") else "airdrop_canopyRig", "position": node.position, "rotation": Vector3.ZERO, "scale": Vector3.ONE, "rest_inverse": node.transform.affine_inverse(), "parent_transform": Transform3D.IDENTITY, "initial_visible": true})
		result.append({"name": label, "mesh": node.mesh, "transform": node.transform, "animation": "", "rig": {}, "bindings": bindings, "instances": null, "cast_shadow": true})
	if name == "garrison_3":
		result.append_array(BaseVariants.templates(name))
	if name.begins_with("mine_"):
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.name < b.name)
	scene.free()
	_cache[name] = result
	return result

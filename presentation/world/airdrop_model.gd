extends RefCounted

const LIBRARY = preload("res://assets/actors/airdrop.glb")
const MODEL_ORIGIN_HEIGHT := 12.0
const CANOPY_ROLE := "airdrop_canopyRig"
static var _cache: Array = []

static func templates() -> Array:
	if not _cache.is_empty():
		return _cache
	var scene := LIBRARY.instantiate()
	for node: Node in scene.get_node("FIELD_airdrop").get_children():
		if not node is MeshInstance3D:
			continue
		var baseline := Transform3D(Basis.IDENTITY, Vector3.UP * MODEL_ORIGIN_HEIGHT)
		var pose: Transform3D = baseline * node.transform
		var bindings: Array = []
		if str(node.name).begins_with("Canopy"):
			bindings.append({"role": CANOPY_ROLE, "position": node.position, "rotation": Vector3.ZERO, "scale": Vector3.ONE, "rest_inverse": pose.affine_inverse(), "parent_transform": baseline, "initial_visible": true})
		_cache.append({"name": str(node.name), "mesh": node.mesh, "transform": pose, "animation": "", "rig": {}, "bindings": bindings, "instances": null, "cast_shadow": true})
	scene.free()
	return _cache

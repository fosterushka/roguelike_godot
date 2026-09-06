extends SceneTree

const Rig = preload("res://presentation/vehicles/wheeled_rig.gd")
const OUTPUT := "res://assets/models/player/runtime_player.json"
var meshes: Array = []
var minimum := Vector3(INF, INF, INF)
var maximum := Vector3(-INF, -INF, -INF)
var wheel_nodes: Array = []

func _initialize() -> void:
	var rig: Node3D = Rig.build_player()
	wheel_nodes = rig.get_meta("wheels")
	_visit(rig, Transform3D.IDENTITY, "", Vector3.ZERO, str(rig.name))
	var size := maximum - minimum
	var sources := ["presentation/vehicles/vehicle_view.gd", "presentation/vehicles/wheeled_rig.gd", "modules/caravan/wheel_suspension.gd"]
	var hashes := {}
	for source in sources:
		hashes[source] = FileAccess.get_sha256("res://" + source)
	var result := {
		"source": "Current Godot runtime: WheeledRig.build_player()",
		"source_files": sources, "source_sha256": hashes,
		"name": "player", "bounds": [size.x, size.y, size.z],
		"bounds_min": [minimum.x, minimum.y, minimum.z],
		"bounds_max": [maximum.x, maximum.y, maximum.z],
		"wheel_groups": wheel_nodes.size(), "meshes": meshes,
	}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write runtime player JSON")
		quit(1)
		return
	file.store_string(JSON.stringify(result))
	file.close()
	print("RUNTIME_PLAYER_EXPORTED meshes=%d wheels=%d bounds=%s" % [meshes.size(), wheel_nodes.size(), size])
	rig.free()
	quit(0)

func _visit(node: Node3D, parent_pose: Transform3D, group: String, center: Vector3, path: String) -> void:
	var pose := parent_pose * node.transform
	if wheel_nodes.has(node):
		group = str(node.name)
		center = pose.origin
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		for surface in visual.mesh.get_surface_count():
			var arrays := visual.mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var attributes := {"position": _vectors(positions), "normal": _vectors(arrays[Mesh.ARRAY_NORMAL])}
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var flat_uv: Array = []
			for point in uv:
				flat_uv.append(point.x)
				flat_uv.append(point.y)
			attributes.uv = flat_uv
			for point in positions:
				var world := pose * point
				minimum = minimum.min(world)
				maximum = maximum.max(world)
			var mat := visual.get_active_material(surface) as StandardMaterial3D
			var tint := mat.albedo_color.to_html(false)
			meshes.append({
				"name": str(node.name), "node_path": path, "matrix": _matrix(pose),
				"attributes": attributes, "indices": Array(arrays[Mesh.ARRAY_INDEX]),
				"wheel_group": group, "wheel_center": [center.x, center.y, center.z],
				"bindings": [], "animate": "", "instances": null,
				"material": {"name": "runtime_" + tint, "color": tint,
					"roughness": mat.roughness, "metallic": mat.metallic,
					"emission": mat.emission.to_html(false) if mat.emission_enabled else "000000",
					"emission_energy": mat.emission_energy_multiplier if mat.emission_enabled else 0,
					"backside": false, "opacity": mat.albedo_color.a},
			})
	for child in node.get_children():
		if child is Node3D:
			_visit(child, pose, group, center, path + "/" + str(child.name))

func _vectors(values: PackedVector3Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(value.x)
		result.append(value.y)
		result.append(value.z)
	return result

func _matrix(pose: Transform3D) -> Array:
	return [pose.basis.x.x, pose.basis.x.y, pose.basis.x.z, 0,
		pose.basis.y.x, pose.basis.y.y, pose.basis.y.z, 0,
		pose.basis.z.x, pose.basis.z.y, pose.basis.z.z, 0,
		pose.origin.x, pose.origin.y, pose.origin.z, 1]

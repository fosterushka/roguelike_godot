extends RefCounted

# World units. Mesh AABBs, including overhang, remain renderer-managed.
const CHUNK_SIZE := 256.0

static func cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CHUNK_SIZE), floori(point.z / CHUNK_SIZE))

# Keep the original child slot; destruction records use flat child indices.
# CPU transforms are supplied explicitly: headless MultiMesh readback is unavailable.
static func split(world: Node3D, source: MultiMeshInstance3D, poses: Array, colors: Array = []) -> Array:
	var groups := {}
	for index in poses.size():
		var key := cell(poses[index].origin)
		if not groups.has(key):
			groups[key] = []
		groups[key].append(index)
	var remap: Array = []
	remap.resize(poses.size())
	var first := true
	var original := source.multimesh
	for key: Vector2i in groups:
		var batch: MultiMeshInstance3D = source if first else source.duplicate(0)
		if not first:
			batch.name = "%s_%d_%d" % [source.name, key.x, key.y]
			world.add_child(batch)
		first = false
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_colors = original.use_colors
		instances.mesh = original.mesh
		instances.instance_count = groups[key].size()
		for local_index in groups[key].size():
			var index: int = groups[key][local_index]
			instances.set_instance_transform(local_index, poses[index])
			if instances.use_colors:
				instances.set_instance_color(local_index, colors[index])
			remap[index] = {"mesh": batch.get_index(), "instance": local_index}
		batch.multimesh = instances
	return remap

static func remap_props(props: Array, mapping: Dictionary) -> void:
	for prop: Dictionary in props:
		for part: Dictionary in prop.get("parts", []):
			if int(part.instance) >= 0 and mapping.has(int(part.mesh)):
				var target: Dictionary = mapping[int(part.mesh)][int(part.instance)]
				part.mesh = target.mesh
				part.instance = target.instance

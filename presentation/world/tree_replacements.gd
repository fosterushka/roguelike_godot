extends RefCounted

const Trees = preload("res://presentation/world/tree_meshes.gd")
const Source = preload("res://presentation/combat/source_model.gd")
const TREE_SIZE_SCALE := 1.18
const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)

static func _pool(point: Vector3) -> String:
	var selector := ((roundi(point.x * 10) * 73856093) ^ (roundi(point.z * 10) * 19349663)) & 1
	return Trees.POOLS[selector]

static func _pose(point: Vector3, scale: float, parts: Array, dead: bool) -> Transform3D:
	var heading := 0.0
	if not parts.is_empty() and parts[0].has("transform"):
		heading = Transform3D(parts[0].transform).basis.get_euler().y
	return Transform3D(Basis(Vector3.UP, heading).scaled(Vector3.ONE * scale * TREE_SIZE_SCALE * (0.62 if dead else 0.55)), point)

static func prepare(context: RefCounted) -> Dictionary:
	var instances: Dictionary = context.instances.duplicate()
	var copied := {}
	var remap := {}
	for tree: Dictionary in context.get_meta("legacy_tree_views", []):
		var visible_parts: Array = tree.parts.filter(func(part: Dictionary) -> bool: return int(part.instance) >= 0)
		if visible_parts.is_empty():
			continue
		var pool: String = Trees.DEAD_POOL if tree.dead else _pool(tree.position)
		if not copied.has(pool):
			instances[pool] = instances[pool].duplicate()
			copied[pool] = true
		var pose := _pose(tree.position, tree.scale, visible_parts, tree.dead)
		var replacement := {"pool": pool, "instance": instances[pool].size(), "transform": pose}
		instances[pool].append(pose)
		for part: Dictionary in visible_parts:
			if not copied.has(part.pool):
				instances[part.pool] = instances[part.pool].duplicate()
				copied[part.pool] = true
			instances[part.pool][part.instance] = HIDDEN
			remap[_key(part)] = replacement
	return {"instances": instances, "parts": remap}

static func parts_for(source: Array, replacements: Dictionary) -> Array:
	var result: Array = []
	var added := {}
	for part: Dictionary in source:
		var replacement: Dictionary = replacements.get(_key(part), part)
		var key := _key(replacement)
		if not added.has(key):
			result.append(replacement)
			added[key] = true
	return result

static func _key(part: Dictionary) -> String:
	return "%s:%d" % [part.pool, int(part.instance)]

static func replace_reference(world: Node3D, layout: Dictionary) -> void:
	var pools := {}
	var replacements := {}
	for pool: String in Trees.POOLS:
		pools[pool] = []
	for prop: Dictionary in layout.props:
		if prop.kind not in ["tree", "deadTree"]:
			continue
		var point := Vector3(prop.position.x, 0, prop.position.z)
		var pool: String = Trees.DEAD_POOL if prop.kind == "deadTree" else _pool(point)
		var parts: Array = []
		for part: Dictionary in prop.parts:
			var visual := world.get_child(int(part.mesh)) as MultiMeshInstance3D
			if visual != null and part.instance >= 0:
				parts.append({"transform": Source._transform(part.matrix)})
				visual.multimesh.set_instance_transform(int(part.instance), HIDDEN)
		var scale := float(prop.radius) / (0.78 if prop.kind == "deadTree" else 0.9)
		var pose := _pose(point, scale, parts, prop.kind == "deadTree")
		replacements[prop.id] = {"pool": pool, "instance": pools[pool].size(), "matrix": _matrix(pose)}
		pools[pool].append(pose)
	var indices := {}
	for pool: String in pools:
		var batch := MultiMeshInstance3D.new()
		batch.name = pool
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = Trees.mesh_for(pool)
		instances.instance_count = pools[pool].size()
		for index in pools[pool].size():
			instances.set_instance_transform(index, pools[pool][index])
		batch.multimesh = instances
		indices[pool] = world.get_child_count()
		world.add_child(batch)
	for prop: Dictionary in layout.props:
		if replacements.has(prop.id):
			var replacement: Dictionary = replacements[prop.id]
			prop.parts = [{"mesh": indices[replacement.pool], "instance": replacement.instance, "matrix": replacement.matrix}]

static func _matrix(pose: Transform3D) -> Array:
	return [pose.basis.x.x, pose.basis.x.y, pose.basis.x.z, 0, pose.basis.y.x, pose.basis.y.y, pose.basis.y.z, 0, pose.basis.z.x, pose.basis.z.y, pose.basis.z.z, 0, pose.origin.x, pose.origin.y, pose.origin.z, 1]

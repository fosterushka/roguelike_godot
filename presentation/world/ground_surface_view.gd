extends RefCounted
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const TRACK_OFFSET := 0.04
const TRACK_PRIORITY := -1
const MUD_OFFSET := 0.020
const SCORCH_OFFSET := 0.024
const BLOOD_OFFSET := 0.028

static func point_at(point: Vector3, offset: float) -> Vector3:
	return Vector3(point.x, Terrain.height_at(point.x, point.z) + offset, point.z)

static func prepare_material(material: StandardMaterial3D, priority: int) -> void:
	material.no_depth_test = false
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = priority
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED

static func conform_quad(visual: MeshInstance3D, offset: float) -> void:
	var transform := visual.global_transform
	var inverse := transform.affine_inverse()
	var lower := Vector2(INF, INF)
	var upper := Vector2(-INF, -INF)
	for corner: Vector3 in [Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)]:
		var world := transform * corner
		lower = lower.min(Vector2(world.x, world.z))
		upper = upper.max(Vector2(world.x, world.z))
	var first := Vector2i(floori((lower.x + Terrain.HALF_SIZE) / Terrain.STEP), floori((lower.y + Terrain.HALF_SIZE) / Terrain.STEP))
	var last := Vector2i(floori((upper.x + Terrain.HALF_SIZE) / Terrain.STEP), floori((upper.y + Terrain.HALF_SIZE) / Terrain.STEP))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(first.y, last.y + 1):
		for column in range(first.x, last.x + 1):
			var x := column * Terrain.STEP - Terrain.HALF_SIZE
			var z := row * Terrain.STEP - Terrain.HALF_SIZE
			var a := point_at(Vector3(x, 0, z), offset)
			var b := point_at(Vector3(x + Terrain.STEP, 0, z), offset)
			var c := point_at(Vector3(x, 0, z + Terrain.STEP), offset)
			var d := point_at(Vector3(x + Terrain.STEP, 0, z + Terrain.STEP), offset)
			for triangle: Array in [[a, b, c], [b, d, c]]:
				var polygon: Array[Dictionary] = []
				for world: Vector3 in triangle:
					var local := inverse * world
					polygon.append({"point": world, "uv": Vector2(local.x + 0.5, 0.5 - local.y)})
				for side in 4:
					polygon = _clip(polygon, side)
				if polygon.size() < 3:
					continue
				var start := vertices.size()
				for vertex: Dictionary in polygon:
					vertices.append(inverse * vertex.point)
					normals.append((transform.basis.transposed() * Terrain.normal_at(vertex.point.x, vertex.point.z)).normalized())
					uvs.append(vertex.uv)
				for index in range(1, polygon.size() - 1):
					var first_edge: Vector3 = polygon[index].point - polygon[0].point
					var second_edge: Vector3 = polygon[index + 1].point - polygon[0].point
					if first_edge.cross(second_edge).length_squared() > 0.0000000001:
						indices.append_array([start, start + index, start + index + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = visual.get_meta("ground_surface_mesh") if visual.has_meta("ground_surface_mesh") else null
	if mesh == null:
		mesh = ArrayMesh.new()
		visual.set_meta("ground_surface_mesh", mesh)
	mesh.clear_surfaces()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	visual.mesh = mesh

static func _clip(polygon: Array[Dictionary], side: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if polygon.is_empty():
		return result
	var previous: Dictionary = polygon.back()
	var previous_distance := _distance(previous.uv, side)
	for current: Dictionary in polygon:
		var current_distance := _distance(current.uv, side)
		if (current_distance >= 0.0) != (previous_distance >= 0.0):
			var weight := previous_distance / (previous_distance - current_distance)
			result.append({"point": Vector3(previous.point).lerp(current.point, weight), "uv": Vector2(previous.uv).lerp(current.uv, weight)})
		if current_distance >= 0.0:
			result.append(current)
		previous = current
		previous_distance = current_distance
	return result

static func _distance(uv: Vector2, side: int) -> float:
	return uv.x if side == 0 else 1.0 - uv.x if side == 1 else uv.y if side == 2 else 1.0 - uv.y

extends SceneTree

const Rocks = preload("res://presentation/world/rock_meshes.gd")
var checks := 0
var failures := 0

func _init() -> void:
	for variant in 6:
		var mesh := Rocks.mesh_for("rockMass%d" % variant)
		check(mesh != null and mesh.get_surface_count() == 1, "One coherent rock surface")
		var data := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = data[Mesh.ARRAY_COLOR]
		var edges := {}
		var valid := vertices.size() >= 300 and vertices.size() % 3 == 0
		var max_radius := 0.0
		for vertex: Vector3 in vertices:
			max_radius = maxf(max_radius, Vector2(vertex.x, vertex.z).length())
		for index in range(0, vertices.size(), 3):
			var a := vertices[index]
			var b := vertices[index + 1]
			var c := vertices[index + 2]
			valid = valid and (b - a).cross(c - a).length() > 0.00001
			valid = valid and (b - a).cross(c - a).dot(normals[index]) < 0
			for pair: Array in [[a, b], [b, c], [c, a]]:
				var keys: Array[String] = [_key(pair[0]), _key(pair[1])]
				keys.sort()
				var key := keys[0] + ":" + keys[1]
				edges[key] = int(edges.get(key, 0)) + 1
		check(valid and edges.values().all(func(count: int) -> bool: return count == 2), "Rock is closed with no holes, degenerate faces or reversed winding")
		check(max_radius <= 1.02 and mesh.get_aabb().end.y <= 1.01, "Rock stays inside registered collision footprint and height")
		check(colors.size() == vertices.size() and mesh.surface_get_material(0).vertex_color_use_as_albedo, "Faceted stone uses its authored colors")
		check(mesh == Rocks.mesh_for("rockMass%d" % variant), "Rock mesh cache survives repeated access")
	check(Rocks.mesh_for("cliffStrata") == null, "Removed shelves are not a new rock mesh")
	print("Natural mesh: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _key(point: Vector3) -> String:
	return "%d,%d,%d" % [roundi(point.x * 100000), roundi(point.y * 100000), roundi(point.z * 100000)]

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

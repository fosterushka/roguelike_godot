extends SceneTree

const Library = preload("res://presentation/world/environment_library.gd")
var checks := 0
var failures := 0

func _init() -> void:
	for pool: String in ["spruceTrees", "birchTrees"]:
		var scene := Library.TREE_SCENE.instantiate()
		var imported: ArrayMesh = scene.find_child(pool, true, false).mesh
		var actual: ArrayMesh = Library.mesh_for(pool)
		var expected_lods := Library._imported_lods(imported)
		var actual_lods := Library._imported_lods(actual)
		check(not expected_lods.is_empty(), pool + " has importer generated LODs")
		var authored := scene.find_child(pool + Library.AUTHORED_LOD_SUFFIX, true, false) as MeshInstance3D
		if pool == "spruceTrees":
			check(authored != null, "Spruce requires the authored distant crown; automatic collapse is not allowed")
		if authored == null:
			check(expected_lods.keys() == actual_lods.keys(), pool + " preserves LOD transition distances")
			for distance: float in expected_lods:
				check(expected_lods[distance] == actual_lods.get(distance), pool + " preserves simplified indices")
		else:
			check(actual_lods.size() == 1 and is_equal_approx(float(actual_lods.keys()[0]), Library.TREE_LOD_EDGE_LENGTH), pool + " uses its authored distant silhouette")
			var authored_indices: PackedInt32Array = authored.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
			var expected_indices := authored_indices.duplicate()
			for index in expected_indices.size():
				expected_indices[index] += imported.surface_get_array_len(0)
			check(actual_lods.values()[0] == expected_indices, pool + " retains every authored distant branch")
		var distant_triangles: int = imported.surface_get_array_index_len(0) / 3
		for distance: float in actual_lods:
			distant_triangles = mini(distant_triangles, actual_lods[distance].size() / 3)
		check(distant_triangles <= Library.TREE_DISTANT_TRIANGLE_BUDGET, pool + " distant LOD stays below 2000 triangles")
		check(actual.get_surface_count() == 1, pool + " uses one shared surface")
		check(actual.surface_get_array_index_len(0) == imported.surface_get_array_index_len(0), pool + " preserves primary triangle geometry")
		check(absf(actual.get_aabb().position.y) < .01, pool + " roots rest on terrain")
		var arrays := actual.surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size(), pool + " retains vegetation colors")
		check(actual == Library.mesh_for(pool), pool + " remains shared between world instances")
		scene.free()
	print("Environment LOD: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

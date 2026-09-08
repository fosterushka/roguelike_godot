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
		check(scene.find_child(pool + "Distant", true, false) == null, pool + " reuses one simple model at every distance")
		check(expected_lods.keys() == actual_lods.keys(), pool + " preserves LOD transition distances")
		for distance: float in expected_lods:
			check(expected_lods[distance] == actual_lods.get(distance), pool + " preserves simplified indices")
		var distant_triangles: int = imported.surface_get_array_index_len(0) / 3
		for distance: float in actual_lods:
			distant_triangles = mini(distant_triangles, actual_lods[distance].size() / 3)
		check(distant_triangles <= Library.TREE_TRIANGLE_BUDGET, pool + " distant LOD stays within the simple tree budget")
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

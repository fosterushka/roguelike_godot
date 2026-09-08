extends SceneTree

const Terrain = preload("res://modules/caravan/terrain_surface.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Terrain.configure({})
	var original := Terrain.create_mesh().surface_get_arrays(0)
	for requested: Rect2i in [Rect2i(0, 0, 32, 32), Rect2i(32, 0, 32, 32), Rect2i(240, 240, 32, 32), Rect2i(500, 500, 32, 32), Rect2i(-4, -4, 8, 8)]:
		var region := requested.intersection(Rect2i(0, 0, Terrain.CELLS, Terrain.CELLS))
		var arrays := Terrain.create_mesh(requested).surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_INDEX].size() == region.size.x * region.size.y * 6, "edge chunks contain only valid cells")
		var matches := true
		for row in region.size.y + 1:
			for column in region.size.x + 1:
				var local_index := row * (region.size.x + 1) + column
				var global_index := (row + region.position.y) * (Terrain.CELLS + 1) + column + region.position.x
				for attribute in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV]:
					matches = matches and arrays[attribute][local_index] == original[attribute][global_index]
		check(matches, "positions, heights, normals and UVs exactly match the original, including seams")
		var winding_matches := true
		for index in arrays[Mesh.ARRAY_INDEX].size():
			var local_vertex: int = arrays[Mesh.ARRAY_INDEX][index]
			var row: int = local_vertex / (region.size.x + 1)
			var column: int = local_vertex % (region.size.x + 1)
			var cell_index: int = index / 6
			var full_cell := (region.position.y + cell_index / region.size.x) * Terrain.CELLS + region.position.x + cell_index % region.size.x
			winding_matches = winding_matches and (row + region.position.y) * (Terrain.CELLS + 1) + column + region.position.x == original[Mesh.ARRAY_INDEX][full_cell * 6 + index % 6]
		check(winding_matches, "triangle winding and diagonals match the physics heightfield")
	check(Terrain.create_mesh(Rect2i(Terrain.CELLS, 0, 32, 32)).get_surface_count() == 0, "outside world creates no geometry")
	print("Terrain chunks: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

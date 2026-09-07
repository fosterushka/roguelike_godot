extends SceneTree

const Library = preload("res://presentation/world/environment_library.gd")
const OUTPUT := "res://docs/validation/model-revision/"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(960, 720)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("5d686b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d3ddd0")
	environment.environment.ambient_light_energy = .8
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.5
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11
	world.add_child(camera)
	camera.position = Vector3(10, 9, 13)
	camera.look_at(Vector3(0, 4.5, 0))
	camera.current = true
	var display := MeshInstance3D.new()
	world.add_child(display)
	var primary: ArrayMesh = Library.mesh_for("spruceTrees")
	var arrays := primary.surface_get_arrays(0)
	var lods := Library._imported_lods(primary)
	arrays[Mesh.ARRAY_INDEX] = lods.values()[0]
	var repaired := ArrayMesh.new()
	repaired.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	repaired.surface_set_material(0, primary.surface_get_material(0))
	var captures: Array = []
	var before_path := OS.get_environment("SPRUCE_LOD_BEFORE")
	if not before_path.is_empty() and FileAccess.file_exists(before_path):
		captures.append(["spruce-lod-before", load(before_path)])
	captures.append(["spruce-lod-after", repaired])
	for capture: Array in captures:
		display.mesh = capture[1]
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT + capture[0] + ".png")
	world.queue_free()
	await process_frame
	quit()

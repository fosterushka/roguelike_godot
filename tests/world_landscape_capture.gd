extends SceneTree

const Generator = preload("res://modules/world/generation/world_generator.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
const Day = preload("res://modules/world/day_cycle.gd")
const CAPTURE_ROOT := "res://docs/validation/world-expansion"
var arena: Node3D
var view: Node3D
var vehicle: CharacterBody3D
var camera: Camera3D

func _initialize() -> void:
	root.size = Vector2i(1280, 800)
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_ROOT))
	arena = preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	paused = true
	var context := Generator.generate(72841, Authored.new())
	arena.rebuild_from_context(context)
	paused = false
	vehicle = CharacterBody3D.new()
	root.add_child(vehicle)
	view = preload("res://presentation/world/weather_view.gd").new()
	root.add_child(view)
	view.setup(arena, vehicle)
	view.externally_driven = true
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 95
	root.add_child(camera)
	camera.current = true
	await _capture("meadow-day", Vector3(0, 0, 35), false)
	await _capture("badlands-day", Vector3(650, 0, 0), false)
	await _capture("tundra-day", Vector3(-650, 0, 0), false)
	await _capture("meadow-night", Vector3(0, 0, 35), true)
	camera.size = 75
	await _capture("terrain-mounds", Vector3(930, 0, 740), false, Vector3(60, 64, 180))
	arena.free()
	view.free()
	vehicle.free()
	camera.free()
	print("WORLD_LANDSCAPE_CAPTURE: 5 images, 0 failures")
	quit()

func _capture(id: String, point: Vector3, night: bool, offset := Vector3(40, 52, 40)) -> void:
	vehicle.position = point
	camera.position = point + offset
	camera.look_at(point)
	var elapsed := ((0.75 if night else 0.25) - Day.START_PHASE) * Day.CYCLE_SECONDS
	view.apply_state({"weather": {"type": "sunny", "elapsed": 0.0}, "elapsed": 0.0, "game_time": elapsed, "tornado": {}, "mud_zones": []})
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(CAPTURE_ROOT.path_join(id + ".png"))
	assert(error == OK)

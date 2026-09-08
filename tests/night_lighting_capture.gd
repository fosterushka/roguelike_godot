extends SceneTree

const Day = preload("res://modules/world/day_cycle.gd")
const Weather = preload("res://presentation/world/weather_view.gd")
var view: Node3D

func _initialize() -> void:
	root.size = Vector2i(1280, 800)
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var arena := preload("res://presentation/world/arena.tscn").instantiate()
	stage.add_child(arena)
	var vehicle := CharacterBody3D.new()
	stage.add_child(vehicle)
	vehicle.add_child(preload("res://presentation/vehicles/vehicle_view.tscn").instantiate())
	view = Weather.new()
	stage.add_child(view)
	view.setup(arena, vehicle)
	view.externally_driven = true
	view.set_process(false)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 70
	stage.add_child(camera)
	camera.position = Vector3(34, 45, 34)
	camera.look_at(Vector3.ZERO)
	var suffix := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	for weather: String in ["sunny", "rainy", "storm"]:
		for night in [false, true]:
			var time := ((0.75 if night else 0.25) - Day.START_PHASE) * Day.CYCLE_SECONDS
			view.apply_state({"weather": {"type": weather}, "game_time": time, "elapsed": 0.0, "tornado": {}, "mud_zones": []})
			# Lighting comparison uses the same scene without random precipitation.
			view._rain.clear()
			for frame in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			var id := "%s-%s-%s" % [weather, "night" if night else "day", suffix]
			assert(frame.save_png("/private/tmp/iron-night-" + id + ".png") == OK)
	stage.free()
	print("NIGHT_LIGHTING_CAPTURE: 6 images, 0 failures")
	quit()

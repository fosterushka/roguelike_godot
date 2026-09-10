extends Node

const Main = preload("res://app/main.tscn")
const World = preload("res://modules/world/world_runtime.gd")
const OUTPUT := "/private/tmp/iron-boundary-"
var game: Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-boundary-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 0
	get_tree().root.add_child(game)
	await game.game_ready
	await game.restart_run()
	preload("res://presentation/ui/ui_locale.gd").language = "ru"
	game.hud.set_countdown(0, false)
	for node: Node in [game, game.session_flow, game.combat, game.world, game.vehicle]:
		node.set_physics_process(false)
	game.sound.set_running(false)
	game.camera.set_process(false)
	game.camera._intro = 0.0
	game.camera.size = 70
	game.camera.global_position = Vector3(32, 39, 32)
	game.camera.look_at(Vector3.ZERO)
	# Hold camera fixed to compare exactly the same colored scene in all states.
	game.vehicle.position.x = World.PLAYABLE_RADIUS
	game.world._update_boundary(0)
	game.world._publish()
	await _capture("inside", false)
	game.vehicle.position.x += 0.01
	game.world._update_boundary(0)
	game.world._publish()
	await _capture("entering", false, 0.2)
	await _capture("outside", true)
	game.hud.jammer_vhs.update_state({"player": {"hp": 100, "jammed": true, "jammer_strength": 1}})
	game.hud.jammer_vhs.update_weather({"weather": {"type": "storm"}})
	game.hud.jammer_vhs.advance(2)
	await _capture("outside-jammed-rain", true)
	game.vehicle.position.x -= 1.0
	game.world._update_boundary(0)
	game.world._publish()
	await _capture("leaving", false, 0.2)
	await _capture("returned", false)
	print("BOUNDARY_SCREEN_CAPTURE: 6 images, sepia verified from rendered pixels")
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _capture(id: String, sepia: bool, delta: float = 2.0) -> void:
	game.hud.boundary_desaturation.advance(delta)
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame := get_tree().root.get_texture().get_image()
	assert(frame.save_png(OUTPUT + id + ".png") == OK)
	var colored := 0
	var bright := 0
	var warm := 0
	for y in range(0, frame.get_height(), 4):
		for x in range(0, frame.get_width(), 4):
			var pixel := frame.get_pixel(x, y)
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) - minf(pixel.r, minf(pixel.g, pixel.b)) > 0.01:
				colored += 1
			if pixel.r > pixel.g + 0.02 and pixel.g > pixel.b + 0.02:
				warm += 1
			if pixel.r > 0.2:
				bright += 1
	assert(bright > 100, "Screen must retain visible detail")
	assert(warm > bright * 0.8 if sepia else colored > 100, "Rendered screen must match boundary color state: " + id)

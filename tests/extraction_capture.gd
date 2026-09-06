extends Node

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
var game: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/iron-extraction-capture-language-%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("ru")
	game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-extraction-capture-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	get_tree().root.add_child(game)
	await game.game_ready
	await game.restart_run()
	var sites: Array = game.world.get_state().extraction.sites
	if sites.is_empty():
		push_error("Extraction capture requires real generated extraction sites")
		get_tree().quit(1)
		return
	var point: Vector3 = sites[0].position
	game.vehicle.global_position = point + Vector3.UP * (Terrain.height_at(point.x, point.z) + 0.5)
	game.vehicle.velocity = Vector3.ZERO
	game.vehicle.motion.speed = 0
	game.camera.set_process(false)
	game.camera.size = 62
	game.camera.global_position = point + Vector3(34, 45, 34)
	game.camera.look_at(point)
	game.world._publish()
	await get_tree().create_timer(1.0).timeout
	await _capture("idle-ru")
	var interact := InputEventKey.new()
	interact.physical_keycode = KEY_E
	interact.keycode = KEY_E
	interact.pressed = true
	get_tree().root.push_input(interact)
	interact.pressed = false
	get_tree().root.push_input(interact)
	if not game.world.activities.extraction.active:
		push_error("Actual extraction interaction failed")
		get_tree().quit(1)
		return
	game.world._publish()
	await _capture("defending-ru")
	game._set_language("en")
	game.world._publish()
	await _capture("defending-en")
	await get_tree().create_timer(8.0).timeout
	await _capture("attackers-en")
	game._set_language("ru")
	game.vehicle.global_position = point + Vector3(float(sites[0].radius) + 1, Terrain.height_at(point.x + float(sites[0].radius) + 1, point.z) + 0.5, 0)
	game.world.activities._update_extraction(0.25)
	game.world._publish()
	await _capture("leaving-ru")
	game.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	DirAccess.remove_absolute(Locale.settings_path)
	print("EXTRACTION_CAPTURE_COMPLETE: 5 images, real generated zone and E input")
	get_tree().quit()

func _capture(id: String) -> void:
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame := get_tree().root.get_texture().get_image()
	var path := "/private/tmp/iron-extraction-%s.png" % id
	print("EXTRACTION_CAPTURE %s status=%d" % [path, frame.save_png(path)])

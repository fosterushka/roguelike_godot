extends Node

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const Day = preload("res://modules/world/day_cycle.gd")
const OUTPUT := "res://docs/validation/qol-audit/images/"
var game: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/qol-activity-language-%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("en")
	game = Main.instantiate()
	game.profile_path = "/private/tmp/qol-activity-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	get_tree().root.add_child(game)
	print("QOL_WAIT_GAME_READY")
	await game.game_ready
	print("QOL_GAME_READY")
	game.run_prepared.connect(func(_seed: int) -> void: print("QOL_RUN_PREPARED"))
	game.run_ready.connect(func(_seed: int) -> void: print("QOL_RUN_READY"))
	await game.restart_run()
	print("QOL_RESTART_DONE")
	for node: Node in [game, game.session_flow, game.combat, game.world, game.vehicle]:
		node.set_physics_process(false)
	for index in 70:
		game.session_flow.advance(0.05)
	game.hud.finish_countdown()
	game.hud.set_countdown(0, false)
	game.hud.set_paused(false)
	await get_tree().create_timer(2.4, true).timeout
	game.camera.set_process(false)
	game.camera.set_physics_process(false)
	var activities = game.world.activities
	var point: Vector3 = activities.extraction_sites[0].position
	_place(point)
	await _capture("extraction-checkpoint")
	if not game.world.interact():
		push_error("Checkpoint interaction failed")
		get_tree().quit(1)
		return
	activities._update_extraction(1.0)
	await _capture("extraction-radio")
	activities._update_extraction(8.0)
	await _capture("extraction-defense")
	activities._update_extraction(8.0)
	await _capture("extraction-gate")
	game._set_language("ru")
	await _capture("extraction-gate-ru")
	game._set_language("en")
	var day_time: float = game.combat.model.elapsed
	game.combat.model.elapsed = (0.75 - Day.START_PHASE) * Day.CYCLE_SECONDS
	await _capture("extraction-night")
	game.combat.model.elapsed = day_time
	activities.cancel_all("capture aftermath")
	var village: Dictionary = game.world.arena.world_layout.villages[0]
	point = Vector3(village.x, 0, village.z)
	game.vehicle.health = game.vehicle.max_health * 0.5
	var saved: Dictionary = activities.announce("settlementDistress", {"position": point, "source_id": village.id})
	activities.finish(saved, "completed")
	_place(point)
	await _capture("settlement-aftermath")
	await _capture("settlement-service-ready")
	game.combat.model.elapsed = (0.75 - Day.START_PHASE) * Day.CYCLE_SECONDS
	await _capture("settlement-night")
	game.combat.model.elapsed = day_time
	if not game.world.interact():
		push_error("Nearby field repair interaction failed")
		get_tree().quit(1)
		return
	await _capture("settlement-service-used")
	point += Vector3(45, 0, 0)
	var convoy: Dictionary = activities.announce("raiderSupplyConvoy", {"position": point, "route": []})
	activities.finish(convoy, "completed")
	_place(point)
	await _capture("convoy-aftermath")
	var destination := point + Vector3(110, 0, -30)
	activities.announce("scavengerRoute", {"position": destination, "route": []})
	await _capture("primary-destination")
	game._set_language("ru")
	await _capture("primary-destination-ru")
	game._set_language("en")
	game.vehicle.motion.heading = 0.0
	_place(activities.extraction_sites[0].position)
	game.extraction_departure.set_process(false)
	if not activities.request_extraction():
		push_error("Final extraction interaction failed")
		get_tree().quit(1)
		return
	activities._update_extraction(18.0)
	game.world._publish()
	await get_tree().create_timer(1.0, true).timeout
	activities._update_extraction(2.0)
	for index in 12:
		game.extraction_departure.advance(0.05)
	game.vehicle.get_node("VehicleView").render_interpolated(1.0)
	await _capture("extraction-departure")
	for index in 14:
		game.extraction_departure.advance(0.05)
	await _capture("extraction-result")
	game.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	print("QOL_ACTIVITY_CAPTURE_COMPLETE")
	get_tree().quit()

func _place(point: Vector3) -> void:
	game.vehicle.global_position = Vector3(point.x, Terrain.height_at(point.x, point.z) + 0.5, point.z)
	game.vehicle.motion.x = point.x
	game.vehicle.motion.z = point.z
	game.vehicle.motion.speed = 0
	game.vehicle.velocity = Vector3.ZERO
	game.combat._sync_vehicle_to_model()
	game.vehicle.physics_pose_advanced.emit(0.0)
	game.vehicle.get_node("VehicleView").render_interpolated(1.0)
	game.camera.size = 58
	game.camera.global_position = point + Vector3(34, 48, 34)
	game.camera.look_at(point)

func _capture(id: String) -> void:
	game.world._publish()
	game.combat._publish()
	game.hud._world_banner.visible = false
	for frame in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame := get_tree().root.get_texture().get_image()
	var path := OUTPUT + id + ".png"
	var status := frame.save_png(path)
	print("QOL_CAPTURE %s status=%d" % [path, status])
	if status != OK:
		get_tree().quit(1)

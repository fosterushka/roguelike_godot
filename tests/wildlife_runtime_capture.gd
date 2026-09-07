extends SceneTree

const Main = preload("res://app/main.tscn")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const OUTPUT := "res://docs/validation/world-upgrade"
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var game := Main.instantiate()
	game.profile_path = "/tmp/wildlife-capture-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	await game.restart_run()
	game.session_flow.clock.intro_remaining = 0.0
	game.session_flow.clock.phase = "running"
	for node: Node in [game, game.session_flow, game.combat, game.world, game.vehicle]:
		node.set_physics_process(false)
	game.sound.set_running(false)
	game.camera.set_process(false)
	game.hud.visible = false
	game.combat.model.enemies.clear()
	game.combat.model.pickups.clear()
	var flock: Array = game.world.ambient.critters
	if flock.is_empty():
		push_error("No sheep in composed game")
		quit(1)
		return
	var sheep: Dictionary = flock[0]
	var largest_group := 0
	for candidate: Dictionary in flock:
		var nearby := 0
		for other: Dictionary in flock:
			nearby += int(candidate.group.position.distance_to(other.group.position) < 8.0)
		if nearby > largest_group:
			largest_group = nearby
			sheep = candidate
	var point: Vector3 = sheep.group.position
	point.y = Terrain.height_at(point.x, point.z)
	game.vehicle.position = point + Vector3(-7, 0, 0)
	game.vehicle.motion.speed = 0.0
	game.vehicle.physics_pose_advanced.emit(0.0)
	game.world.step_ambient(0.016)
	game.world._publish()
	game.camera.size = 23.0
	game.camera.global_position = point + Vector3(18, 22, 20)
	game.camera.look_at(point + Vector3.UP)
	await _capture("flock-alive")
	game.vehicle.position = sheep.group.position
	game.vehicle.motion.speed = 8.0
	game.vehicle.physics_pose_advanced.emit(0.0)
	game.world.step_ambient(0.016)
	var drops: int = game.combat.model.pickups.size()
	if not sheep.dead or drops == 0:
		failures += 1
		push_error("Composed ram failed to drop scrap")
	game.vehicle.position += Vector3(-5, 0, 0)
	game.vehicle.motion.speed = 0.0
	game.vehicle.physics_pose_advanced.emit(0.0)
	for tick in 90:
		game.world.step_ambient(1.0 / 60.0)
	game.combat_view.apply_state(game.combat.get_state())
	await _capture("flock-scrap")
	print("Wildlife composed runtime: %d sheep, %d drops, %d failures" % [flock.size(), drops, failures])
	game.queue_free()
	paused = false
	await process_frame
	quit(0 if failures == 0 else 1)

func _capture(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT.path_join(label + ".png"))
	failures += int(result != OK)

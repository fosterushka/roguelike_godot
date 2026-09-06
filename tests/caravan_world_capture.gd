extends Node
const Main = preload("res://app/main.tscn")
const Catalog = preload("res://modules/caravan/wagon_catalog.gd")
var game: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	get_window().size = Vector2i(1280, 800)
	get_tree().root.content_scale_size = Vector2i(1280, 800)
	game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-caravan-capture-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	get_tree().root.add_child(game)
	await game.game_ready
	game.progression.profile.expedition.credits = 5000
	for type: String in Catalog.TYPES:
		game.expedition.caravan.buy_wagon(type)
	game._open_caravan()
	await _capture("garage")
	game._close_caravan()
	await game.restart_run()
	for index in 70:
		game.session_flow.advance(0.05)
	for node: Node in [game, game.session_flow, game.world, game.vehicle, game.combat]:
		node.set_physics_process(false)
	game.camera.set_process(false)
	var model = game.combat.model
	model.spawn_queue.clear()
	model.enemies.clear()
	model.player.pending_upgrades = 0
	model.player.coins = 2000
	game.expedition.caravan.install_attachment("wagon-1", 0, "cargo_rack")
	game.expedition.caravan.install_attachment("wagon-2", 0, "repair_station")
	game.expedition.caravan.install_attachment("wagon-6", 0, "anti_air_station")
	var person: Dictionary = game.crew_runtime.recruits[0]
	person.position = model.player.position + Vector3(3, 0, 1)
	game.crew_runtime.view.update_people(game.crew_runtime._all_people(), 0)
	game._update_crew_hint()
	game.combat._publish()
	game.world.weather.phase = {"type": "sunny", "previous_type": "sunny", "starts_at": 0.0, "ends_at": 200.0, "duration": 200.0, "index": 0}
	game.world._publish()
	game.hud.jammer_vhs.reset_weather()
	await get_tree().create_timer(0.35, true).timeout
	for frame in 180:
		game.camera._process(1.0 / 60.0)
	await _capture("convoy-rescue")
	game.crew_runtime.rescue_nearest()
	game.caravan.step(0.01)
	game._update_crew_hint()
	game._open_caravan()
	game.caravan_panel.tab = "crew"
	game.caravan_panel._refresh()
	await _capture("crew")
	game._close_caravan()
	var scavenger: Dictionary = game.crew_runtime.recruits.filter(func(entry: Dictionary) -> bool: return entry.role == "looter")[0]
	scavenger.position = model.player.position + Vector3(2, 0, 1)
	game.crew_runtime.rescue_nearest()
	game.raid_loot.reset()
	model.pickups.clear()
	game.raid_loot.spawn_items("capture-parcel", model.player.position + Vector3(12, 0, 0), {"relic": 1})
	game.crew_runtime.toggle_collection()
	await _people_steps(1.5)
	await _capture("collecting")
	await _people_steps(10.0)
	await _capture("delivered")
	print("CREW_RENDER_DELIVERY boarded=%s cargo=%s" % [scavenger.boarded, game.expedition.cargo_inventory()])
	var vhs = game.hud.jammer_vhs
	vhs.set_process(false)
	game.world.weather.phase = {"type": "storm", "previous_type": "storm", "starts_at": 0.0, "ends_at": 200.0, "duration": 200.0, "index": 0}
	game.world.weather.elapsed = 30.0
	game.world._publish()
	game.world._weather_view.advance_visual(1.0)
	vhs.update_weather({"weather": {"type": "storm"}})
	vhs.advance(2)
	await _capture("rain")
	model.player.jammed = true
	model.player.jammer_strength = 1.0
	model.player.jammer_pulse = 0.8
	game.combat._publish()
	await _capture("rain-jammer")
	model.fire_projectile("bullet", "player", model.player.position + Vector3(0, 3, 0), model.player.position + Vector3(20, 3, 0), 5)
	model.fire_projectile("bullet", "enemy", model.player.position + Vector3(-18, 3, -3), model.player.position + Vector3(0, 3, -3), 5)
	model._update_projectiles(0.07)
	game.combat._publish()
	await _capture("rain-jammer-tracers")
	model.player.jammed = false
	model.player.jammer_strength = 0
	model.player.jammer_pulse = 0
	game.combat._publish()
	vhs.reset_weather()
	game.combat_view.tracers.segment({"from": model.player.position + Vector3(0, 3, 0), "to": model.player.position + Vector3(15, 2, 5), "team": "player"})
	game.combat_view.tracers.segment({"from": model.player.position + Vector3(-16, 2, -8), "to": model.player.position + Vector3(-3, 2, -2), "team": "enemy"})
	await _capture("tracers")
	game.caravan.damage_target("wagon-3", 10000, "explosion")
	game.combat._publish()
	game._update_cargo()
	await _capture("destroyed-middle")
	await _extraction()
	print("CARAVAN_WORLD_CAPTURE_DONE")
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _people_steps(seconds: float) -> void:
	for frame in int(seconds * 60):
		game.caravan.step(1.0 / 60.0)
		game.combat._sync_model_to_vehicle()
		game.combat._publish()
		game._update_crew_hint()
		await get_tree().process_frame

func _extraction() -> void:
	var model = game.combat.model
	game.crew_runtime.recall()
	game._buy_equipment("module:bazooka:crawler:1")
	game._buy_equipment("module:assaultRifle:crawler:2")
	game.expedition.caravan.capture_modules()
	var site: Dictionary = game.world.activities.get_extraction_state().sites[0]
	var offset: Vector3 = site.position - game.vehicle.global_position
	game.vehicle.global_position += offset
	game.vehicle.motion.x = game.vehicle.position.x
	game.vehicle.motion.z = game.vehicle.position.z
	for wagon: Dictionary in game.expedition.caravan.wagons:
		if wagon.attached and not wagon.dead:
			wagon.position += offset
			wagon.pose.position += offset
			wagon.previous_pose.position += offset
	game.caravan.formation.reset()
	game.session_flow.advance(1.0 / 60.0)
	game.vehicle._physics_process(1.0 / 60.0)
	game.combat._sync_vehicle_to_model()
	game.camera.reset_view()
	for frame in 180:
		game.camera._process(1.0 / 60.0)
	game.world.interact()
	for frame in 2400:
		if game.screen_state == "result":
			break
		if game.screen_state == "choice":
			var choices: Array = game.progression.get_shop_state().choices
			if not choices.is_empty():
				game._menu_action("choose", choices[0].id)
		game.session_flow.advance(1.0 / 60.0)
		game.vehicle._physics_process(1.0 / 60.0)
		game.world._physics_process(1.0 / 60.0)
		game.combat._physics_process(1.0 / 60.0)
		game._physics_process(1.0 / 60.0)
		game.camera._process(1.0 / 60.0)
		if model.player.hp < model.player.max_hp * 0.6:
			game.combat.activate_ability(2)
		await get_tree().process_frame
		if frame == 120:
			await _capture("extraction-defense")
	await _capture("extraction-result")
	print("CARAVAN_RENDER_EXTRACTION screen=%s result=%s" % [game.screen_state, game.expedition.last_result])

func _capture(label: String) -> void:
	for frame in 4:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path := "/private/tmp/iron-caravan-" + label + ".png"
		get_viewport().get_texture().get_image().save_png(path)
		print("CARAVAN_CAPTURE " + path)

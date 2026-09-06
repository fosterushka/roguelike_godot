extends Node

const Main = preload("res://app/main.tscn")
const Catalog = preload("res://modules/caravan/wagon_catalog.gd")
const Crew = preload("res://modules/crew/crew_factory.gd")

var game: Node3D
var captures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	get_window().size = Vector2i(1280, 800)
	get_tree().root.content_scale_size = Vector2i(1280, 800)
	game = Main.instantiate()
	game.profile_path = "/private/tmp/convoy-assets-capture-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	get_tree().root.add_child(game)
	await game.game_ready
	_prepare_garage()
	await game.restart_run()
	await _prepare_runtime()
	await _capture("attachments-all-wagons")
	_add_all_modules()
	game._sync_progression_stats()
	await _settle(5)
	await _capture("equipment-and-wagons")
	game.camera.half_height = 11.0
	game.camera.follow_offset = Vector3(12, 16, 12)
	game.camera._intro = 0.0
	await _settle(5)
	game.combat.set_running(false)
	game.world.set_running(false)
	game.vehicle.set_physics_process(false)
	game.camera.set_process(false)
	get_tree().paused = true
	await _capture("gameplay-pickup-wagons-crew")
	game.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	print("CONVOY_ASSETS_CAPTURE_DONE %d" % captures)
	get_tree().quit()

func _prepare_garage() -> void:
	game.progression.profile.expedition.credits = 10000
	game.progression.profile.expedition.stash.scrap = 500
	for type: String in Catalog.TYPES:
		if not game.expedition.caravan.buy_wagon(type):
			push_error("Could not buy showcase wagon " + type)
	var attachment_types: Array = Catalog.ATTACHMENTS.keys()
	for index in attachment_types.size():
		var wagon_id := "wagon-%d" % (index / 3 + 1)
		var slot := index % 3
		if not game.expedition.caravan.install_attachment(wagon_id, slot, attachment_types[index]):
			push_error("Could not install showcase attachment " + attachment_types[index])
	for crew_spec in [{"id": "crew-pickup-left", "role": "mechanic", "carrier": "crawler", "seat": 0}, {"id": "crew-pickup-right", "role": "loader", "carrier": "crawler", "seat": 1}, {"id": "crew-wagon-left", "role": "shooter", "carrier": "wagon-1", "seat": 0}, {"id": "crew-wagon-right", "role": "looter", "carrier": "wagon-1", "seat": 1}]:
		var person := Crew.create(str(crew_spec.role), str(crew_spec.id))
		person.carrier_id = crew_spec.carrier
		person.seat = int(crew_spec.seat)
		game.progression.profile.expedition.caravan.crew[person.id] = Crew.save(person)
		game.progression.profile.expedition.caravan.selected_crew_ids.append(person.id)

func _prepare_runtime() -> void:
	game.session_flow.clock.intro_remaining = 0.0
	game.session_flow.clock.phase = "running"
	game.hud.set_countdown(0, false)
	game.world.weather.phase = {"type": "sunny", "previous_type": "sunny", "starts_at": 0.0, "ends_at": 200.0, "duration": 200.0, "index": 0}
	game.world._sync_weather_model()
	game.world._publish()
	game.hud.jammer_vhs.reset_weather()
	game.combat.model.player.pending_upgrades = 0
	game.combat.model.enemies.clear()
	game.combat.model.spawn_queue.clear()
	game.camera.half_height = 22.0
	game.camera.follow_offset = Vector3(25, 34, 25)
	game.camera._intro = 0.0
	game._sync_progression_stats()
	await _settle(8)

func _add_all_modules() -> void:
	var module_types: Array = game.progression.catalog.modules.keys()
	for type: String in module_types:
		if type == "walkerTrailer":
			continue
		if game.combat.model.player.modules.any(func(module: Dictionary) -> bool: return str(module.type) == type):
			continue
		var mount: Dictionary = game.progression._next_mount(type)
		if not game.progression._add_module(type, mount):
			push_error("Could not add showcase module " + type)

func _settle(frames: int) -> void:
	for frame in frames:
		await get_tree().process_frame
		game.camera._process(1.0 / 60.0)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := "res://docs/validation/convoy-assets/%s.png" % label
	var status := get_viewport().get_texture().get_image().save_png(path)
	print("CONVOY_ASSETS_CAPTURE %s status=%d wagons=%d modules=%d crew=%d" % [path, status, game.expedition.caravan.wagons.size(), game.combat.model.player.modules.size(), game.expedition.caravan.crew.size()])
	captures += 1

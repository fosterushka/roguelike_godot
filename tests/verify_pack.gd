extends SceneTree

const Main = preload("res://app/main.tscn")
const WeatherRules = preload("res://modules/world/weather_rules.gd")
const EnemyFactory = preload("res://modules/combat/enemy_factory.gd")
const Roads = preload("res://modules/world/road_surface.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/iron-pack-language-%d.cfg" % Time.get_ticks_usec()
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-pack-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	var errors: Array[String] = []
	if not game.preparation.errors.is_empty():
		errors.append_array(game.preparation.errors)
	if game.hud.run_menu._description.text.begins_with("SINGLEPLAYER") == false:
		errors.append("Pack English menu unavailable")
	game._set_language("ru")
	if not game.hud.run_menu._description.text.begins_with("ОДИНОЧНАЯ"):
		errors.append("Pack Russian menu unavailable")
	await game.restart_run()
	if game.screen_state != "running" or game.arena.world_layout.villages.is_empty():
		errors.append("Pack cannot start generated offline world")
	var road_point: Dictionary = game.arena._roads.roads[0].points[0]
	if Roads.speed_multiplier_at(Vector3(road_point.x, 0, road_point.z)) != 1.5 or Roads.speed_multiplier_at(Vector3(10000, 0, 10000)) != 1.0:
		errors.append("Pack road speed footprint unavailable after world generation")
	if game.arena.source_world.context.ambient_critters.any(func(critter: Dictionary) -> bool: return str(critter.id).begins_with("figure")):
		errors.append("Pack still generates decorative people")
	var houses: Array = game.world.props.records.values().filter(func(prop: Dictionary) -> bool: return prop.kind == "building")
	if houses.is_empty():
		errors.append("Pack has no village houses")
	else:
		game.world.damage_props(houses[0].position, 0.1, 10000.0)
		if not houses[0].destroyed or game.arena._prop_colliders[houses[0].id].collision_layer != 0:
			errors.append("Pack house destruction fails")
	if not game.world.props.records.values().any(func(prop: Dictionary) -> bool: return prop.get("rock_obstacle", false) and prop.kind == "boulder" and is_finite(float(prop.hp))):
		errors.append("Pack destructible rocks missing")
	if game.world.weather.phase.type not in WeatherRules.TYPES:
		errors.append("Pack random weather missing")
	if WeatherRules.TRANSITION_SECONDS != 24.0:
		errors.append("Pack weather transition missing")
	var spawned := EnemyFactory.create("shooter", 99, Vector3.ZERO, RandomNumberGenerator.new())
	if spawned.get("model", "") != "drone":
		errors.append("Pack enemy factory missing")
	if game.world._activity_view._flare_smoke.plumes.size() != 12:
		errors.append("Pack airdrop smoke pool missing")
	if not game.hud.radar.visible or game.hud.radar.effective_range != 18.0:
		errors.append("Pack basic map missing at run start")
	if not game.hud.radar.detected_hostiles().is_empty():
		errors.append("Pack reveals enemies before radar upgrade")
	if game.vehicle.get_node("VehicleView")._model.get_meta("wheels", []).size() != 4:
		errors.append("Pack wheel vehicle missing")
	if game.preparation.procedural_models != ["ArmoredWheelVehicle", "SteeringWheelTrailer"]:
		errors.append("Pack procedural rigs not prepared")
	game.combat.model.player.coins = 300
	if not game.combat.buy_upgrade("module:radar") or game.combat.model.player.radar_range != 40:
		errors.append("Pack first radar tier unavailable")
	for level in [2,3,4]:
		if not game.combat.buy_upgrade("radar:%d" % level):
			errors.append("Pack radar upgrade missing")
	if game.combat.model.player.radar_range != 260 or game.combat.model.player.radar_level != 4:
		errors.append("Pack full radar power unavailable")
	game.combat.model.player.coins += 60
	if not game.combat.buy_upgrade("module:mineHacker") or not game.combat.model.player.modules.any(func(module: Dictionary) -> bool: return module.type == "mineHacker"):
		errors.append("Pack mine hacking kit cannot be installed")
	for kind: String in ["jammerTruck", "repairCrawler", "minelayer"]:
		if kind not in game.combat.model.Waves.queue_for(3):
			errors.append("Pack support vehicle not enabled: " + kind)
	game._toggle_armory()
	await process_frame
	if not game.hud.armory.visible or game.hud.armory.cards.columns < 2:
		errors.append("Pack compact armory unavailable")
	game._show_choices()
	if game.hud.run_menu._language_button.visible:
		errors.append("Pack upgrade menu exposes language setting")
	if game.preparation.completed != game.preparation.total:
		errors.append("Pack manifest not fully loaded")
	game.queue_free()
	await process_frame
	paused = false
	DirAccess.remove_absolute(Locale.settings_path)
	for message in errors:
		push_error(message)
	print("Offline pack: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)

extends SceneTree

const Main = preload("res://app/main.tscn")
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

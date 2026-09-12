extends SceneTree

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/fieldwork-nav-language-%d.cfg" % Time.get_ticks_usec()
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/fieldwork-nav-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	game._open_expedition()
	var hub = game.hideout_hub
	_check(not game.crew_runtime.view.speech_layer.visible, "World interaction prompts are suppressed behind modal screens")
	for dimensions in [Vector2i(960, 600), Vector2i(1280, 800)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for language: String in ["en", "ru"]:
			game._set_language(language)
			hub.select_tab("stash")
			await process_frame
			await process_frame
			_check(game.expedition_panel.body.get_child(0).get_child_count() == 2, "Storage and packed supplies are visible together")
			_check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(hub.deploy_button.get_global_rect()), "Departure stays inside " + str(dimensions))
			var settings: Button
			for node in hub._rail.get_children():
				if node.get_meta("section", "") == "settings": settings = node
			_click(settings.get_global_rect().get_center())
			_check(game.screen_state == "options" and game.hud.run_menu.settings_panel.visible, "Settings rail opens actual game settings")
			game._menu_action("options_back", "")
			_check(game.screen_state == "expedition" and hub.visible and hub.tab == "stash", "Settings returns to the originating supply screen")
			hub.select_tab("armory")
			await process_frame
			await process_frame
			var armory = game.hud.armory
			armory.select_module("bazooka")
			await process_frame
			_check(armory._module_actions.bazooka.is_visible_in_tree() and not armory._module_actions.assaultRifle.is_visible_in_tree(), "Only selected equipment exposes transaction actions")
			_check(not armory.item_preview_pip.visible, "Inspector does not open a floating model tooltip")
			_check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(armory._inspector.get_global_rect()), "Selected item inspector fits " + str(dimensions))
			_check(armory._inspector.get_global_rect().end.y <= hub.deploy_button.get_global_rect().position.y, "Inspector cannot cover the fixed departure footer")
	game.queue_free()
	await process_frame
	paused = false
	print("FIELDWORK UI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

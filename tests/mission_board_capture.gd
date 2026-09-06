extends Node

const Main = preload("res://app/main.tscn")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var game: Node
var captures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/iron-mission-capture-language-%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("ru")
	game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-mission-capture-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	get_tree().root.add_child(game)
	await game.game_ready
	game._open_expedition()
	game.expedition_panel.show_state(game.expedition.snapshot(), "quests")
	await _capture("new-profile-ru-1280")
	var accepted := 0
	for quest: Dictionary in game.expedition.snapshot().quests:
		if accepted == 3:
			break
		if quest.get("can_accept", false) and game.expedition.action("accept", str(quest.id)):
			accepted += 1
	for resolution: Vector2i in [Vector2i(1280, 800), Vector2i(960, 600)]:
		await _resize(resolution)
		for language: String in ["ru", "en"]:
			game._set_language(language)
			game.expedition_panel.show_state(game.expedition.snapshot(), "quests")
			await _capture("active-%s-%d" % [language, resolution.x])
	var board = game.expedition_panel.mission_board
	board.status_select.select(3)
	board.status_select.item_selected.emit(3)
	board.next.pressed.emit()
	await _capture("all-page2-en-960")
	board.category_filter.select(2)
	board.category_filter.item_selected.emit(2)
	await _capture("hunting-en-960")
	board.category_filter.select(0)
	board.category_filter.item_selected.emit(0)
	board.status_select.select(0)
	board.status_select.item_selected.emit(0)
	game._close_expedition()
	await game.restart_run()
	await get_tree().create_timer(1.0).timeout
	for resolution: Vector2i in [Vector2i(1280, 800), Vector2i(960, 600)]:
		await _resize(resolution)
		for language: String in ["ru", "en"]:
			game._set_language(language)
			game._on_state(game.combat.get_state())
			await _capture("hud-%s-%d" % [language, resolution.x])
	game.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	DirAccess.remove_absolute(Locale.settings_path)
	print("MISSION_BOARD_CAPTURE_COMPLETE: %d images, %d active missions" % [captures, accepted])
	get_tree().quit()

func _resize(resolution: Vector2i) -> void:
	get_tree().root.size = resolution
	get_tree().root.content_scale_size = resolution
	for frame in 3:
		await get_tree().process_frame

func _capture(id: String) -> void:
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame := get_tree().root.get_texture().get_image()
	var path := "/private/tmp/iron-missions-%s.png" % id
	print("MISSION_CAPTURE %s status=%d size=%s" % [path, frame.save_png(path), frame.get_size()])
	captures += 1

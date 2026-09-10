extends RefCounted

const Catalog = preload("res://modules/settings/settings_catalog.gd")
const Actions = preload("res://app/input_actions.gd")
var game: Node

func setup(owner_game: Node) -> void:
	game = owner_game
	apply()

func values() -> Dictionary:
	return Catalog.normalize(game.progression.profile.settings)

func change(key: String, value: Variant) -> void:
	var data := values()
	data[key] = value
	game.progression.update_settings(data)
	apply(key in ["fullscreen", "resolution"])

func apply(display: bool = true) -> void:
	var data := values()
	game.camera.shake_intensity = data.cameraShake
	game.expedition_panel.intensity = data.cameraShake
	game.sound.set_enabled(data.soundEnabled)
	game.sound.set_mix(data)
	game.hud.set_sound_enabled(data.soundEnabled)
	Actions.apply_bindings(data.bindings)
	Engine.max_fps = Catalog.effective_fps(data)
	var quality := Catalog.effective_quality(data)
	var viewport := game.get_viewport()
	viewport.scaling_3d_scale = quality.scale
	viewport.msaa_3d = int(quality.msaa)
	game.arena.set_graphics_quality(quality)
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data.vsync else DisplayServer.VSYNC_DISABLED)
	if display:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if data.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not data.fullscreen:
			var available := DisplayServer.screen_get_usable_rect()
			var size: Vector2i = Catalog.RESOLUTIONS[int(data.resolution)].min(available.size)
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(available.position + (available.size - size) / 2)

func bind_key(action: String, key: int) -> bool:
	if action not in Actions.KEYS or action in ["pause_game", "restart_run"] or key == KEY_ESCAPE:
		return false
	for other: String in Actions.KEYS:
		if other == action:
			continue
		for event: InputEvent in InputMap.action_get_events(other):
			if event is InputEventKey and event.physical_keycode == key:
				return false
	var bindings: Dictionary = values().bindings
	bindings[action] = key
	change("bindings", bindings)
	return true

func reset_bindings() -> void:
	change("bindings", {})

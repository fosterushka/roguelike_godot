extends CanvasLayer

const Icons = preload("res://presentation/ui/ui_icons.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")

signal ability_selected(slot: int)
signal ability_requested
signal pause_requested
signal resume_requested
signal menu_action_requested(action: String, id: String)
signal loading_progress_changed(value: float, stage: String)
signal touch_command_requested(command: String)
signal sound_requested
signal armory_requested
signal restart_requested
signal language_requested(language: String)

const TouchControls = preload("res://presentation/ui/touch_controls.gd")
const Armory = preload("res://presentation/ui/armory_panel.gd")
const RunMenu = preload("res://presentation/ui/run_menu.gd")
const WorldMarkers = preload("res://presentation/ui/world_markers.gd")
const Radar = preload("res://presentation/ui/radar.gd")
const AbilitySlot = preload("res://presentation/ui/ability_slot.gd")
var run_menu: ColorRect
var armory: ColorRect
var touch_controls: Control
var radar: Control
var markers: Control
var _objective_label: Label
var _hack_label: Label
var _run_label: Label
var _abilities_label: Label
var _hotbar_buttons: Array[Button] = []
var _hotbar: HBoxContainer
var _stats_panel: PanelContainer
var _coins_label: Label
var _player_stats_label: Label
var _target_label: Label
var _sound_button: Button
var _language_button: Button
var _options_button: Button
var _gameplay: Control
var _gameplay_active := false
var _last_telemetry: Dictionary = {}

const INK := Color("eee9db")
const MUTED := Color("b8b7aa")
const AMBER := Color("e6ac58")
const STRIP := Color(0.055, 0.065, 0.065, 0.92)

var _speed_label: Label
var _health_label: Label
var _fuel_label: Label
var _health_bar: ProgressBar
var _fuel_bar: ProgressBar
var _pause_overlay: ColorRect
var _loading_overlay: ColorRect
var _loading_label: Label
var _loading_bar: ProgressBar
var loading_progress := 0.0
var _resume_button: Button
var _countdown_label: Label
var _countdown: Control
var _world_banner: PanelContainer
var _world_banner_text: Label
var _banner_remaining := 0.0
var reward_notice: PanelContainer
var _status_label: Label
var fury_meter: Control
var jammer_overlay: Control
var jammer_vhs: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var screen := Control.new()
	screen.name = "Screen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	Locale.initialize()
	_gameplay = Control.new()
	_gameplay.name = "Gameplay"
	_gameplay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gameplay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(_gameplay)
	jammer_vhs = preload("res://presentation/ui/jammer_vhs.gd").new()
	_gameplay.add_child(jammer_vhs)
	markers = WorldMarkers.new()
	_gameplay.add_child(markers)
	_build_telemetry(_gameplay)
	_build_controls(_gameplay)
	jammer_overlay = preload("res://presentation/ui/jammer_overlay.gd").new()
	_gameplay.add_child(jammer_overlay)
	_build_run_info(_gameplay)
	fury_meter = preload("res://presentation/ui/road_fury_meter.gd").new()
	_gameplay.add_child(fury_meter)
	touch_controls = TouchControls.new()
	_gameplay.add_child(touch_controls)
	touch_controls.command_requested.connect(func(command: String) -> void: touch_command_requested.emit(command))
	armory = Armory.new()
	screen.add_child(armory)
	armory.action_requested.connect(func(action: String, id: String) -> void: menu_action_requested.emit(action, id))
	run_menu = RunMenu.new()
	screen.add_child(run_menu)
	run_menu.language_requested.connect(func(value: String) -> void: language_requested.emit(value))
	run_menu.action_requested.connect(func(action: String, id: String) -> void: menu_action_requested.emit(action, id))
	_countdown = preload("res://presentation/ui/run_countdown.gd").new()
	screen.add_child(_countdown)
	_countdown_label = _countdown.glyph
	_build_world_banner(_gameplay)
	reward_notice = preload("res://presentation/ui/reward_notice.gd").new()
	_gameplay.add_child(reward_notice)
	markers.occluders.assign([_stats_panel, _hotbar, radar, _run_label, _objective_label, _target_label, _hack_label, _status_label, _world_banner, reward_notice, jammer_overlay, fury_meter])
	_build_pause(screen)
	_build_loading(screen)
	_sync_gameplay_visibility()


func update_telemetry(data: Dictionary) -> void:
	_last_telemetry = data
	_speed_label.text = Locale.text("СКОРОСТЬ") + "  " + Locale.text("%03d км/ч") % roundi(absf(float(data.get("speed", 0.0))) * 3.6)
	_update_meter(_health_label, _health_bar, Locale.text("КОРПУС"), float(data.get("health", 0.0)), float(data.get("max_health", 100.0)))
	_update_meter(_fuel_label, _fuel_bar, Locale.text("ТОПЛИВО"), float(data.get("fuel", 0.0)), float(data.get("max_fuel", 100.0)))


func set_paused(value: bool) -> void:
	_pause_overlay.visible = value
	if value:
		_resume_button.grab_focus()
	else:
		_resume_button.release_focus()
	_sync_banner_visibility()
	_sync_gameplay_visibility()


func set_loading(value: bool) -> void:
	if value:
		jammer_vhs.reset_weather()
		loading_progress = 0.0
		reward_notice.clear()
		_banner_remaining = 0.0
		_world_banner.visible = false
	_loading_overlay.visible = value
	_sync_gameplay_visibility()


func set_status(message: String) -> void:
	_status_label.text = message
	_status_label.visible = not message.is_empty()


func _build_telemetry(screen: Control) -> void:
	_stats_panel = PanelContainer.new()
	_stats_panel.name = "PlayerStats"
	_stats_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_stats_panel.offset_left = 12
	_stats_panel.offset_right = 232
	_stats_panel.offset_top = -222
	_stats_panel.offset_bottom = -12
	_stats_panel.add_theme_stylebox_override("panel", _panel_style())
	_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(_stats_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_stats_panel.add_child(column)
	var health := _meter(column, "health")
	_health_label = health[0]
	_health_bar = health[1]
	var fuel := _meter(column, "fuel")
	_fuel_label = fuel[0]
	_fuel_bar = fuel[1]
	_speed_label = _label("", 12, INK)
	column.add_child(_speed_label)
	_coins_label = _label("", 12, AMBER)
	column.add_child(_coins_label)
	var scrap_icon := Icons.view("scrap", 18)
	_coins_label.add_child(scrap_icon)
	var scrap_backing := StyleBoxEmpty.new()
	scrap_backing.content_margin_left = 24
	_coins_label.add_theme_stylebox_override("normal", scrap_backing)
	_player_stats_label = _label("", 11, MUTED)
	column.add_child(_player_stats_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	column.add_child(actions)
	var armory_button := _button(Locale.text("АРСЕНАЛ"), 76)
	armory_button.tooltip_text = Locale.text("АРСЕНАЛ [B]")
	armory_button.pressed.connect(func() -> void: armory_requested.emit())
	Icons.apply(armory_button, "armory", 18)
	armory_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(armory_button)
	var pause_button := _button(Locale.text("ПАУЗА"), 76)
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	Icons.apply(pause_button, "settings", 18)
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(pause_button)
	update_telemetry({"health": 100.0, "fuel": 100.0})


func _build_controls(screen: Control) -> void:
	_status_label = _label("", 13, INK)
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_status_label.offset_left = -240
	_status_label.offset_right = 240
	_status_label.offset_top = 120
	_status_label.offset_bottom = 146
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.visible = false
	screen.add_child(_status_label)


func _build_pause(screen: Control) -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.color = Color(0.025, 0.035, 0.035, 0.88)
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	screen.add_child(_pause_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	var title := _label(Locale.text("ПАУЗА"), 30, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := _label(Locale.text("Заезд приостановлен"), 15, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	_resume_button = _button(Locale.text("ПРОДОЛЖИТЬ"), 300)
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	column.add_child(_resume_button)
	var restart_button := _button(Locale.text("НАЧАТЬ ЗАНОВО"), 300)
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	column.add_child(restart_button)
	_options_button = _button("НАСТРОЙКИ" if Locale.language == "ru" else "OPTIONS", 300)
	_options_button.pressed.connect(func() -> void: menu_action_requested.emit("options", ""))
	column.add_child(_options_button)
	var menu_button := _button(Locale.text("ГЛАВНОЕ МЕНЮ"), 300)
	menu_button.pressed.connect(func() -> void: menu_action_requested.emit("menu", ""))
	column.add_child(menu_button)
	column.add_child(_label(Locale.text("УПРАВЛЕНИЕ"), 12, AMBER))
	var hints := _label(Locale.text("WASD · Движение     Shift · Дрифт\nF / ЛКМ · Цель     E · Взаимодействие\n1–3 · Выбор навыка     Space · Применить\nB · Арсенал     M · Масштаб карты\nP / Esc · Пауза"), 12, MUTED)
	hints.name = "ControlTips"
	column.add_child(hints)


func _build_loading(screen: Control) -> void:
	_loading_overlay = ColorRect.new()
	_loading_overlay.color = Color("111717")
	_loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(_loading_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	var title := _label("IRON CARAVAN", 30, AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_loading_label = _label(Locale.text("Подготовка игры"), 17, MUTED)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_loading_label)
	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(420, 8)
	_loading_bar.show_percentage = false
	column.add_child(_loading_bar)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = Locale.text(text)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _meter(parent: BoxContainer, icon_key: String) -> Array:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 126
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 4)
	parent.add_child(column)
	var label := _label("", 12, INK)
	var row := HBoxContainer.new()
	row.add_child(Icons.view(icon_key, 18))
	row.add_child(label)
	column.add_child(row)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(126, 5)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("3b4240")
	var fill := StyleBoxFlat.new()
	fill.bg_color = AMBER
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	column.add_child(bar)
	return [label, bar]


func _update_meter(label: Label, bar: ProgressBar, caption: String, value: float, maximum: float) -> void:
	var ratio := clampf(value / maxf(maximum, 0.001), 0.0, 1.0)
	label.text = "%s  %d%%" % [caption, roundi(ratio * 100.0)]
	bar.value = ratio * 100.0


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = STRIP
	style.border_color = Color("786347")
	style.border_width_bottom = 1
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _button(text: String, width: float) -> Button:
	var button := Button.new()
	button.text = Locale.text(text)
	button.custom_minimum_size = Vector2(width, 32)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", INK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("303734")
	normal.border_color = Color("706247")
	normal.set_border_width_all(1)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("4b4738")
	hover.border_color = AMBER
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("685238")
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = AMBER
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	return button

func _build_run_info(screen: Control) -> void:
	_objective_label = _label("", 12, MUTED)
	_objective_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_objective_label.offset_left = 12
	_objective_label.offset_right = 310
	_objective_label.offset_top = -332
	_objective_label.offset_bottom = -244
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.add_child(_objective_label)
	_hack_label = _label("", 12, AMBER)
	_hack_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hack_label.offset_left = -180
	_hack_label.offset_right = 180
	_hack_label.offset_top = -105
	_hack_label.offset_bottom = -77
	_hack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(_hack_label)
	_target_label = _label("", 12, AMBER)
	_target_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_target_label.offset_left = -300
	_target_label.offset_right = -12
	_target_label.offset_top = -322
	_target_label.offset_bottom = -232
	_target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.add_child(_target_label)
	_run_label = _label("", 13, INK)
	_run_label.name = "WaveStatus"
	_run_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_run_label.offset_left = -210
	_run_label.offset_right = 210
	_run_label.offset_top = 12
	_run_label.offset_bottom = 40
	_run_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(_run_label)
	_abilities_label = _label("", 12, AMBER)
	_abilities_label.visible = false
	screen.add_child(_abilities_label)
	_hotbar = HBoxContainer.new()
	_hotbar.name = "Abilities"
	_hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.offset_left = -165
	_hotbar.offset_right = 165
	_hotbar.offset_top = -66
	_hotbar.offset_bottom = -12
	_hotbar.add_theme_constant_override("separation", 6)
	screen.add_child(_hotbar)
	for index in 3:
		var button := AbilitySlot.new()
		button.slot = index
		button.pressed.connect(func() -> void:
			ability_selected.emit(index)
			ability_requested.emit())
		_hotbar.add_child(button)
		_hotbar_buttons.append(button)
	radar = Radar.new()
	radar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	radar.offset_left = -188
	radar.offset_right = -12
	radar.offset_top = -220
	radar.offset_bottom = -12
	screen.add_child(radar)
	for label: Label in [_run_label, _target_label, _hack_label, _objective_label]:
		var backing := StyleBoxFlat.new()
		backing.bg_color = Color(0.025, 0.04, 0.028, 0.88)
		backing.content_margin_left = 8
		backing.content_margin_right = 8
		backing.content_margin_top = 5
		backing.content_margin_bottom = 5
		label.add_theme_stylebox_override("normal", backing)

func update_run(data: Dictionary, camera: Camera3D, selected: int) -> void:
	fury_meter.update_player(data.get("player", {}))
	jammer_overlay.update_state(data)
	jammer_vhs.update_state(data)
	markers.update_state(data, camera)
	var hack: Dictionary = data.get("hack_status", {})
	_hack_label.text = Locale.text("НУЖЕН МОДУЛЬ ВЗЛОМА МИН") if hack.get("requires_module", false) else Locale.text("[E] УДЕРЖИВАЙТЕ · ВЗЛОМ %.1f/3 с") % (float(hack.get("progress", 0.0)) * 3.0) if hack.get("available", false) else ""
	var seconds := int(data.get("elapsed", 0))
	_run_label.text = Locale.text("ВОЛНА %d/%d · ВРАГИ %d") % [data.get("wave", 1), data.get("final_wave", 6), data.get("remaining", 0)]
	_coins_label.text = Locale.text("ЛОМ %d") % data.get("scrap", 0)
	_player_stats_label.text = Locale.text("УРОВЕНЬ %d · XP %d/%d\nУБИТО %d · %02d:%02d") % [data.get("level", 1), data.get("xp", 0), data.get("xp_next", 70), data.get("kills", 0), int(seconds / 60.0), seconds % 60]
	var player: Dictionary = data.get("player", {})
	for index in 3:
		_hotbar_buttons[index].update_state(player, selected == index)
	_target_label.text = ""
	for enemy: Dictionary in data.get("enemies", []):
		if enemy.get("id", -2) == data.get("focus_id", -1) or enemy.get("boss", false):
			_target_label.text += "%s  %d/%d%s\n" % [Locale.text(str(enemy.get("kind", enemy.get("type", "ЦЕЛЬ")))).to_upper(), enemy.get("hp", 0), enemy.get("max_hp", 1), Locale.text(" · ФАЗА %d") % (int(enemy.get("phase", 0)) + 1) if enemy.get("boss", false) else ""]
	for enemy: Dictionary in data.get("enemies", []):
		if enemy.get("boss", false):
			var parts: Array[String] = []
			for component: Dictionary in enemy.get("components", []):
				parts.append("%s %d/%d" % [Locale.text(str(component.get("kind", ""))), component.get("hp", 0), component.get("max_hp", 0)])
			_target_label.text += " · ".join(parts)
	_target_label.visible = not _target_label.text.is_empty()
	_hack_label.visible = not _hack_label.text.is_empty()
	radar.update_state(data, camera)

func show_menu(title: String, description: String, rows: Array, main_menu: bool = false) -> void:
	armory.hide_panel()
	_pause_overlay.visible = false
	run_menu.display(title, description, rows, main_menu)
	_sync_banner_visibility()
	_sync_gameplay_visibility()

func hide_menus() -> void:
	armory.hide_panel()
	run_menu.visible = false
	set_paused(false)

func update_world(data: Dictionary) -> void:
	jammer_vhs.update_weather(data)
	markers.update_world(data)
	radar.update_world(data)
	var activity: Dictionary = data.get("activity", {}).get("current", {})
	var extraction: Dictionary = data.get("extraction", {})
	var lines: Array[String] = []
	if not activity.is_empty():
		lines.append(Locale.text("ЗАДАЧА: %s · %s") % [Locale.text(str(activity.get("type", ""))).to_upper(), Locale.text(str(activity.get("state", "")))])
		if not str(activity.get("reward_label", "")).is_empty():
			lines.append(Locale.text(str(activity.reward_label)))
	if extraction.get("visible", false):
		var ru := Locale.language == "ru"
		if extraction.get("active", false):
			lines.append(("ЗАЩИЩАЙТЕ ЗОНУ · %.1f с" if ru else "DEFEND ZONE · %.1fs") % extraction.get("remaining_seconds", 20.0))
			if extraction.get("mode", "") == "leaving":
				lines.append(("ВЕРНИТЕСЬ: %.1f с" if ru else "RETURN TO ZONE: %.1fs") % extraction.get("leave_remaining", 3.0))
			else:
				lines.append(("АТАКУЮЩИЕ: %d" if ru else "ATTACKERS: %d") % extraction.get("hostile_count", 0))
		elif extraction.get("can_request", false):
			lines.append("[E] ЭВАКУАЦИЯ · ЗАЩИТА 20 с" if ru else "[E] EXTRACT · DEFEND 20s")
		else:
			lines.append(("ЗОНА ЭВАКУАЦИИ · %d м" if ru else "EXTRACTION ZONE · %dm") % extraction.get("distance", 0))
	_objective_label.text = "\n".join(lines)
	_objective_label.visible = not lines.is_empty()
	var boundary: Dictionary = data.get("boundary", {})
	if boundary.get("outside", false):
		set_status(Locale.text("ВЕРНИТЕСЬ В БОЕВУЮ ЗОНУ · %.1f с") % float(boundary.get("remaining", 15.0)))
	elif not data.get("station", {}).is_empty():
		set_status(Locale.text("ЗАПРАВКА · +24 топлива/с"))
	else:
		set_status("")

func set_sound_enabled(value: bool) -> void:
	if is_instance_valid(_sound_button):
		_sound_button.text = Locale.text("ЗВУК: ВКЛ") if value else Locale.text("ЗВУК: ВЫКЛ")

func set_loading_progress(stage: String, progress: float) -> void:
	loading_progress = maxf(loading_progress, clampf(progress, 0.0, 1.0))
	_loading_label.text = Locale.text(stage)
	_loading_bar.value = loading_progress * 100.0
	loading_progress_changed.emit(loading_progress, stage)

func show_armory(state: Dictionary, player: Dictionary) -> void:
	run_menu.visible = false
	_pause_overlay.visible = false
	armory.display(state, player)
	_sync_banner_visibility()
	_sync_gameplay_visibility()

func _build_world_banner(screen: Control) -> void:
	_world_banner = PanelContainer.new()
	_world_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_world_banner.offset_left = -280
	_world_banner.offset_right = 280
	_world_banner.offset_top = 54
	_world_banner.offset_bottom = 112
	_world_banner.add_theme_stylebox_override("panel", _panel_style())
	_world_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_banner_text = _label("", 16, AMBER)
	_world_banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world_banner.add_child(_world_banner_text)
	_world_banner.visible = false
	screen.add_child(_world_banner)

func show_world_banner(title: String, detail: String) -> void:
	_world_banner_text.text = Locale.text(title) + "\n" + Locale.text(detail)
	_banner_remaining = 2.1
	_sync_banner_visibility()
	_sync_gameplay_visibility()

func _sync_banner_visibility() -> void:
	_world_banner.visible = _banner_remaining > 0 and not get_tree().paused and not armory.visible and not run_menu.visible and not _pause_overlay.visible and not _loading_overlay.visible

func _process(delta: float) -> void:
	_sync_banner_visibility()
	_sync_gameplay_visibility()
	if not _world_banner.visible:
		return
	_banner_remaining = maxf(0, _banner_remaining - delta)
	_world_banner.visible = _banner_remaining > 0

func set_countdown(step: Variant, show: bool) -> void:
	_countdown.set_step(int(step), show)

func set_gameplay_active(active: bool) -> void:
	_gameplay_active = active
	_sync_gameplay_visibility()

func _sync_gameplay_visibility() -> void:
	if not is_instance_valid(_gameplay) or not is_instance_valid(_loading_overlay):
		return
	_gameplay.visible = _gameplay_active and not _pause_overlay.visible and not armory.visible and not run_menu.visible and not _loading_overlay.visible

func set_language(value: String) -> void:
	Locale.set_language(value)
	Locale.refresh_controls(get_node("Screen"))
	if is_instance_valid(_language_button):
		_language_button.text = "LANGUAGE: ENGLISH" if Locale.language == "en" else "ЯЗЫК: РУССКИЙ"
	if is_instance_valid(_options_button):
		_options_button.text = "НАСТРОЙКИ" if Locale.language == "ru" else "OPTIONS"
	run_menu.refresh_language()
	reward_notice.refresh_language()
	jammer_overlay.refresh_language()
	update_telemetry(_last_telemetry)
	if armory.visible:
		armory.display(armory._shop, armory._player)

func finish_countdown() -> void:
	_countdown.finish()

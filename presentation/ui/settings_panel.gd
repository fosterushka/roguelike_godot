extends ColorRect

const Fieldwork = preload("res://presentation/ui/fieldwork_tokens.gd")

signal closed
signal language_requested(language: String)
const Catalog = preload("res://modules/settings/settings_catalog.gd")
const Styles = preload("res://presentation/ui/ui_styles.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const PANEL_WIDTH := 1000.0
const PANEL_HEIGHT := 650.0
const MARGIN := 24.0
const CONTROL_NAMES := {
	"drive_forward": ["Вперёд", "Forward"], "drive_backward": ["Назад", "Reverse"],
	"drive_left": ["Влево", "Left"], "drive_right": ["Вправо", "Right"],
	"handbrake": ["Ручной тормоз", "Handbrake"], "focus_target": ["Выбрать цель", "Focus target"],
	"interact": ["Взаимодействие", "Interact"], "ability_one": ["Способность 1", "Ability 1"],
	"ability_two": ["Способность 2", "Ability 2"], "ability_three": ["Способность 3", "Ability 3"],
	"activate_ability": ["Активировать способность", "Activate ability"], "armory": ["Оружейная", "Armory"],
	"inventory": ["Инвентарь", "Inventory"], "crew_menu": ["Экипаж", "Crew"],
	"crew_collect": ["Собрать экипаж", "Collect crew"], "radar_zoom": ["Масштаб радара", "Radar zoom"],
}
var controller: RefCounted
var current_tab := 0
var _column: VBoxContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tabs: VBoxContainer
var _heading: Label
var _back: Button
var _status: Label
var _binding := ""

func words(ru: String, en: String) -> String:
	return ru if Locale.language == "ru" else en

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Fieldwork.BG
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 24)
	margin.add_child(_column)
	var header := HBoxContainer.new()
	_column.add_child(header)
	_heading = Styles.label("", 28)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_heading)
	_back = Styles.button("")
	_back.custom_minimum_size = Vector2(116, 36)
	Styles.ghost(_back)
	preload("res://presentation/ui/ui_icons.gd").apply(_back, "back", 18)
	_back.pressed.connect(func() -> void: _binding = ""; closed.emit())
	header.add_child(_back)
	_column.add_child(HSeparator.new())
	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 40)
	_column.add_child(workspace)
	_tabs = VBoxContainer.new()
	_tabs.custom_minimum_size.x = 180
	_tabs.add_theme_constant_override("separation", 8)
	workspace.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)
	_column.add_child(HSeparator.new())
	_status = Styles.label("", 12)
	Styles.muted(_status)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_status)
	resized.connect(_fit)
	_fit()
	visible = false

func _fit() -> void:
	if _column == null:
		return
	_scroll.custom_minimum_size.x = minf(792, size.x - 284)

func display(settings_controller: RefCounted) -> void:
	controller = settings_controller
	visible = true
	rebuild()

func rebuild() -> void:
	_binding = ""
	_heading.text = words("Настройки", "Settings")
	_back.text = words("Назад", "Back")
	_status.text = words("Изменения применяются и сохраняются сразу.", "Changes apply and save immediately.")
	for container in [_tabs, _body]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	var captions := [words("Изображение", "Display"), words("Звук", "Audio"), words("Управление", "Controls")]
	for index in captions.size():
		var tab := Styles.button(captions[index])
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		Styles.tab(tab, index == current_tab)
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size.y = 38
		preload("res://presentation/ui/ui_icons.gd").apply(tab, ["monitor", "sound", "keyboard"][index], 18)
		tab.toggle_mode = true
		tab.button_pressed = index == current_tab
		tab.pressed.connect(func() -> void: current_tab = index; _scroll.scroll_vertical = 0; rebuild())
		_tabs.add_child(tab)
	_body.add_child(Styles.label(captions[current_tab], 24))
	var subtitle := Styles.label([words("Параметры экрана и производительности.", "Display and performance settings."), words("Громкость и звуки игры.", "Game sound and volume."), words("Клавиши и управление камерой.", "Key bindings and camera controls.")][current_tab], 14)
	Styles.muted(subtitle)
	_body.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	_body.add_child(spacer)
	match current_tab:
		0: _video()
		1: _audio()
		2: _controls()

func _field(caption: String) -> HBoxContainer:
	_body.add_child(HSeparator.new())
	var column := HBoxContainer.new()
	column.custom_minimum_size.y = 40
	column.add_theme_constant_override("separation", 4)
	var label := Styles.label(caption, 14)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	_body.add_child(column)
	return column

func _toggle(key: String, caption: String) -> void:
	var button := Styles.button("")
	button.custom_minimum_size.x = 100
	button.toggle_mode = true
	button.button_pressed = controller.values()[key]
	button.text = (words("  [ВКЛ]", "  [ON]") if button.button_pressed else words("  [ВЫКЛ]", "  [OFF]"))
	button.toggled.connect(func(value: bool) -> void:
		button.text = (words("  [ВКЛ]", "  [ON]") if value else words("  [ВЫКЛ]", "  [OFF]"))
		controller.change(key, value)
		if key in ["laptop", "fullscreen"]: rebuild())
	_field(caption).add_child(button)

func _select(key: String, caption: String, items: Array, disabled: bool = false) -> void:
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(240, 36)
	for item: String in items:
		select.add_item(item)
	select.selected = int(controller.values()[key])
	if controller.values().laptop:
		if key == "quality": select.selected = 0
		if key == "fpsLimit": select.selected = Catalog.FPS_LIMITS.find(Catalog.LAPTOP_FPS)
	select.disabled = disabled
	select.item_selected.connect(func(index: int) -> void: controller.change(key, index))
	_field(caption).add_child(select)

func _slider(key: String, caption: String) -> void:
	var column := _field(caption)
	var row := HBoxContainer.new()
	row.custom_minimum_size.x = 240
	column.add_child(row)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = Catalog.MAX_CAMERA_SHAKE if key == "cameraShake" else 1.0
	slider.step = Catalog.SLIDER_STEP
	slider.value = controller.values()[key]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 30
	row.add_child(slider)
	var amount := Styles.label("%d%%" % roundi(slider.value * 100), 14)
	amount.custom_minimum_size.x = 48
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(amount)
	slider.value_changed.connect(func(value: float) -> void:
		amount.text = "%d%%" % roundi(value * 100)
		controller.change(key, value))

func _video() -> void:
	var data: Dictionary = controller.values()
	_toggle("laptop", words("Режим ноутбука: 60 FPS, низкое качество", "Laptop mode: 60 FPS, low quality"))
	_toggle("fullscreen", words("Полный экран", "Fullscreen"))
	var resolutions: Array = []
	for resolution: Vector2i in Catalog.RESOLUTIONS:
		resolutions.append("%d × %d" % [resolution.x, resolution.y])
	_select("resolution", words("Разрешение окна", "Window resolution"), resolutions, data.fullscreen)
	if data.fullscreen:
		_body.add_child(Styles.label(words("Полный экран использует разрешение рабочего стола.", "Fullscreen uses the desktop resolution."), 13))
	_toggle("vsync", words("Вертикальная синхронизация (VSync)", "Vertical synchronization (VSync)"))
	_select("quality", words("Качество графики", "Graphics quality"), [words("Низкое", "Low"), words("Среднее", "Medium"), words("Высокое", "High")], data.laptop)
	var limits: Array = []
	for fps: int in Catalog.FPS_LIMITS:
		limits.append(words("Без ограничения", "Unlimited") if fps == 0 else "%d FPS" % fps)
	_select("fpsLimit", words("Ограничение частоты кадров", "Frame rate limit"), limits, data.laptop)
	var hz := DisplayServer.screen_get_refresh_rate() if DisplayServer.get_name() != "headless" else -1.0
	var refresh := "%.0f Hz" % hz if hz > 0 else words("не определена", "unavailable")
	var info := Styles.label(words("Частота монитора: %s. Меняется в настройках ОС.", "Monitor refresh: %s. Change it in OS settings.") % refresh, 13)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(info)

func _audio() -> void:
	_toggle("soundEnabled", words("Звук включён", "Sound enabled"))
	_slider("masterVolume", words("Общая громкость", "Master volume"))
	_slider("effectsVolume", words("Эффекты и окружение", "Effects and ambience"))
	_slider("engineVolume", words("Двигатель", "Engine"))
	_slider("uiVolume", words("Интерфейс", "Interface"))

func _controls() -> void:
	_slider("cameraShake", words("Тряска камеры", "Camera shake"))
	var language := Styles.button(words("Язык: Русский", "Language: English"))
	language.pressed.connect(func() -> void: language_requested.emit("en" if Locale.language == "ru" else "ru"))
	_body.add_child(language)
	var reset := Styles.button(words("Сбросить клавиши", "Reset keys"))
	reset.pressed.connect(func() -> void: controller.reset_bindings(); rebuild())
	_body.add_child(reset)
	_body.add_child(Styles.label(words("Esc / P: пауза. Колесо: масштаб. СКМ: обзор.", "Esc / P: pause. Wheel: zoom. MMB: pan."), 13))
	for action: String in CONTROL_NAMES:
		var names: Array = CONTROL_NAMES[action]
		var keys: Array[String] = []
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys.append(OS.get_keycode_string(event.physical_keycode))
		var button := Styles.button(words(names[0], names[1]) + "    " + " / ".join(keys))
		button.pressed.connect(func() -> void:
			if not _binding.is_empty(): rebuild(); return
			_binding = action
			button.text = words("Нажмите клавишу; Esc отменяет", "Press a key; Esc cancels"))
		_body.add_child(button)

func capture_input(event: InputEvent) -> bool:
	if not is_visible_in_tree() or _binding.is_empty() or not event is InputEventKey:
		return false
	if not event.pressed or event.echo:
		return true
	if event.keycode == KEY_ESCAPE:
		rebuild()
	elif not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed) and controller.bind_key(_binding, event.physical_keycode if event.physical_keycode != 0 else event.keycode):
		rebuild()
	else:
		_status.text = words("Клавиша занята или недоступна. Выберите другую.", "Key is in use or unavailable. Choose another.")
	return true

func _input(event: InputEvent) -> void:
	if capture_input(event):
		get_viewport().set_input_as_handled()

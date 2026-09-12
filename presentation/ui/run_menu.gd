extends ColorRect

const Fieldwork = preload("res://presentation/ui/fieldwork_tokens.gd")

signal action_requested(action: String, id: String)
signal language_requested(language: String)
const Locale = preload("res://presentation/ui/ui_locale.gd")
var settings_panel: ColorRect
var _language_button: Button
var _content: Dictionary = {}
const Icons = preload("res://presentation/ui/ui_icons.gd")
const Styles = preload("res://presentation/ui/ui_styles.gd")
var _hero_fade: TextureRect
var _eyebrow: Label
var _offline_note: Label
var _background: TextureRect
var _column: VBoxContainer
var _title: Label
var _description: Label
const ChoiceCard = preload("res://presentation/ui/upgrade_choice_card.gd")
const CHOICE_WIDTH := 840.0
const CHOICE_GAP := 12
const SCREEN_MARGIN := 40.0
var _confirm_choice: Button
var _selected_choice := ""
var _choice_controls: Array[Button] = []
var _rows: BoxContainer
var _scroll: ScrollContainer
var _center: CenterContainer
var _main_layout: MarginContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Fieldwork.BG
	_background = TextureRect.new()
	_background.texture = load("res://assets/ui/fieldwork/hero-scene.png")
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.modulate = Color.WHITE
	_background.anchor_left = 0.375
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_hero_fade = TextureRect.new()
	_hero_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.5, 1])
	gradient.colors = PackedColorArray([Fieldwork.BG, Color(Fieldwork.BG, 0.88), Color(Fieldwork.BG, 0.05)])
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_from = Vector2.ZERO
	fade.fill_to = Vector2.RIGHT
	_hero_fade.texture = fade
	add_child(_hero_fade)
	_eyebrow = Styles.label("", 11)
	_eyebrow.position = Vector2(64, 66)
	_eyebrow.add_theme_color_override("font_color", Fieldwork.ACCENT)
	add_child(_eyebrow)
	_offline_note = Styles.label("", 12)
	_offline_note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_offline_note.offset_left = 68
	_offline_note.offset_top = -84
	_offline_note.offset_bottom = -40
	Styles.muted(_offline_note)
	add_child(_offline_note)
	var center := CenterContainer.new()
	_center = center
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_column = VBoxContainer.new()
	_column.custom_minimum_size.x = 520
	_column.add_theme_constant_override("separation", 10)
	center.add_child(_column)
	_main_layout = MarginContainer.new()
	add_child(_main_layout)
	_main_layout.hide()
	_title = Styles.label("", 30)
	_column.add_child(_title)
	_description = Styles.label("", 15)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_description)
	_language_button = Styles.button("LANGUAGE: ENGLISH" if Locale.language == "en" else "ЯЗЫК: РУССКИЙ")
	Icons.apply(_language_button, "settings")
	_language_button.pressed.connect(func() -> void: language_requested.emit("ru" if Locale.language == "en" else "en"))
	add_child(_language_button)
	_language_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_language_button.offset_left = -230
	_language_button.offset_right = -32
	_language_button.offset_top = -68
	_language_button.offset_bottom = -32
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(520, 320)
	_column.add_child(_scroll)
	_rows = BoxContainer.new()
	_rows.vertical = true
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	_confirm_choice = Styles.button("")
	_confirm_choice.size_flags_horizontal = Control.SIZE_SHRINK_END
	Styles.primary(_confirm_choice)
	_confirm_choice.pressed.connect(func() -> void:
		if not _selected_choice.is_empty():
			_confirm_choice.disabled = true
			action_requested.emit("choose", _selected_choice))
	_column.add_child(_confirm_choice)
	settings_panel = preload("res://presentation/ui/settings_panel.gd").new()
	add_child(settings_panel)
	settings_panel.closed.connect(func() -> void: action_requested.emit("options_back", ""))
	settings_panel.language_requested.connect(func(value: String) -> void: language_requested.emit(value))
	visible = false

func display(title: String, description: String, rows: Array, main_menu: bool = false) -> void:
	settings_panel.hide()
	_column.get_parent().show()
	_content = {"title": title, "description": description, "rows": rows, "main_menu": main_menu}
	var choices := not rows.is_empty() and rows.all(func(row: Dictionary) -> bool: return row.get("action", "") == "choose")
	_choice_controls.clear()
	_selected_choice = ""
	_confirm_choice.visible = choices
	_confirm_choice.disabled = true
	_confirm_choice.text = "Подтвердить выбор" if Locale.language == "ru" else "Confirm selection"
	_rows.vertical = not choices
	_rows.add_theme_constant_override("separation", CHOICE_GAP if choices else 8)
	_main_layout.visible = main_menu
	_center.visible = not main_menu
	var target: Container = _main_layout if main_menu else _center
	if _column.get_parent() != target:
		_column.reparent(target)
	_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if main_menu else Control.SIZE_FILL
	_main_layout.position = Vector2(68, 140) if size.x >= 1100 else Vector2(32, 104)
	_main_layout.size = Vector2(380 if size.x >= 1100 else 320, size.y - _main_layout.position.y - 120)
	_eyebrow.position = Vector2(64, 66) if size.x >= 1100 else Vector2(32, 58)
	_column.custom_minimum_size.x = minf(CHOICE_WIDTH, get_viewport_rect().size.x - SCREEN_MARGIN) if choices else minf(320.0, get_viewport_rect().size.x * 0.34) if main_menu else 520.0
	_scroll.custom_minimum_size.x = 304 if main_menu else _column.custom_minimum_size.x
	_scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if main_menu else Control.SIZE_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	color = Fieldwork.BG if main_menu else Color(0.04, 0.06, 0.05, 0.82)
	_background.visible = main_menu
	_hero_fade.visible = main_menu
	_eyebrow.visible = main_menu
	_eyebrow.text = "ЭКСПЕДИЦИИ / РЕСУРСЫ / ВЫЖИВАНИЕ" if Locale.language == "ru" else "EXPEDITIONS / RESOURCES / SURVIVAL"
	_offline_note.visible = false
	_language_button.visible = main_menu
	_scroll.custom_minimum_size.y = mini(rows.size() * 54, 300) if main_menu else 280
	_title.add_theme_font_size_override("font_size", (72 if size.x >= 1100 else 56) if main_menu and title == "IRON CARAVAN" else 28 if main_menu else 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.text = "IRON\nCARAVAN" if main_menu and title == "IRON CARAVAN" else Locale.text(title)
	_description.text = Locale.text(description)
	Styles.muted(_description)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for row: Dictionary in rows:
		if choices:
			var slot := ChoiceCard.new()
			_rows.add_child(slot)
			slot.configure(row)
			slot.selected.connect(func(id: String) -> void:
				_selected_choice = id
				_confirm_choice.disabled = false
				for control: Button in _choice_controls:
					Styles.selected(control, str(control.get_meta("choice_id")) == id))
			_choice_controls.append(slot.button)
			continue
		var button := Styles.button(str(row.get("label", "")))
		var action: String = str(row.get("action", ""))
		if main_menu and action == "multiplayer":
			button.free()
			_offline_note.text = ("ОДИНОЧНАЯ ИГРА\n" if Locale.language == "ru" else "SINGLEPLAYER\n") + Locale.text(str(row.get("label", "")))
			_offline_note.visible = true
			continue
		button.disabled = bool(row.get("disabled", false))
		button.set_meta("action_id", str(row.get("action", "")))
		if main_menu:
			button.custom_minimum_size.y = 48 if action in ["singleplayer", "raid", "start"] else 42
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_font_size_override("font_size", 14)
			Styles.ghost(button)
			(button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = Color.TRANSPARENT
			Icons.apply(button, {"singleplayer": "play", "raid": "plus", "start": "play", "options": "settings", "quit": "exit", "vault": "box", "menu": "back"}.get(action, "arrow"), 18)
		button.tooltip_text = Locale.text(str(row.get("description", "")))
		button.pressed.connect(func() -> void: action_requested.emit(str(row.get("action", "")), str(row.get("id", ""))))
		_rows.add_child(button)
		if main_menu and _rows.get_child_count() == 1 and not button.disabled:
			Styles.primary(button)
		if not str(row.get("description", "")).is_empty():
			var detail := Styles.label(str(row.description), 13)
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.custom_minimum_size.x = 0
			_rows.add_child(detail)
	visible = true

func _input(event: InputEvent) -> void:
	if settings_panel.visible:
		return
	if not visible or not event is InputEventKey or not event.pressed or event.keycode != KEY_TAB:
		return
	var controls: Array = _choice_controls.filter(func(button: Button) -> bool: return not button.disabled) if not _choice_controls.is_empty() else _rows.get_children().filter(func(child: Node) -> bool: return child is Button and not child.disabled)
	if _confirm_choice.visible and not _confirm_choice.disabled:
		controls.append(_confirm_choice)
	if _language_button.visible:
		controls.append(_language_button)
	if controls.is_empty():
		return
	var current := controls.find(get_viewport().gui_get_focus_owner())
	controls[posmod(current + (-1 if event.shift_pressed else 1), controls.size())].grab_focus()
	get_viewport().set_input_as_handled()

func refresh_language() -> void:
	_language_button.text = "LANGUAGE: ENGLISH" if Locale.language == "en" else "ЯЗЫК: РУССКИЙ"
	if visible and not _content.is_empty():
		display(_content.title, _content.description, _content.rows, _content.get("main_menu", false))

func show_settings(controller: RefCounted) -> void:
	_column.get_parent().hide()
	settings_panel.display(controller)
	visible = true

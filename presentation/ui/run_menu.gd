extends ColorRect

signal action_requested(action: String, id: String)
signal language_requested(language: String)
const Locale = preload("res://presentation/ui/ui_locale.gd")
var _language_button: Button
var _content: Dictionary = {}
const Styles = preload("res://presentation/ui/ui_styles.gd")
var _background: TextureRect
var _column: VBoxContainer
var _title: Label
var _description: Label
var _rows: VBoxContainer
var _scroll: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0.02, 0.027, 0.025, 0.9)
	_background = TextureRect.new()
	_background.texture = load("res://assets/menu/wasteland-menu-background.webp")
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.modulate = Color(0.38, 0.38, 0.38, 1.0)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_column = VBoxContainer.new()
	_column.custom_minimum_size.x = 540
	_column.add_theme_constant_override("separation", 12)
	center.add_child(_column)
	_title = Styles.label("", 30)
	_column.add_child(_title)
	_description = Styles.label("", 15)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_description)
	_language_button = Styles.button("LANGUAGE: ENGLISH" if Locale.language == "en" else "ЯЗЫК: РУССКИЙ")
	_language_button.pressed.connect(func() -> void: language_requested.emit("ru" if Locale.language == "en" else "en"))
	_column.add_child(_language_button)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(580, 380)
	_column.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	visible = false

func display(title: String, description: String, rows: Array, main_menu: bool = false) -> void:
	_content = {"title": title, "description": description, "rows": rows, "main_menu": main_menu}
	_background.visible = main_menu
	_language_button.visible = main_menu
	_scroll.custom_minimum_size.y = rows.size() * 52 if main_menu else 320
	_title.add_theme_font_size_override("font_size", 48 if main_menu else 28)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if main_menu else HORIZONTAL_ALIGNMENT_LEFT
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if main_menu else HORIZONTAL_ALIGNMENT_LEFT
	_title.text = Locale.text(title)
	_description.text = Locale.text(description)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for row: Dictionary in rows:
		var button := Styles.button(str(row.get("label", "")))
		button.disabled = bool(row.get("disabled", false))
		button.set_meta("action_id", str(row.get("action", "")))
		if main_menu:
			button.custom_minimum_size.y = 48
			button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.tooltip_text = Locale.text(str(row.get("description", "")))
		button.pressed.connect(func() -> void: action_requested.emit(str(row.get("action", "")), str(row.get("id", ""))))
		_rows.add_child(button)
		if not str(row.get("description", "")).is_empty():
			var detail := Styles.label(str(row.description), 13)
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.custom_minimum_size.x = 500
			_rows.add_child(detail)
	visible = true

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.keycode != KEY_TAB:
		return
	var controls: Array = _rows.get_children().filter(func(child: Node) -> bool: return child is Button and not child.disabled)
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

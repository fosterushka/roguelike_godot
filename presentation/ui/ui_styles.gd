extends RefCounted

const Locale = preload("res://presentation/ui/ui_locale.gd")
const Tokens = preload("res://presentation/ui/fieldwork_tokens.gd")
const Icons = preload("res://presentation/ui/ui_icons.gd")

static var _regular_font: SystemFont
static var _strong_font: SystemFont

static func font(strong: bool = false) -> SystemFont:
	if _regular_font == null:
		_regular_font = SystemFont.new()
		_regular_font.font_names = PackedStringArray(["Inter", "DejaVu Sans", "Arial"])
		_strong_font = _regular_font.duplicate()
		_strong_font.font_weight = 700
	return _strong_font if strong else _regular_font

static func label(text: String, font_size: int = 15) -> Label:
	var result := Label.new()
	result.text = Locale.text(text)
	result.add_theme_font_override("font", font(font_size >= 16))
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", Tokens.TEXT)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func button(text: String) -> Button:
	var result := Button.new()
	result.text = Locale.text(text)
	result.custom_minimum_size = Vector2(132, 36)
	result.add_theme_font_override("font", font(true))
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	result.add_theme_font_size_override("font_size", 14)
	result.add_theme_color_override("font_color", Tokens.TEXT)
	result.add_theme_color_override("font_hover_color", Tokens.TEXT)
	result.add_theme_color_override("font_disabled_color", Tokens.QUIET)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Tokens.RAISED
	normal.border_color = Tokens.CONTROL
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(Tokens.CONTROL_RADIUS)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Tokens.HOVER
	hover.border_color = Tokens.ACCENT
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Tokens.ACCENTBG
	pressed.border_color = Tokens.ACCENT
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Tokens.PANEL
	disabled.border_color = Tokens.LINE
	result.add_theme_stylebox_override("normal", normal)
	result.add_theme_stylebox_override("hover", hover)
	result.add_theme_stylebox_override("pressed", pressed)
	result.add_theme_stylebox_override("disabled", disabled)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Tokens.ACCENT
	focus.set_border_width_all(2)
	result.add_theme_stylebox_override("focus", focus)
	return result

static func panel_style() -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Tokens.PANEL
	result.border_color = Tokens.LINE
	result.set_border_width_all(1)
	result.set_corner_radius_all(Tokens.PANEL_RADIUS)
	result.content_margin_left = 16
	result.content_margin_right = 16
	result.content_margin_top = 16
	result.content_margin_bottom = 16
	return result

static func primary(control: Button) -> void:
	var normal := control.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	normal.bg_color = Tokens.ACCENT
	normal.border_color = Tokens.ACCENT
	control.add_theme_stylebox_override("normal", normal)
	control.add_theme_color_override("font_color", Tokens.INK)
	control.add_theme_color_override("icon_normal_color", Tokens.INK)

static func selected(control: Button, active: bool) -> void:
	var normal := control.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	normal.bg_color = Tokens.ACCENTBG if active else Tokens.PANEL
	normal.border_color = Tokens.ACCENT if active else Tokens.LINE
	normal.border_width_left = 3 if active else 1
	control.add_theme_stylebox_override("normal", normal)
	control.add_theme_color_override("font_color", Tokens.ACCENT if active else Tokens.TEXT)
	control.add_theme_color_override("icon_normal_color", Tokens.ACCENT if active else Tokens.MUTED)

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	result.default_font = font()
	for type in ["Label", "Button", "OptionButton", "CheckButton", "LineEdit", "RichTextLabel"]:
		result.set_color("font_color", type, Tokens.TEXT)
		result.set_color("font_disabled_color", type, Tokens.QUIET)
	var control := button("")
	for type in ["Button", "OptionButton", "LineEdit"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			result.set_stylebox(state, type, control.get_theme_stylebox(state))
	control.free()
	var separator := StyleBoxLine.new()
	separator.color = Tokens.LINE
	separator.thickness = 1
	result.set_stylebox("separator", "HSeparator", separator)
	result.set_stylebox("panel", "PanelContainer", panel_style())
	return result

static func ghost(control: Button) -> void:
	var normal := control.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	normal.bg_color = Tokens.PANEL
	normal.set_border_width_all(0)
	control.add_theme_stylebox_override("normal", normal)

static func navigation(control: Button, active: bool) -> void:
	var normal := control.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	normal.bg_color = Tokens.RAISED if active else Color.TRANSPARENT
	normal.set_border_width_all(0)
	normal.border_width_left = 3 if active else 0
	normal.border_color = Tokens.ACCENT
	normal.content_margin_left = 14
	normal.content_margin_right = 8
	control.add_theme_stylebox_override("normal", normal)
	control.add_theme_color_override("font_color", Tokens.TEXT if active else Tokens.MUTED)
	control.add_theme_color_override("icon_normal_color", Tokens.ACCENT if active else Tokens.MUTED)

static func tab(control: Button, active: bool) -> void:
	selected(control, active)
	var normal := control.get_theme_stylebox("normal") as StyleBoxFlat
	normal.set_border_width_all(1 if active else 0)
	control.alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.add_theme_font_size_override("font_size", 13)

static func muted(label: Label) -> void:
	label.add_theme_color_override("font_color", Tokens.MUTED)

extends RefCounted

const Locale = preload("res://presentation/ui/ui_locale.gd")
const Icons = preload("res://presentation/ui/ui_icons.gd")

static func label(text: String, font_size: int = 15) -> Label:
	var result := Label.new()
	result.text = Locale.text(text)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", Color("eee9db"))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func button(text: String) -> Button:
	var result := Button.new()
	result.text = Locale.text(text)
	result.custom_minimum_size = Vector2(132, 36)
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	result.add_theme_font_size_override("font_size", 14)
	result.add_theme_color_override("font_color", Color("eee9db"))
	result.add_theme_color_override("font_hover_color", Color("ffffff"))
	result.add_theme_color_override("font_disabled_color", Color("9caaa7"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("253132")
	normal.border_color = Color("4b5e5d")
	normal.set_border_width_all(1)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("3e4841")
	hover.border_color = Color("cfab69")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("514630")
	pressed.border_color = Color("edc575")
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("1d2729")
	disabled.border_color = Color("354544")
	result.add_theme_stylebox_override("normal", normal)
	result.add_theme_stylebox_override("hover", hover)
	result.add_theme_stylebox_override("pressed", pressed)
	result.add_theme_stylebox_override("disabled", disabled)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("edc575")
	focus.set_border_width_all(2)
	result.add_theme_stylebox_override("focus", focus)
	return result

static func panel_style() -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color("1b282b")
	result.border_color = Color("425453")
	result.set_border_width_all(1)
	result.content_margin_left = 12
	result.content_margin_right = 12
	result.content_margin_top = 8
	result.content_margin_bottom = 8
	return result

extends RefCounted

const Locale = preload("res://presentation/ui/ui_locale.gd")

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
	result.custom_minimum_size = Vector2(200, 38)
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("303734")
	normal.border_color = Color("786347")
	normal.set_border_width_all(1)
	normal.content_margin_left = 12
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("59503c")
	result.add_theme_stylebox_override("normal", normal)
	result.add_theme_stylebox_override("hover", hover)
	result.add_theme_stylebox_override("pressed", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("edc575")
	focus.set_border_width_all(2)
	result.add_theme_stylebox_override("focus", focus)
	return result

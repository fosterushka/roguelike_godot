extends Control
const Locale = preload("res://presentation/ui/ui_locale.gd")
var caption: Label
var detail: Label
var strength := 0.0
var reversed := false
var active := false
var pulse := 0.0

func _ready() -> void:
	name = "JammerStatus"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(16, 16)
	size = Vector2(270, 36)
	for index in 2:
		var label := Label.new()
		label.position = Vector2(30, index * 17)
		label.add_theme_font_size_override("font_size", 12 if index == 0 else 10)
		label.add_theme_color_override("font_color", Color("edc4ff"))
		label.add_theme_color_override("font_shadow_color", Color(0.025, 0.025, 0.04, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		if index == 0:
			caption = label
		else:
			detail = label
	refresh_language()
	visible = false

func update_state(state: Dictionary) -> void:
	var player: Dictionary = state.get("player", {})
	strength = clampf(float(player.get("jammer_strength", 0)), 0, 1)
	reversed = bool(player.get("jammer_reversed", false))
	pulse = clampf(float(player.get("jammer_pulse", 0)), 0, 1)
	active = float(player.get("hp", 100)) > 0 and (bool(player.get("jammed", false)) or strength > 0.001)
	visible = active
	detail.visible = reversed
	modulate.a = 0.62 + strength * 0.38
	queue_redraw()

func refresh_language() -> void:
	caption.text = Locale.text("СИГНАЛ ПОДАВЛЕН")
	detail.text = Locale.text("УПРАВЛЕНИЕ ИНВЕРТИРОВАНО")

func _draw() -> void:
	var color := Color("ffa8c3") if reversed else Color("ce91ed")
	for index in 4:
		var height := 4.0 + index * 3.0
		var alpha := 0.28 if strength * 4 < index else 0.7 + pulse * 0.3
		draw_rect(Rect2(index * 6, 16 - height, 3, height), Color(color, alpha))
	draw_line(Vector2(0, 22), Vector2(22, 22), Color(color, 0.7), 1.0)

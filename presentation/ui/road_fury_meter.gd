extends Control

const Locale = preload("res://presentation/ui/ui_locale.gd")
var caption: Label
var meter: ProgressBar

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -165
	offset_right = 165
	offset_top = -102
	offset_bottom = -65
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("ffe0a0"))
	caption.add_theme_color_override("font_shadow_color", Color("18252a"))
	caption.add_theme_constant_override("shadow_offset_x", 1)
	caption.add_theme_constant_override("shadow_offset_y", 1)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	meter = ProgressBar.new()
	meter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	meter.offset_top = -5
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part: String in ["background", "fill"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("eec16d") if part == "fill" else Color("27362f")
		meter.add_theme_stylebox_override(part, style)
	add_child(meter)

func update_player(player: Dictionary) -> void:
	var active := float(player.get("road_fury_overdrive", 0.0))
	var cooldown := float(player.get("road_fury_cooldown", 0.0))
	var ru := Locale.language == "ru"
	if active > 0.0:
		caption.text = ("ФОРСАЖ  %.1f с" if ru else "OVERDRIVE  %.1fs") % active
		meter.value = active / 5.0 * 100.0
	elif cooldown > 0.0:
		caption.text = ("ФОРСАЖ: ВОССТАНОВЛЕНИЕ  %.1f с" if ru else "OVERDRIVE: RECOVERING  %.1fs") % cooldown
		meter.value = (1.0 - cooldown / 8.0) * 100.0
	else:
		caption.text = ("КОМБО ×%d · ДРИФТ / ТАРАН" if ru else "COMBO ×%d · DRIFT / RAM") % int(player.get("road_fury_combo", 0))
		meter.value = clampf(float(player.get("momentum", 0.0)), 0.0, 1.0) * 100.0

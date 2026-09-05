extends PanelContainer

const Locale = preload("res://presentation/ui/ui_locale.gd")
var remaining := 0.0
var reward: Dictionary = {}
var label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_left = -270
	offset_right = 270
	offset_top = 118
	offset_bottom = 192
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152922")
	style.border_color = Color("85cfa4")
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("eee9db"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	hide()

func show_reward(event: Dictionary) -> void:
	reward = event.duplicate(true)
	remaining = 8.0
	refresh_language()
	show()

func refresh_language() -> void:
	if reward.is_empty():
		return
	label.text = Locale.text("ПРИПАСЫ ПОЛУЧЕНЫ") + "\n" + Locale.text("Лом +%d · Опыт +%d · Топливо +%d") % [int(reward.get("salvage", 0)), int(reward.get("xp", 0)), roundi(float(reward.get("fuel", 0)))]
	if not str(reward.get("blueprint", "")).is_empty():
		label.text += "\n" + Locale.text("Чертёж: %s · Установите в арсенале") % Locale.text(str(reward.get("blueprint_name", reward.blueprint)))

func clear() -> void:
	reward.clear()
	remaining = 0.0
	hide()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or get_tree().paused:
		return
	remaining = maxf(0, remaining - delta)
	visible = remaining > 0

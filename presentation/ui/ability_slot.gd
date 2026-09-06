extends Button

const Icons = preload("res://presentation/ui/ui_icons.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const INK := Color("eee9db")
const AMBER := Color("e6ac58")
const MUTED := Color("979b92")
const NAMES := ["НИТРО", "ТАРАН", "РЕМОНТ"]
var slot := 0
var cooldown_ratio := 0.0
var status := ""
var _heading: Label
var _status_label: Label
var _normal: StyleBoxFlat
var _hover: StyleBoxFlat
var _selected := false

func _ready() -> void:
	custom_minimum_size = Vector2(106, 54)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_normal = StyleBoxFlat.new()
	_normal.bg_color = Color("18201b")
	_normal.border_color = Color("525b4d")
	_normal.set_border_width_all(1)
	var hover := _normal.duplicate() as StyleBoxFlat
	_hover = hover
	hover.bg_color = Color("303829")
	hover.border_color = AMBER
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = AMBER
	focus.set_border_width_all(2)
	for state in ["normal", "disabled"]:
		add_theme_stylebox_override(state, _normal)
	for state in ["hover", "pressed"]:
		add_theme_stylebox_override(state, hover)
	add_theme_stylebox_override("focus", focus)
	_heading = _label(Vector2(8, 5), 11)
	_status_label = _label(Vector2(31, 29), 10)
	_status_label.size = Vector2(70, 18)
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_label.clip_text = true
	var action_icon := Icons.view(["fuel", "ammo", "repair"][slot], 20)
	action_icon.position = Vector2(6, 27)
	add_child(action_icon)

func _label(origin: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = origin
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label

func update_state(player: Dictionary, selected: bool) -> void:
	var cooldowns := ["nitro_cooldown", "ram_cooldown", "repair_cooldown"]
	var cooldown := float(player.get(cooldowns[slot], 0.0))
	var maximum := 10.0 if slot == 0 else 8.0 * float(player.get("ram_cd_mult", 1.0)) if slot == 1 else 5.0
	cooldown_ratio = clampf(cooldown / maxf(maximum, 0.01), 0.0, 1.0)
	status = Locale.text("ГОТОВО")
	disabled = false
	if slot == 1 and not player.get("has_bumper", false):
		status = Locale.text("НУЖЕН БАМПЕР")
		disabled = true
	elif cooldown > 0.0:
		status = "%.1fs" % cooldown
		disabled = true
	elif slot == 2 and float(player.get("hp", 0.0)) >= float(player.get("max_hp", 1.0)):
		status = Locale.text("КОРПУС ЦЕЛ")
		disabled = true
	elif slot == 2 and int(player.get("coins", 0)) < 15:
		status = Locale.text("15 ЛОМ")
		disabled = true
	_heading.text = "%d  %s" % [slot + 1, Locale.text(NAMES[slot])]
	_status_label.text = status
	_status_label.add_theme_color_override("font_color", MUTED if disabled else AMBER)
	_selected = selected
	_normal.border_color = Color("ffdf8a") if selected else Color("525b4d")
	_normal.bg_color = Color("67471d") if selected else Color("18201b")
	_normal.set_border_width_all(3 if selected else 1)
	_hover.bg_color = Color("795522") if selected else Color("303829")
	_hover.border_color = Color("ffdf8a") if selected else AMBER
	_hover.set_border_width_all(3 if selected else 1)
	_heading.add_theme_color_override("font_color", INK if selected or not disabled else MUTED)
	var descriptions := ["Краткое ускорение", "Удар по врагам впереди", "Ремонт корпуса за 15 лома"]
	tooltip_text = Locale.text(descriptions[slot]) + " · " + status
	queue_redraw()

func _draw() -> void:
	if cooldown_ratio > 0.0:
		draw_rect(Rect2(1, size.y - 3, (size.x - 2) * cooldown_ratio, 2), AMBER)

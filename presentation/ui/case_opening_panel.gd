extends ColorRect

signal closed
const Styles = preload("res://presentation/ui/ui_styles.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Icon = preload("res://presentation/ui/case_reward_icon.gd")
const DURATION := 3.0
const CARD_WIDTH := 154.0
const CARD_GAP := 8.0
const WINNER_INDEX := 23
var reward: Dictionary = {}
var elapsed := 0.0
var revealed := false
var strip: HBoxContainer
var window: Control
var title: Label
var subtitle: Label
var result: Label
var guaranteed: Label
var contents: Label
var button: Button
var panel: PanelContainer

static func words(ru: String, en: String) -> String:
	return ru if Locale.language == "ru" else en

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.025, 0.035, 0.03, 0.88)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("192522")
	style.border_color = Color("b69c66")
	style.set_border_width_all(1)
	for side in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	title = _label(column, 23)
	subtitle = _label(column, 14)
	window = Control.new()
	window.custom_minimum_size.y = 142
	window.clip_contents = true
	column.add_child(window)
	strip = HBoxContainer.new()
	strip.add_theme_constant_override("separation", int(CARD_GAP))
	window.add_child(strip)
	var marker := ColorRect.new()
	marker.color = Color("efc77f")
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	marker.offset_left = -2
	marker.offset_right = 2
	marker.offset_bottom = 10
	window.add_child(marker)
	var lower_marker := marker.duplicate() as ColorRect
	lower_marker.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	lower_marker.offset_left = -2
	lower_marker.offset_right = 2
	lower_marker.offset_top = -10
	lower_marker.offset_bottom = 0
	window.add_child(lower_marker)
	result = _label(column, 20)
	result.custom_minimum_size.y = 32
	guaranteed = _label(column, 13)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 74
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	contents = _label(scroll, 12)
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button = Styles.button("")
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(activate)
	column.add_child(button)
	resized.connect(_layout)
	window.resized.connect(_position_strip)
	_layout()
	hide()

func _label(parent: Node, font_size: int) -> Label:
	var label := Styles.label("", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _layout() -> void:
	if not is_instance_valid(panel):
		return
	var width := minf(880, size.x - 32)
	panel.custom_minimum_size.x = width
	_position_strip()

func show_case(value: Dictionary) -> void:
	reward = value.duplicate(true)
	elapsed = 0
	revealed = false
	_rebuild_strip()
	refresh_language()
	show()
	_layout.call_deferred()
	button.grab_focus()

func _rebuild_strip() -> void:
	for child in strip.get_children():
		strip.remove_child(child)
		child.queue_free()
	var pool: Array = reward.get("pool", [])
	if pool.is_empty():
		return
	for index in WINNER_INDEX + 4:
		# Decorative order cannot choose or change the already awarded result.
		var entry: Dictionary = reward.selected if index == WINNER_INDEX else pool[(index * 7 + index / maxi(1, pool.size())) % pool.size()]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(CARD_WIDTH, 138)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("283530")
		style.border_color = _tint(str(entry.kind))
		style.border_width_bottom = 3
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", style)
		strip.add_child(card)
		var column := VBoxContainer.new()
		card.add_child(column)
		var icon := Icon.new()
		icon.kind = str(entry.kind)
		icon.tint = _tint(icon.kind)
		icon.custom_minimum_size.y = 55
		column.add_child(icon)
		var caption := _label(column, 14)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.text = reward_name(entry)
		caption.custom_minimum_size = Vector2(CARD_WIDTH - 20, 48)

static func _tint(kind: String) -> Color:
	return Color("8fbad6") if kind == "blueprint" else Color("92c999") if kind == "repair" else Color("d8b57a")

static func reward_name(entry: Dictionary) -> String:
	match str(entry.get("kind", "")):
		"blueprint": return Locale.text(str(entry.get("name", entry.get("type", ""))))
		"salvage": return words("Лом +%d", "Scrap +%d") % int(entry.get("amount", 0))
		"fuel": return words("Топливо +%s", "Fuel +%s") % _amount(float(entry.get("amount", 0)))
		"repair": return words("Ремонт +%s", "Repair +%s") % _amount(float(entry.get("amount", 0)))
		"xp": return words("Опыт +%d", "XP +%d") % int(entry.get("amount", 0))
	return str(entry.get("name", entry.get("id", "")))

static func _amount(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else ("%.2f" % value).trim_suffix("0").trim_suffix(".")

func refresh_language() -> void:
	if reward.is_empty():
		return
	title.text = words("ВОЗДУШНЫЙ ГРУЗ", "AIRDROP CACHE") if reward.source == "airdrop" else words("МАШИНА СНАБЖЕНИЯ", "SUPPLY VEHICLE")
	subtitle.text = words("Случайный бонус · Игра на паузе", "Random bonus · Game paused")
	result.text = words("ОТКРЫВАЕМ ГРУЗ…", "OPENING CACHE…") if not revealed else words("ПОЛУЧЕНО: ", "RECEIVED: ") + reward_name(reward.selected)
	var bundle: Dictionary = reward.get("guaranteed", {})
	var lines: Array[String] = []
	for kind: String in ["salvage", "xp", "fuel", "repair"]:
		if float(bundle.get(kind, 0)) <= 0:
			continue
		lines.append(words("Опыт +%d", "XP +%d") % int(bundle[kind]) if kind == "xp" else reward_name({"kind": kind, "amount": bundle[kind]}))
	guaranteed.text = words("Также получено: ", "Also received: ") + " · ".join(lines) if not lines.is_empty() else ""
	var names: Array[String] = []
	for entry: Dictionary in reward.get("pool", []):
		names.append(reward_name(entry))
	contents.text = words("ВОЗМОЖНЫЕ БОНУСЫ\n", "POSSIBLE BONUSES\n") + " · ".join(names)
	if revealed and str(reward.selected.kind) == "blueprint":
		subtitle.text = words("Чертёж открыт. Установите оружие в арсенале.", "Blueprint unlocked. Install the weapon in Armory.")
	button.text = words("ПРОДОЛЖИТЬ [ENTER]", "CONTINUE [ENTER]") if revealed else words("ПОКАЗАТЬ СРАЗУ [ENTER]", "REVEAL NOW [ENTER]")

func advance(delta: float) -> void:
	if not visible or revealed:
		return
	elapsed = minf(DURATION, elapsed + maxf(0, delta))
	if elapsed >= DURATION:
		revealed = true
		refresh_language()
	_position_strip()

func _process(delta: float) -> void:
	advance(delta)

func _position_strip() -> void:
	if not is_instance_valid(window):
		return
	var progress := 1.0 - pow(1.0 - clampf(elapsed / DURATION, 0, 1), 4.0)
	var target := WINNER_INDEX * (CARD_WIDTH + CARD_GAP) + CARD_WIDTH * 0.5
	strip.position = Vector2(window.size.x * 0.5 - lerpf(CARD_WIDTH * 0.5, target, progress), 0)

func activate() -> void:
	if not visible:
		return
	if not revealed:
		advance(DURATION)
	else:
		hide()
		closed.emit()

func clear() -> void:
	reward.clear()
	hide()

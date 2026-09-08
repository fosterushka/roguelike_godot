extends Control

signal selected(id: String)

const Styles = preload("res://presentation/ui/ui_styles.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const CARD_HEIGHT := 250.0
const HOVER_LIFT := 8.0
const HOVER_DURATION := 0.14
const CONTENT_MARGIN := 14.0
var button: Button
var _motion: Tween

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = CARD_HEIGHT + HOVER_LIFT
	button = Styles.button("")
	button.name = "Choice"
	button.custom_minimum_size = Vector2.ZERO
	add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.offset_top = HOVER_LIFT
	button.mouse_entered.connect(_raise.bind(true))
	button.mouse_exited.connect(_raise.bind(false))
	button.focus_entered.connect(_raise.bind(true))
	button.focus_exited.connect(_raise.bind(false))

func configure(row: Dictionary) -> void:
	button.disabled = bool(row.get("disabled", false))
	button.set_meta("action_id", "choose")
	button.set_meta("choice_id", str(row.get("id", "")))
	button.pressed.connect(func() -> void: selected.emit(str(row.get("id", ""))))
	var content := VBoxContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = CONTENT_MARGIN
	content.offset_right = -CONTENT_MARGIN
	content.offset_top = CONTENT_MARGIN
	content.offset_bottom = -CONTENT_MARGIN
	content.add_theme_constant_override("separation", 12)
	var title := Styles.label(str(row.get("label", "")), 18)
	title.name = "Title"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	var detail := Styles.label(str(row.get("description", "")), 13)
	detail.name = "Description"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(detail)
	var hint := Styles.label("ВЫБРАТЬ" if Locale.language == "ru" else "SELECT", 12)
	hint.modulate = Color("cfab69")
	content.add_child(hint)

func _raise(raised: bool) -> void:
	if button.disabled:
		return
	if _motion != null:
		_motion.kill()
	_motion = create_tween().set_parallel(true)
	_motion.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion.tween_property(button, "offset_top", 0.0 if raised else HOVER_LIFT, HOVER_DURATION)
	_motion.tween_property(button, "offset_bottom", -HOVER_LIFT if raised else 0.0, HOVER_DURATION)

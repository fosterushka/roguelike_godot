extends Control

const Locale = preload("res://presentation/ui/ui_locale.gd")

signal command_requested(command: String)
var enabled := false
var _pressed: Dictionary = {}
var _buttons: Array[Button] = []
var _touches: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var movement := GridContainer.new()
	movement.columns = 3
	movement.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	movement.position = Vector2(20, -280)
	add_child(movement)
	for item in [{"label": "", "action": ""}, {"label": "W", "action": "drive_forward"}, {"label": "SHIFT", "action": "handbrake"}, {"label": "A", "action": "drive_left"}, {"label": "S", "action": "drive_backward"}, {"label": "D", "action": "drive_right"}]:
		movement.add_child(_button(item.label, item.action))
	var combat := GridContainer.new()
	combat.columns = 2
	combat.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	combat.position = Vector2(-190, -280)
	add_child(combat)
	for item in [{"label": Locale.text("ЦЕЛЬ"), "action": "focus"}, {"label": "E", "action": "interact"}, {"label": Locale.text("НАВЫК"), "action": "ability"}, {"label": "1 / 2 / 3", "action": "select"}]:
		combat.add_child(_button(item.label, item.action))
	resized.connect(_layout)
	_layout()

func _button(caption: String, action: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(76, 46)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.04, 0.86)
	style.border_color = Color("b09b68")
	style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", style)
	button.set_meta("touch_action", action)
	button.disabled = action.is_empty()
	button.button_down.connect(func() -> void: press(action))
	button.button_up.connect(func() -> void: release(action))
	button.mouse_exited.connect(func() -> void: release(action))
	_buttons.append(button)
	return button

func _layout() -> void:
	visible = enabled and DisplayServer.is_touchscreen_available()

func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		release_all()
	_layout()

func press(action: String) -> void:
	if not enabled or action.is_empty():
		return
	if action in ["focus", "ability", "select"]:
		command_requested.emit(action)
		return
	Input.action_press(action)
	_pressed[action] = true
	if action == "interact":
		command_requested.emit("interact")

func release(action: String) -> void:
	if _pressed.has(action):
		Input.action_release(action)
		_pressed.erase(action)

func release_all() -> void:
	_touches.clear()
	for action: String in _pressed.keys():
		Input.action_release(action)
	_pressed.clear()

func _exit_tree() -> void:
	release_all()

func _input(event: InputEvent) -> void:
	if not enabled or not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			for button in _buttons:
				if not button.disabled and button.get_global_rect().has_point(event.position):
					var action: String = button.get_meta("touch_action")
					_touches[event.index] = {"action": action, "button": button}
					press(action)
					get_viewport().set_input_as_handled()
					break
		elif _touches.has(event.index):
			_release_touch(event.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		if not _touches[event.index].button.get_global_rect().has_point(event.position):
			_release_touch(event.index)
		get_viewport().set_input_as_handled()

func _release_touch(index: int) -> void:
	var action: String = _touches[index].action
	_touches.erase(index)
	if not _touches.values().any(func(touch: Dictionary) -> bool: return touch.action == action):
		release(action)

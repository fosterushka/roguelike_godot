extends Camera3D

@export var target: Node3D
@export var follow_offset := Vector3(34, 45, 34)
var half_height := 31.0
var shake := 0.0
var punch := 0.0
var _lead := Vector3.ZERO
var _subject_view: Node3D
var _focus := Vector3.ZERO
var _drag := Vector3.ZERO
var _dragging := false
var _intro := 2.65
var _elapsed := 0.0
var _zoom := 1.0
var death_cinematic: Dictionary = {}
var run_clock: RefCounted

func _ready() -> void:
	process_priority = 100
	projection = Camera3D.PROJECTION_ORTHOGONAL
	near = 0.1
	far = 500
	current = true
	reset_view()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			half_height = clampf(half_height + (-2.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 2.0), 24.0, 48.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		var up := Vector3(global_basis.y.x, 0, global_basis.y.z).normalized()
		_drag += (-global_basis.x * event.relative.x + up * event.relative.y) * size / get_viewport().get_visible_rect().size.y
		_drag = _drag.limit_length(70.0)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	delta = clampf(delta, 0.0, 0.05)
	if not is_instance_valid(target):
		return
	_elapsed += delta
	_intro = float(run_clock.intro_remaining) if run_clock != null else maxf(0.0, _intro - delta)
	var pose := subject_pose()
	var subject_speed := absf(float(pose.speed))
	var speed := clampf(subject_speed / 10.0, 0.0, 1.5)
	var forward := Vector3(sin(pose.heading), 0, cos(pose.heading))
	if not _dragging:
		_drag = _drag.lerp(Vector3.ZERO, 1.0 - exp(-delta * 1.5))
	_lead = _lead.lerp(forward * (5.0 + subject_speed * 0.52), 1.0 - exp(-12.0 * delta))
	_focus = Vector3(pose.position.x, 0, pose.position.z) + _lead + _drag
	var trauma := shake * shake
	var oscillation := Vector3((sin(_elapsed * 47) + sin(_elapsed * 71) * 0.45) * trauma, sin(_elapsed * 61 + 1.3) * trauma * 0.38, (cos(_elapsed * 53) + sin(_elapsed * 83) * 0.35) * trauma)
	shake = maxf(0.0, shake - delta * 1.55)
	punch = maxf(0.0, punch - delta * 2.8)
	var intro := clampf(_intro / 2.65, 0.0, 1.0)
	var cinematic := not death_cinematic.is_empty() and float(death_cinematic.elapsed) < float(death_cinematic.duration)
	var desired := _focus + follow_offset + oscillation + Vector3(10, 16, 10) * intro
	if cinematic:
		var progress := clampf(float(death_cinematic.elapsed) / float(death_cinematic.duration), 0, 1)
		var orbit: float = death_cinematic.heading + 2.25 + progress * 0.72
		var distance := 18.0 - progress * 3.5
		_focus = death_cinematic.position + Vector3.UP * 1.4
		desired = Vector3(_focus.x + cos(orbit) * distance + oscillation.x, 15.5 + oscillation.y, _focus.z + sin(orbit) * distance + oscillation.z)
	global_position = global_position.lerp(desired, 1.0 - pow(0.00004, delta)) if cinematic else desired
	look_at(_focus + Vector3.UP * oscillation.y * 0.12, Vector3.UP)
	rotation.z += sin(_elapsed * 67) * trauma * 0.009
	_zoom = lerpf(_zoom, (1.42 if cinematic else 1.0 - speed * 0.025 - punch * 0.015) * (1.0 - intro * 0.18), 1.0 - pow(0.001, delta))
	size = half_height * 2.0 / _zoom

func add_shake(power: float) -> void:
	shake = maxf(shake, power)
	punch = maxf(punch, power)

func reset_view() -> void:
	if not is_instance_valid(target):
		return
	death_cinematic.clear()
	_drag = Vector3.ZERO
	_dragging = false
	_intro = 2.65
	_elapsed = 0.0
	shake = 0.0
	punch = 0.0
	_zoom = 0.82
	_subject_view = target.get_node_or_null("VehicleView") as Node3D
	var pose := subject_pose()
	_lead = Vector3(sin(pose.heading), 0, cos(pose.heading)) * 5.0
	_focus = Vector3(pose.position.x, 0, pose.position.z) + _lead
	global_position = _focus + follow_offset + Vector3(10, 16, 10)
	look_at(_focus, Vector3.UP)
	size = half_height * 2.0 / _zoom

func subject_pose() -> Dictionary:
	if is_instance_valid(_subject_view) and _subject_view.has_method("get_render_pose"):
		var pose: Dictionary = _subject_view.get_render_pose()
		if not pose.is_empty():
			return pose
	return {"position": target.global_position, "heading": target.global_rotation.y, "speed": target.velocity.length() if target is CharacterBody3D else 0.0}

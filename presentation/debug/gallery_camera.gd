extends Camera3D

const MIN_SPAN := 1.2
const MAX_SPAN := 1200.0
const ORBIT_RATE := 0.006
const PAN_RATE := 0.75
const FOLLOW_RATE := 12.0
var center := Vector3.ZERO
var target := Vector3.ZERO
var span := 40.0
var target_span := 40.0
var yaw := 0.45
var pitch := 0.8
var input_blocked := false

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	far = 3000.0
	current = true

func focus(point: Vector3, width: float) -> void:
	target = point
	target_span = clampf(width, MIN_SPAN, MAX_SPAN)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_span = maxf(MIN_SPAN, target_span * 0.84)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_span = minf(MAX_SPAN, target_span / 0.84)
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			yaw -= event.relative.x * ORBIT_RATE
			pitch = clampf(pitch + event.relative.y * ORBIT_RATE, 0.12, 1.5)
		elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			var right := global_basis.x
			var forward := Vector3(-sin(yaw), 0, -cos(yaw))
			target += (-right * event.relative.x + forward * event.relative.y) * span / 700.0

func _process(delta: float) -> void:
	if not input_blocked:
		var movement := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var forward := Vector3(sin(yaw), 0, cos(yaw))
		target += (right * movement.x + forward * movement.y) * target_span * PAN_RATE * delta
	var blend := 1.0 - exp(-FOLLOW_RATE * delta)
	center = center.lerp(target, blend)
	span = lerpf(span, target_span, blend)
	size = span
	position = center + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * maxf(40.0, span)
	look_at(center)

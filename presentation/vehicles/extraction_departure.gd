extends Node

signal finished

const DURATION := 1.2
const DISTANCE := 12.0
var _played_generation := -1
var _elapsed := 0.0
var _visual: Node3D
var _direction := Vector3.ZERO
var active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start(visual: Node3D, generation: int, heading: float) -> void:
	cancel()
	_played_generation = generation
	_visual = visual
	_direction = Vector3(sin(heading), 0, cos(heading))
	_elapsed = 0.0
	active = true

func has_played(generation: int) -> bool:
	return _played_generation == generation

func skip(generation: int) -> void:
	cancel()
	_played_generation = generation

func cancel() -> void:
	if is_instance_valid(_visual):
		_visual.set_departure_offset(Vector3.ZERO)
	_visual = null
	active = false

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not active or not is_instance_valid(_visual):
		return
	_elapsed = minf(DURATION, _elapsed + clampf(delta, 0.0, 0.05))
	var progress := _elapsed / DURATION
	_visual.set_departure_offset(_direction * DISTANCE * progress * progress)
	if _elapsed >= DURATION:
		active = false
		finished.emit()

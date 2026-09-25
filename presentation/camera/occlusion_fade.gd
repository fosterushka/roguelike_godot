extends Node

const Grid = preload("res://modules/world/spatial_grid.gd")
const Visibility = preload("res://modules/combat/visibility_rules.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const QUERY_INTERVAL := 0.08
const FADE_IN_SECONDS := 0.16
const FADE_OUT_SECONDS := 0.26
const TRANSPARENCY := 0.82
const SUBJECT_MARGIN := 1.3
const MAX_FADED_PROPS := 24
const MAX_ENEMY_SUBJECTS := 8
var _arena: Node3D
var _camera: Camera3D
var _vehicle: Node3D
var _grid := Grid.new()
var _records: Dictionary = {}
var _state: Dictionary = {}
var _wanted: Dictionary = {}
var _faded: Dictionary = {}
var _remaining := 0.0

func setup(arena: Node3D, camera: Camera3D, vehicle: Node3D) -> void:
	_arena = arena
	_camera = camera
	_vehicle = vehicle
	_arena.occlusion_layout_changed.connect(_rebuild)
	_arena.occlusion_prop_moved.connect(_move_prop)
	_rebuild()

func update_state(state: Dictionary) -> void:
	_state = state

func _rebuild() -> void:
	clear()
	_grid = Grid.new()
	_records.clear()
	for record: Dictionary in _arena.occlusion_records():
		_records[record.id] = record
		_grid.insert(record)

func _move_prop(id: String, offset: Vector3) -> void:
	if not _records.has(id):
		return
	var record: Dictionary = _records[id]
	_grid.remove(record)
	record.position += offset
	var bounds: AABB = record.bounds
	bounds.position += offset
	record.bounds = bounds
	_grid.insert(record)
	_remaining = 0.0

func clear() -> void:
	if is_instance_valid(_arena):
		for id: String in _faded:
			_arena.fade_prop(id, 0.0)
	_faded.clear()
	_wanted.clear()
	_remaining = 0.0

func _process(delta: float) -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(_vehicle):
		return
	_remaining -= delta
	if _remaining <= 0.0:
		_remaining = QUERY_INTERVAL
		_find_occluders()
	for id: String in _wanted:
		if not _faded.has(id):
			_faded[id] = 0.0
	for id: String in _faded.keys():
		var target := TRANSPARENCY if _wanted.has(id) else 0.0
		var duration := FADE_IN_SECONDS if target > float(_faded[id]) else FADE_OUT_SECONDS
		_faded[id] = move_toward(float(_faded[id]), target, delta * TRANSPARENCY / duration)
		_arena.fade_prop(id, _faded[id])
		if _faded[id] <= 0.0:
			_faded.erase(id)

func _find_occluders() -> void:
	_wanted.clear()
	var subjects: Array[Vector3] = [_vehicle.global_position + Vector3.UP * 1.5]
	var player: Dictionary = _state.get("player", {})
	var fog := float(_state.get("visibility_fog", 0.0))
	var enemies: Array = _state.get("enemies", []).filter(func(enemy: Dictionary) -> bool: return not enemy.get("dead", false) and enemy.has("position") and Visibility.detects(player, enemy.position, fog))
	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.position.distance_squared_to(_vehicle.global_position) < b.position.distance_squared_to(_vehicle.global_position))
	for enemy: Dictionary in enemies.slice(0, MAX_ENEMY_SUBJECTS):
		var point: Vector3 = enemy.position
		point.y += Terrain.height_at(point.x, point.z) + 1.5
		subjects.append(point)
	for subject: Vector3 in subjects:
		var screen := _camera.unproject_position(subject)
		if _camera.is_position_behind(subject) or not _camera.get_viewport().get_visible_rect().has_point(screen):
			continue
		# Orthographic cameras have parallel rays; camera.global_position is not
		# the ray origin for a subject away from the middle of the screen.
		var from := _camera.project_ray_origin(screen)
		var candidates := _grid.nearby(subject, from.distance_to(subject))
		for prop: Dictionary in candidates:
			if _wanted.size() >= MAX_FADED_PROPS:
				return
			if _arena.is_prop_destroyed(prop.id):
				continue
			if prop.bounds.grow(SUBJECT_MARGIN).intersects_segment(from, subject) != null:
				_wanted[prop.id] = true

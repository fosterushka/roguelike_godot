extends RefCounted
const Grid = preload("res://modules/world/spatial_grid.gd")
var grid := Grid.new()

func setup(obstacles: Array) -> void:
	grid = Grid.new()
	for obstacle: Dictionary in obstacles:
		grid.insert({"id": obstacle.id, "position": Vector3(obstacle.x, 0, obstacle.z), "radius": obstacle.radius})

func direction(enemy: Dictionary, desired: Vector3, speed: float) -> Vector3:
	var desired_length := Vector2(desired.x, desired.z).length()
	if desired_length <= 0.0001:
		return Vector3.ZERO
	var forward := Vector3(desired.x / desired_length, 0, desired.z / desired_length)
	var radius := maxf(0.35, float(enemy.get("radius", 0.7)))
	var look_ahead := maxf(5.0, radius * 2.5 + absf(speed) * 1.2)
	var position: Vector3 = enemy.position
	var nearest: Dictionary = {}
	var nearest_progress := INF
	var nearest_side := 0.0
	for obstacle: Dictionary in grid.nearby(position, look_ahead + radius):
		var offset: Vector3 = obstacle.position - position
		var progress := offset.dot(forward)
		var clearance: float = radius + obstacle.radius + 0.8
		if progress < -clearance * 0.25 or progress > look_ahead + clearance:
			continue
		var side := forward.x * offset.z - forward.z * offset.x
		if absf(side) >= clearance or progress >= nearest_progress:
			continue
		nearest = obstacle
		nearest_progress = progress
		nearest_side = side
	if nearest.is_empty():
		return forward
	var offset: Vector3 = nearest.position - position
	var length := maxf(0.0001, offset.length())
	var away := -offset / length
	var angle := fallback_angle(str(nearest.id))
	var side_sign := -signf(nearest_side) if absf(nearest_side) > 0.05 else signf(forward.x * sin(angle) - forward.z * cos(angle))
	if side_sign == 0:
		side_sign = 1
	var tangent := Vector3(-offset.z, 0, offset.x) / length * side_sign
	var urgency := clampf(1.0 - nearest_progress / look_ahead, 0, 1)
	var steer := forward * (0.35 - urgency * 0.2) + tangent * (0.8 + urgency * 0.55) + away * (0.35 + urgency * 0.55)
	return steer / maxf(0.0001, steer.length())

static func fallback_angle(id: String) -> float:
	var hash_value := 2166136261
	for index in id.length():
		hash_value = ((hash_value ^ id.unicode_at(index)) * 16777619) & 0xffffffff
	return float(hash_value) / 4294967295.0 * TAU

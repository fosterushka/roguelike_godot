extends RefCounted

const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const MAX_SHEEP := 72
const GRAZER_RANDOM_DRAWS := 5
const FLOCK_SIZE := 6
const FLOCK_SPACING := 2.2
const SCRAP_REWARD := 3
const MIN_RAM_SPEED := 2.2
const BODY_RADIUS := 0.65
const MAX_SWEEP_DISTANCE := 20.0
const FALL_RESPONSE := 9.0
const REST_HEIGHT := 0.15

static func run_over(critter: Dictionary, previous: Vector3, current: Vector3, speed: float, radius: float) -> bool:
	if critter.get("dead", false) or absf(speed) < MIN_RAM_SPEED or not current.is_finite():
		return false
	var start := previous if previous.is_finite() and previous.distance_to(current) < MAX_SWEEP_DISTANCE else current
	var point: Vector3 = critter.group.position
	var nearest := Geometry2D.get_closest_point_to_segment(Vector2(point.x, point.z), Vector2(start.x, start.z), Vector2(current.x, current.z))
	if nearest.distance_squared_to(Vector2(point.x, point.z)) > pow(radius + BODY_RADIUS, 2.0) or absf(current.y - point.y) > 2.0:
		return false
	critter.dead = true
	critter.fall_direction = -1.0 if sin(critter.heading) < 0.0 else 1.0
	return true

static func settle(critter: Dictionary, delta: float) -> void:
	var group: Node3D = critter.group
	var blend := 1.0 - exp(-FALL_RESPONSE * delta)
	group.rotation.z = lerpf(group.rotation.z, float(critter.get("fall_direction", 1.0)) * PI * 0.5, blend)
	group.position.y = lerpf(group.position.y, Terrain.height_at(group.position.x, group.position.z) + REST_HEIGHT, blend)

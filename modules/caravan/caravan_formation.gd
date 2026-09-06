extends RefCounted
const Pose = preload("res://modules/caravan/vehicle_pose.gd")
const Suspension = preload("res://modules/caravan/wheel_suspension.gd")
const Ground = preload("res://modules/caravan/terrain_surface.gd")
const MAX_WAGONS := 6
const FRONT_AXLE := 1.55
const DRAWBAR := 1.7
const PLAYER_HITCH := 3.78
const WAGON_HITCH := 2.1
const MAX_JOINT_ANGLE := 1.05
const MAX_YAW_RATE := 2.8
const MAX_SPEED := 28.0
var _previous_player: Dictionary = {}

func reset() -> void:
	_previous_player.clear()

# All positions are authoritative world coordinates; rendering only interpolates pose snapshots.
func step(player: Dictionary, wagons: Array, delta: float, resolve_motion: Callable = Callable()) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var scale_value := float(player.get("scale", player.get("visual_scale", 0.88)))
	var current := {"position": Vector3(player.get("position", Vector3.ZERO)), "heading": float(player.get("heading", 0)), "scale": scale_value, "speed": float(player.get("speed", 0)), "wind_roll": float(player.get("wind_roll", 0))}
	var leader := current.duplicate()
	leader.rear_hitch = PLAYER_HITCH
	for index in wagons.size():
		var wagon: Dictionary = wagons[index]
		if index >= MAX_WAGONS:
			wagon.attached = false
		if not wagon.has("pose"):
			_initialize(wagon, leader, scale_value, resolve_motion)
			_previous_player = current.duplicate()
		if wagon.get("attached", true) and not wagon.get("dead", false):
			leader = {"position": wagon.position, "heading": wagon.heading, "rear_hitch": WAGON_HITCH}
	if _previous_player.is_empty():
		_previous_player = current.duplicate()
	if delta <= 0.0 or not is_finite(delta):
		return events
	for wagon: Dictionary in wagons:
		wagon.previous_pose = wagon.pose.duplicate(true)
		wagon.impact_cooldown = maxf(0.0, float(wagon.get("impact_cooldown", 0.0)) - delta)
	var count := maxi(1, ceili(delta * 120.0))
	var dt := delta / count
	for substep in count:
		var fraction := float(substep + 1) / count
		leader = {"position": Vector3(_previous_player.position).lerp(current.position, fraction), "heading": lerp_angle(_previous_player.heading, current.heading, fraction), "rear_hitch": PLAYER_HITCH, "speed": current.speed, "wind_roll": current.wind_roll}
		for index in wagons.size():
			var wagon: Dictionary = wagons[index]
			if wagon.get("dead", false) or not wagon.get("attached", true):
				wagon.was_attached = false
				wagon.velocity = Vector3.ZERO
				continue
			if not wagon.get("was_attached", true):
				wagon.recoupling = true
				wagon.recoupling_time = 0.0
				wagon.hitch_strain = 0.0
			wagon.was_attached = true
			_advance_wagon(wagon, leader, scale_value, dt, resolve_motion, events)
			if wagon.get("detach_requested", false):
				var detached: Array[String] = []
				for tail in range(index, wagons.size()):
					wagons[tail].attached = false
					wagons[tail].was_attached = false
					wagons[tail].detach_requested = false
					detached.append(str(wagons[tail].id))
				events.append({"kind": "wagon_detached", "id": wagon.id, "detached_ids": detached, "reason": wagon.get("detachment_reason", "hitch_strain"), "position": wagon.position})
				break
			leader = {"position": wagon.position, "heading": wagon.heading, "rear_hitch": WAGON_HITCH, "speed": wagon.pose.speed, "wind_roll": wagon.pose.wind_roll}
	_previous_player = current.duplicate()
	return events

func _initialize(wagon: Dictionary, leader: Dictionary, scale_value: float, resolve_motion: Callable) -> void:
	var forward := _forward(float(leader.heading))
	var point: Vector3 = leader.position - forward * (float(leader.rear_hitch) + FRONT_AXLE + DRAWBAR) * scale_value if wagon.get("attached", true) else wagon.get("position", Vector3.ZERO)
	if resolve_motion.is_valid():
		point = resolve_motion.call(point, point, _radius(wagon, scale_value))
	point.y = Ground.height_at(point.x, point.z)
	wagon.position = point
	wagon.heading = float(leader.heading)
	wagon.velocity = Vector3.ZERO
	wagon.hitch_strain = 0.0
	wagon.was_attached = wagon.get("attached", true)
	wagon.recoupling = false
	wagon.suspension = Suspension.create()
	Suspension.step(wagon.suspension, point, wagon.heading, 0, 0, 1.0 / 120.0, scale_value, true)
	wagon.pose = Pose.capture(point, wagon.heading, scale_value, 0, 0, 0, wagon.suspension)
	wagon.pose.wind_roll = 0.0
	wagon.previous_pose = wagon.pose.duplicate(true)

func _advance_wagon(wagon: Dictionary, leader: Dictionary, scale_value: float, delta: float, resolve_motion: Callable, events: Array[Dictionary]) -> void:
	var start: Vector3 = wagon.position
	var heading := float(wagon.heading)
	var old_forward := _forward(heading)
	var hitch: Vector3 = leader.position - _forward(leader.heading) * float(leader.rear_hitch) * scale_value
	hitch.y = 0.0
	var old_rear := start - old_forward * FRONT_AXLE * scale_value
	var to_hitch := hitch - old_rear
	var desired := atan2(to_hitch.x, to_hitch.z) if Vector2(to_hitch.x, to_hitch.z).length_squared() > 0.0001 else heading
	# Reverse assistance prevents an arcade six-wagon chain folding back through itself.
	if float(leader.speed) < -0.25:
		desired = lerp_angle(desired, float(leader.heading), 1.0 - exp(-4.0 * delta))
	var angle := clampf(wrapf(desired - float(leader.heading), -PI, PI), -MAX_JOINT_ANGLE, MAX_JOINT_ANGLE)
	desired = float(leader.heading) + angle
	var turn := clampf(wrapf(desired - heading, -PI, PI), -MAX_YAW_RATE * delta, MAX_YAW_RATE * delta)
	var next_heading := heading + turn
	var ideal := hitch - _forward(next_heading) * (FRONT_AXLE + DRAWBAR) * scale_value
	ideal.y = start.y
	var maximum_speed := 6.0 if wagon.get("recoupling", false) else MAX_SPEED
	var target := start + (ideal - start).limit_length(maximum_speed * delta)
	var actual: Vector3 = resolve_motion.call(start, target, _radius(wagon, scale_value)) if resolve_motion.is_valid() else target
	var blocked := Vector2(actual.x - target.x, actual.z - target.z).length()
	if blocked > 0.005 and float(wagon.impact_cooldown) <= 0.0:
		var impact_speed := Vector2(target.x - start.x, target.z - start.z).length() / delta
		var amount := clampf(pow(maxf(0.0, impact_speed - 3.0), 2.0) * 0.3, 0.0, 65.0)
		if amount > 0.0:
			events.append({"kind": "wagon_impact", "id": wagon.id, "amount": amount, "position": actual, "cause": "collision"})
			wagon.impact_cooldown = 0.4
	var front := actual + _forward(next_heading) * FRONT_AXLE * scale_value
	var gap := Vector2(front.x - hitch.x, front.z - hitch.z).length()
	var error := absf(gap - DRAWBAR * scale_value)
	if wagon.get("recoupling", false):
		wagon.recoupling_time = float(wagon.get("recoupling_time", 0.0)) + delta
		if error < 0.25 * scale_value:
			wagon.recoupling = false
		elif wagon.recoupling_time > 3.0:
			wagon.detach_requested = true
			wagon.detachment_reason = "recouple_blocked"
	elif error > 0.3 * scale_value:
		wagon.hitch_strain = float(wagon.hitch_strain) + error * delta * 1.8 / maxf(0.25, float(wagon.get("hitch_strength", 1.0)))
		if error > 1.3 * scale_value or wagon.hitch_strain >= 1.0:
			wagon.detach_requested = true
			wagon.detachment_reason = "hitch_strain"
	else:
		wagon.hitch_strain = maxf(0.0, float(wagon.hitch_strain) - delta * 0.6)
	wagon.position = actual
	wagon.heading = next_heading
	wagon.velocity = (actual - start) / delta
	var speed: float = Vector3(wagon.velocity).dot(_forward(next_heading))
	Suspension.step(wagon.suspension, actual, next_heading, speed, turn / delta, delta, scale_value, true)
	wagon.position.y = wagon.suspension.height
	var wheel_angle: float = wagon.pose.wheel_angle + speed * delta / (Suspension.RADIUS * scale_value)
	var roll := lerpf(float(wagon.pose.get("wind_roll", 0)), float(leader.wind_roll) * 0.5, 1.0 - exp(-4.0 * delta))
	wagon.pose = Pose.capture(wagon.position, next_heading, scale_value, speed, clampf(angle / MAX_JOINT_ANGLE, -1, 1), wheel_angle, wagon.suspension)
	wagon.pose.wind_roll = roll
	wagon.pose.hitch_gap = gap
	wagon.pose.hitch_strain = wagon.hitch_strain

static func _forward(heading: float) -> Vector3:
	return Vector3(sin(heading), 0, cos(heading))

static func _radius(wagon: Dictionary, scale_value: float) -> float:
	return float(wagon.get("radius", 2.2)) * scale_value / 0.88

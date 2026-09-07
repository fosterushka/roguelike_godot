extends CharacterBody3D

signal telemetry_changed(data: Dictionary)
signal physics_pose_advanced(delta: float)

const Jammer = preload("res://modules/combat/jammer_rules.gd")
const Pose = preload("res://modules/caravan/vehicle_pose.gd")
const Dimensions = preload("res://modules/caravan/player_dimensions.gd")
const MotionState = preload("res://modules/caravan/vehicle_motion_state.gd")
const Motion = preload("res://modules/caravan/vehicle_motion.gd")
const Suspension = preload("res://modules/caravan/wheel_suspension.gd")
const RoadSurface = preload("res://modules/world/road_surface.gd")
const Fuel = preload("res://modules/caravan/vehicle_fuel.gd")

var wheel_angle := 0.0
var suspension := Suspension.create()
var obstacle_impact_query: Callable
var clock_delta: Callable
var player_stats: Dictionary = {}
var surface_effects: Dictionary = {"traction": 1.0, "movement": 1.0, "turn": 1.0}
var tornado_effect: Dictionary = {}

var motion: MotionState = MotionState.new()
var max_health: float = 250.0
var health: float = 250.0
var max_fuel: float = Fuel.CAPACITY
var fuel: float = Fuel.CAPACITY
var _driving_enabled: bool = true
var _spawn_position: Vector3
var _spawn_heading: float

func _ready() -> void:
	_spawn_position = position
	_spawn_heading = rotation.y
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CylinderShape3D.new()
	shape.radius = Dimensions.BASE_RADIUS
	shape.height = 3.0
	var collider := CollisionShape3D.new()
	collider.name = "VehicleCollider"
	collider.shape = shape
	collider.position.y = 1.55
	add_child(collider)
	reset_vehicle()

func _physics_process(delta: float) -> void:
	if clock_delta.is_valid():
		delta = float(clock_delta.call())
	if delta <= 0.0:
		return
	if not _driving_enabled:
		return
	sync_collision_dimensions()
	var controls: Dictionary = {
		"throttle": Input.get_action_strength("drive_forward") - Input.get_action_strength("drive_backward"),
		"steer": Input.get_action_strength("drive_left") - Input.get_action_strength("drive_right"),
		"handbrake": Input.is_action_pressed("handbrake"),
	}
	motion.x = position.x
	motion.z = position.z
	var tuning := Fuel.drive_tuning(fuel, player_stats)
	tuning.traction *= float(surface_effects.get("traction", 1.0)) * float(suspension.grip)
	tuning.surface_traction = float(surface_effects.get("traction", 1.0))
	tuning.mass = float(player_stats.get("weight", Motion.Handling.BASE_MASS))
	tuning.wheeled = true
	tuning.wheelbase = (Suspension.FRONT_Z - Suspension.REAR_Z) * float(player_stats.get("visual_scale", Dimensions.BASE_SCALE))
	tuning.acceleration *= clampf(1.0 - float(suspension.slope) * signf(motion.speed) * 1.6, 0.65, 1.25)
	tuning.maximum_speed *= float(surface_effects.get("movement", 1.0)) * RoadSurface.speed_multiplier_at(global_position)
	tuning.acceleration *= float(surface_effects.get("movement", 1.0))
	tuning.maximum_speed *= float(tornado_effect.get("movement", 1.0))
	tuning.acceleration *= float(tornado_effect.get("movement", 1.0))
	controls.steer *= float(surface_effects.get("turn", 1.0))
	controls = Jammer.controls(controls, player_stats)
	Motion.step(motion, controls, tuning, delta)
	var previous_position := position
	var requested := Vector3(motion.x - position.x, 0.0, motion.z - position.z) + Vector3(tornado_effect.get("force", Vector3.ZERO)) * delta
	var collision: KinematicCollision3D = move_and_collide(requested)
	if collision:
		var breached: bool = obstacle_impact_query.is_valid() and bool(obstacle_impact_query.call(collision.get_collider(), motion.speed))
		motion.speed *= (0.97 if bool(tuning.get("ram", false)) else 0.86) if breached else 0.22
		if breached and move_and_collide(collision.get_remainder()) != null:
			motion.speed *= 0.22
	motion.x = position.x
	motion.z = position.z
	rotation.y = motion.heading
	Suspension.step(suspension, global_position, motion.heading, motion.speed, motion.yaw_velocity, delta, float(player_stats.get("visual_scale", Dimensions.BASE_SCALE)))
	position.y = float(suspension.height) + float(tornado_effect.get("lift", 0.0))
	velocity = (position - previous_position) / maxf(delta, 0.000001)
	fuel = Fuel.consume(fuel, max_fuel, motion.speed, controls["throttle"], delta, float(player_stats.get("fuel_burn_mult", 1.0)))
	wheel_angle += Vector2(position.x - previous_position.x, position.z - previous_position.z).length() * signf(motion.speed) / (Suspension.RADIUS * maxf(0.1, float(player_stats.get("visual_scale", Dimensions.BASE_SCALE))))
	_emit_telemetry()
	physics_pose_advanced.emit(delta)

func reset_vehicle() -> void:
	tornado_effect.clear()
	Jammer.clear_player(player_stats)
	position = _spawn_position
	rotation.y = _spawn_heading
	motion = MotionState.new()
	suspension = Suspension.create()
	wheel_angle = 0.0
	motion.x = position.x
	motion.z = position.z
	motion.heading = _spawn_heading
	motion.move_heading = _spawn_heading
	velocity = Vector3.ZERO
	health = max_health
	fuel = max_fuel
	_emit_telemetry()

func set_driving_enabled(enabled: bool) -> void:
	_driving_enabled = enabled
	if not enabled:
		physics_pose_advanced.emit(0.0)

func _emit_telemetry() -> void:
	telemetry_changed.emit({
		"speed": motion.speed,
		"health": health,
		"max_health": max_health,
		"fuel": fuel,
		"max_fuel": max_fuel,
		"heading": motion.heading,
		"slip_angle": motion.slip_angle,
		"steer": motion.steer,
		"suspension": suspension,
	})

func sync_collision_dimensions() -> void:
	var collider := get_node_or_null("VehicleCollider") as CollisionShape3D
	if collider != null and collider.shape is CylinderShape3D:
		var radius := Dimensions.radius(float(player_stats.get("visual_scale", Dimensions.BASE_SCALE)))
		if not is_equal_approx(collider.shape.radius, radius):
			collider.shape.radius = radius

func current_render_pose() -> Dictionary:
	var pose := Pose.capture(global_position, motion.heading, float(player_stats.get("visual_scale", Dimensions.BASE_SCALE)), motion.speed, motion.steer, wheel_angle, suspension)
	pose.wind_roll = float(tornado_effect.get("roll", 0.0))
	if float(tornado_effect.get("lift", 0.0)) > 0.25:
		pose.suspension.wheel_contacts = [false, false, false, false]
		pose.suspension.contacts = 0
	return pose

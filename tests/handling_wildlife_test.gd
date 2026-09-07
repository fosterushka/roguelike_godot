extends SceneTree

const Motion = preload("res://modules/caravan/vehicle_motion.gd")
const State = preload("res://modules/caravan/vehicle_motion_state.gd")
const Wildlife = preload("res://modules/world/wildlife_rules.gd")
const Ambient = preload("res://modules/world/ambient_system.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var dry := _coast(1.0, 12.0)
	var wet := _coast(0.78, 12.0)
	var heavy := _coast(0.78, 30.0)
	check(wet > dry * 1.4, "Rain increases stopping distance")
	check(heavy > wet * 1.4, "Heavy vehicles carry more momentum")
	check(absf(_coast(0.78, 12.0, 120) - wet) < 0.2, "Braking distance stable across physics frequencies")
	var low := _turn(3.0)
	var high := _turn(15.0)
	check(high.steer < low.steer and high.steer > 0.6, "Steering filters high speed direction changes")
	check(absf(high.yaw_velocity) < 1.0, "High speed turn rate is bounded")
	var group := Node3D.new()
	root.add_child(group)
	var critter := {"group": group, "dead": false, "heading": 0.0, "origin": Vector3.ZERO, "phase": 0.0, "turn": 3.0, "speed": 0.2, "activityState": "roaming", "fleeRemaining": 0.0, "recoveryRemaining": 2.0}
	check(not Wildlife.run_over(critter, Vector3.ZERO, Vector3.ZERO, 1.0, 1.0), "Slow contact does not kill sheep")
	check(Wildlife.run_over(critter, Vector3(-5, 0, 0), Vector3(5, 0, 0), 8.0, 1.0), "Swept vehicle hit catches crossed sheep")
	check(not Wildlife.run_over(critter, Vector3.ZERO, Vector3.ZERO, 8.0, 1.0), "Dead sheep cannot reward twice")
	for frame in 60:
		Wildlife.settle(critter, 1.0 / 60)
	check(absf(group.rotation.z) > 1.5, "Dead sheep settles on its side")
	critter.dead = false
	group.transform = Transform3D.IDENTITY
	var context := preload("res://modules/world/generation/generation_context.gd").new()
	context.ambient_critters = [critter]
	var ambient := Ambient.new()
	ambient.bind(context)
	ambient.step(1.0 / 60, [], false, 0.0, Vector3.ZERO, 8.0)
	check(ambient.rewards.size() == 1 and critter.dead, "Runtime creates one scrap reward on ram")
	ambient.rewards.clear()
	ambient.step(1.0 / 60, [], false, 0.0, Vector3.ZERO, 8.0)
	check(ambient.rewards.is_empty(), "Remaining over corpse cannot farm scrap")
	ambient.reset(123)
	check(not critter.dead and group.transform == Transform3D.IDENTITY, "Restart restores flock and clears corpse pose")
	group.free()
	var authored := preload("res://modules/world/generation/authored_props.gd").new()
	var generated := preload("res://modules/world/generation/world_generator.gd").generate(72841, authored)
	check(generated.ambient_critters.size() >= Wildlife.FLOCK_SIZE and generated.ambient_critters.size() <= Wildlife.MAX_SHEEP, "Generated world contains bounded sheep flocks")
	for attempt in Wildlife.MAX_SHEEP:
		authored.grazer(100, 100)
	check(generated.ambient_critters.size() == Wildlife.MAX_SHEEP, "Direct forest sheep creation also obeys global cap")
	for node: Node3D in generated.groups:
		node.free()
	print("Handling and wildlife: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _coast(traction: float, mass: float, hz: int = 60) -> float:
	var state := State.new()
	state.speed = 10.0
	var tuning := {"maximum_speed": 10.0, "acceleration": 6.7, "braking": 15.5, "traction": traction, "surface_traction": traction, "mass": mass, "wheeled": true}
	for tick in hz * 20:
		Motion.step(state, {"throttle": 0.0, "steer": 0.0, "handbrake": false}, tuning, 1.0 / hz)
	return state.z

func _turn(speed: float) -> RefCounted:
	var state := State.new()
	state.speed = speed
	state.throttle = 1.0
	for tick in 6:
		Motion.step(state, {"throttle": 1.0, "steer": 1.0, "handbrake": false}, {"maximum_speed": speed, "acceleration": 6.7, "braking": 15.5, "traction": 1.0, "wheeled": true}, 1.0 / 60)
	return state

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

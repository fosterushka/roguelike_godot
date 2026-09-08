extends SceneTree

const Suspension = preload("res://modules/caravan/wheel_suspension.gd")
const Rig = preload("res://presentation/vehicles/wheeled_rig.gd")
const Pose = preload("res://modules/caravan/vehicle_pose.gd")
const Inputs = preload("res://app/input_actions.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Inputs.register()
	Inputs.register()
	check(_matches(KEY_SPACE, "handbrake") and not _matches(KEY_SPACE, "activate_ability"), "Space only binds the handbrake gameplay action")
	check(_matches(KEY_F, "activate_ability") and not _matches(KEY_F, "focus_target") and _matches(KEY_E, "interact"), "F activates ability; E interacts without key conflicts")
	for trailer in [false, true]:
		for rate in [30, 60, 120]:
			var slow := _drive(3.0, rate, trailer)
			var fast := _drive(14.0, rate, trailer)
			print("AIR trailer=", trailer, " hz=", rate, " slow=", slow, " fast=", fast)
			check(fast.air_time > 0.05 and fast.rising_air, "Fast crest produces an upward airborne phase")
			check(fast.air_time > slow.air_time and fast.max_gap > slow.max_gap, "Crest takeoff depends on approach speed")
			check(fast.ballistic and fast.settled and fast.wheel_gap, "Airborne body follows gravity, wheels leave ground, landing settles")
	var state := Suspension.create()
	state.initialized = true
	state.height = 5.0
	state.pitch = 0.2
	state.roll = -0.1
	state.contacts = 0
	state.grounds = PackedFloat32Array([0, 0, 0, 0])
	Suspension.step(state, Vector3.ZERO, 0, 0, 0, 1.0 / 60, 1, false, func(_x: float, _z: float) -> float: return 0.0)
	check(is_equal_approx(state.velocity, -Suspension.GRAVITY / 60) and is_equal_approx(state.pitch, 0.2) and is_equal_approx(state.roll, -0.1), "No ground force or terrain alignment is applied during free fall")
	var frozen := state.duplicate(true)
	Suspension.step(state, Vector3.ZERO, 0, 0, 0, 0)
	check(state == frozen, "Pause freezes airborne motion and support history")
	print("Vehicle airborne: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _drive(speed: float, rate: int, trailer: bool) -> Dictionary:
	var sample := func(_x: float, z: float) -> float: return 0.9 * exp(-pow(z / 2.2, 2))
	var state := Suspension.create()
	var rig := Rig.build_trailer() if trailer else Rig.build_player()
	root.add_child(rig)
	var air_time := 0.0
	var max_gap := 0.0
	var rising_air := false
	var ballistic := true
	var wheel_gap := false
	var dt := 1.0 / rate
	for tick in ceili((24.0 / speed + 3.0) * rate):
		var point := Vector3(0, 0, minf(12, -12 + tick * dt * speed))
		var before_contacts: int = state.contacts
		var before_velocity: float = state.velocity
		Suspension.step(state, point, 0, speed, 0, dt, 1, trailer, sample)
		if state.contacts == 0:
			air_time += dt
			rising_air = rising_air or state.velocity > 0.1
			if before_contacts == 0:
				ballistic = ballistic and absf(state.velocity - before_velocity + Suspension.GRAVITY * dt) < 0.0001
			point.y = state.height
			rig.transform = Pose.transform(Pose.capture(point, 0, 1, speed, 0, 0, state))
			Rig.animate(rig, state, 0, speed, 0, trailer)
			var minimum_gap := INF
			for wheel: Node3D in rig.get_meta("wheels"):
				var p := wheel.global_position
				minimum_gap = minf(minimum_gap, p.y - Suspension.RADIUS - sample.call(p.x, p.z))
			max_gap = maxf(max_gap, minimum_gap)
			wheel_gap = wheel_gap or minimum_gap > 0.03
	rig.free()
	return {"air_time": air_time, "max_gap": max_gap, "rising_air": rising_air, "ballistic": ballistic, "wheel_gap": wheel_gap, "settled": state.contacts == 4 and absf(state.velocity) < 0.01 and absf(state.height) < 0.01}

func _matches(key: Key, action: String) -> bool:
	var event := InputEventKey.new()
	event.physical_keycode = key
	return event.is_action(action)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

extends SceneTree

const Controller = preload("res://modules/caravan/vehicle_controller.gd")
const View = preload("res://presentation/vehicles/vehicle_view.gd")
const Camera = preload("res://presentation/camera/follow_camera.gd")
const Motion = preload("res://modules/caravan/vehicle_motion.gd")
const State = preload("res://modules/caravan/vehicle_motion_state.gd")
const Suspension = preload("res://modules/caravan/wheel_suspension.gd")
const Pose = preload("res://modules/caravan/vehicle_pose.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_controls()
	_test_rigid_suspension()
	_test_load_transfer()
	var results: Array[Dictionary] = []
	for rate in [30, 60, 144]:
		results.append(await _test_render_rate(rate))
	for index in range(1, results.size()):
		check(results[index].position.distance_to(results[0].position) < 0.0001, "Body final pose independent of render frequency")
		check(results[index].trailer.distance_to(results[0].trailer) < 0.0001, "Trailer path independent of render frequency")
		check(results[index].projection.distance_to(results[0].projection) < 0.05, "Camera projection agrees across render frequencies")
	print("Vehicle response: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_controls() -> void:
	var state := State.new()
	state.speed = 6.0
	state.throttle = 1.0
	var tuning := {"maximum_speed": 6.0, "acceleration": 4.0, "braking": 8.0, "traction": 1.0, "wheeled": true, "wheelbase": 4.7}
	for tick in 6:
		Motion.step(state, {"throttle": 1.0, "steer": 1.0, "handbrake": false}, tuning, 1.0 / 60)
	check(state.steer > 0.7 and state.steer < 0.9 and state.heading > 0.0, "High speed steering ramps smoothly during first100ms")
	check(state.speed == 6.0, "Responsive steering preserves maximum driving speed")
	for tick in 6:
		Motion.step(state, {"throttle": 1.0, "steer": -1.0, "handbrake": false}, tuning, 1.0 / 60)
	check(state.steer < -0.5 and state.steer > -0.85, "Changing steering direction smoothly crosses neutral")
	var normal := State.new()
	var handbrake := State.new()
	normal.speed = 6.0
	handbrake.speed = 6.0
	for tick in 12:
		Motion.step(normal, {"throttle": 1.0, "steer": 1.0, "handbrake": false}, tuning, 1.0 / 60)
		Motion.step(handbrake, {"throttle": 1.0, "steer": 1.0, "handbrake": true}, tuning, 1.0 / 60)
	check(absf(handbrake.slip_angle) > absf(normal.slip_angle) * 2 and handbrake.speed < normal.speed, "Handbrake preserves controlled drift and speed loss")
	for tick in 120:
		Motion.step(handbrake, {"throttle": 1.0, "steer": 0.0, "handbrake": true}, tuning, 1.0 / 60)
	check(is_zero_approx(handbrake.speed), "Held handbrake stops and holds vehicle even with throttle pressed")
	for tick in 150:
		Motion.step(state, {"throttle": -1.0, "steer": 1.0, "handbrake": false}, tuning, 1.0 / 60)
	check(state.speed < 0 and state.yaw_velocity < 0, "Reverse remains limited and turns in the correct direction")

func _test_rigid_suspension() -> void:
	var state := Suspension.create()
	for tick in 120:
		Suspension.step(state, Vector3.ZERO, 0, 6, 1.2, 1.0 / 60, 1.0, false, func(x: float, z: float) -> float: return x * 0.06 + z * 0.04)
	check(state.pitch < -0.03 and state.roll > 0.05 and absf(state.pitch_velocity) < 0.001 and absf(state.roll_velocity) < 0.001, "Body settles into the terrain slope")
	check(absf(state.wheel_offsets[0] - state.wheel_offsets[1]) < 0.01, "Body alignment keeps suspension centered on a uniform slope")
	var first := Pose.capture(Vector3.ZERO, PI - 0.1, 0.88, 0, 0, 0, state)
	var last := Pose.capture(Vector3.ONE, -PI + 0.1, 1.42, 1, 1, 1, state)
	first.suspension.roll = 0.0
	var midpoint := Pose.interpolate(first, last, 0.5)
	check(is_equal_approx(midpoint.suspension.roll, last.suspension.roll * 0.5), "Terrain roll interpolates between physics ticks")
	var transform := Pose.transform(midpoint)
	check(absf(absf(midpoint.heading) - PI) < 0.00001, "Yaw interpolation crosses angle wrap without a full revolution")
	check(_rigid(transform.basis), "Interpolating vehicle growth preserves uniform scale with no shear")

func _test_load_transfer() -> void:
	var state := Suspension.create()
	var flat := func(_x: float, _z: float) -> float: return 0.0
	Suspension.step(state, Vector3.ZERO, 0, 0, 0, 1.0 / 60, 1.0, false, flat)
	for tick in 60:
		Suspension.step(state, Vector3.ZERO, 0, (tick + 1) * 0.1, 0, 1.0 / 60, 1.0, false, flat)
	check(state.pitch < -0.03 and absf(state.pitch) <= Suspension.MAX_LOAD_PITCH, "Acceleration lifts nose with bounded suspension squat")
	var first := Pose.capture(Vector3.ZERO, 0, 1, 0, 0, 0, Suspension.create())
	var accelerated := Pose.capture(Vector3(0, state.height, 0), 0, 1, 6, 0, 0, state)
	var half := Pose.interpolate(first, accelerated, 0.5)
	check(is_equal_approx(half.suspension.pitch, state.pitch * 0.5), "Body pitch interpolates between physics ticks")
	var rig := preload("res://presentation/vehicles/wheeled_rig.gd").build_player()
	root.add_child(rig)
	rig.transform = Pose.transform(accelerated)
	preload("res://presentation/vehicles/wheeled_rig.gd").animate(rig, state, 0.6, 6, 0)
	var wheels: Array = rig.get_meta("wheels")
	var grounded := true
	for index in wheels.size():
		var expected: Vector3 = wheels[index].get_meta("anchor")
		expected.y = (Suspension.body_basis(state) * expected).y + float(state.height) + float(state.wheel_offsets[index])
		grounded = grounded and wheels[index].global_position.distance_to(expected) < 0.00001
		grounded = grounded and wheels[index].global_basis.y.distance_to(Vector3.UP) < 0.00001
	check(grounded and _rigid(rig.basis), "Pitch preserves all tire contact positions and rigid chassis without shear")
	rig.free()
	for tick in 30:
		Suspension.step(state, Vector3.ZERO, 0, 6.0 - (tick + 1) * 0.2, 0, 1.0 / 60, 1.0, false, flat)
	check(state.pitch > 0.04 and state.contacts == 4, "Braking dips nose while all wheels retain support")
	for tick in 240:
		Suspension.step(state, Vector3.ZERO, 0, 0, 0, 1.0 / 60, 1.0, false, flat)
	check(absf(state.pitch) < 0.00001 and absf(state.pitch_velocity) < 0.00001, "Load transfer settles when vehicle stops")

func _test_render_rate(rate: int) -> Dictionary:
	var controller := Controller.new()
	root.add_child(controller)
	controller.set_physics_process(false)
	controller.player_stats = {"visual_scale": 1.0}
	var view := View.new()
	view.name = "VehicleView"
	controller.add_child(view)
	view.set_process(false)
	view.apply_player_state({"position": Vector3.ZERO, "heading": 0.0, "visual_scale": 1.0, "carriers": [{"id": "trailer-1"}], "modules": []}, 1)
	var camera := Camera.new()
	camera.target = controller
	root.add_child(camera)
	camera.set_process(false)
	camera._intro = 0.0
	var next_physics := 1.0 / 60
	var previous_render := Vector3.ZERO
	var smooth := true
	var rigid := true
	var camera_aligned := true
	var fixed_basis: Basis
	for frame in range(1, rate * 3 + 1):
		var elapsed := float(frame) / rate
		while next_physics <= elapsed + 0.0000001:
			controller.position.z = next_physics * 3.0
			controller.motion.speed = 3.0
			controller.motion.heading = 0.0
			controller.wheel_angle = next_physics * 3.0 / Suspension.RADIUS
			controller.physics_pose_advanced.emit(1.0 / 60)
			next_physics += 1.0 / 60
		var fraction := (elapsed - (next_physics - 1.0 / 60)) * 60
		view.render_interpolated(fraction)
		camera._process(1.0 / rate)
		if frame == 1:
			fixed_basis = camera.global_basis
		if elapsed > 0.2:
			smooth = smooth and absf(view.global_position.z - previous_render.z - 3.0 / rate) < 0.00002
			camera_aligned = camera_aligned and camera.global_basis.z.distance_to(fixed_basis.z) < 0.000002
			rigid = rigid and _rigid(view.global_basis) and _rigid(view._trailers["trailer-1"].global_basis)
		previous_render = view.global_position
	check(smooth, "%dfps rendering has uniform body steps with60Hz physics" % rate)
	check(camera_aligned, "%dfps camera keeps orientation fixed instead of looking at a stepped physics target" % rate)
	check(rigid, "%dfps body and trailer remain rigid and uniformly scaled" % rate)
	view.on_impact(0.8, -0.8)
	view.render_interpolated(1.0)
	check(_rigid(view.global_basis) and view._body.impact_pitch == 0 and view._body.impact_roll == 0, "Combat impact never tilts or stretches the body")
	var contacts := view.get_tire_contacts()
	var ids: Dictionary = {}
	for contact: Dictionary in contacts:
		ids[contact.id] = true
	check(contacts.size() == 8 and ids.size() == 8, "Public tyre contacts expose stable wheel IDs for car and trailer")
	view.render_interpolated(0.0)
	camera._process(0.0)
	var result := {"position": view.global_position, "trailer": view._trailers["trailer-1"].global_position, "projection": camera.unproject_position(view.global_position)}
	controller.set_driving_enabled(false)
	view.render_interpolated(0.1)
	var frozen := view.global_transform
	view.render_interpolated(0.9)
	check(view.global_transform == frozen, "Disabling driving collapses interpolation history instead of oscillating during pause")
	controller.queue_free()
	camera.queue_free()
	await process_frame
	return result

func _rigid(basis: Basis) -> bool:
	return absf(basis.x.length() - basis.y.length()) < 0.00001 and absf(basis.y.length() - basis.z.length()) < 0.00001 and absf(basis.x.dot(basis.z)) < 0.00001 and absf(basis.x.dot(basis.y)) < 0.00001 and absf(basis.y.dot(basis.z)) < 0.00001

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

extends SceneTree

const MotionState = preload("res://modules/caravan/vehicle_motion_state.gd")
const Motion = preload("res://modules/caravan/vehicle_motion.gd")
const Controller = preload("res://modules/caravan/vehicle_controller.gd")
const Fuel = preload("res://modules/caravan/vehicle_fuel.gd")
const FIELDS: Array[String] = ["x", "z", "speed", "heading", "move_heading", "throttle", "steer", "yaw_velocity", "slip_angle"]

func _init() -> void:
	_run_tests.call_deferred()

func _run_tests() -> void:
	var source: String = FileAccess.get_file_as_string("res://tests/fixtures/vehicle_motion.json")
	var fixture = JSON.parse_string(source)
	if not fixture is Dictionary:
		push_error("Vehicle fixture missing or invalid")
		quit(1)
		return
	var checks: int = 0
	var failures: int = 0
	for scenario: Dictionary in fixture["scenarios"]:
		var state: MotionState = MotionState.new()
		var fuel: float = scenario["initial_fuel"]
		var frame_index: int = 0
		var elapsed_steps: int = 0
		for segment: Dictionary in scenario["segments"]:
			var controls: Dictionary = {"throttle": segment.get("throttle", 0.0), "steer": segment.get("steer", 0.0), "handbrake": segment.get("handbrake", false)}
			for _step: int in range(int(segment["steps"])):
				var tuning: Dictionary = Fuel.drive_tuning(fuel, scenario.get("stats", {"weight": 10.0}))
				# These immutable TypeScript fixtures test the motion integrator at the
				# original speed. Current 50 km/h balance is tested by road_speed_test.
				tuning.maximum_speed = _legacy_fixture_speed(fuel, scenario.get("stats", {"weight": 10.0}))
				tuning["nitro"] = segment.get("nitro", false)
				tuning["ram"] = segment.get("ram", false)
				tuning["traction"] = scenario["traction"]
				Motion.step(state, controls, tuning, fixture["delta"])
				fuel = Fuel.consume(fuel, float(scenario.get("stats", {}).get("max_fuel", Fuel.CAPACITY)), state.speed, controls["throttle"], fixture["delta"], float(scenario.get("stats", {}).get("fuel_burn_mult", 1.0)))
				elapsed_steps += 1
				var expected: Dictionary = scenario["frames"][frame_index]
				if elapsed_steps != int(expected["after_step"]):
					continue
				for field: String in FIELDS:
					checks += 1
					if absf(float(state.get(field)) - float(expected[field])) > 0.00000001:
						push_error("%s step %d %s differs: %s vs %s" % [scenario["name"], elapsed_steps, field, state.get(field), expected[field]])
						failures += 1
				checks += 1
				if absf(fuel - float(expected["fuel"])) > 0.00000001:
					push_error("%s step %d fuel differs" % [scenario["name"], elapsed_steps])
					failures += 1
				frame_index += 1
	print("Vehicle TypeScript parity: %d scenarios, %d checks, %d failures" % [fixture["scenarios"].size(), checks, failures])
	failures += await _test_controller()
	quit(1 if failures > 0 else 0)

func _legacy_fixture_speed(fuel: float, stats: Dictionary) -> float:
	return maxf(4.2, (9.2 + float(stats.get("level", 1)) * 0.18) * float(stats.get("speed_mult", 1.0)) * float(stats.get("motor_speed_mult", 1.0)) - float(stats.get("weight", 12)) * 0.105) * (1.0 + float(stats.get("momentum", 0.0)) * 0.08) * (1.0 if fuel > 0 else 0.35)

func _test_controller() -> int:
	for action: String in ["drive_forward", "drive_backward", "drive_left", "drive_right", "handbrake"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var world := Node3D.new()
	root.add_child(world)
	var wall := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 4.0, 1.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector3(0.0, 2.0, 10.0)
	world.add_child(wall)
	var vehicle := Controller.new()
	world.add_child(vehicle)
	vehicle.set_physics_process(false)
	await physics_frame
	await physics_frame
	Input.action_press("drive_forward")
	for _frame: int in range(300):
		vehicle._physics_process(1.0 / 60.0)
	Input.action_release("drive_forward")
	var failures: int = 0
	failures += _check(vehicle.position.z > 5.9 and vehicle.position.z + 3.5 < 9.51, "Source circular base hull must stop before the wall")
	failures += _check(absf(vehicle.motion.z - vehicle.position.z) < 0.00001, "Corrected collision position must update motion state")
	failures += _check(vehicle.fuel < vehicle.max_fuel and vehicle.fuel > 0.0, "Driving must consume fuel")
	var wall_position: float = vehicle.position.z
	Input.action_press("drive_backward")
	for _frame: int in range(120):
		vehicle._physics_process(1.0 / 60.0)
	Input.action_release("drive_backward")
	failures += _check(vehicle.position.z < wall_position - 1.0, "Vehicle must be able to reverse away from wall")
	vehicle.set_driving_enabled(false)
	var frozen_position: Vector3 = vehicle.position
	var frozen_fuel: float = vehicle.fuel
	vehicle._physics_process(1.0)
	failures += _check(vehicle.position == frozen_position and vehicle.fuel == frozen_fuel, "Disabled driving must freeze motion and fuel")
	vehicle.health = 10.0
	vehicle.reset_vehicle()
	failures += _check(vehicle.position == Vector3.ZERO and vehicle.motion.speed == 0.0 and vehicle.health == vehicle.max_health and vehicle.fuel == vehicle.max_fuel, "Reset must restore spawn, motion, health and fuel")
	world.queue_free()
	await process_frame
	print("Vehicle controller: 6 checks, %d failures" % failures)
	return failures

func _check(condition: bool, message: String) -> int:
	if condition:
		return 0
	push_error(message)
	return 1

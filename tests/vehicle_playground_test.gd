extends SceneTree
const Playground = preload("res://presentation/debug/vehicle_playground.tscn")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := Playground.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.vehicle.set_physics_process(false)
	check(scene.vehicle.terrain_sampler.is_valid(), "Playground uses the live vehicle controller with its test terrain sampler")
	for lane in 4:
		scene.reset_lane(lane)
		check(is_equal_approx(scene.vehicle.position.x, scene.Ground.LANES[lane]) and scene.vehicle.suspension.contacts == 4, "Lane reset clears suspension and positions vehicle on the flat approach")
	scene.reset_lane(0)
	Input.action_press("drive_forward")
	var airborne := false
	var landed := false
	for tick in 420:
		scene.vehicle._physics_process(1.0 / 60)
		if scene.vehicle.suspension.contacts == 0:
			airborne = true
		elif airborne:
			landed = true
	Input.action_release("drive_forward")
	check(scene.vehicle.position.z > 20 and airborne and landed, "Real controller accelerates over playground crest, takes off and lands")
	Input.action_press("handbrake")
	for tick in 120:
		scene.vehicle._physics_process(1.0 / 60)
	Input.action_release("handbrake")
	check(is_zero_approx(scene.vehicle.motion.speed), "Playground handbrake stops the actual vehicle")
	check(is_equal_approx(scene.vehicle.fuel, scene.vehicle.max_fuel), "Playground fuel is unlimited")
	scene.reset_lane(0)
	check(scene.last_air_time == 0 and scene.vehicle.suspension.velocity == 0 and scene.vehicle.motion.speed == 0, "Reset clears airtime, vertical momentum and driving speed")
	scene.queue_free()
	await process_frame
	print("Vehicle playground: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

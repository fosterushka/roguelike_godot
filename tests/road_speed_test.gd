extends SceneTree

const Roads = preload("res://modules/world/road_surface.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const Tracks = preload("res://presentation/world/track_surface.gd")
const Controller = preload("res://modules/caravan/vehicle_controller.gd")
const Fuel = preload("res://modules/caravan/vehicle_fuel.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	preload("res://app/input_actions.gd").register()
	Roads.configure([{"width": 8.0, "points": [{"x": -70, "z": -10}, {"x": 10, "z": -10}, {"x": 10, "z": 60}]}])
	check(Roads.contains(Vector3(-33, 200, -6)), "Road width includes boundary and ignores height")
	check(not Roads.contains(Vector3(-33, 0, -5.99)), "Road shoulder outside width keeps normal speed")
	check(Roads.contains(Vector3(-74, 0, -10)), "Negative grid coordinates and endpoint are indexed")
	check(not Roads.contains(Vector3(-74.01, 0, -10)), "Endpoint has bounded radius")
	check(Roads.contains(Vector3(12, 0, -8)), "Bend and junction remain connected")
	check(Tracks.kind_at(Vector3(-33, 0, -10), false) == Tracks.Kind.ROAD, "Tyre palette and driving use the same road footprint")
	Roads.configure([])
	check(Roads.speed_multiplier_at(Vector3(-33, 0, -10)) == 1.0, "Reconfiguration clears old roads")
	var layout := [{"width": 8.0, "points": [{"x": 0, "z": -2000}, {"x": 0, "z": 2000}]}]
	Terrain.configure({}, layout)
	check(Roads.contains(Vector3.ZERO), "Terrain setup configures physics roads independently of rendering")
	Terrain.heights.clear()
	var car := Controller.new()
	root.add_child(car)
	car.set_physics_process(false)
	Input.action_press("drive_forward")
	check(is_equal_approx(terminal_speed(car, 30.0, {}, 100.0, 1.0) * 3.6, 50.0), "Starter reaches 50 km/h off-road")
	check(is_equal_approx(terminal_speed(car, 0.0, {}, 100.0, 1.0) * 3.6, 75.0), "Starter reaches 75 km/h on road")
	check(Fuel.maximum_speed(100, {"motor_speed_mult": 1.08}) > Fuel.maximum_speed(100), "Motor upgrade still improves top speed")
	check(Fuel.maximum_speed(100, {"weight": 20.0}) < Fuel.maximum_speed(100), "Extra cargo weight still reduces top speed")
	for stats: Dictionary in [{}, {"speed_mult": 1.2, "motor_speed_mult": 1.3, "weight": 20.0, "momentum": 2.0}]:
		for fuel in [100.0, 0.0]:
			for movement in [1.0, 0.6]:
				var offroad := terminal_speed(car, 30.0, stats, fuel, movement)
				var road := terminal_speed(car, 0.0, stats, fuel, movement)
				var expected: float = float(Fuel.drive_tuning(fuel, stats).maximum_speed) * movement
				check(is_equal_approx(offroad, expected), "Off-road preserves base speed, upgrades, fuel and weather")
				check(is_equal_approx(road, offroad * 1.5), "Road speed is exactly 1.5 times equivalent off-road speed")
	for rate in [30, 60, 144]:
		terminal_speed(car, 30.0, {}, 100.0, 1.0)
		car.position.x = 0.0
		var before: float = car.motion.speed
		car._physics_process(1.0 / rate)
		check(car.motion.speed > before and car.motion.speed - before <= Fuel.BASE_ACCELERATION / rate, "Entering road accelerates continuously")
		terminal_speed(car, 0.0, {}, 100.0, 1.0)
		car.position.x = 30.0
		before = car.motion.speed
		car._physics_process(1.0 / rate)
		check(car.motion.speed < before and before - car.motion.speed <= Fuel.BASE_ACCELERATION / rate, "Leaving road decelerates continuously")
	Input.action_release("drive_forward")
	car.free()
	Terrain.configure({})
	check(not Roads.contains(Vector3.ZERO), "New world without roads removes speed bonus")
	print("Road speed: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func terminal_speed(car: CharacterBody3D, x: float, stats: Dictionary, fuel: float, movement: float) -> float:
	car.reset_vehicle()
	car.position = Vector3(x, 0, 0)
	car.player_stats = stats
	car.surface_effects = {"traction": 1.0, "movement": movement, "turn": 1.0}
	for tick in 1200:
		car.fuel = fuel
		car._physics_process(1.0 / 60.0)
	return car.motion.speed

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

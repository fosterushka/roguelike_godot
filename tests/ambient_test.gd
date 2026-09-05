extends SceneTree
const Ambient = preload("res://modules/world/ambient_system.gd")
const Random = preload("res://modules/world/activities/source_random.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ambient.json"))
	for scenario: Dictionary in fixtures:
		var group := Node3D.new()
		group.position.x = 20 if scenario.id == "return_home" else 0
		var critter := {"group": group, "origin": Vector3.ZERO, "heading": 0.3, "speed": 0.21, "activityState": "roaming", "fleeRemaining": 0.0, "recoveryRemaining": 2.0}
		var rng := Random.new()
		rng.state = 991827
		var sample := 0
		for frame in 480:
			var threats: Array = [{"position": Vector3(2, 0, 0)}, {"position": Vector3(40, 0, 0)}] if scenario.id == "threat_recovery" and frame < 30 else []
			Ambient.update_behavior(critter, 1.0 / 60.0, threats, scenario.id == "storm_origin" and frame < 20, rng)
			if sample < scenario.frames.size() and frame == int(scenario.frames[sample].frame):
				var expected: Dictionary = scenario.frames[sample]
				check(Vector2(group.position.x - expected.x, group.position.z - expected.z).length() < 0.0002, "Source ambient position %s frame%d" % [scenario.id, frame])
				check(absf(critter.heading - expected.heading) < 0.0002 and critter.activityState == expected.state, "Source ambient heading/state")
				check(absf(critter.fleeRemaining - expected.flee) < 0.00001 and absf(critter.recoveryRemaining - expected.recovery) < 0.00001, "Source flee/recover timer")
				sample += 1
		group.free()
	preload("res://app/input_actions.gd").register()
	var arena := preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	var vehicle := preload("res://modules/caravan/vehicle_controller.gd").new()
	root.add_child(vehicle)
	var combat := preload("res://modules/combat/combat_runtime.gd").new()
	root.add_child(combat)
	combat.setup(vehicle)
	var world := preload("res://modules/world/world_runtime.gd").new()
	root.add_child(world)
	world.setup(arena, combat, vehicle)
	var village: Dictionary = arena.world_layout.villages[0]
	vehicle.position = Vector3(village.x, 0, village.z)
	vehicle.motion.speed = 2.2
	world._consume_nearby_village()
	check(not village.consumed, "Source tribute requires speed above2.2")
	vehicle.motion.speed = 2.21
	world._consume_nearby_village()
	check(village.consumed and not village.intact and combat.model.pickups.size() == 5, "Driving through settlement scatters exactly5tribute drops")
	check(not world.activities.village_eligible(village.id), "Consumed settlement loses extraction/activity eligibility")
	check(not world.consume_village(village) and combat.model.pickups.size() == 5, "Tribute cannot duplicate")
	check(world.props.events.is_empty(), "Village tribute bypasses individual prop salvage")
	world.reset_run()
	check(not village.consumed and village.intact and world.activities.village_eligible(village.id), "Reset restores settlement and colliders")
	print("Ambient and tribute: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

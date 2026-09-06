extends SceneTree
const World = preload("res://modules/world/world_runtime.gd")
const Vehicle = preload("res://modules/caravan/vehicle_controller.gd")
const Combat = preload("res://modules/combat/combat_runtime.gd")
const Rules = preload("res://modules/world/activities/extraction_rules.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	_test_vegetation_clearance()
	preload("res://app/input_actions.gd").register()
	var arena := preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	var vehicle := Vehicle.new()
	root.add_child(vehicle)
	vehicle.set_driving_enabled(false)
	var combat := Combat.new()
	root.add_child(combat)
	combat.setup(vehicle)
	var world := World.new()
	root.add_child(world)
	world.setup(arena, combat, vehicle)
	world.set_running(true)
	combat.set_running(true)
	for node: Node in [world, combat, vehicle]:
		node.set_physics_process(false)
	var activities: RefCounted = world.activities
	var first: Array = activities.get_extraction_state().sites
	check(first.size() == 3, "Every run exposes three extraction zones immediately")
	check(activities.get_extraction_state().visible and activities.get_extraction_state().required_credits == 0, "Extraction is visible before completing any task")
	activities.reset(72841)
	check(first == activities.get_extraction_state().sites, "Same seed and terrain produce stable independent zones")
	world.foundries.step(0.0)
	for site: Dictionary in first:
		check(world.props.is_clear(site.position, site.radius), "Full extraction disk remains clear after fort generation")
		check(site.position.length() >= 100.0 and site.position.length() <= 480.0, "Zones remain within the reachable central arena")
	vehicle.global_position = first[0].position
	vehicle.motion.speed = 8.0
	check(activities.credits == 0 and world.interact(), "E starts extraction while moving without credits or quests")
	check(combat.model.player.extraction_active and activities.extraction.spawned == 3, "Activation starts real defenders and exposes active combat guard")
	check(not world.interact(), "Repeated E cannot restart timer or spawn another opening wave")
	var defenders: Array = combat.model.enemies.filter(func(enemy: Dictionary) -> bool: return enemy.get("extraction_defender", false))
	for enemy: Dictionary in defenders:
		check(enemy.position.distance_to(first[0].position) > first[0].radius and not enemy.counts_toward_wave, "Defenders start outside the circle and do not belong to ordinary waves")
	var village: Dictionary = arena.world_layout.villages[0]
	for prop: Dictionary in activities._village_props.get(village.id, []):
		world.props.destroy(prop)
	check(not activities.village_eligible(village.id), "Test destroys a real settlement")
	activities._update_extraction(5.0)
	check(activities.extraction.progress == 5.0 and activities.extraction.hostile_count > 0 and activities.extraction.spawned == 6, "Twenty-second defense advances with enemies nearby and deploys timed reinforcements")
	check(activities.get_extraction_state().sites == first, "Destroyed villages do not invalidate any extraction zone")
	vehicle.global_position += Vector3(25, 0, 0)
	activities._update_extraction(2.0)
	check(activities.extraction.active and activities.extraction.progress == 5.0 and activities.get_extraction_state().mode == "leaving", "Leaving pauses timer and gives a three-second return grace")
	vehicle.global_position = first[0].position
	activities._update_extraction(1.0)
	check(activities.extraction.progress == 6.0 and activities.extraction.out_of_range == 0.0, "Reentering resumes defense and clears leave grace")
	vehicle.global_position += Vector3(25, 0, 0)
	activities._update_extraction(3.0)
	check(not activities.extraction.active and not combat.model.player.extraction_active, "Three seconds outside cancels defense and releases wave guard")
	vehicle.global_position = first[0].position
	for index in 8:
		check(world.interact(), "Canceled defense can be activated again")
		activities.cancel_extraction("test retry")
	var living: Array = combat.model.enemies.filter(func(enemy: Dictionary) -> bool: return not enemy.dead and enemy.get("extraction_defender", false))
	check(living.size() <= 10, "Repeated activation cannot grow live extraction attackers beyond ten")
	for enemy: Dictionary in living:
		combat.model.kill_enemy(enemy)
	check(world.interact() and activities.extraction.spawned == 3, "A fresh attempt sends new attackers after previous ones are defeated")
	combat.model.player.hp = 0.0
	activities._update_extraction(20.0)
	check(not activities.extraction.active and combat.model.status != "extracted", "A dead player cannot complete extraction even on final tick")
	combat.model.player.hp = 200.0
	vehicle.health = 200.0
	check(world.interact(), "A living controlled scenario can start a new defense")
	activities._update_extraction(19.5)
	check(activities.extraction.active and is_equal_approx(activities.get_extraction_state().remaining_seconds, 0.5), "Extraction cannot finish before twenty in-zone seconds")
	activities._update_extraction(0.5)
	check(combat.model.status == "extracted" and not world.running and not combat.model.player.extraction_active, "Twenty seconds alive inside finishes the real combat runtime as extracted")
	for seed_value: int in [1, 42, 72841]:
		var generated: RefCounted = preload("res://modules/world/generation/world_generator.gd").generate(seed_value, preload("res://modules/world/generation/authored_props.gd").new())
		var view := preload("res://presentation/world/generated_world_view.gd").new()
		var layout: Dictionary = view.build(generated)
		var props := preload("res://modules/world/prop_system.gd").new()
		props.setup(layout)
		preload("res://modules/caravan/terrain_surface.gd").configure(layout, generated.layout.roads)
		var sites: Array = preload("res://modules/world/activities/extraction_sites.gd").generate(layout, props, seed_value)
		check(sites.size() == 3, "Generated seed %d has all three extraction zones" % seed_value)
		for site: Dictionary in sites:
			check(props.is_clear(site.position, 20.0), "Generated seed %d has a clear full defense disk" % seed_value)
			var clear_of_trees := true
			for prop: Dictionary in props.records.values():
				if prop.kind in ["tree", "deadTree"] and not prop.destroyed:
					var offset: Vector3 = prop.position - site.position
					if Vector2(offset.x, offset.z).length() < float(prop.radius) + 20.0:
						clear_of_trees = false
			check(clear_of_trees, "Generated seed %d leaves the full defense disk free of dense vegetation" % seed_value)
			for other: Dictionary in sites:
				if other.id != site.id:
					check(site.position.distance_to(other.position) >= 120.0, "Generated extraction zones are separated")
		check(sites == preload("res://modules/world/activities/extraction_sites.gd").generate(layout, props, seed_value), "Generated zone placement is deterministic")
		view.free()
	world.queue_free()
	combat.queue_free()
	vehicle.queue_free()
	arena.queue_free()
	await process_frame
	print("EXTRACTION_DEFENSE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_vegetation_clearance() -> void:
	var props := preload("res://modules/world/prop_system.gd").new()
	props.setup({"props": [{"id": "tree-probe", "kind": "tree", "position": {"x": 0, "z": 0}, "radius": 1.0, "hp": 28.0, "solid": false}], "rockObstacles": []})
	var sites = preload("res://modules/world/activities/extraction_sites.gd")
	check(props.is_clear(Vector3.ZERO, 18.0) and not sites._clear(props, Vector3.ZERO), "Extraction circles exclude tree trunks even when normal movement can break through them")
	check(not sites._access_clear(props, Vector3(-5, 0, 0), Vector3(5, 0, 0)), "Extraction approach corridors stay clear of living trees")
	props.records["tree-probe"].kind = "deadTree"
	check(not sites._clear(props, Vector3.ZERO) and not sites._access_clear(props, Vector3(-5, 0, 0), Vector3(5, 0, 0)), "Dead-tree trunks also block selecting a defense clearing")
	props.records["tree-probe"].destroyed = true
	check(sites._clear(props, Vector3.ZERO) and sites._access_clear(props, Vector3(-5, 0, 0), Vector3(5, 0, 0)), "Destroyed vegetation no longer blocks a cleared extraction approach")

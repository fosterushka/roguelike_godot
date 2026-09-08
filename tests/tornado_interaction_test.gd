extends SceneTree
const Policy = preload("res://modules/world/destruction_policy.gd")
const Damage = preload("res://modules/world/damage_context.gd")
const Air = preload("res://modules/world/airborne_motion.gd")
const Ground = preload("res://modules/caravan/terrain_surface.gd")
const Fuel = preload("res://modules/caravan/vehicle_fuel.gd")
const Roads = preload("res://modules/world/road_surface.gd")
var checks := 0
var failures := 0
var world: Node3D
var arena: Node3D
var vehicle: CharacterBody3D
var combat: Node3D

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	preload("res://app/input_actions.gd").register()
	arena = preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	vehicle = preload("res://modules/caravan/vehicle_controller.gd").new()
	root.add_child(vehicle)
	vehicle.set_physics_process(false)
	combat = preload("res://modules/combat/combat_runtime.gd").new()
	root.add_child(combat)
	combat.setup(vehicle)
	combat.set_physics_process(false)
	world = preload("res://modules/world/world_runtime.gd").new()
	root.add_child(world)
	world.setup(arena, combat, vehicle)
	world.set_physics_process(false)
	world.set_running(true)
	combat.set_running(true)
	_test_tree_fall()
	_test_prop_flight()
	_test_tree_landing()
	_test_npc_flight()
	_test_natural_activities()
	_test_player_entry()
	_test_vehicle_effects()
	_test_timestep()
	var original_records: int = world.props.records.size()
	var original_rewards: int = combat.model.pickups.size()
	world.set_warmup_visible(true)
	check(not world.prop_motion_view._warmup_nodes.is_empty(), "Loading prepares actual whole-prop mesh instances and stump material")
	world.set_warmup_visible(false)
	check(world.prop_motion_view._warmup_nodes.is_empty() and world.props.records.size() == original_records and combat.model.pickups.size() == original_rewards, "Visual warmup clears temporary objects without altering gameplay or rewards")
	var captured: Dictionary = combat.model.spawn_enemy("rifleman", world.tornado.position)
	world._update_tornado(1.0 / 60.0)
	check(captured.get("airborne", false) and captured.get("lift_height", -1.0) == 0.0, "Fresh capture begins at ground level before lifting")
	world.reset_run()
	check(not captured.get("airborne", false), "Reset releases NPC even on the exact zero-height capture frame")
	check(world.tornado_interaction.prop_flights.is_empty() and world.tornado_interaction.actor_flights.is_empty() and world.prop_motion_view.moving.is_empty() and world.prop_motion_view.stumps.is_empty(), "Reset clears every flight, fallen tree and stump visual")
	check(vehicle.tornado_effect.is_empty(), "Reset removes player force, lift, slowdown and roll")
	check(world.prop_motion_view._free_visuals.size() == world.prop_motion_view.LIMIT, "Reset returns every reusable whole-prop visual to its bounded pool")
	for node: Node in [world, combat, vehicle, arena]:
		node.queue_free()
	await process_frame
	print("TORNADO_INTERACTION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_tree_fall() -> void:
	var trees: Array = world.props.records.values().filter(func(prop: Dictionary) -> bool: return prop.kind == "tree" and Policy.leaves_stump(prop))
	check(not trees.is_empty(), "Real trees include deterministic stump outcomes")
	var tree: Dictionary = trees[0]
	for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		world.props.destroy(tree, 1.0, Damage.create("collision", direction, "player"))
		world._flush_prop_events()
		world.prop_motion_view.step(0.6, {})
		var visual: Node3D = world.prop_motion_view.moving[tree.id].node
		check((visual.basis * Vector3.UP).dot(direction) > 0.2, "Fallen tree rotates around trunk base in actual impact direction")
		check(visual.position.is_equal_approx(world.prop_motion_view.moving[tree.id].base), "Falling tree base never slides away from impact point")
		var stump_id: String = str(tree.id) + ":stump"
		check(world.props.records.has(stump_id) and world.prop_motion_view.stumps.has(stump_id), "Selected ordinary fall creates a visible damageable stump")
		world.damage_props(tree.position, 1.0, 1.0, Damage.create("explosion"))
		check(world.props.records[stump_id].destroyed and not world.prop_motion_view.stumps.has(stump_id), "Even a weak intersecting explosion removes the stump fully")
		check(not world.prop_motion_view.moving.has(tree.id), "Explosion also clears the already fallen tree mesh")
		world.reset_run()
	vehicle.motion.move_heading = 0.0
	vehicle.motion.speed = -6.0
	check(world._impact_direction().dot(Vector3.FORWARD) > 0.99, "Reverse driving produces reverse tree-fall direction")
	world.damage_props(tree.position, 0.1, 9999.0, Damage.create("explosion"))
	check(tree.destroyed and not world.props.records.has(str(tree.id) + ":stump") and not world.prop_motion_view.moving.has(tree.id), "Direct explosion shatters standing tree without a stump or fall animation")
	world.reset_run()

func _test_prop_flight() -> void:
	var prop: Dictionary = world.props.records.values().filter(func(item: Dictionary) -> bool: return item.solid and item.kind == "well")[0]
	var original: Vector3 = prop.position
	var body: StaticBody3D = arena._prop_colliders[prop.id]
	var body_origin: Vector3 = body.position
	var rewards: int = combat.model.pickups.size()
	check(world.props.lift(prop), "A whole prop can enter flight")
	world._flush_prop_events()
	check(body.collision_layer == 0 and not world.props.grid.nearby(original, 1.0).has(prop), "Lift removes both physical collider and spatial entry at old position")
	check(world.prop_motion_view.moving.has(prop.id), "Lift renders the actual prop geometry as a moving whole")
	var destination := original + Vector3(90, 0, 30)
	world.props.land(prop, destination, 11.0)
	world._flush_prop_events()
	check(not prop.destroyed and prop.hp < prop.max_hp and prop.position == destination, "Healthy thrown prop survives impact with damage at the landing point")
	check(body.collision_layer == 1 and is_equal_approx(body.position.x - body_origin.x, 90.0), "Landing restores physical collider at the new location")
	check(not world.props.grid.nearby(original, 1).has(prop) and world.props.grid.nearby(destination, 1).has(prop), "Landing updates spatial index without a ghost wall")
	check(not world.prop_motion_view.moving.has(prop.id) and combat.model.pickups.size() == rewards, "Landing releases moving visual and grants no free salvage")
	world.reset_run()
	check(prop.position == original and body.position.is_equal_approx(body_origin), "Reset restores moved prop and collider to original map location")
	var launched := 0
	var shattered := 0
	world.tornado.intensity = 1.0
	for tree: Dictionary in world.props.records.values():
		if tree.kind != "tree" or not Policy.can_throw(tree):
			continue
		world.tornado.position = tree.position
		world.tornado_interaction.step(world, 1.0 / 60.0)
		world._flush_prop_events()
		launched += int(tree.get("airborne", false))
		shattered += int(tree.destroyed)
		if launched >= 2 and shattered >= 2:
			break
	check(launched >= 2 and shattered >= 2, "Real tornado captures demonstrate both fixed launch and shatter outcomes")
	check(combat.model.pickups.size() == rewards, "Natural shatter never awards salvage")
	world.reset_run()

func _test_tree_landing() -> void:
	var tree: Dictionary = world.props.records.values().filter(func(prop: Dictionary) -> bool: return prop.kind == "tree")[0]
	var original: Vector3 = tree.position
	var destination := original + Vector3(40, 0, 20)
	var rewards: int = combat.model.pickups.size()
	world.props.lift(tree)
	world._flush_prop_events()
	world.prop_motion_view.step(0.1, {str(tree.id): {"position": destination + Vector3.UP, "roll": 0.7}})
	var airborne: Node3D = world.prop_motion_view.moving[tree.id].node
	var rotation: Quaternion = airborne.quaternion
	world.props.land(tree, destination, 1.0)
	world._flush_prop_events()
	check(tree.destroyed and not tree.airborne and tree.hp == 0.0, "Even a gentle tornado tree landing remains destroyed")
	check(not world.props.grid.nearby(destination, 1).has(tree), "Fallen tree never becomes an upright obstacle again")
	check(world.prop_motion_view.moving[tree.id].node == airborne and airborne.quaternion.is_equal_approx(rotation), "Landing retains airborne visual and rotation without upright reset")
	for frame in 360:
		world.prop_motion_view.step(1.0 / 60.0, {})
	check(absf((airborne.basis * Vector3.UP).y) < 0.12 and airborne.position.distance_to(destination) > 0.5, "Tree tumbles onto its side and slides after landing")
	check(combat.model.pickups.size() == rewards, "Weather landing grants no player salvage")
	world.prop_motion_view.step(15.0, {})
	check(not world.prop_motion_view.moving.has(tree.id), "Settled debris returns to bounded pool")
	world.reset_run()
	check(not tree.destroyed and tree.position == original, "New run restores thrown tree at original position")


func _test_npc_flight() -> void:
	combat.model.enemies.clear()
	combat.model.events.clear()
	world.tornado.intensity = 1.0
	world.tornado.position = Vector3.ZERO
	var soldier: Dictionary = combat.model.spawn_enemy("rifleman", Vector3.RIGHT)
	var survivor: Dictionary = combat.model.spawn_enemy("repairCrawler", Vector3.LEFT)
	survivor.activity_route_controlled = true
	var hp: float = combat.model.player.hp
	var kills: int = combat.model.player.kills
	combat.model.player.damage_mult = 100.0
	world._update_tornado(1.0 / 60.0)
	check(soldier.airborne and not soldier.dead and soldier.hp == soldier.max_hp, "Core captures NPC alive without instant damage or kill")
	for frame in 30:
		world._update_tornado(1.0 / 60.0)
		combat.model._update_enemies(1.0 / 60.0)
	check(soldier.lift_height > 2.0 and not soldier.dead, "NPC visibly rises before any landing damage")
	check(combat.model.player.hp == hp and combat.model.projectiles.is_empty(), "Flying NPC cannot ram or shoot the player")
	var rendered: Dictionary = preload("res://presentation/combat/enemy_animation.gd").advance(soldier, {}, 0.0, 0.0)
	check(rendered.position.y > Ground.height_at(soldier.position.x, soldier.position.z) + 2.0, "Actual NPC animation preserves flight height")
	check(combat.model._aim_center(soldier).y > Ground.height_at(soldier.position.x, soldier.position.z) + 3.0, "Projectile aim center follows airborne NPC")
	for frame in 240:
		world._update_tornado(1.0 / 60.0)
	check(soldier.dead and not soldier.airborne, "Fragile NPC dies only after full throw and landing")
	check(not survivor.dead and survivor.hp < survivor.max_hp, "Heavier NPC survives landing without player's100x damage multiplier")
	check(combat.model.player.kills == kills and combat.model.events.any(func(event: Dictionary) -> bool: return event.kind == "death" and event.get("cause", "") == "tornado_landing" and not event.get("rewarded", true)), "Landing death retains natural cause and grants no kill credit")
	check(absf(survivor.get("tornado_offset_x", 0)) + absf(survivor.get("tornado_offset_z", 0)) > 1, "Route-controlled NPC retains thrown displacement for smooth route recovery")
	world.reset_run()
	combat.model.enemies.clear()
	combat.model.player.damage_mult = 1.0

func _test_player_entry() -> void:
	vehicle.position = Vector3.ZERO
	world.tornado.intensity = 1.0
	world.tornado.position = Vector3(1, 0, 0)
	world._update_tornado(1.0 / 60.0)
	var state: Dictionary = world.tornado_interaction.player_state
	var chosen: String = state.mode
	check(chosen in ["shove", "slow"] and state.entry == 1 and state.blend < 0.1, "Player receives one mode with gradual initial influence")
	for frame in 60:
		world._update_tornado(1.0 / 60.0)
	check(state.mode == chosen and state.entry == 1 and state.blend > 0.8, "Player mode stays fixed while strength smoothly increases")
	world.tornado.position = Vector3(16.9, 0, 0)
	world._update_tornado(0.2)
	world.tornado.position = Vector3(1, 0, 0)
	world._update_tornado(0.2)
	check(state.mode == chosen and state.entry == 1, "Short edge excursions cannot reroll the effect")
	world.tornado.position = Vector3(100, 0, 0)
	world._update_tornado(0.01)
	check(state.blend > 0.5, "Leaving tornado cannot snap the vehicle effect off")
	for frame in 240:
		world._update_tornado(1.0 / 60.0)
	check(not state.inside and state.blend < 0.001 and Vector3(vehicle.tornado_effect.force).length() < 0.001, "Full exit fades effects and allows the next entry")
	world.tornado.position = Vector3(1, 0, 0)
	world._update_tornado(1.0 / 60.0)
	check(state.entry == 2, "Reentry draws exactly one new outcome")
	var saved: Dictionary = state.duplicate(true)
	paused = true
	world._physics_process(0.0)
	check(state == saved, "Paused zero simulation delta cannot advance tornado")
	paused = false

func _test_timestep() -> void:
	var outcomes: Array = []
	for fps: int in [30, 60, 120]:
		var flight := Air.create(Vector3(2, 0, 0), "repeatable", Vector3.ZERO)
		for frame in fps * 5:
			Air.step(flight, Vector3.ZERO, 1.0 / fps)
			if flight.landed:
				break
		check(flight.landed and flight.age > 1.5, "Every frame rate includes actual airborne time")
		outcomes.append(flight)
	for result: Dictionary in outcomes:
		check(Vector3(result.position).distance_to(outcomes[0].position) < 0.001 and absf(result.impact_speed - outcomes[0].impact_speed) < 0.001, "30/60/120 FPS produce identical throw and landing damage")

func _test_vehicle_effects() -> void:
	for expected: String in ["shove", "slow"]:
		var chosen_seed := 0
		for seed_value in range(1, 100):
			var is_shove := Policy.roll("%d:%d:player:1" % [seed_value, world.weather.phase.index]) < 0.5
			if is_shove == (expected == "shove"):
				chosen_seed = seed_value
				break
		world._seed = chosen_seed
		world.tornado_interaction.reset(vehicle)
		vehicle.reset_vehicle()
		vehicle.position = Vector3.ZERO
		world.tornado.position = Vector3(1, 0, 0)
		world.tornado.intensity = 1.0
		world.tornado.age = 1.0
		for frame in 90:
			world._update_tornado(1.0 / 60.0)
		check(vehicle.tornado_effect.mode == expected, "Deterministic seed selects requested real vehicle effect")
		if expected == "shove":
			var before: Vector3 = vehicle.position
			vehicle._physics_process(1.0 / 60.0)
			check(Vector2(vehicle.position.x - before.x, vehicle.position.z - before.z).length() > 0.03, "Shove actually moves the player through vehicle collision code")
			var pose: Dictionary = vehicle.current_render_pose()
			check(vehicle.position.y > float(vehicle.suspension.height) + 0.3 and absf(pose.wind_roll) > 0.01, "Real player pose contains light lift and visible roll")
			check(pose.suspension.contacts == 0 and absf(preload("res://modules/caravan/vehicle_pose.gd").transform(pose).basis.y.x) > 0.01, "Lift releases wheel contacts and rendered basis includes roll")
		else:
			vehicle.motion.speed = Fuel.maximum_speed(vehicle.fuel, vehicle.player_stats) * Roads.speed_multiplier_at(vehicle.position)
			Input.action_press("drive_forward")
			for frame in 600:
				vehicle._physics_process(1.0 / 60.0)
			Input.action_release("drive_forward")
			var normal_speed := Fuel.maximum_speed(vehicle.fuel, vehicle.player_stats) * Roads.speed_multiplier_at(vehicle.position)
			check(vehicle.motion.speed < normal_speed * 0.6 and vehicle.tornado_effect.force == Vector3.ZERO and vehicle.tornado_effect.lift == 0.0, "Slow mode cuts normal driving speed by at least forty percent without lifting or shoving")

func _test_natural_activities() -> void:
	for participated: bool in [false, true]:
		world.reset_run()
		combat.model.enemies.clear()
		combat.model.events.clear()
		var first: Dictionary = combat.model.spawn_enemy("rifleman", Vector3(180, 0, 0))
		var second: Dictionary = combat.model.spawn_enemy("rifleman", Vector3(182, 0, 0))
		var activity: Dictionary = world.activities.register_dispatch("natural-check", first.position, [first, second])
		var coins: int = combat.model.player.coins
		if participated:
			combat.model.kill_enemy(first)
		else:
			combat.model.damage_enemy_natural(first.id, 999.0, "tornado_landing")
		combat.model.damage_enemy_natural(second.id, 999.0, "tornado_landing")
		world.activities._update(activity, 0.0)
		if participated:
			check(activity.state == "completed" and world.activities.credits == 1, "Mixed combat retains activity reward when player actually helped")
		else:
			check(activity.state == "failed" and world.activities.credits == 0 and combat.model.player.coins == coins, "Entirely natural NPC losses cannot award activity credits or money")
			check(not combat.model.events.any(func(event: Dictionary) -> bool: return event.kind == "activity_completed"), "Natural-only activity creates no mission completion or loot crate")
	world.reset_run()
	combat.model.enemies.clear()

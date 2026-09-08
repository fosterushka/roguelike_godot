extends SceneTree
const World = preload("res://modules/world/world_runtime.gd")
const Extraction = preload("res://modules/world/activities/extraction_rules.gd")
const Rules = preload("res://modules/world/activities/activity_rules.gd")
const BaseDefenseRules = preload("res://modules/world/activities/base_defense_rules.gd")
const EnemyAI = preload("res://modules/combat/enemy_ai.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const Vehicle = preload("res://modules/caravan/vehicle_controller.gd")
const Combat = preload("res://modules/combat/combat_runtime.gd")
var checks := 0
var failures := 0
var results: Array = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	preload("res://app/input_actions.gd").register()
	var arena := preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	var vehicle := Vehicle.new()
	root.add_child(vehicle)
	vehicle.set_driving_enabled(false)
	var combat := Combat.new()
	root.add_child(combat)
	combat.setup(vehicle)
	combat.combat_event.connect(func(event: Dictionary) -> void:
		if event.kind == "result": results.append(event)
	)
	var world := World.new()
	root.add_child(world)
	world.setup(arena, combat, vehicle)
	world.set_running(true)
	var activities: RefCounted = world.activities
	check(activities.next_major >= 9 and activities.next_major <= 14, "firstmajor9to14")
	check(activities.next_minor >= 5 and activities.next_minor <= 9, "firstminor5to9")
	check(absf(activities.next_major - 9.410234484588727) < 0.0000001 and absf(activities.next_minor - 6.388639932498336) < 0.0000001, "sourceLCGseed72841goldentimers")
	check(not arena.world_layout.activityRoutes.is_empty() and arena.world_layout.villages[0].deploymentAnchors.size() == 8, "exactsource routes+village8anchors")
	var route := [{"x": 100.0, "z": 0.0}, {"x": 150.0, "z": 0.0}, {"x": 200.0, "z": 0.0}]
	var major: Dictionary = activities.announce("raiderSupplyConvoy", {"position": Vector3(100, 0, 0), "route": route})
	check(not major.is_empty(), "majorreserved")
	check(activities.announce("settlementDistress", {"position": Vector3(150, 0, 0), "source_id": arena.world_layout.villages[0].id}).is_empty(), "majorcap1")
	var minor: Dictionary = activities.announce("scavengerRoute", {"position": Vector3(100, 0, 0), "route": route})
	check(not minor.is_empty(), "minorreserved")
	check(not activities.announce("scavengerRoute", {"position": Vector3(200, 0, 0), "route": route}).is_empty(), "secondminorreserved")
	check(activities.announce("scavengerRoute", {"position": Vector3(200, 0, 0), "route": route}).is_empty(), "minorcap2")
	var coins: int = combat.model.player.coins
	var xp: float = combat.model.player.xp
	check(activities.finish(major, "completed"), "completionaccepted")
	check(combat.model.player.coins == coins + 18 and combat.model.player.xp == xp + 11 and activities.credits == 1, "convoy18reward11xp1credit")
	check(not activities.finish(major, "completed"), "duplicatecompletionrejected")
	var contract_events := 0
	for event in combat.model.events:
		contract_events += int(event.kind == "activity_completed")
	check(contract_events == 1, "contracteventexactlyonce")
	check(activities.finish(minor, "failed"), "failureaccepted")
	check(combat.model.player.coins == coins + 18, "failuregrantsnoreward")
	check(activities.recovery_until == 10, "source10secondrecovery")
	world.reset_run()
	var expiring: Dictionary = activities.announce("scavengerRoute", {"position": Vector3(100, 0, 0), "route": route})
	activities.elapsed = 82.0
	activities._update(expiring, 0.0)
	check(expiring.state == "expired" and activities.credits == 0, "source82secondexpiry")
	world.reset_run()
	var village: Dictionary = arena.world_layout.villages[0]
	var distress: Dictionary = activities.announce("settlementDistress", {"position": Rules.point(village), "source_id": village.id})
	var village_prop: Dictionary = activities._village_props[village.id][0]
	world.props.destroy(village_prop)
	world._flush_prop_events()
	activities._update(distress, 0.1)
	check(distress.state == "failed", "destroyedvillagedistressfails")
	check(not activities.village_eligible(village.id), "destroyed village is unavailable for settlement activities")
	world.reset_run()
	combat.set_running(true)
	var sites: Array = activities.get_extraction_state().sites
	check(sites.size() == 3, "Three independent extraction zones exist before completing activities")
	var extraction_site: Dictionary = sites[0]
	vehicle.global_position = extraction_site.position
	activities.credits = 0
	vehicle.motion.speed = 1.6
	check(world.interact() and activities.credits == 0, "E inside a zone starts free extraction without settlement or speed requirements")
	check(not world.interact(), "Active extraction cannot start twice")
	vehicle.global_position = activities.extraction.position
	var hostile: Dictionary = combat.model.spawn_enemy("rifleman", vehicle.global_position + Vector3(15, 0, 0))
	activities._update_extraction(5.0)
	check(activities.extraction.progress == 5.0, "Defense countdown continues while enemies attack")
	check(activities.get_extraction_state().hostile_count > 0, "Defense state reports nearby attackers")
	hostile.dead = true
	activities._update_extraction(5.0)
	check(activities.extraction.progress == 10.0, "Remaining inside advances the defense timer")
	vehicle.global_position += Vector3(Extraction.ZONE_RADIUS + 2.0, 0, 0)
	activities._update_extraction(1.0)
	check(activities.extraction.active and activities.extraction.out_of_range == 1.0 and activities.extraction.progress == 10.0, "Leaving pauses the timer during grace period")
	activities._update_extraction(Extraction.LEAVE_GRACE - 1.0)
	check(not activities.extraction.active and activities.credits == 0, "Leaving for three seconds cancels extraction")
	vehicle.global_position = extraction_site.position
	check(world.interact(), "The independent extraction zone allows another attempt")
	activities._update_extraction(Extraction.SECURE_SECONDS)
	check(combat.model.status == "extracted" and not combat.model.running and vehicle.health > 0, "Surviving twenty seconds in the zone extracts alive")
	check(results.size() == 1 and results[0].get("extracted", false) and not results[0].won, "Extraction is one distinct non-victory outcome")
	combat.reset_run()
	world.reset_run()
	world.set_running(true)
	vehicle.global_position = Vector3.ZERO
	var drop: Dictionary = world.support.spawn_airdrop(Vector3.ZERO)
	world.support._update_airdrops(3.0)
	check(drop.landed, "airdropgravitylands")
	coins = combat.model.player.coins
	world.support._update_airdrops(0.0)
	check(world.support.airdrops.is_empty() and combat.model.player.coins == coins + 28, "airdrop28salvageatlevel1")
	world.support._update_airdrops(0.0)
	check(combat.model.player.coins == coins + 28, "airdroprewardonce")
	vehicle.health = 20.0
	var cart: Dictionary = world.support.spawn_healer(Vector3.ZERO)
	world.support._update_healers(0.0)
	check(cart.claimed and vehicle.health == 115.0, "rescue90plus5levelheal")
	world.support._update_healers(0.0)
	check(vehicle.health == 115.0, "rescuehealsonce")
	var history: Dictionary = activities.announce("scavengerRoute", {"position": Vector3(100, 0, 0), "route": route})
	var elapsed: float = activities.elapsed
	var seq: int = activities.next_sequence
	world.set_warmup_visible(true)
	world.set_warmup_visible(false)
	check(activities.elapsed == elapsed and activities.next_sequence == seq and history.state == "announced", "activitywarmupinert")
	combat.model.running = true
	root.get_tree().paused = true
	await physics_frame
	await physics_frame
	check(activities.elapsed == elapsed, "pausedruntimeclockfrozen")
	root.get_tree().paused = false
	combat.model.running = false
	var node_count := world.get_child_count()
	for index in 4:
		world.reset_run()
	check(activities.records.is_empty() and activities.participants.is_empty() and activities.credits == 0 and world.support.airdrops.is_empty(), "resetclearsactivityactorsandrewards")
	check(world.get_child_count() == node_count, "repeatresetnodecountbounded")
	combat.reset_run()
	world.reset_run()
	vehicle.global_position = Vector3.ZERO
	var convoy: Dictionary = activities.request("raiderSupplyConvoy")
	check(not convoy.is_empty(), "sourceconvoyrouteavailable")
	activities.elapsed = 3.0
	activities._update(convoy, 0.0)
	check(convoy.state == "active" and convoy.participant_ids.size() == 2, "convoyatomicallyspawnsbuggybike")
	var convoy_positions: Array = []
	for id in convoy.participant_ids:
		var enemy: Dictionary = activities.participants[id]
		check(enemy.activity_route_controlled and not enemy.counts_toward_wave, "convoyownednonwaveactors")
		convoy_positions.append(enemy.position)
	activities._update(convoy, 1.0)
	check(convoy.route_progress == 11.2, "convoysource6point2speed")
	for id in convoy.participant_ids:
		combat.model.kill_enemy(activities.participants[id])
	activities._update(convoy, 0.0)
	check(convoy.state == "completed" and activities.credits == 1, "destroyingconvoycompletescontract")
	combat.reset_run()
	world.reset_run()
	vehicle.global_position = Vector3.ZERO
	var rescue: Dictionary = activities.request("settlementDistress")
	check(not rescue.is_empty(), "sourcedistressvillageavailable")
	activities.elapsed = 3.0
	activities._update(rescue, 0.0)
	check(rescue.state == "announced" and rescue.deployment_anchors.size() == 3, "distressreserves3sourceanchors")
	activities.elapsed = 5.1
	activities._update(rescue, 0.0)
	check(rescue.state == "active" and rescue.participant_ids.size() == 3, "distresstelegraphcommits3raiders")
	for id in rescue.participant_ids:
		combat.model.kill_enemy(activities.participants[id])
	activities._update(rescue, 0.0)
	check(rescue.state == "completed", "clearedraiderscompletedistress")
	combat.reset_run()
	world.reset_run()
	world.foundries.step(0.0)
	check(world.foundries.foundries.size() == 10, "tenoriginalfoundrynetwork")
	check(world.props.dynamic_solids.size() == 10, "foundrysolidsbounded10")
	for source in world.foundries.foundries:
		check(not source.enemy.counts_toward_wave and source.enemy.hp == source.enemy.max_hp and source.enemy.max_hp > 0.0, "sourcefoundryhpandnonwaveownership")
	var foundry: Dictionary = world.foundries.foundries[0]
	var collider: StaticBody3D = world.foundries.colliders[foundry.index]
	var collider_shape: BoxShape3D = collider.get_child(0).shape
	check(collider_shape.size.is_equal_approx(foundry.enemy.hitbox_size) and is_equal_approx(foundry.solid.height, foundry.enemy.height) and is_equal_approx(collider.rotation.y, foundry.enemy.yaw) and is_equal_approx(collider.position.y, Terrain.height_at(foundry.enemy.position.x, foundry.enemy.position.z) + foundry.enemy.height * 0.5), "foundrycolliderusesauthoredcombatdimensions")
	var defenders_before := 0
	var defender_ids_before: Dictionary = {}
	for enemy: Dictionary in combat.model.enemies:
		defenders_before += int(enemy.get("source_id", -1) == foundry.enemy.id and not enemy.dead)
		defender_ids_before[enemy.id] = true
	var base_yaw: float = float(foundry.enemy.yaw)
	combat.model.damage_enemy(foundry.enemy.id, BaseDefenseRules.damage_threshold(foundry.enemy.max_hp))
	world.foundries.step(0.0)
	activities.elapsed += BaseDefenseRules.EXIT_SPACING * float(BaseDefenseRules.defender_count(foundry.enemy.tier) - 1) + 0.01
	world.foundries.step(0.0)
	var defenders_after := 0
	var exits_from_gate := true
	for enemy: Dictionary in combat.model.enemies:
		if enemy.get("source_id", -1) == foundry.enemy.id and not enemy.dead:
			defenders_after += 1
			if not defender_ids_before.has(enemy.id):
				var starts_at_door: bool = enemy.position.distance_to(Vector3(enemy.spawn_start)) < 0.001 and enemy.position.distance_to(foundry.enemy.position) < foundry.enemy.radius
				EnemyAI.move(combat.model, enemy, BaseDefenseRules.DEPLOY_DURATION, enemy.speed, 0.0, Vector3.ZERO)
				exits_from_gate = exits_from_gate and starts_at_door and enemy.position.distance_to(foundry.enemy.position) > foundry.enemy.radius + BaseDefenseRules.DEFENDER_RADIUS and is_equal_approx(wrapf(enemy.yaw - foundry.gate_yaw, -PI, PI), 0.0) and world.props.is_clear(enemy.position, BaseDefenseRules.DEFENDER_RADIUS)
	check(defenders_after == defenders_before + BaseDefenseRules.defender_count(foundry.enemy.tier) and exits_from_gate and is_equal_approx(foundry.enemy.yaw, base_yaw), "attackedfoundryreleasesstablefixedgatewave")
	var pickups_before: int = combat.model.pickups.size()
	combat.model.kill_enemy(foundry.enemy)
	world.foundries.step(0.0)
	check(combat.model.pickups.size() == pickups_before + 4 + foundry.enemy.tier, "sourcefoundrysalvagedrops")
	check(world.foundries.colliders[foundry.index].collision_layer == 0 and foundry.solid.destroyed, "deadfoundryremovesallcollision")
	combat.reset_run()
	world.reset_run()
	check(world.props.dynamic_solids.is_empty(), "foundryresetclearsvolumes")
	combat.reset_run()
	world.reset_run()
	vehicle.global_position = Vector3.ZERO
	var meeting: Dictionary = activities.announce("scavengerRoute", {"position": Vector3(100, 0, 0), "route": route})
	activities.elapsed = 2.0
	activities._update(meeting, 0.0)
	check(meeting.state == "active", "minorhealerrouteactivates")
	vehicle.global_position = Vector3(100, 0, 0)
	activities._update(meeting, 0.1)
	check(meeting.state == "completed" and activities.credits == 1, "contactscavengerwithin5completes")
	combat.reset_run()
	world.reset_run()
	vehicle.global_position = Vector3.ZERO
	var overflow: Dictionary = activities.request("raiderSupplyConvoy")
	for index in 109:
		combat.model.spawn_enemy("rifleman", Vector3(500, 0, 500))
	var pressure_count: int = combat.model.enemies.size()
	check(pressure_count == 84, "source infantry population cap applies before activity allocation")
	activities.elapsed = 3.0
	# Pressure guard correctly prevents allocating an over-budget convoy before partial commit.
	activities._update(overflow, 0.0)
	check(overflow.state == "announced" and overflow.participant_ids.is_empty() and combat.model.enemies.size() == pressure_count, "pressurecaprejectsconvoywithoutpartialspawn")
	_check_reachable_routes(world, vehicle, combat)
	print("WORLD_ACTIVITIES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check_reachable_routes(world: Node3D, vehicle: Node3D, combat: Node) -> void:
	var activities: RefCounted = world.activities
	var bend := Vector3(55, 0, 0)
	check(Rules.sampled_route([Vector3.ZERO, bend, Vector3(55, 0, 80)]).has(bend), "Road resampling preserves original corners instead of cutting across obstacles")
	var full_radius := Rules.reachable_radius(vehicle.max_fuel, vehicle.player_stats)
	var low_radius := Rules.reachable_radius(40.0, vehicle.player_stats)
	check(full_radius <= Rules.MAX_SPAWN_DISTANCE and low_radius < full_radius, "Activity radius is capped at 700m and shrinks with remaining fuel")
	check(Rules.reachable_radius(0.0, vehicle.player_stats) == 0.0, "An empty tank does not offer unreachable timed travel")
	var heavy_stats := {"weight": 45.0, "fuel_burn_mult": 1.5}
	check(Rules.reachable_radius(40.0, heavy_stats) < Rules.reachable_radius(40.0, {}), "Heavy vehicles and increased burn reduce mission range")
	check(Rules.reachable_radius(40.0, {"fuel_burn_mult": 4.0}) == 0.0, "High fuel burn is measured without clipping to one unit")
	check(activities.register_dispatch("far", vehicle.global_position + Vector3(1000, 0, 0), []).is_empty(), "Foundry registration also rejects distant objectives")
	var original_routes: Array = world.arena.world_layout.activityRoutes
	var origin := Vector3(900, 0, 0)
	combat.reset_run()
	world.reset_run()
	vehicle.global_position = origin
	vehicle.fuel = vehicle.max_fuel
	world.arena.world_layout.activityRoutes = [{"points": [origin + Vector3(100, 0, 0), origin + Vector3(350, 0, 0), origin + Vector3(650, 0, 0)]}]
	var route: Dictionary = activities.request("scavengerRoute")
	check(not route.is_empty(), "A mission can spawn near a player far from the map origin")
	if not route.is_empty():
		var local_route := true
		for point in route.route:
			local_route = local_route and Rules.point(point).distance_to(origin) <= Rules.MAX_SPAWN_DISTANCE
		check(local_route, "The entire moving objective route stays within the player's spawn radius")
		check(route.expires_at - activities.elapsed >= route.encounter_seconds, "Deadline includes driving, completion and arrival buffer")
		check(Rules.route_length(route.route) / route.route_speed >= route.encounter_seconds - 0.01, "Traffic cannot escape before the budgeted arrival and completion window")
		var travel := Rules.travel_seconds(route.position.distance_to(origin), vehicle.fuel, vehicle.player_stats)
		var Fuel = preload("res://modules/caravan/vehicle_fuel.gd")
		var remaining := Fuel.consume(vehicle.fuel, vehicle.max_fuel, Fuel.maximum_speed(vehicle.fuel, vehicle.player_stats), 1.0, travel + Rules.COMPLETION_SECONDS + Rules.ARRIVAL_BUFFER_SECONDS, float(vehicle.player_stats.get("fuel_burn_mult", 1.0)))
		check(remaining >= vehicle.max_fuel * Rules.FUEL_RESERVE_RATIO - 0.01, "Conservative travel and encounter leave the promised fuel reserve")
	combat.reset_run()
	world.reset_run()
	vehicle.global_position = origin
	vehicle.fuel = 0.0
	check(activities.request("scavengerRoute").is_empty(), "Zero-fuel requests skip distant road missions")
	world.arena.world_layout.activityRoutes = original_routes

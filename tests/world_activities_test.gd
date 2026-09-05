extends SceneTree
const World = preload("res://modules/world/world_runtime.gd")
const Extraction = preload("res://modules/world/activities/extraction_rules.gd")
const Rules = preload("res://modules/world/activities/activity_rules.gd")
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
	check(not activities.village_eligible(village.id), "destroyedvillagecannotextract")
	world.reset_run()
	var extraction_site: Dictionary = {}
	for candidate: Dictionary in arena.world_layout.villages:
		vehicle.global_position = Rules.point(candidate)
		var site: Dictionary = activities._nearest_site()
		if not site.is_empty() and not site.anchor.is_empty():
			extraction_site = site
			break
	check(not extraction_site.is_empty(), "sourceclear extractionanchor")
	activities.credits = 2
	vehicle.motion.speed = 1.6
	check(not world.interact(), "extractionrejectsmovingfast")
	vehicle.motion.speed = 0.0
	check(world.interact() and activities.credits == 0, "extractEconsumes2credits")
	check(not world.interact(), "activeextractcannotdoublecharge")
	vehicle.global_position = activities.extraction.position
	var hostile: Dictionary = combat.model.spawn_enemy("rifleman", vehicle.global_position + Vector3(15, 0, 0))
	activities._update_extraction(5.0)
	check(activities.extraction.contested and activities.extraction.progress == 0, "hostilewithin28pausesprogress")
	hostile.dead = true
	activities._update_extraction(10.0)
	check(activities.extraction.progress == 10, "uncontestedholdadvances")
	vehicle.global_position += Vector3(13, 0, 0)
	activities._update_extraction(1.0)
	check(activities.extraction.active and activities.extraction.out_of_range == 1, "leavegracefirstsecond")
	activities._update_extraction(1.0)
	check(not activities.extraction.active and activities.credits == 0, "leave2secondsabandonswithoutrefund")
	vehicle.global_position = Rules.point(extraction_site.village)
	activities.credits = 2
	check(world.interact(), "extractioncanretrynewcredits")
	vehicle.global_position = activities.extraction.position
	activities._update_extraction(30.0)
	check(combat.model.status == "extracted" and not combat.model.running and vehicle.health > 0, "30secondextractionendsalive")
	check(results.size() == 1 and results[0].get("extracted", false) and not results[0].won, "extractionisnotvictorycontract")
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
		check(not source.enemy.counts_toward_wave and source.enemy.hp == 260 + source.enemy.tier * 110, "sourcefoundryhpandnonwaveownership")
	var foundry: Dictionary = world.foundries.foundries[0]
	var pickups_before: int = combat.model.pickups.size()
	combat.model.kill_enemy(foundry.enemy)
	world.foundries.step(0.0)
	check(combat.model.pickups.size() == pickups_before + 4 + foundry.enemy.tier, "sourcefoundrysalvagedrops")
	check(world.foundries.colliders[foundry.index].collision_layer == 0 and foundry.solid.destroyed, "deadfoundryremovesallcollision")
	combat.reset_run()
	world.reset_run()
	check(world.props.dynamic_solids.is_empty() and world.foundries.pending.is_empty(), "foundryresetclearsvolumesandtelegraphs")
	world.foundries.step(0.0)
	var dispatch_source: Dictionary = world.foundries.foundries[0]
	vehicle.global_position = dispatch_source.enemy.position + Vector3(35, 0, 0)
	dispatch_source.cooldown = 0.0
	world.foundries.step(2.0)
	check(world.foundries.pending.is_empty(), "Managed source waves do not run legacy foundry reinforcement director")
	world.foundries._step_legacy_dispatch(2.0)
	check(world.foundries.pending.size() == 1, "Dormant legacy rules remain directly testable")
	var deployment: Dictionary = world.foundries.pending[0]
	check(not deployment.record.is_empty() and deployment.record.state == "announced", "dispatchcontractannouncedbeforecommit")
	activities.elapsed = 3.0
	world.foundries._step_legacy_dispatch(0.0)
	check(world.foundries.pending.is_empty() and deployment.record.state == "active", "foundrytelegraphcommitsparticipant")
	for id in deployment.record.participant_ids:
		combat.model.kill_enemy(activities.participants[id])
	activities._update(deployment.record, 0.0)
	check(deployment.record.state == "completed" and activities.credits == 1, "foundrydispatchrewardcontract")
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
	print("WORLD_ACTIVITIES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

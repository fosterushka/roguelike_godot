extends SceneTree

const Model = preload("res://modules/combat/combat_model.gd")
const Protocols = preload("res://modules/combat/protocol_rules.gd")
const Sidegrades = preload("res://modules/combat/sidegrade_rules.gd")
const Rockets = preload("res://modules/combat/rocket_rules.gd")
const Fury = preload("res://modules/combat/road_fury_rules.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func close(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.00001, "%s: %s expected %s" % [label, actual, expected])

func fresh():
	var model = Model.new()
	model.spawn_queue.clear()
	model.running = true
	model.weapons.clear()
	return model

func target(model, position := Vector3(0, 0, 20)) -> Dictionary:
	var enemy: Dictionary = model.spawn_enemy("buggy", position)
	enemy.hp = 1000.0
	enemy.max_hp = 1000.0
	return enemy

func shot(module_type: String, kind := "bullet") -> Dictionary:
	return {"module_type": module_type, "kind": kind, "team": "player", "damage": 20.0, "position": Vector3.ZERO}

func _initialize() -> void:
	_test_sidegrades()
	_test_protocols()
	_test_projectiles()
	_test_fury()
	_test_mines()
	_test_runtime()
	_test_activity_contract()
	_test_nearest_collision()
	_test_external_finish()
	print("Advanced combat tests: %s/%s passed" % [checks - failures, checks])
	quit(1 if failures else 0)

func _test_sidegrades() -> void:
	var model = fresh()
	for type: String in ["grenadeLauncher", "railgun", "assaultRifle", "missileRack"]:
		model.install_weapon(type)
	model.player.selected_sidegrades = {"grenadeLauncher": "fragmentation-shells", "railgun": "penetrator-sabots", "assaultRifle": "concussion-rounds", "missileRack": "tracking-rockets"}
	var grenade := Sidegrades.tuning(model.player, model.weapons[0])
	close(grenade.range, 44.0 * 0.82, "fragmentation range")
	close(grenade.splash_multiplier, 1.3, "fragmentation radius")
	var rail := Sidegrades.tuning(model.player, model.weapons[1])
	close(rail.damage, 76.0 * 0.8, "penetrator damage")
	check(rail.pierce == 1, "penetrator extra target")
	var rifle := Sidegrades.tuning(model.player, model.weapons[2])
	close(rifle.damage, 9.0 * 0.82, "concussion damage")
	var enemy := target(model)
	Sidegrades.apply_control(enemy, rifle)
	close(enemy.slow_remaining, 1.5, "concussion duration")
	close(enemy.slow_multiplier, 0.75, "concussion slow")
	Protocols.advance_status(enemy, 1.5)
	close(enemy.slow_multiplier, 1.0, "concussion expiry")
	var drone: Dictionary = model.spawn_enemy("shooter", Vector3(0, 0, 30))
	Sidegrades.apply_control(drone, rifle)
	check(not drone.has("slow_remaining"), "airborne concussion exclusion")
	var missile := Sidegrades.tuning(model.player, model.weapons[3])
	close(missile.range, 56.0 * 1.2, "tracking acquisition")
	close(missile.damage, 60.0 * 0.85, "tracking damage tradeoff")
	model.player.selected_sidegrades.assaultRifle = "tracking-rockets"
	close(Sidegrades.tuning(model.player, model.weapons[2]).damage, 9.0, "wrong bucket ignored")

func _test_protocols() -> void:
	var model = fresh()
	model.player.active_protocols = ["breachCrew", "targetRelay", "suppressionCycle", "combinedFeed", "salvageLoop", "stormConductor"]
	var enemy := target(model)
	enemy.type = "keep"
	model.player.ram_timer = 0.9
	Protocols.ram(model.player, enemy, 1.0)
	close(enemy.breached_until, 7.0, "charged ram breach duration")
	Protocols.mark_focus(model.player, enemy, 1.0)
	close(enemy.relay_until, 9.0, "focus mark duration")
	close(model.protocols.hit(model.player, enemy, shot("missileRack", "rocket"), 2.0, true), 1.75, "breach+relay add, not multiply")
	close(model.protocols.hit(model.player, enemy, shot("missileRack", "rocket"), 2.0, true), 1.0, "marks consumed once")
	Protocols.mark_focus(model.player, enemy, 1.0)
	close(model.protocols.hit(model.player, enemy, shot("railgun", "sabot"), 9.0, true), 1.0, "relay expiry boundary")
	enemy.type = "buggy"
	Protocols.ram(model.player, enemy, 10.0)
	close(enemy.breached_until, 0.0, "small npc cannot breach")
	for index in range(7):
		model.protocols.hit(model.player, enemy, shot("assaultRifle"), 12.0, true)
	check(enemy.suppression == 5, "suppression stack cap")
	model.protocols.hit(model.player, enemy, shot("grenadeLauncher", "grenade"), 12.1, true)
	close(enemy.stagger_remaining, 0.65, "suppression interruption")
	check(Protocols.advance_status(enemy, 0.65), "interrupted tick remains skipped")
	check(not Protocols.advance_status(enemy, 0.01), "interruption ends")
	model.protocols.hit(model.player, enemy, shot("assaultRifle"), 20.0, true)
	model.protocols.hit(model.player, enemy, shot("grenadeLauncher", "grenade"), 23.0, true)
	close(enemy.stagger_remaining, 0.0, "expired suppression gives no stagger")
	model.protocols.reset()
	model.install_weapon("assaultRifle")
	model.install_weapon("bazooka")
	model.protocols.hit(model.player, enemy, shot("assaultRifle"), 25.0, true)
	model.protocols.hit(model.player, enemy, shot("bazooka", "rocket"), 28.0, true)
	check(model.protocols.combined_weapon(model.player, model.weapons, 29.0).type == "assaultRifle", "combinedfeed chooses opposite family")
	check(model.protocols.combined_weapon(model.player, model.weapons, 31.0).is_empty(), "combinedfeed expires in3s")
	var bonus := shot("assaultRifle")
	bonus.synergy_eligible = false
	model.protocols.hit(model.player, enemy, bonus, 29.0, true)
	check(model.protocols.last_family == "explosive", "bonus cannot prime itself")
	model.player.hp = 150.0
	model.player.treasury_count = 2
	model.player.coin_mult = 2.0
	close(model.protocols.salvage_multiplier(model.player), 2.0, "salvageloop suppresses treasury")
	model.protocols.collect(model.player, 19.0)
	close(model.player.hp, 150.0, "salvage charge threshold")
	model.protocols.collect(model.player, 1.0)
	close(model.player.hp, 180.0, "salvage heals30")
	close(model.protocols.salvage_charge, 0.0, "salvage pulse consumed")
	model.player.active_protocols.erase("salvageLoop")
	close(model.protocols.salvage_multiplier(model.player), 2.0 * pow(1.15, 2), "treasury multiplicative count")
	enemy.position = Vector3(0, 0, 20)
	enemy.wet_until = 6.0
	enemy.relay_until = 0.0
	var second := target(model, Vector3(0, 0, 28))
	second.wet_until = 6.0
	model.elapsed = 1.0
	model._projectile_damage(enemy, shot("railgun", "sabot"), 100.0, true)
	close(second.hp, 955.0, "conductor 45percent chain")
	second.hp = 1000.0
	second.wet_until = 0.0
	model._projectile_damage(enemy, shot("railgun", "sabot"), 100.0, true)
	close(second.hp, 1000.0, "conductor excludes dry target")
	model.player.hp = 87.4
	model.player.regen_rate = 10.0
	model._tick_abilities(0.1)
	close(model.player.hp, 88.4, "regen crosses35percent threshold as source")

func _test_projectiles() -> void:
	var model = fresh()
	var first := target(model, Vector3(0, 0, 10))
	var second := target(model, Vector3(0, 0, 15))
	var third := target(model, Vector3(0, 0, 20))
	model.fire_projectile("sabot", "player", Vector3(0, 1, 0), Vector3(0, 1, 30), 60.8, first.id, {"module_type": "railgun", "pierce": 1})
	model._update_projectiles(0.3)
	close(first.hp, 939.2, "sabot first victim")
	close(second.hp, 939.2, "sabot extra victim")
	close(third.hp, 1000.0, "sabot stops after2")
	check(model.projectiles.is_empty(), "piercing shot consumed")
	model.player.speed = 0.0
	close(Rockets.spread(model.player), 0.00045, "stationary rocket spread")
	model.player.speed = 9.2
	close(Rockets.spread(model.player), 0.05545, "moving rocket spread")
	model.player.yaw_velocity = 1.36
	model.player.slip_angle = 0.35
	close(Rockets.spread(model.player), 0.09, "rocket maximum spread")
	var profile := Rockets.profile(model.player, "player", 72841)
	check(Rockets.sample(profile, 0.0).is_zero_approx(), "rocket starts at muzzle")
	check(Rockets.sample(profile, 0.2).length() <= 0.38, "corkscrew amplitude bound")
	check(Rockets.sample(profile, 9.0).length() < Rockets.sample(profile, 0.2).length(), "corkscrew decays")
	model.fire_projectile("rocket", "player", Vector3(0, 3, 0), Vector3(0, 3, 40), 20.0)
	var projectile: Dictionary = model.projectiles.back()
	var before: Vector3 = projectile.position
	model._update_projectiles(0.1)
	check(projectile.position != before and projectile.rocket_age == 0.1, "actual rocket moves sampled trajectory")

func _test_fury() -> void:
	var fury = Fury.new()
	for index in range(3):
		fury.record(0.1)
	close(fury.momentum, 0.35, "RoadFury third combo1.5")
	fury.decay(2.0, 0.1)
	close(fury.momentum, 0.35, "RoadFury grace retains")
	fury.decay(2.0, 0.1)
	close(fury.momentum, 0.25, "only time beyondgrace decays")
	check(fury.combo == 0, "combo expires")
	fury.reset()
	var player := {"speed": 7.0, "handbraking": true, "slip_angle": 0.2}
	fury.step(player, 1.0)
	close(fury.momentum, 0.035, "drift rewards per7m")
	var model = fresh()
	model.player.speed = 5.0
	var buggy := target(model, Vector3(0, 0, 2))
	model.road_fury.collide(model, buggy, 2.0, 0.1)
	check(buggy.dead, "source crawler roadkills buggy")
	close(model.road_fury.momentum, 0.1, "roadkill grants RoadFury")
	var keep := target(model, Vector3(0, 0, 3))
	keep.type = "keep"
	model.player.has_bumper = true
	model.player.ram_timer = 0.9
	model.player.active_protocols = ["breachCrew"]
	model.road_fury.reset()
	model.road_fury.collide(model, keep, 3.0, 0.1)
	close(keep.hp, 1000.0 - (22.0 + 5.0 * 11.0) * 2.15, "bumper charged source damage")
	close(model.player.speed, 4.5, "bumper source retainedspeed")
	check(keep.shove_velocity.length() > 0.0 and keep.breached_until > 0.0, "bumper shove and protocol")

func _test_mines() -> void:
	var model = fresh()
	var owner := target(model, Vector3(0, 0, 10))
	var mine: Dictionary = model.hazards.drop(model, owner)
	check(not mine.is_empty(), "mine created")
	close(mine.position.z, 10.0 - owner.radius - 1.35, "mine drop behind owner")
	for index in range(5):
		model.hazards.drop(model, owner)
	check(model.hazards.drop(model, owner).is_empty(), "mine owner cap6")
	model.hazards.reset()
	mine = model.hazards.drop(model, owner)
	model.player.position = mine.position + Vector3(4, 0, 0)
	model.hazards.step(model, 0.9)
	check(mine.armed, "mine arms0.9")
	model.player.interact = true
	for index in range(20):
		model.hazards.step(model, 0.1)
	close(mine.hack_progress, 2.0, "mine hold progress")
	model.player.interact = false
	model.hazards.step(model, 0.5)
	close(mine.hack_progress, 1.0, "mine hack decay2x")
	model.player.interact = true
	for index in range(20):
		model.hazards.step(model, 0.1)
	check(mine.allegiance == "friendly", "mine switches allegiance after3s")
	owner.position = mine.position
	var hp: float = owner.hp
	model.hazards.step(model, 0.1)
	close(owner.hp, hp - 30.0, "hacked mine damages nearby npc")
	check(model.hazards.mines.is_empty(), "mine explosion removed once")
	model.hazards.step(model, 0.1)
	close(owner.hp, hp - 30.0, "mine reward/damage exactonce")
	mine = model.hazards.drop(model, owner)
	model.running = false
	var life: float = mine.life
	model.hazards.step(model, 1.0)
	close(mine.life, life, "paused mine lifetime frozen")

func _test_runtime() -> void:
	var model = fresh()
	model.player.active_protocols = ["targetRelay"]
	var enemy := target(model)
	model.focus_next()
	check(enemy.relay_until == 8.0, "actual focus marks target")
	model.player.treasury_count = 2
	model.player.coin_mult = 2.0
	var coins: int = model.player.coins
	var id: int = model.spawn_pickup(Vector3.ZERO, 10)
	check(model.collect_pickup(id), "actual salvage collected")
	check(model.player.coins == coins + 26, "actual treasury collection rounds source")
	check(not model.collect_pickup(id), "treasury reward exactonce")
	model.road_fury.record(0.1)
	model.hazards.drop(model, enemy)
	model.protocols.salvage_charge = 10.0
	model.reset_run()
	check(model.hazards.mines.is_empty() and model.protocols.salvage_charge == 0.0 and model.road_fury.momentum == 0.0, "reset clears advanced state")
	check(model.player.selected_sidegrades.is_empty() and model.player.active_protocols.is_empty(), "reset clears run tuning")

func _test_activity_contract() -> void:
	var model = fresh()
	var garrison: Dictionary = model.spawn_enemy("garrison_3", Vector3(0, 0, 80), {"counts_toward_wave": false})
	close(garrison.hp, 590.0, "garrison tier3health")
	close(garrison.radius, 4.43 * 1.3, "garrison footprint")
	close(garrison.height, 3.45 * 1.3, "garrison aimheight")
	check(model.snapshot().remaining == 0, "activity garrison doesnot blockwave")
	model._wave_age = 1.0
	model.step(0.1)
	check(model.status == "intermission", "wave cancomplete withroaminggarrison")
	model.kill_enemy(garrison)
	check(model.pickups.size() == 7, "garrison4+tierdrops")
	for pickup: Dictionary in model.pickups:
		check(pickup.value >= 3 and pickup.value <= 5, "garrison salvage sourcevalue")
	var controlled: Dictionary = model.spawn_enemy("buggy", Vector3(0, 0, 25), {"activity_route_controlled": true, "counts_toward_wave": false})
	controlled.cooldown = 0.0
	var position: Vector3 = controlled.position
	model._update_enemies(0.1)
	check(controlled.position == position and model.projectiles.is_empty(), "routecontroller owns motionandfire")
	controlled.activity_route_controlled = false
	controlled.encounter_movement_multiplier = 1.2
	controlled.encounter_cadence_multiplier = 1.2
	controlled.speed = 2.0
	controlled.yaw = PI
	controlled.cooldown = 2.0
	model._update_enemies(0.1)
	close(controlled.position.z, 24.76, "foundry movementoverclock")
	close(controlled.cooldown, 1.88, "foundry cadenceoverclock")
	var low: Dictionary = model.spawn_enemy("rifleman", Vector3(0, 0, 10))
	var high: Dictionary = model.spawn_enemy("rifleman", Vector3(0, 0, 20), {"priority": 2})
	check(model.resolve_target(30).id == high.id, "priority overridesnearest")
	model.focus_id = low.id
	check(model.resolve_target(30).id == low.id, "manualfocus overridespriority")

func _test_nearest_collision() -> void:
	var model = fresh()
	var far := target(model, Vector3(0, 0, 20))
	var near := target(model, Vector3(0, 0, 10))
	var prop_hits := [0]
	model.world_collision_query = func(projectile: Dictionary) -> bool:
		if projectile.previous.z <= 15.0 and projectile.position.z >= 15.0:
			prop_hits[0] += 1
			projectile.position.z = 15.0
			return true
		return false
	model.fire_projectile("sabot", "player", Vector3(0, 1, 0), Vector3(0, 1, 30), 20.0)
	model._update_projectiles(0.3)
	close(near.hp, 980.0, "nearest NPC hit before farther wall")
	close(far.hp, 1000.0, "far NPC not hit throughnearone")
	check(prop_hits[0] == 0, "farwall callback cannot mutate")
	model.fire_projectile("sabot", "player", Vector3(0, 1, 0), Vector3(0, 1, 30), 20.0, -1, {"pierce": 1})
	model._update_projectiles(0.3)
	close(near.hp, 960.0, "pierce hitsnearNPC")
	check(prop_hits[0] == 1, "pierce reacheswall afternearNPC")
	close(far.hp, 1000.0, "wall blockssecond piercedNPC")
	model.world_collision_query = func(projectile: Dictionary) -> bool:
		if projectile.position.z >= 3.0:
			prop_hits[0] += 1
			projectile.position.z = 3.0
			return true
		return false
	model.fire_projectile("bullet", "player", Vector3(0, 1, 0), Vector3(0, 1, 30), 20.0)
	model._update_projectiles(0.3)
	close(near.hp, 960.0, "nearwall blocksNPC")
	check(prop_hits[0] == 2, "nearwall onlyhitonce")

func _test_external_finish() -> void:
	var runtime = load("res://modules/combat/combat_runtime.gd").new()
	var results: Array[Dictionary] = []
	runtime.combat_event.connect(func(event: Dictionary) -> void:
		if event.kind == "result":
			results.append(event))
	runtime.model.running = true
	check(runtime.finish_run(false, "extracted"), "external extraction accepted")
	check(results.size() == 1 and results[0].extracted and results[0].reason == "extracted", "external result immediately published")
	check(runtime.model.status == "extracted" and not runtime.model.running, "extraction isterminal")
	check(not runtime.finish_run(false, "boundary") and results.size() == 1, "external result exactonce")
	runtime.set_running(true)
	check(not runtime.model.running, "extracted cannotresume")
	runtime.free()

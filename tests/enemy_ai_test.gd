extends SceneTree
const Model = preload("res://modules/combat/combat_model.gd")
const AI = preload("res://modules/combat/enemy_ai.gd")
const Evasion = preload("res://modules/combat/drone_evasion.gd")
const Priority = preload("res://modules/combat/priority_rules.gd")
const Spawning = preload("res://modules/combat/spawn_rules.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func close(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.00002, "%s: %s expected%s" % [label, actual, expected])
func fresh():
	var model = Model.new()
	model.running = true
	model.weapons.clear()
	model.spawn_queue.clear()
	return model
func _initialize() -> void:
	movement()
	evasion()
	support()
	boss()
	spawning()
	muzzles()
	print("Enemy AI tests: %s/%s passed" % [checks - failures, checks])
	quit(1 if failures else 0)
func movement() -> void:
	var model = fresh()
	var soldier: Dictionary = model.spawn_enemy("rifleman", Vector3(0, 0, 30))
	AI.move(model, soldier, 0.1, 2.25, 30.0, Vector3.FORWARD)
	close(soldier.position.z, 29.775, "rifle approaches atsource speed")
	soldier.position.z = 5.0
	AI.move(model, soldier, 0.1, 2.25, 5.0, Vector3.FORWARD)
	close(soldier.position.z, 5.1125, "rifle retreats halfspeed")
	var buggy: Dictionary = model.spawn_enemy("buggy", Vector3(0, 0, 10))
	buggy.yaw = PI
	AI.move(model, buggy, 0.1, 4.0, 10.0, Vector3.FORWARD)
	close(buggy.position.z, 10.14, "buggy reverses35percent")
	buggy.position.z = 16.0
	AI.move(model, buggy, 0.1, 4.0, 16.0, Vector3.FORWARD)
	close(buggy.position.z, 15.92, "buggy slowapproach20percent")
	var drone: Dictionary = model.spawn_enemy("shooter", Vector3(0, 0, 24))
	model.elapsed = 2.0
	AI.move(model, drone, 0.1, 4.5, 24.0, Vector3.FORWARD)
	check(absf(drone.position.x) > 0.001, "drone source strafe")
	check(drone.height >= 4.58 and drone.height <= 5.02, "drone altitude oscillation")
	var drone_variant: Dictionary = drone.duplicate(true)
	drone_variant.kind = "convoy_shooter"
	drone_variant.position = Vector3(0, 0, 24)
	drone_variant.behavior.flight.strafe = 0.91
	AI.move(model, drone_variant, 0.1, 4.5, 24.0, Vector3.FORWARD)
	check(absf(drone_variant.position.x) > 0.001, "named shooter variant uses its flight profile at runtime")
	model.enemy_steering_query = func(_enemy: Dictionary, _direction: Vector3, _speed: float) -> Vector3: return Vector3.RIGHT
	soldier.position = Vector3(0, 0, 30)
	AI.move(model, soldier, 0.1, 2.25, 30.0, Vector3.FORWARD)
	close(soldier.position.x, 0.225, "AI consumes world steering query")
	var bomber: Dictionary = model.spawn_enemy("bomber", Vector3(0, 0, 3.3))
	model.weather_type = "foggy"
	var hp: float = model.player.hp
	AI.attack(model, bomber, 0.1, 1.0, 3.3, false)
	close(model.player.hp, hp - 46.0, "fog doesnt shrink physical bomber blast")
	check(bomber.dead, "bomber detonates once")
	var bomber_variant: Dictionary = bomber.duplicate(true)
	bomber_variant.kind = "convoy_bomber"
	bomber_variant.dead = false
	bomber_variant.hp = bomber_variant.max_hp
	bomber_variant.position = Vector3(0, 0, 3.3)
	hp = model.player.hp
	AI.attack(model, bomber_variant, 0.1, 1.0, 3.3, false)
	close(model.player.hp, hp - 46.0, "named bomber variant uses detonation profile")
func evasion() -> void:
	var model = fresh()
	var drone: Dictionary = model.spawn_enemy("shooter", Vector3(0, 0, 12))
	model.fire_projectile("bullet", "player", Vector3(0, 4.8, 0), Vector3(0, 4.8, 30), 9.0)
	var threat := Evasion.threat(drone, model.projectiles)
	check(not threat.is_empty() and threat.time > 0.0 and threat.time < 0.32, "drone predicts incomingbullet")
	var dodge_seed := 0
	while Evasion.dodge_sample(dodge_seed, 0) >= 0.3:
		dodge_seed += 1
	drone.dodge_seed = dodge_seed
	var vector := Evasion.advance(drone, model.projectiles, 0.01)
	check(not vector.is_zero_approx() and drone.dodge_remaining == 0.21, "seeded dodge starts")
	close(drone.dodge_cooldown, 0.95, "source dodge cooldown")
	check(Evasion.advance(drone, model.projectiles, 0.02) == vector, "dodge direction retained")
	Evasion.advance(drone, model.projectiles, 0.3)
	check(drone.dodge_attempt == 1, "samebullet doesnt reroll dodge")
	model.projectiles[0].kind = "rocket"
	check(Evasion.threat(drone, model.projectiles).is_empty(), "dodge ignores rockets")
	var drone_variant: Dictionary = drone.duplicate(true)
	drone_variant.kind = "convoy_shooter"
	drone_variant.behavior.evasion.chance = 1.0
	drone_variant.behavior.evasion.duration = 0.37
	drone_variant.dodge_remaining = 0.0
	drone_variant.dodge_cooldown = 0.0
	drone_variant.dodge_threat_id = -1
	model.projectiles[0].kind = "bullet"
	var variant_vector := Evasion.advance(drone_variant, model.projectiles, 0.01)
	check(not variant_vector.is_zero_approx() and drone_variant.dodge_remaining == 0.37, "named shooter variant uses its evasion profile at runtime")
func support() -> void:
	var model = fresh()
	var repair: Dictionary = model.spawn_enemy("repairCrawler", Vector3(0, 0, 40))
	var first: Dictionary = model.spawn_enemy("buggy", Vector3(0, 0, 45))
	var second: Dictionary = model.spawn_enemy("buggy", Vector3(0, 0, 48))
	first.hp = 80.0
	second.hp = 20.0
	check(Priority.repair_target(repair, model.enemies) == second, "repair chooses lowest healthratio")
	Priority.heal(model, repair, second, 1.0)
	close(second.hp, 23.0, "repair tick bounded250ms")
	var repair_variant: Dictionary = repair.duplicate(true)
	repair_variant.kind = "convoy_repair"
	repair_variant.id = 700
	repair_variant.position = Vector3(0, 0, 40)
	second.hp = 20.0
	model.enemies.append(repair_variant)
	AI.move(model, repair_variant, 0.1, 2.75, 40.0, Vector3.FORWARD)
	close(second.hp, 21.2, "named repair variant heals through repair profile at runtime")
	var boss_target: Dictionary = model.spawn_enemy("leviathan", Vector3(0, 0, 43))
	boss_target.hp = 1.0
	check(not Priority.valid_repair(repair, boss_target), "repair excludesboss")
	var minelayer: Dictionary = model.spawn_enemy("minelayer", Vector3(0, 0, 80))
	minelayer.yaw = PI
	for index in range(41):
		AI.move(model, minelayer, 0.1, 3.45, 80.0, Vector3.FORWARD)
	check(model.hazards.mines.size() == 1, "moving minelayer dropsafter4s")
	var mine_variant: Dictionary = minelayer.duplicate(true)
	mine_variant.kind = "convoy_mines"
	mine_variant.id = 701
	mine_variant.dead = false
	mine_variant.mine_drop_remaining = 0.1
	AI.move(model, mine_variant, 0.1, 3.45, 80.0, Vector3.FORWARD)
	check(model.hazards.mines.size() == 2, "named minelayer variant drops mines through profile at runtime")
	var jammer: Dictionary = model.spawn_enemy("jammerTruck", Vector3(0, 0, 48))
	check(Priority.jammed(model.player, model.enemies), "jammer radius inclusive48")
	jammer.stagger_remaining = 0.1
	check(not Priority.jammed(model.player, model.enemies), "suppression disablesjammer")
	check(model.spawn_enemy("jammerTruck", Vector3.ZERO).is_empty(), "oneactivepriorityperkind")
func boss() -> void:
	var model = fresh()
	var parent: Dictionary = model.spawn_enemy("leviathan", Vector3(0, 0, 35))
	check(parent.components.size() == 5 and model.snapshot().boss_components.size() == 5, "five exposed/hidden component records")
	check(not parent.targetable and not parent.damageable, "boss parent cannotbe shot")
	close(parent.components[0].position.y, model.Leviathan.Geometry.anchor("missilePod").y, "shared missile anchor height")
	close(parent.components[1].position.x, model.Leviathan.Geometry.anchor("gunPod").x, "shared gun anchor offset")
	check(model.resolve_target(80).get("is_component", false), "autofire targetscomponent")
	check(not model.damage_enemy(parent.components[4].id, 9999.0), "hidden core damageblocked")
	model.damage_enemy(parent.components[0].id, 9999.0)
	check(parent.phase == 0 and model.player.kills == 0, "onepod no phase orreward")
	model.damage_enemy(parent.components[1].id, 9999.0)
	check(parent.phase == 1 and parent.components[2].exposed and not parent.components[4].exposed, "bothpodsexposedrives")
	parent.yaw = PI * 0.5
	model.Leviathan.sync(parent)
	close(parent.components[2].position.z, 35.0 - model.Leviathan.Geometry.anchor("leftDrive").x, "component follows parent yaw")
	model.damage_enemy(parent.components[2].id, 9999.0)
	model.damage_enemy(parent.components[3].id, 9999.0)
	check(parent.phase == 2 and parent.components[4].targetable, "bothdrives exposecore")
	parent.core_cooldown = 0.0
	model.Leviathan.step(model, parent, 0.1, 35.0)
	close(parent.core_telegraph, 0.9, "core attacktelegraph")
	model.Leviathan.step(model, parent, 0.9, 35.0)
	check(model.projectiles.size() == 13, "acquiredcore8radial5aimed")
	model.projectiles.clear()
	parent.core_telegraph = 0.1
	model.Leviathan.step(model, parent, 0.1, 100.0)
	check(model.projectiles.size() == 8, "unacquiredcoreonly8radial")
	model.damage_enemy(parent.components[4].id, 9999.0)
	check(parent.dead and model.player.kills == 1, "coredeath rewardsonlyparentonce")
	check(not model.damage_enemy(parent.components[4].id, 9999.0), "deadcore duplicateblocked")
func spawning() -> void:
	var model = fresh()
	for kind in ["rifleman", "shooter", "leviathan"]:
		var point: Vector3 = Spawning.wave_position(model, kind)
		var minimum := 180.0 if kind == "leviathan" else 62.0 if kind == "rifleman" else 85.0
		var maximum := 650.0 if kind == "leviathan" else 92.0 if kind == "rifleman" else 260.0
		check(point.length() >= minimum and point.length() <= maximum, "source spawn annulus " + kind)
	model.spawn_validity_query = func(_point: Vector3, _radius: float) -> bool: return false
	check(Spawning.wave_position(model, "rifleman") == null, "blockedspawn exhausts boundedsearch")
	model.spawn_queue.append("rifleman")
	model.step(0.1)
	check(model.spawn_queue.size() == 1 and model._spawn_remaining == 0.25, "failedspawn retained with250msretry")
	model.spawn_validity_query = Callable()
	for index in range(12):
		model.spawn_enemy("shooter", Vector3(0, 0, 70))
	check(model.spawn_enemy("shooter", Vector3(0, 0, 70)).is_empty(), "source12dronecapacity")
func muzzles() -> void:
	var model = fresh()
	model.install_weapon("assaultRifle")
	var target: Dictionary = model.spawn_enemy("buggy", Vector3(50, 0, 0))
	model.weapon_origin_query = func(_weapon: Dictionary) -> Vector3: return Vector3(30, 3.6, 0)
	model._update_weapons(0.1)
	check(model.projectiles.size() == 1, "acquisition rangefromactualmount")
	check(model.projectiles[0].position == Vector3(30, 3.6, 0), "actualshotspawnsmuzzlecallback")
	model.running = false
	var age: float = model.elapsed
	model.step(1.0)
	close(model.elapsed, age, "paused AI andbossfrozen")

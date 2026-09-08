extends SceneTree

const Runtime = preload("res://modules/combat/combat_runtime.gd")
const Model = preload("res://modules/combat/combat_model.gd")
const Waves = preload("res://modules/combat/wave_rules.gd")
const Shots = preload("res://modules/combat/projectile_rules.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func run() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 912
	var conservative := true
	for index in 2000:
		var start := Vector3(random.randf_range(-10, 10), 0, random.randf_range(-10, 10))
		var end := Vector3(random.randf_range(-10, 10), 0, random.randf_range(-10, 10))
		var center := start.lerp(end, random.randf()) + Vector3(random.randf_range(-1, 1), 0, random.randf_range(-1, 1))
		var radius := random.randf_range(0.1, 2)
		if Shots.hit_fraction(start, end, center, radius) >= 0:
			conservative = conservative and Shots.segment_may_hit_xz(start, end, center, radius)
	check(conservative, "Projectile broad phase never rejects an actual sphere hit")
	check(not Shots.segment_may_hit_xz(Vector3.ZERO, Vector3.RIGHT, Vector3(20, 0, 20), 1), "Projectile broad phase skips distant targets")
	var model = Model.new()
	check(model.weapons.size() == 1, "source starter M4 is installed")
	check(Waves.queue_for(1).size() == 9, "wave one has eight riflemen and one bike")
	check(Waves.queue_for(6).size() == 46, "final wave includes source combatants and three support vehicles")
	check(model.player.fuel == 100.0 and model.player.pickup_radius == 6.2, "source fuel and pickup values")
	check(model.weapons[0].def.damage == 9 and model.weapons[0].def.cooldown == 0.3 and model.weapons[0].def.range == 32, "source M4 damage cadence and range")
	model.step(0.1)
	check(model.enemies.is_empty(), "startup does not simulate before running")
	model.running = true
	model.spawn_queue.clear()
	var enemy: Dictionary = model.spawn_enemy("rifleman", Vector3(12, 0, 0))
	for _step in 100:
		model.step(0.02)
	check(enemy.dead, "automatic starter rifle acquires and kills a moving enemy")
	check(model.player.kills == 1, "kill reward occurs once")
	model.kill_enemy(enemy)
	check(model.player.kills == 1, "duplicate kill cannot award again")
	var pickup_id: int = model.spawn_pickup(Vector3.ZERO, 10)
	var coins: int = model.player.coins
	check(model.collect_pickup(pickup_id), "pickup accepts first claim")
	check(not model.collect_pickup(pickup_id), "pickup rejects duplicate claim")
	check(model.player.coins == coins + 10, "salvage adds exact value")
	model.reset_run(42)
	check(model.enemies.is_empty() and model.projectiles.is_empty() and model.pickups.is_empty(), "reset clears all transient combat state")
	check(model.player.kills == 0 and model.player.coins == 35 and model.player.hp == 250.0, "reset restores source player defaults")
	check(model.weapons.size() == 1 and model.focus_id == -1 and not model.running, "reset clears focus, upgrades and running flag")
	model.running = true
	model.spawn_queue.clear()
	model.weapons.clear()
	var first: Dictionary = model.spawn_enemy("rifleman", Vector3(5, 0, 0))
	var second: Dictionary = model.spawn_enemy("rifleman", Vector3(25, 0, 0))
	model.focus_id = second.id
	check(model.resolve_target(32).id == second.id, "focused in-range target outranks nearer target")
	check(model.resolve_target(10).id == first.id, "out-of-range focus falls back to nearest")
	check(Shots.hits(Vector3(-10, 1, 0), Vector3(10, 1, 0), Vector3(0, 1, 0), 0.5), "swept hit prevents projectile tunnelling")
	check(not Shots.hits(Vector3(-10, 1, 0), Vector3(10, 1, 0), Vector3(0, 4, 0), 0.5), "swept hit respects height")
	model.damage_player(10000)
	check(model.status == "dead" and not model.running and model.player.hp == 0.0, "death stops run and clamps hull")
	check(not model.activate_ability(2), "dead player cannot repair")
	model.reset_run()
	model.running = true
	model.spawn_queue.clear()
	model.weapons.clear()
	for _step in 11:
		model.step(0.1)
	check(model.status == "intermission", "empty completed wave enters intermission")
	for _step in 51:
		model.step(0.1)
	check(model.wave == 2 and model.status == "combat", "five-second intermission starts next wave")
	model.reset_run()
	model.running = true
	model.spawn_queue.clear()
	model.weapons.clear()
	model.wave = 6
	var boss: Dictionary = model.spawn_enemy("leviathan", Vector3(100, 0, 0))
	model.damage_enemy(boss.id, 10000)
	check(not boss.dead and boss.phase == 0 and boss.hp == 1270.0, "boss hull cannot bypass component gates")
	model.damage_enemy(boss.components[0].id, 10000)
	model.damage_enemy(boss.components[1].id, 10000)
	check(boss.phase == 1, "both weapons unlock drives")
	model.damage_enemy(boss.components[2].id, 10000)
	model.damage_enemy(boss.components[3].id, 10000)
	check(boss.phase == 2, "both drives unlock core")
	model.damage_enemy(boss.components[4].id, 10000)
	for _step in 11:
		model.step(0.1)
	check(model.status == "complete" and not model.running, "last wave reaches victory only after core death")
	model.reset_run()
	for _index in 250:
		model.spawn_enemy("rifleman", Vector3(100, 0, 0))
		model.spawn_pickup(Vector3.ZERO, 1)
		model.fire_projectile("bullet", "player", Vector3.ZERO, Vector3.RIGHT, 9)
	check(model.enemies.size() <= Model.MAX_ENEMIES, "enemy capacity remains bounded")
	check(model.pickups.size() == Model.MAX_PICKUPS, "pickup capacity remains bounded")
	check(model.projectiles.size() == Model.MAX_PROJECTILES, "projectile capacity remains bounded")
	model.reset_run()
	model.running = true
	model.player.hp = 200.0
	check(model.activate_ability(2) and model.player.hp == 230.0 and model.player.coins == 20 and model.player.repair_cooldown == 5.0, "source repair slot, cost, amount and cooldown")
	check(not model.activate_ability(1), "ram slot requires installed bumper")
	model.player.has_bumper = true
	check(model.activate_ability(1) and model.player.ram_timer == 0.9 and model.player.ram_cooldown == 8.0, "source ram duration and cooldown")
	check(model.activate_ability(0) and model.player.nitro_timer == 1.85 and model.player.nitro_cooldown == 10.0, "source nitro duration and cooldown")
	var runtime := Runtime.new()
	root.add_child(runtime)
	runtime.set_running(false)
	check(not runtime.get_state().running, "runtime loads and exposes stopped model")
	runtime.queue_free()
	print("Combat tests: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)

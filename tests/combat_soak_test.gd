extends SceneTree
const Model = preload("res://modules/combat/combat_model.gd")
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
	var model := Model.new()
	model.reset_run(991827)
	model.running = true
	model.spawn_queue.clear()
	model._wave_age = -100000.0
	model.player.max_hp = 1000000000.0
	model.player.hp = model.player.max_hp
	var largest := {"enemies": 0, "projectiles": 0, "pickups": 0, "mines": 0}
	var reward_ids: Dictionary = {}
	for tick in 18000:
		if tick % 30 == 0:
			for index in 6:
				model.spawn_enemy(["rifleman", "ak", "bike", "shooter", "minelayer", "repairCrawler"][index], Vector3(10 + index * 2, 0, 14))
		if tick % 10 == 0:
			for index in 4:
				model.fire_projectile(["bullet", "rocket", "grenade", "sabot"][index], "player", Vector3(0, 3, 0), Vector3(0, 2, 30), 10)
		if tick % 120 == 0:
			for enemy: Dictionary in model.enemies.duplicate():
				model.damage_enemy(enemy.id, 99999)
		model.step(0.1)
		for event: Dictionary in model.drain_events():
			if event.kind == "death":
				check(not reward_ids.has(event.id), "Entity death emits reward once throughout soak")
				reward_ids[event.id] = true
		largest.enemies = maxi(largest.enemies, model.enemies.size())
		largest.projectiles = maxi(largest.projectiles, model.projectiles.size())
		largest.pickups = maxi(largest.pickups, model.pickups.size())
		largest.mines = maxi(largest.mines, model.hazards.mines.size())
		if tick % 600 == 0:
			model.running = false
			var before := model.snapshot()
			model.step(0.1)
			check(model.snapshot() == before, "Pause is inert during long combat")
			model.running = true
	check(model.elapsed > 1799.0 and model.status == "combat", "Thirty simulated minutes remain active without terminal corruption")
	check(largest.enemies <= model.MAX_ENEMIES and largest.projectiles <= model.MAX_PROJECTILES and largest.pickups <= model.MAX_PICKUPS and largest.mines <= 36, "Combat actor/projectile/pickup/mine caps remain bounded")
	var generation: int = model.generation
	model.reset_run(72841)
	check(model.generation == generation + 1 and model.enemies.is_empty() and model.projectiles.is_empty() and model.pickups.is_empty() and model.hazards.mines.is_empty(), "Reset clears long-lived combat state after soak")
	check(model.player.hp == 250 and model.player.kills == 0 and model.elapsed == 0, "Reset restores source player state after soak")
	print("Combat soak: %d checks, %d failures, 1800 simulated seconds, peak %s" % [checks, failures, largest])
	quit(0 if failures == 0 else 1)

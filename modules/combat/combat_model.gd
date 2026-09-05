extends RefCounted
const Terrain = preload("res://modules/caravan/terrain_surface.gd")

const Dimensions = preload("res://modules/caravan/player_dimensions.gd")
const Waves = preload("res://modules/combat/wave_rules.gd")
const EnemyFactory = preload("res://modules/combat/enemy_factory.gd")
const Enemies = preload("res://modules/combat/enemy_catalog.gd")
const Leviathan = preload("res://modules/combat/leviathan_rules.gd")
const Jammer = preload("res://modules/combat/jammer_rules.gd")
const Shots = preload("res://modules/combat/projectile_rules.gd")
const Protocols = preload("res://modules/combat/protocol_rules.gd")
const Sidegrades = preload("res://modules/combat/sidegrade_rules.gd")
const Rockets = preload("res://modules/combat/rocket_rules.gd")
const Spawning = preload("res://modules/combat/spawn_rules.gd")
const EnemyAI = preload("res://modules/combat/enemy_ai.gd")
const Priority = preload("res://modules/combat/priority_rules.gd")
const Fury = preload("res://modules/combat/road_fury_rules.gd")
const Mines = preload("res://modules/combat/mine_rules.gd")
var road_fury = Fury.new()
var hazards = Mines.new()
var protocols = Protocols.new()

const MAX_ENEMIES := 110
const MAX_PROJECTILES := 140
const MAX_PICKUPS := 72

var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var events: Array[Dictionary] = []
var weapons: Array[Dictionary] = []
var player: Dictionary = {}
var wave := 1
var status := "idle"
var jammer := Jammer.new()
var weather_type := "clear"
var weather_fog_strength := -1.0
var world_collision_query: Callable
var enemy_motion_query: Callable
var enemy_steering_query: Callable
var weapon_origin_query: Callable
var spawn_validity_query: Callable
var spawn_visibility_query: Callable
var elapsed := 0.0
var intermission := 0.0
var running := false
var focus_id := -1
var generation := 0
var spawn_queue: Array[String] = []
var random := RandomNumberGenerator.new()
var _next_id := 1
var _spawn_remaining := 0.0
var _wave_age := 0.0
var _catalog: Dictionary = {}

func _init() -> void:
	var file := FileAccess.open("res://data/game_catalogs.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_catalog = parsed.get("modules", {})
	if not _catalog.has("assaultRifle"):
		push_error("Combat requires data/game_catalogs.json with the original assaultRifle definition")
	reset_run()

func reset_run(seed_value: int = 72841) -> void:
	weather_type = "clear"
	weather_fog_strength = -1.0
	generation += 1
	protocols.reset()
	road_fury.reset()
	hazards.reset()
	random.seed = seed_value
	enemies.clear()
	projectiles.clear()
	pickups.clear()
	events.clear()
	weapons.clear()
	_next_id = 1
	wave = 1
	status = "combat"
	elapsed = 0.0
	intermission = 0.0
	running = false
	focus_id = -1
	_wave_age = 0.0
	_spawn_remaining = 0.0
	spawn_queue = Waves.queue_for(wave)
	player = {"position": Vector3.ZERO, "velocity": Vector3.ZERO, "speed": 0.0,
		"hp": 250.0, "max_hp": 250.0, "fuel": 100.0, "max_fuel": 100.0,
		"coins": 35, "kills": 0, "xp": 0, "xp_next": 70, "level": 1,
		"damage_mult": 1.0, "range_mult": 1.0, "fire_rate": 1.0, "armor": 0.0,
		"emergency_armor": 0.0, "pickup_radius": 6.2, "coin_mult": 1.0,
		"repair_power": 30.0, "repair_cooldown": 0.0, "ram_cooldown": 0.0,
		"ram_timer": 0.0, "has_bumper": false, "ram_cd_mult": 1.0,
		"nitro_timer": 0.0, "nitro_cooldown": 0.0, "nitro_recovery": 1.0,
		"regen_rate": 0.0, "double_shot_chance": 0.0, "overdrive_feed": false,
		"counter_drone_jammer": false, "active_protocols": [], "selected_sidegrades": {}, "treasury_count": 0,
		"visual_scale": 0.88, "radius": 3.5, "low_hp_sfx_remaining": 0.0, "heading": 0.0, "yaw_velocity": 0.0, "slip_angle": 0.0, "momentum": 0.0, "interact": false}
	jammer.reset(player, seed_value)
	install_weapon("assaultRifle")

func install_weapon(type: String) -> bool:
	if not _catalog.has(type) or not _catalog[type].has("projectile"):
		return false
	weapons.append({"type": type, "level": 1, "cooldown": 0.0, "def": _catalog[type].duplicate(true)})
	return true

func step(delta: float) -> void:
	if not running or status in ["dead", "complete", "extracted"] or delta <= 0.0:
		return
	delta = minf(delta, 0.1)
	elapsed += delta
	_tick_abilities(delta)
	road_fury.step(player, delta)
	if status == "intermission":
		intermission = maxf(0.0, intermission - delta)
		if intermission == 0.0:
			wave += 1
			status = "combat"
			spawn_queue = Waves.queue_for(wave)
			_spawn_remaining = 0.0
			_wave_age = 0.0
			_emit("wave", {"wave": wave})
	else:
		_wave_age += delta
		_spawn_remaining -= delta
		if not spawn_queue.is_empty() and _spawn_remaining <= 0.0 and enemies.size() < MAX_ENEMIES:
			var position: Variant = Spawning.wave_position(self, spawn_queue.front())
			var spawned: Dictionary = {}
			if position is Vector3:
				spawned = spawn_enemy(spawn_queue.front(), position)
			if not spawned.is_empty():
				spawn_queue.pop_front()
			_spawn_remaining = Waves.SPAWN_INTERVAL if not spawned.is_empty() else 0.25

	_update_enemies(delta)
	if status == "dead":
		return
	_update_weapons(delta)
	_update_projectiles(delta)
	if status == "dead":
		return
	_update_pickups(delta)
	hazards.step(self, delta)
	jammer.step(player, enemies, 0.0)
	enemies = enemies.filter(func(enemy: Dictionary) -> bool: return not enemy.dead)
	if status == "combat" and spawn_queue.is_empty() and _wave_remaining() == 0 and _wave_age >= 1.0:
		projectiles.clear()
		if wave == Waves.FINAL_WAVE:
			_finish(true)
		else:
			status = "intermission"
			intermission = Waves.INTERMISSION_SECONDS
			_emit("wave_cleared", {"wave": wave})

func spawn_enemy(kind: String, position: Vector3, options: Dictionary = {}) -> Dictionary:
	if enemies.size() >= MAX_ENEMIES or not Enemies.DEFINITIONS.has(kind):
		return {}
	if not Spawning.capacity(enemies, kind, Enemies.DEFINITIONS):
		return {}
	var enemy := EnemyFactory.create(kind, _id(), position, random, options)
	if enemy.is_empty():
		return {}
	enemy.wave = wave
	if enemy.get("boss", false):
		Leviathan.setup(enemy, self)
	enemies.append(enemy)
	_emit("spawn", {"id": enemy.id, "type": enemy.type, "enemy_kind": kind, "position": position, "counts_toward_wave": enemy.counts_toward_wave})
	return enemy

func _update_enemies(delta: float) -> void:
	for enemy: Dictionary in enemies:
		if enemy.dead:
			continue
		var offset: Vector3 = player.position - enemy.position
		offset.y = 0.0
		var distance := offset.length()
		var direction := offset.normalized()
		var jammed: bool = enemy.type == "drone" and player.counter_drone_jammer and distance <= 32.0
		var cadence: float = (0.55 if jammed else 1.0) * enemy.get("encounter_cadence_multiplier", 1.0)
		if enemy.get("collidable", true):
			road_fury.collide(self, enemy, distance, delta)
		if enemy.dead or status == "dead":
			continue
		var interrupted := Protocols.advance_status(enemy, delta)
		if interrupted or enemy.get("activity_route_controlled", false):
			continue
		var speed: float = enemy.speed * (0.55 if jammed else 1.0) * enemy.get("encounter_movement_multiplier", 1.0) * enemy.get("slow_multiplier", 1.0)
		if enemy.get("boss", false):
			var destroyed_drives := 0
			for component: Dictionary in enemy.components:
				if component.phase == 1 and component.hp <= 0.0:
					destroyed_drives += 1
			speed *= [1.0, 0.68, 0.32][destroyed_drives]
		if enemy.type != "garrison":
			enemy.position += enemy.get("shove_velocity", Vector3.ZERO) * delta
			enemy.shove_velocity = enemy.get("shove_velocity", Vector3.ZERO) * pow(0.045, delta)
		EnemyAI.move(self, enemy, delta, speed, distance, direction)
		enemy.x = enemy.position.x
		enemy.z = enemy.position.z
		enemy.hit_time = maxf(0.0, enemy.hit_time - delta)
		EnemyAI.attack(self, enemy, delta, cadence, distance, jammed)

func _update_weapons(delta: float) -> void:
	jammer.step(player, enemies, delta)
	for weapon: Dictionary in weapons:
		weapon.cooldown -= delta * player.fire_rate * (1.16 if player.overdrive_feed and absf(player.speed) > 4.0 else 1.0)
		if weapon.cooldown > 0.0:
			continue
		var tuning := Sidegrades.tuning(player, weapon)
		tuning.weapon_mount = weapon.get("mount", {"carrierId": "crawler", "slot": 0})
		var origin: Vector3 = weapon_origin_query.call(weapon) if weapon_origin_query.is_valid() else player.position + Vector3.UP * 2.8
		var target := resolve_target(float(tuning.range) * player.range_mult * (0.55 if player.jammed else 1.0) * weather_range_multiplier(player.get("radar_range", 0.0) > 0.0), origin)
		if target.is_empty():
			continue
		var aim := _target_aim(target) + Vector3(target.get("shove_velocity", Vector3.ZERO)) * 0.18
		fire_projectile(weapon.def.projectile, "player", origin, aim, tuning.damage, target.id, tuning)
		if random.randf() < player.double_shot_chance:
			fire_projectile(weapon.def.projectile, "player", origin + Vector3.UP * 0.68 + Vector3(cos(player.heading), 0.0, -sin(player.heading)) * 0.35, aim - Vector3(cos(player.heading), 0.0, -sin(player.heading)) * 0.35, tuning.damage * 0.72, target.id, tuning)
		weapon.cooldown = weapon.def.cooldown

	var bonus: Dictionary = protocols.combined_weapon(player, weapons, elapsed)
	if not bonus.is_empty():
		var origin: Vector3 = weapon_origin_query.call(bonus) if weapon_origin_query.is_valid() else player.position + Vector3.UP * 2.8
		var target := resolve_target(bonus.def.range * player.range_mult * (0.55 if player.jammed else 1.0), origin)
		if not target.is_empty():
			protocols.primed_until = 0.0
			fire_projectile(bonus.def.projectile, "player", origin, _target_aim(target) + Vector3(target.get("shove_velocity", Vector3.ZERO)) * 0.18, bonus.def.damage, target.id, {"module_type": bonus.type, "synergy_eligible": false})

func resolve_target(distance_limit: float, origin: Vector3 = Vector3.INF) -> Dictionary:
	if origin == Vector3.INF:
		origin = player.position
	var nearest: Dictionary = {}
	var best := distance_limit * distance_limit
	var priority := -INF
	for enemy: Dictionary in _target_candidates():
		if enemy.dead or enemy.get("targetable", true) == false:
			continue
		var distance: float = Vector2(enemy.position.x - origin.x, enemy.position.z - origin.z).length_squared()
		if enemy.id == focus_id and distance <= distance_limit * distance_limit:
			return enemy
		var target_priority: float = enemy.get("priority", 0.0)
		if distance < distance_limit * distance_limit and (target_priority > priority or (target_priority == priority and distance < best)):
			best = distance
			priority = target_priority
			nearest = enemy
	return nearest

func focus_next() -> void:
	var candidates := _target_candidates()
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return left.position.distance_squared_to(player.position) < right.position.distance_squared_to(player.position))
	if candidates.is_empty():
		focus_id = -1
		return
	var current := -1
	for index in candidates.size():
		if candidates[index].id == focus_id:
			current = index
	focus_id = candidates[(current + 1) % candidates.size()].id
	Protocols.mark_focus(player, candidates[(current + 1) % candidates.size()], elapsed)

func focus_at(position: Vector3) -> void:
	var distance := 12.0 * 12.0
	focus_id = -1
	for enemy: Dictionary in _target_candidates():
		var candidate: float = enemy.position.distance_squared_to(position)
		if not enemy.dead and candidate <= distance:
			distance = candidate
			focus_id = enemy.id

	for enemy: Dictionary in _target_candidates():
		if enemy.id == focus_id:
			Protocols.mark_focus(player, enemy, elapsed)

func fire_projectile(kind: String, team: String, origin: Vector3, aim: Vector3, damage: float, target: int = -1, options: Dictionary = {}) -> void:
	if projectiles.size() >= MAX_PROJECTILES:
		projectiles.pop_front()
	if kind == "rocket" and team == "player":
		aim = Rockets.aim(origin, aim, player, random.randf())
	if team == "player":
		aim = jammer.aim(origin, aim, player, _next_id)
	var shot := Shots.create(_id(), kind, team, origin, aim, damage, target)
	shot.merge(options, true)
	shot.hit_targets = []
	shot.pierce_remaining = options.get("pierce", 0)
	if kind == "rocket":
		shot.base_position = origin
		shot.rocket_age = 0.0
		shot.rocket_profile = Rockets.profile(player, team, random.randi())
	projectiles.append(shot)
	_emit("shot", {"id": shot.id, "position": origin, "target_position": aim, "projectile_kind": kind, "team": team, "module_type": options.get("module_type", ""), "weapon_mount": options.get("weapon_mount", {}), "velocity": shot.velocity})

func _update_projectiles(delta: float) -> void:
	for shot: Dictionary in projectiles:
		shot.previous = shot.position
		shot.life -= delta
		shot.velocity.y -= shot.gravity * delta
		if shot.kind == "rocket":
			Rockets.move(shot, delta)
		else:
			shot.position += shot.velocity * delta
		shot.x = shot.position.x
		shot.z = shot.position.z
		var hit := _resolve_projectile_segment(shot)
		if not hit and shot.position.y <= Terrain.height_at(shot.position.x, shot.position.z) + 0.04:
			if Shots.blast_radius(shot.kind) > 0.0:
				_explode(shot, -1, true)
			else:
				_emit("projectile_ground", {"position": shot.position, "velocity": shot.velocity, "projectile_kind": shot.kind})
			hit = true
		shot.x = shot.position.x
		shot.z = shot.position.z
		shot.dead = hit or shot.life <= 0.0
		if status == "dead":
			break
	projectiles = projectiles.filter(func(shot: Dictionary) -> bool: return not shot.dead)

func _resolve_projectile_segment(shot: Dictionary) -> bool:
	var start: Vector3 = shot.previous
	var end: Vector3 = shot.position
	var hits: Array[Dictionary] = []
	if shot.team == "player":
		for enemy: Dictionary in _target_candidates():
			if enemy.dead or enemy.id in shot.get("hit_targets", []) or (enemy.get("collidable", true) == false and not enemy.get("is_component", false)):
				continue
			var fraction := Shots.hit_fraction(start, end, _aim_center(enemy), enemy.radius + shot.radius + (0.12 if enemy.type == "soldier" else 0.1))
			if fraction >= 0.0:
				hits.append({"fraction": fraction, "enemy": enemy})
	else:
		var player_radius := Dimensions.radius(player.visual_scale)
		var fraction := Shots.hit_fraction(start, end, player.position + Vector3.UP * 2.2, player_radius + shot.radius)
		if fraction >= 0.0:
			hits.append({"fraction": fraction})
	hits.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left.fraction < right.fraction)
	var segment_start := start
	for entry: Dictionary in hits:
		shot.previous = segment_start
		shot.position = start.lerp(end, entry.fraction)
		if _world_projectile_hit(shot):
			return true
		if shot.team == "player":
			var enemy: Dictionary = entry.enemy
			if Shots.blast_radius(shot.kind) > 0.0:
				_explode(shot, enemy.id)
				return true
			shot.hit_targets.append(enemy.id)
			_projectile_damage(enemy, shot, shot.damage, true)
			if shot.pierce_remaining <= 0:
				return true
			shot.pierce_remaining -= 1
		else:
			damage_player(shot.damage)
			_emit("hit", {"position": shot.position, "team": "player", "damage": shot.damage, "projectile_kind": shot.kind})
			if Shots.blast_radius(shot.kind) > 0.0:
				_emit("explosion", {"position": shot.position, "radius": Shots.blast_radius(shot.kind), "projectile_kind": shot.kind, "damage": shot.damage, "team": shot.team})
			return true
		segment_start = shot.position
	shot.previous = segment_start
	shot.position = end
	return _world_projectile_hit(shot)

func _world_projectile_hit(shot: Dictionary) -> bool:
	if not world_collision_query.is_valid() or not world_collision_query.call(shot):
		return false
	if Shots.blast_radius(shot.kind) > 0.0:
		_explode(shot)
	return true

func _explode(shot: Dictionary, direct_id: int = -1, ground: bool = false) -> void:
	var base_radius := (4.0 if shot.kind == "rocket" else 4.8) if ground else Shots.blast_radius(shot.kind)
	var radius := base_radius * float(shot.get("splash_multiplier", 1.0))
	if shot.team == "player":
		for enemy: Dictionary in _target_candidates():
			var distance: float = 0.0 if enemy.id == direct_id else enemy.position.distance_to(shot.position)
			if not enemy.dead and distance < radius:
				_projectile_damage(enemy, shot, shot.damage * (1.0 - distance / radius * 0.35), enemy.id == direct_id)
	else:
		var distance: float = player.position.distance_to(shot.position)
		if distance < radius:
			damage_player(shot.damage * (1.0 - distance / radius * 0.35))
	_emit("explosion", {"position": shot.position, "radius": radius, "projectile_kind": shot.kind, "damage": shot.damage, "team": shot.team, "visual_scale": (1.0 if ground else 1.1) if shot.kind == "grenade" else (0.86 if ground else 0.9)})

func _projectile_damage(enemy: Dictionary, shot: Dictionary, amount: float, direct: bool) -> void:
	var multiplier: float = protocols.hit(player, enemy, shot, elapsed, direct)
	var chain: Dictionary = {}
	if direct and shot.get("module_type", "") == "railgun" and shot.get("synergy_eligible", true) and Protocols.active(player, "stormConductor"):
		chain = Protocols.conductor_target(_target_candidates(), enemy, elapsed)
	damage_enemy(enemy.id, amount * multiplier)
	Sidegrades.apply_control(enemy, shot)
	if not chain.is_empty() and not chain.dead:
		damage_enemy(chain.id, amount * multiplier * 0.45)
		_emit("conductor_arc", {"position": enemy.position, "target_position": chain.position})

func damage_enemy(id: int, amount: float, lethal: bool = true) -> bool:
	for enemy: Dictionary in enemies:
		if enemy.dead:
			continue
		if enemy.get("boss", false):
			for component: Dictionary in enemy.components:
				if component.id == id:
					var scaled: float = maxf(0.0, amount) * player.damage_mult
					return Leviathan.damage(self, enemy, component, scaled if lethal else minf(scaled, maxf(0.0, component.hp - 1.0)))
			if enemy.id == id:
				return false
		if enemy.id != id or enemy.get("damageable", true) == false:
			continue
		amount = maxf(0.0, amount) * player.damage_mult * enemy.get("incoming", 1.0)
		if not lethal:
			amount = minf(amount, maxf(0.0, enemy.hp - 1.0))
		enemy.hp = maxf(0.0, enemy.hp - amount)
		enemy.hit_time = 1.0 / 6.0
		_emit("hit", {"id": id, "type": enemy.type, "position": _aim_center(enemy), "damage": amount})
		if enemy.hp <= 0.0:
			kill_enemy(enemy)
		return true
	return false

func damage_enemy_nonlethal(id: int, amount: float) -> bool:
	return damage_enemy(id, amount, false)

func kill_enemy(enemy: Dictionary, options: Dictionary = {}) -> void:
	if enemy.dead:
		return
	enemy.dead = true
	if not options.get("grant_rewards", true):
		if focus_id == enemy.id:
			focus_id = -1
		_emit("death", {"id": enemy.id, "source_id": enemy.get("source_id", ""), "type": enemy.type, "enemy_kind": enemy.kind, "position": enemy.position, "radius": enemy.radius, "tier": enemy.get("tier", 1), "heading": enemy.get("yaw", 0.0), "boss": enemy.get("boss", false), "cause": options.get("cause", ""), "rewarded": false})
		return
	player.kills += 1
	if focus_id == enemy.id:
		focus_id = -1
	var boss: bool = enemy.get("boss", false)
	var drops := 12 if boss else 5 if enemy.type == "keep" else 4 + int(enemy.tier) if enemy.type == "garrison" else 3 if enemy.type == "buggy" else 2 if enemy.kind == "kamikaze" else 1
	for _index in drops:
		var value := random.randi_range(6, 10) if boss else random.randi_range(4, 7) if enemy.type == "keep" else random.randi_range(3, 5) if enemy.type == "garrison" else random.randi_range(2, 4) if enemy.type == "buggy" else random.randi_range(1, 2)
		spawn_pickup(enemy.position + Vector3(random.randf_range(-2.5, 2.5), 0, random.randf_range(-2.5, 2.5)), value)
	var fuel_chance := 0.8 if enemy.type == "priorityVehicle" else 0.55 if enemy.type == "buggy" else 0.32 if enemy.type == "bike" else 0.16 if enemy.type == "drone" else 0.0
	if random.randf() < fuel_chance:
		spawn_pickup(enemy.position, 42 if enemy.type == "priorityVehicle" else 34 if enemy.type == "buggy" else 24 if enemy.type == "bike" else 18, "fuel")
	_emit("death", {"id": enemy.id, "source_id": enemy.get("source_id", ""), "type": enemy.type, "enemy_kind": enemy.kind, "position": enemy.position, "radius": enemy.radius, "tier": enemy.get("tier", 1), "heading": enemy.get("yaw", 0.0), "boss": boss})

func damage_player(amount: float, lethal: bool = true) -> void:
	if status in ["dead", "complete", "extracted"] or not running:
		return
	var emergency: float = player.emergency_armor if player.hp < player.max_hp * 0.3 else 0.0
	amount = maxf(0.0, amount) * maxf(0.0, 1.0 - player.armor - emergency)
	if not lethal:
		amount = minf(amount, maxf(0.0, player.hp - 1.0))
	player.hp = maxf(0.0, player.hp - amount)
	_emit("player_hit", {"position": player.position, "damage": amount, "hp": player.hp})
	if player.hp == 0.0:
		_finish(false)

func damage_player_nonlethal(amount: float) -> void:
	damage_player(amount, false)

func spawn_pickup(position: Vector3, value: int, kind: String = "salvage") -> int:
	if pickups.size() >= MAX_PICKUPS:
		pickups.pop_front()
	var id := _id()
	pickups.append({"id": id, "position": position, "x": position.x, "z": position.z,
		"kind": kind, "value": value, "life": 32.0 if kind == "fuel" else 22.0, "dead": false})
	return id

func _update_pickups(delta: float) -> void:
	for pickup: Dictionary in pickups:
		pickup.life -= delta
		var distance: float = pickup.position.distance_to(player.position)
		if distance < player.pickup_radius:
			var pull: float = clampf(1.0 - distance / player.pickup_radius, 0.0, 1.0)
			pickup.position = pickup.position.lerp(player.position, minf(1.0, delta * (3.5 + pull * 13.0)))
			pickup.x = pickup.position.x
			pickup.z = pickup.position.z
		if pickup.position.distance_to(player.position) < 2.35:
			collect_pickup(pickup.id)
		if pickup.life <= 0.0:
			pickup.dead = true
	pickups = pickups.filter(func(pickup: Dictionary) -> bool: return not pickup.dead)

func collect_pickup(id: int) -> bool:
	if not running or status in ["dead", "complete", "extracted"]:
		return false
	for pickup: Dictionary in pickups:
		if pickup.id != id or pickup.dead:
			continue
		if pickup.kind == "fuel" and player.fuel >= player.max_fuel:
			return false
		pickup.dead = true
		var amount := int(pickup.value)
		if pickup.kind == "fuel":
			player.fuel = minf(player.max_fuel, player.fuel + amount)
		else:
			amount = maxi(1, roundi(amount * protocols.salvage_multiplier(player)))
			player.coins += amount
			protocols.collect(player, pickup.value)
			player.xp += maxi(1, roundi(amount * 0.72))
		_emit("pickup", {"id": id, "position": pickup.position, "pickup_kind": pickup.kind, "amount": amount})
		return true
	return false

func activate_ability(slot: int) -> bool:
	if not running or status in ["dead", "complete", "extracted"]:
		return false
	match slot:
		0:
			if player.nitro_cooldown > 0.0:
				return false
			player.nitro_timer = 1.85
			player.nitro_cooldown = 10.0
		2:
			if player.repair_cooldown > 0.0 or player.coins < 15 or player.hp >= player.max_hp:
				return false
			player.coins -= 15
			player.hp = minf(player.max_hp, player.hp + player.repair_power)
			player.repair_cooldown = 5.0
		1:
			if not player.has_bumper or player.ram_cooldown > 0.0:
				return false
			player.ram_timer = 0.9
			player.ram_cooldown = 8.0 * player.ram_cd_mult
		_:
			return false
	_emit("ability", {"slot": slot, "position": player.position})
	return true

func _tick_abilities(delta: float) -> void:
	player.visual_scale = Dimensions.advance_scale(player.visual_scale, player.level, delta)
	player.radius = Dimensions.radius(player.visual_scale)
	if player.hp < player.max_hp * 0.18 and player.get("low_hp_sfx_remaining", 0.0) <= 0.0:
		_emit("low_hp", {"position": player.position})
		player.low_hp_sfx_remaining = 1.1
	player.low_hp_sfx_remaining = maxf(0.0, player.get("low_hp_sfx_remaining", 0.0) - delta)
	refresh_build_protocols()
	protocols.pulse(player)
	for key in ["nitro_timer", "ram_timer", "repair_cooldown", "ram_cooldown"]:
		player[key] = maxf(0.0, player[key] - delta)
	player.nitro_cooldown = maxf(0.0, player.nitro_cooldown - delta * player.nitro_recovery)
	if player.hp < player.max_hp * 0.35:
		player.hp = minf(player.max_hp, player.hp + player.regen_rate * delta)

func refresh_build_protocols() -> void:
	var targets: Array[Dictionary] = enemies.duplicate()
	targets.append_array(_boss_components())
	protocols.sync(player, targets)

func snapshot() -> Dictionary:
	return {"generation": generation, "wave": wave, "final_wave": Waves.FINAL_WAVE,
		"status": status, "phase": status, "weather_type": weather_type, "running": running, "elapsed": elapsed,
		"threat": clampf((wave - 1) * 12.0 + minf(58.0, _wave_remaining() * 2.0), 0.0, 100.0),
		"intermission": intermission, "remaining": spawn_queue.size() + _wave_remaining(),
		"safe_radius": Waves.radius(wave), "kills": player.kills, "scrap": player.coins,
		"coins": player.coins, "health": player.hp, "max_health": player.max_hp,
		"level": player.level, "xp": player.xp, "xp_next": player.xp_next,
		"mines": hazards.mines.duplicate(true), "hack_status": hazards.hack_status.duplicate(),
		"salvage_charge": protocols.salvage_charge, "focus_id": focus_id, "player": player.duplicate(true), "weapons": weapons.duplicate(true),
		"boss_components": _boss_components().duplicate(true), "enemies": enemies.duplicate(true), "projectiles": projectiles.duplicate(true), "pickups": pickups.duplicate(true)}

func drain_events() -> Array[Dictionary]:
	var result := events.duplicate()
	events.clear()
	return result

func _finish(won: bool, reason: String = "") -> void:
	jammer.reset(player, jammer.seed_value)
	if status in ["dead", "complete", "extracted"]:
		return
	status = "extracted" if reason == "extracted" else "complete" if won else "dead"
	hazards.reset()
	running = false
	spawn_queue.clear()
	_emit("result", {"won": won, "reason": reason, "extracted": reason == "extracted", "wave": wave, "kills": player.kills, "elapsed": elapsed, "position": player.position})

func _boss_components() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy: Dictionary in enemies:
		if enemy.get("boss", false) and not enemy.dead:
			Leviathan.sync(enemy)
			result.append_array(enemy.components)
	return result

func _target_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy: Dictionary in enemies:
		if not enemy.dead and enemy.get("targetable", true):
			result.append(enemy)
	for component: Dictionary in _boss_components():
		if not component.dead and component.exposed:
			result.append(component)
	return result

func _wave_remaining() -> int:
	var count := 0
	for enemy: Dictionary in enemies:
		if not enemy.dead and enemy.get("counts_toward_wave", true):
			count += 1
	return count

func _target_aim(enemy: Dictionary) -> Vector3:
	if enemy.get("is_component", false):
		return enemy.position
	var height: float = enemy.height if enemy.type in ["drone", "garrison"] else 2.8 if enemy.type == "keep" else 1.05
	return enemy.position + Vector3.UP * (height + Terrain.height_at(enemy.position.x, enemy.position.z))

func _aim_center(enemy: Dictionary) -> Vector3:
	if enemy.get("is_component", false):
		return enemy.position
	var height: float = enemy.height if enemy.type in ["drone", "garrison"] else 2.5 if enemy.type == "keep" else 1.5 if enemy.type == "buggy" else 1.0 if enemy.type == "bike" else 1.05
	return enemy.position + Vector3.UP * (height + Terrain.height_at(enemy.position.x, enemy.position.z))

func _id() -> int:
	var result := _next_id
	_next_id += 1
	return result

func _emit(kind: String, data: Dictionary) -> void:
	data.kind = kind
	data.generation = generation
	events.append(data)
	if events.size() > 512:
		events.pop_front()

func weather_range_multiplier(radar: bool = false, npc: bool = false) -> float:
	var strength := weather_fog_strength if weather_fog_strength >= 0 else (1.0 if weather_type == "foggy" else 0.0)
	return preload("res://modules/world/weather_rules.gd").visibility_multiplier(strength, radar, npc)

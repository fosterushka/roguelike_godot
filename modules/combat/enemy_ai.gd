extends RefCounted
const Catalog = preload("res://modules/combat/enemy_catalog.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")

const Evasion = preload("res://modules/combat/drone_evasion.gd")
const Priority = preload("res://modules/combat/priority_rules.gd")

static func steer(model, enemy: Dictionary, direction: Vector3, speed: float) -> Vector3:
	if model.enemy_steering_query.is_valid():
		return model.enemy_steering_query.call(enemy, direction, speed)
	return direction

static func heading(current: float, desired: float, rate: float, delta: float) -> float:
	return current + wrapf(desired - current, -PI, PI) * (1.0 - exp(-rate * delta))

static func move(model, enemy: Dictionary, delta: float, speed: float, distance: float, direction: Vector3) -> void:
	var old: Vector3 = enemy.position
	enemy.visual_effective_speed = speed
	enemy.deploying = false
	enemy.animation_time = enemy.get("animation_time", 0.0) + delta
	enemy.attack_animation = maxf(0.0, enemy.get("attack_animation", 0.0) - delta * 4.4)
	var turn_mult: float = enemy.get("weather_turn_multiplier", 1.0)
	if enemy.type == "soldier":
		if enemy.get("spawn_timer", 0.0) > 0.0:
			enemy.deploying = true
			enemy.spawn_timer = maxf(0.0, enemy.spawn_timer - delta)
			var progress: float = 1.0 - enemy.spawn_timer / enemy.spawn_duration
			enemy.position = Vector3(enemy.spawn_start).lerp(enemy.spawn_exit, smoothstep(0.0, 1.0, progress))
			enemy.yaw = atan2(enemy.spawn_exit.x - enemy.spawn_start.x, enemy.spawn_exit.z - enemy.spawn_start.z)
			enemy.move_blend = 1.0
			return
		var desired := direction
		var blend := 0.0
		var gait := 1.0
		if distance > enemy.preferred:
			desired = steer(model, enemy, direction, speed)
			enemy.position += desired * speed * delta
			blend = 1.0
		elif enemy.kind != "bomber" and distance < enemy.preferred * 0.58:
			desired = steer(model, enemy, -direction, speed * 0.5)
			enemy.position += desired * speed * 0.5 * delta
			desired = -desired
			blend = 0.55
			gait = -1.0
		enemy.move_blend = enemy.get("move_blend", 0.0) + (blend - enemy.get("move_blend", 0.0)) * (1.0 - pow(0.0005, delta))
		enemy.gait_direction = enemy.get("gait_direction", 1.0) + (gait - enemy.get("gait_direction", 1.0)) * (1.0 - pow(0.002, delta))
		enemy.phase_animation = enemy.get("phase_animation", 0.0) + delta * (4.8 + enemy.speed * 1.15) * maxf(0.12, enemy.get("move_blend", 0.0))
		enemy.yaw += wrapf(atan2(desired.x, desired.z) - enemy.yaw, -PI, PI) * (1.0 - pow(0.0008, delta))
	elif enemy.type == "drone":
		var desired := atan2(direction.x, direction.z)
		var turn := wrapf(desired - enemy.yaw, -PI, PI)
		enemy.yaw += turn * delta * (3.4 if enemy.kind == "kamikaze" else 2.6)
		var evasion := Evasion.advance(enemy, model.projectiles, delta)
		enemy.dodging = not evasion.is_zero_approx()
		var strafe := sin(model.elapsed * 0.9 + enemy.yaw) * 0.65 if enemy.kind == "shooter" else 0.0
		var throttle := 1.0 if enemy.kind == "kamikaze" or distance > enemy.preferred else -0.55 if distance < enemy.preferred * 0.7 else 0.08
		enemy.position += (direction * throttle + Vector3(direction.z, 0.0, -direction.x) * strafe + evasion) * speed * delta
		enemy.position = enemy.position.limit_length(maxf(20.0, model.Waves.radius(model.wave) - 36.0))
		enemy.height = enemy.get("flight_height", enemy.height) + sin(model.elapsed * 2.7 + enemy.yaw) * (0.12 if enemy.kind == "kamikaze" else 0.22)
		enemy.roll = -turn * 0.12 + evasion.x * 0.18
	elif enemy.type in ["bike", "buggy", "priorityVehicle"]:
		var support: Dictionary = Priority.support(model, enemy, delta) if enemy.type == "priorityVehicle" else {}
		var offset: Vector3 = (support.position if not support.is_empty() else model.player.position) - enemy.position
		offset.y = 0.0
		var target_distance := maxf(0.001, offset.length())
		var throttle := 1.0
		var rate := 2.8 if enemy.type == "bike" else 1.7
		if enemy.type == "buggy":
			throttle = -0.35 if distance < 13.0 else 0.2 if distance < 20.0 else 1.0
		elif enemy.type == "priorityVehicle":
			throttle = 1.0 if target_distance > enemy.preferred else -0.32 if target_distance < enemy.preferred * 0.62 else 0.18
			if enemy.kind == "repairCrawler" and not support.is_empty() and target_distance < 9.0:
				throttle = 0.0
			rate = 1.25 if enemy.kind == "repairCrawler" else 1.55
		enemy.visual_throttle = throttle
		var movement_sign := -1.0 if throttle < 0.0 else 1.0
		var navigation := steer(model, enemy, offset.normalized() * movement_sign, speed * absf(throttle)) * movement_sign
		enemy.yaw = heading(enemy.yaw, atan2(navigation.x, navigation.z), rate * turn_mult, delta)
		enemy.position += Vector3(sin(enemy.yaw), 0.0, cos(enemy.yaw)) * speed * throttle * delta
		enemy.position = enemy.position.limit_length(maxf(20.0, model.Waves.radius(model.wave) - 40.0))
		if enemy.kind == "repairCrawler":
			Priority.heal(model, enemy, support, delta)
		elif enemy.kind == "minelayer" and absf(speed * throttle * delta) > 0.01:
			enemy.mine_drop_remaining = enemy.get("mine_drop_remaining", 4.0) - delta
			if enemy.mine_drop_remaining <= 0.000001:
				model.hazards.drop(model, enemy)
				enemy.mine_drop_remaining = 4.0
	elif enemy.type == "keep":
		var navigation := steer(model, enemy, direction, speed)
		enemy.yaw = heading(enemy.yaw, atan2(navigation.x, navigation.z), (1.35 if enemy.get("boss", false) else 2.1) * turn_mult, delta)
		if distance > enemy.radius + 12.0:
			enemy.position += Vector3(sin(enemy.yaw), 0.0, cos(enemy.yaw)) * speed * delta
		enemy.position = enemy.position.limit_length(maxf(20.0, model.Waves.radius(model.wave) - 30.0))
	if enemy.type != "drone" and model.enemy_motion_query.is_valid():
		enemy.position = model.enemy_motion_query.call(enemy, old, enemy.position)
	enemy.velocity = (enemy.position - old) / maxf(delta, 0.000001)

static func attack(model, enemy: Dictionary, delta: float, cadence: float, distance: float, jammed: bool) -> void:
	if enemy.get("deploying", false):
		return
	if enemy.kind == "bomber":
		if distance <= 3.4:
			model.damage_player(enemy.damage)
			model._emit("enemy_detonation", {"id": enemy.id, "position": enemy.position, "radius": 5.2})
			model.kill_enemy(enemy)
		return
	if enemy.kind == "kamikaze":
		if distance <= 4.2 and not jammed:
			model.damage_player(enemy.damage)
			model.kill_enemy(enemy)
		return
	if enemy.get("boss", false):
		model.Leviathan.step(model, enemy, delta * cadence, distance)
		if distance < enemy.radius + 3.5:
			model.damage_player(delta * cadence * 28.0)
		return
	if enemy.type in ["bike", "buggy"] and distance < enemy.radius + 3.1:
		model.damage_player(delta * cadence * (7.0 if enemy.type == "bike" else 12.0))
	elif enemy.type == "keep" and distance < enemy.radius + 3.5:
		model.damage_player(delta * cadence * 16.0)
	enemy.cooldown -= delta * cadence
	var range_mult: float = model.weather_range_multiplier(false, true)
	if enemy.cooldown > 0.0 or enemy.damage <= 0.0 or distance >= enemy.range * range_mult:
		return
	if enemy.type == "garrison" and enemy.position.length() >= model.Waves.radius(model.wave):
		return
	var height := 1.3
	var aim_height := 2.4
	var lead := 0.22
	match enemy.type:
		"drone":
			height = enemy.height - 0.2
			aim_height = 2.3
			lead = 0.28
		"buggy":
			height = 2.1
			lead = 0.24
		"priorityVehicle":
			height = 2.35
			lead = 0.24
		"garrison":
			height = enemy.height * Catalog.GARRISON_AIM_HEIGHT_RATIO
			lead = 0.32
		"keep":
			height = 4.0
			lead = 0.42
	var origin: Vector3 = enemy.position + Vector3.UP * (height + Terrain.height_at(enemy.position.x, enemy.position.z))
	var forward := Vector3(sin(model.player.heading), 0.0, cos(model.player.heading))
	var aim: Vector3 = model.player.position + Vector3.UP * aim_height + forward * model.player.speed * lead
	if model.enemy_target_query.is_valid():
		var target: Dictionary = model.enemy_target_query.call(origin)
		if not target.is_empty():
			aim = target.position + Vector3(target.get("velocity", Vector3.ZERO)) * lead
	model.fire_projectile(enemy.get("projectile", "bullet"), "enemy", origin, aim, enemy.damage)
	enemy.cooldown = (enemy.interval + model.random.randf_range(0.0, enemy.get("jitter", 0.0))) * 1.4
	enemy.attack_animation = 1.0

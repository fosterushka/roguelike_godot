extends RefCounted
const Dimensions = preload("res://modules/caravan/player_dimensions.gd")

var momentum := 0.0
var combo := 0
var multiplier := 1.0
var grace := 0.0
var drift_distance := 0.0

func reset() -> void:
	momentum = 0.0
	combo = 0
	multiplier = 1.0
	grace = 0.0
	drift_distance = 0.0

func record(gain: float) -> void:
	if gain <= 0.0:
		return
	combo = combo + 1 if grace > 0.0 else 1
	multiplier = 3.0 if combo >= 10 else 2.0 if combo >= 6 else 1.5 if combo >= 3 else 1.0
	momentum = clampf(momentum + gain * multiplier, 0.0, 1.0)
	grace = 3.0

func decay(delta: float, rate: float) -> void:
	var decay_time := maxf(0.0, delta - grace)
	grace = maxf(0.0, grace - delta)
	if grace <= 0.0:
		combo = 0
		multiplier = 1.0
		momentum = maxf(0.0, momentum - decay_time * rate)

func step(player: Dictionary, delta: float) -> void:
	var speed := absf(float(player.speed))
	var rate := 0.025 if speed > 3.0 else 0.075
	var retention: float = maxf(0.0, player.get("momentum_decay_mult", 1.0))
	var eligible: bool = player.get("handbraking", false) and speed >= 4.5 and absf(float(player.get("slip_angle", 0.0))) >= 0.18
	if drift_distance >= 7.0:
		drift_distance = 0.0
	if not eligible:
		decay(delta * retention, rate)
	else:
		var remaining := delta
		var event_count := 0
		while remaining > 0.0 and event_count < 16:
			var crossing := (7.0 - drift_distance) / speed
			if crossing > remaining + 0.000000001:
				decay(remaining * retention, rate)
				drift_distance += speed * remaining
				remaining = 0.0
			else:
				crossing = minf(crossing, remaining)
				decay(crossing * retention, rate)
				remaining = maxf(0.0, remaining - crossing)
				drift_distance = 0.0
				record(0.035)
				event_count += 1
		if remaining > 0.0:
			decay(remaining * retention, rate)
	player.momentum = momentum
	player.road_fury_combo = combo
	player.road_fury_multiplier = multiplier

func collide(model, enemy: Dictionary, distance: float, delta: float) -> void:
	var player: Dictionary = model.player
	var speed := absf(float(player.speed))
	var visual_scale: float = player.get("visual_scale", minf(1.42, 0.88 + (player.level - 1) * 0.075))
	var contact: float = Dimensions.radius(visual_scale) + enemy.radius
	enemy.collision_cooldown = maxf(0.0, enemy.collision_cooldown - delta)
	if distance >= contact:
		if enemy.type in ["bike", "buggy"]:
			if distance > contact + 5.0:
				enemy.near_miss_armed = true
			elif distance <= contact + 2.5 and enemy.get("near_miss_armed", true) and speed >= 4.5:
				record(0.08)
				enemy.near_miss_armed = false
		return
	enemy.near_miss_armed = false
	var normal: Vector3 = (enemy.position - player.position).normalized()
	if normal.is_zero_approx():
		normal = Vector3.FORWARD
	var forward := Vector3(sin(player.heading), 0.0, cos(player.heading)) * (1.0 if player.speed >= 0 else -1.0)
	var small: bool = enemy.type in ["soldier", "bike", "buggy", "drone"]
	var ready: bool = enemy.collision_cooldown <= 0.0
	if small:
		if speed > 0.75 and ready:
			model.damage_enemy(enemy.id, 9999.0)
			model._emit("roadkill_impact", {"position": enemy.position, "enemy_type": enemy.type})
			if speed >= 4.5 and enemy.dead and enemy.type != "drone":
				record(0.1)
		else:
			enemy.position += normal * (contact - distance + 0.08) + forward * 0.3
		return
	var overlap := contact - distance
	var charged: bool = player.ram_timer > 0.0
	var bumper: bool = player.has_bumper and enemy.type == "keep" and speed > 2.05 and ready
	if bumper:
		var impact: Vector3 = (enemy.position + player.position) * 0.5
		impact.y = 1.7
		var facing := maxf(0.2, normal.dot(forward))
		var charge := 2.15 if charged else 1.0
		model.Protocols.ram(player, enemy, model.elapsed)
		model.damage_enemy(enemy.id, (22.0 + speed * 11.0) * facing * charge * (1.0 + momentum * 0.6))
		enemy.position += normal * (overlap + 0.7) + forward * 0.65
		enemy.shove_velocity = enemy.get("shove_velocity", Vector3.ZERO) + normal * (5.8 + speed * 1.2) * charge + forward * 3.0
		player.position -= normal * overlap * 0.18
		player.speed *= 0.9 if charged else 0.76
		model._emit("ram_impact", {"position": impact, "speed": speed, "bumper": true, "boss": enemy.get("boss", false)})
		enemy.collision_cooldown = 0.55
	else:
		player.position -= normal * overlap * 0.72
		if enemy.type != "garrison":
			enemy.position += normal * overlap * 0.18
			enemy.shove_velocity = enemy.get("shove_velocity", Vector3.ZERO) + normal * overlap * 1.8
		if speed > 1.7 and ready:
			var impact: Vector3 = (enemy.position + player.position) * 0.5
			impact.y = 1.4
			model.Protocols.ram(player, enemy, model.elapsed)
			model.damage_enemy(enemy.id, (8.0 + speed * 7.5) * (3.8 if charged else 1.0) * (1.0 + momentum * 0.3))
			if not charged:
				model.damage_player(maxf(2.0, speed * 1.35))
			model._emit("ram_impact", {"position": impact, "speed": speed, "bumper": false, "boss": enemy.get("boss", false)})
			enemy.collision_cooldown = 0.48
			player.speed *= 0.66 if charged else -0.18
		elif player.speed > 0.0:
			player.speed *= 0.82
	if ready and speed >= 4.5:
		record(0.18 if charged else 0.12)
	player.momentum = momentum

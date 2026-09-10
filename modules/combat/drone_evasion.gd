extends RefCounted
const Seed = preload("res://modules/combat/rocket_rules.gd")

static func profile(enemy: Dictionary) -> Dictionary:
	return enemy.behavior.evasion

static func dodge_sample(seed_value: int, attempt: int) -> float:
	return Seed._unit(seed_value, ((maxi(0, attempt) + 1) * 0x9e3779b9) & 0xffffffff)

static func threat(enemy: Dictionary, projectiles: Array[Dictionary]) -> Dictionary:
	var profile := profile(enemy)
	var nearest: Dictionary = {}
	var center: Vector3 = enemy.position + Vector3.UP * enemy.height
	for shot: Dictionary in projectiles:
		if shot.dead or shot.team != "player" or shot.kind != "bullet":
			continue
		var horizontal := Vector2(shot.velocity.x, shot.velocity.z)
		if horizontal.length_squared() < 0.0001:
			continue
		var offset := Vector2(center.x - shot.position.x, center.z - shot.position.z)
		var time := offset.dot(horizontal) / horizontal.length_squared()
		if time <= 0.0 or time > profile.reaction:
			continue
		var closest: Vector3 = shot.position + shot.velocity * time
		var radius := maxf(profile.minimum_radius, enemy.radius + shot.radius + profile.padding)
		if center.distance_squared_to(closest) > radius * radius or (not nearest.is_empty() and nearest.time <= time):
			continue
		var sign_value: float = enemy.get("dodge_sign", 1.0)
		nearest = {"shot_id": shot.id, "direction": Vector3(-horizontal.y, 0, horizontal.x).normalized() * sign_value, "urgency": 1.0 - time / profile.reaction, "time": time}
	return nearest

static func advance(enemy: Dictionary, projectiles: Array[Dictionary], delta: float) -> Vector3:
	var profile := profile(enemy)
	enemy.dodge_cooldown = maxf(0.0, enemy.get("dodge_cooldown", 0.0) - delta)
	enemy.dodge_remaining = maxf(0.0, enemy.get("dodge_remaining", 0.0) - delta)
	if enemy.dodge_remaining > 0.0:
		return enemy.get("dodge_vector", Vector3.ZERO)
	var candidate := threat(enemy, projectiles)
	if candidate.is_empty() or candidate.shot_id == enemy.get("dodge_threat_id", -1):
		return Vector3.ZERO
	enemy.dodge_threat_id = candidate.shot_id
	if enemy.dodge_cooldown > 0.0:
		return Vector3.ZERO
	var attempt: int = enemy.get("dodge_attempt", 0)
	enemy.dodge_attempt = attempt + 1
	enemy.dodge_cooldown = profile.cooldown
	if dodge_sample(enemy.get("dodge_seed", 0), attempt) >= profile.chance:
		return Vector3.ZERO
	enemy.dodge_remaining = profile.duration
	enemy.dodge_vector = candidate.direction * (profile.strength + candidate.urgency * profile.urgency_strength)
	return enemy.dodge_vector

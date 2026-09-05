extends RefCounted

static func valid_repair(owner: Dictionary, target: Dictionary) -> bool:
	return not target.is_empty() and target != owner and not target.dead and target.hp > 0.0 and target.hp < target.max_hp and target.get("counts_as_hostile", true) and target.get("repairable", true) and not target.get("boss", false) and not target.get("is_component", false) and target.position.distance_squared_to(owner.position) <= 36.0 * 36.0

static func repair_target(owner: Dictionary, enemies: Array[Dictionary]) -> Dictionary:
	var selected: Dictionary = {}
	var best_ratio := INF
	var best_distance := INF
	for candidate: Dictionary in enemies:
		if not valid_repair(owner, candidate):
			continue
		var ratio: float = candidate.hp / candidate.max_hp
		var distance: float = candidate.position.distance_squared_to(owner.position)
		if ratio < best_ratio or (is_equal_approx(ratio, best_ratio) and distance < best_distance):
			selected = candidate
			best_ratio = ratio
			best_distance = distance
	return selected

static func support(model, enemy: Dictionary, delta: float) -> Dictionary:
	if enemy.kind != "repairCrawler":
		return {}
	enemy.repair_recheck = enemy.get("repair_recheck", 0.0) - delta
	var target: Dictionary = {}
	for candidate: Dictionary in model.enemies:
		if candidate.id == enemy.get("repair_target_id", -1):
			target = candidate
	if enemy.repair_recheck <= 0.0:
		target = repair_target(enemy, model.enemies)
		enemy.repair_recheck = 0.25
	elif not valid_repair(enemy, target):
		target = {}
	enemy.repair_target_id = target.get("id", -1)
	return target

static func heal(model, enemy: Dictionary, target: Dictionary, delta: float) -> void:
	enemy.repair_pulse = maxf(0.0, enemy.get("repair_pulse", 0.0) - delta)
	if target.is_empty() or not valid_repair(enemy, target):
		enemy.repair_beam_target = Vector3.ZERO
		return
	var before: float = target.hp
	target.hp = minf(target.max_hp, target.hp + clampf(delta, 0.0, 0.25) * 12.0)
	enemy.repair_beam_target = target.position
	if target.hp > before and enemy.repair_pulse <= 0.0:
		enemy.repair_pulse = 0.85
		model._emit("repair_pulse", {"id": enemy.id, "position": enemy.position, "target_position": target.position})

static func jammed(player: Dictionary, enemies: Array[Dictionary]) -> bool:
	return not preload("res://modules/combat/jammer_rules.gd").source(player, enemies).is_empty()

extends RefCounted

var mines: Array[Dictionary] = []
var hack_status: Dictionary = {}
var _previous_player := Vector3.ZERO
var _has_previous := false

func reset() -> void:
	mines.clear()
	hack_status = {"available": false, "active": false, "progress": 0.0, "mine_id": -1}
	_previous_player = Vector3.ZERO
	_has_previous = false

func drop(model, owner: Dictionary) -> Dictionary:
	if not model.running or owner.is_empty() or owner.dead or mines.size() >= 36:
		return {}
	var count := 0
	for mine: Dictionary in mines:
		if not mine.dead and mine.owner == owner.id:
			count += 1
	if count >= 6:
		return {}
	var position: Vector3 = owner.position - Vector3(sin(owner.yaw), 0.0, cos(owner.yaw)) * (owner.radius + 1.35)
	var mine := {"id": model._id(), "owner": owner.id, "position": position, "arm_remaining": 0.9,
		"life": 25.0, "radius": 2.35, "damage": 30.0, "allegiance": "enemy", "hack_progress": 0.0,
		"armed": false, "triggered": false, "dead": false}
	mines.append(mine)
	model._emit("mine_drop", {"id": mine.id, "position": position})
	return mine

func step(model, delta: float) -> void:
	if not model.running:
		return
	var player: Dictionary = model.player
	if not _has_previous:
		_previous_player = player.position
		_has_previous = true
	var candidate: Dictionary = {}
	var nearest := 4.5 * 4.5
	for mine: Dictionary in mines:
		mine.life = maxf(0.0, mine.life - delta)
		mine.arm_remaining = maxf(0.0, mine.arm_remaining - delta)
		mine.armed = mine.arm_remaining <= 0.000001
		mine.dead = mine.dead or mine.life <= 0.0
		if mine.dead or not mine.armed or mine.allegiance == "friendly":
			continue
		var distance: float = mine.position.distance_squared_to(player.position)
		if distance <= nearest:
			nearest = distance
			candidate = mine
	hack_status = {"available": not candidate.is_empty(), "active": false, "progress": 0.0, "mine_id": -1}
	for mine: Dictionary in mines:
		if mine.dead:
			continue
		if mine.allegiance != "friendly":
			var hacking: bool = mine == candidate and player.get("interact", false)
			mine.hack_progress = clampf(mine.hack_progress + delta * (1.0 if hacking else -2.0), 0.0, 3.0)
			if mine.hack_progress >= 3.0 - 0.000001:
				mine.allegiance = "friendly"
				model._emit("mine_hacked", {"id": mine.id, "position": mine.position})
			elif mine == candidate:
				hack_status = {"available": true, "active": hacking, "progress": mine.hack_progress / 3.0, "mine_id": mine.id}
		if not mine.armed:
			continue
		if mine.allegiance == "friendly":
			for enemy: Dictionary in model.enemies:
				if not enemy.dead and mine.position.distance_squared_to(enemy.position) <= mine.radius * mine.radius:
					mine.dead = true
					break
			if mine.dead:
				for enemy: Dictionary in model.enemies:
					if not enemy.dead and mine.position.distance_squared_to(enemy.position) <= mine.radius * mine.radius:
						model.damage_enemy(enemy.id, mine.damage)
		else:
			if model.Shots.hits(_previous_player * Vector3(1, 0, 1), player.position * Vector3(1, 0, 1), mine.position, mine.radius):
				mine.dead = true
				model.damage_player(mine.damage)
		if mine.dead:
			mine.triggered = true
			model._emit("mine_explosion", {"id": mine.id, "position": mine.position, "radius": mine.radius})
	_previous_player = player.position
	mines = mines.filter(func(mine: Dictionary) -> bool: return not mine.dead)

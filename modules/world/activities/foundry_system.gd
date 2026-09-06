extends RefCounted
const RandomSource = preload("res://modules/world/activities/source_random.gd")
var world: Node3D
var activities: RefCounted
var random := RandomSource.new()
var foundries: Array[Dictionary] = []
var colliders: Array[StaticBody3D] = []
var pending: Array[Dictionary] = []
var spawned := false
var decision_remaining := 1.4

func setup(runtime: Node3D, activity_system: RefCounted) -> void:
	world = runtime
	activities = activity_system
	var collision_root := Node3D.new()
	collision_root.name = "FoundryColliders"
	world.add_child(collision_root)
	for index in 10:
		var collider := StaticBody3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 5.5
		shape.height = 8.0
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collider.add_child(collision)
		collider.collision_layer = 0
		collision_root.add_child(collider)
		colliders.append(collider)

func reset(seed_value: int) -> void:
	for foundry in foundries:
		foundry.enemy.dead = true
	foundries.clear()
	pending.clear()
	world.props.dynamic_solids.clear()
	for collider in colliders:
		collider.collision_layer = 0
	spawned = false
	decision_remaining = 1.4
	random.seed_run(seed_value ^ 0x15ab74)

func step(delta: float) -> void:
	if not spawned:
		_spawn_network()
	for foundry in foundries:
		if foundry.enemy.dead and not foundry.get("reward_claimed", false):
			foundry.reward_claimed = true
			activities.credits += 1
			world.combat.model.player.activity_credits = activities.credits
			world.combat.model._emit("activity_completed", {"id": "%d:foundry-%d" % [world.combat.model.generation, foundry.enemy.id], "activity_type": "foundryDestroyed", "weather": world.weather.phase.type, "position": foundry.enemy.position, "loot_source": "foundry", "loot_count": 1, "reward_info": {"reward_label": "Rare upgrade cargo"}})
		foundry.solid.destroyed = foundry.enemy.dead
		colliders[foundry.index].collision_layer = 0 if foundry.enemy.dead else 1
		foundry.cooldown = maxf(0.0, foundry.cooldown - delta)
	for enemy: Dictionary in world.combat.model.enemies:
		var multiplier := 1.0
		if not enemy.dead and enemy.type != "garrison":
			for foundry in foundries:
				if not foundry.enemy.dead and enemy.position.distance_to(foundry.enemy.position) <= 90.0:
					multiplier = 1.2
					break
		enemy.encounter_movement_multiplier = multiplier
		enemy.encounter_cadence_multiplier = multiplier

func _step_legacy_dispatch(delta: float) -> void:
	_update_pending()
	decision_remaining -= delta
	if decision_remaining > 0:
		return
	decision_remaining = random.between(1.4, 2.6)
	if not activities._pressure_allows(1.0):
		return
	for foundry in foundries:
		if foundry.enemy.dead or foundry.cooldown > 0 or foundry.enemy.position.distance_to(world.vehicle.global_position) > 78:
			continue
		var point: Vector3 = foundry.enemy.position + Vector3(sin(foundry.enemy.yaw), 0, cos(foundry.enemy.yaw)) * (foundry.enemy.radius + 1.3)
		if not activities.position_clear(point) or point.distance_to(world.vehicle.global_position) < 5.25:
			continue
		var duration := random.between(1.5, 2)
		var record: Dictionary = {}
		if activities.elapsed >= activities.recovery_until:
			record = activities.announce("foundryDispatch", {"position": point, "source_id": foundry.enemy.id})
			if not record.is_empty():
				record.telegraph_until = activities.elapsed + duration
				record.starts_at = record.telegraph_until
				record.expires_at = record.telegraph_until + 60.0
		pending.append({"source": foundry, "position": point, "until": activities.elapsed + duration, "record": record})
		foundry.cooldown = 5.0
		break

func _spawn_network() -> void:
	spawned = true
	for attempt in 180:
		if foundries.size() >= 10:
			break
		var angle := random.between(0, TAU)
		var distance := sqrt(random.between(180.0 * 180.0, 1128.0 * 1128.0))
		var point := Vector3(cos(angle), 0, sin(angle)) * distance
		if point.distance_to(world.vehicle.global_position) < 170 or not world.props.is_clear(point, 6.0):
			continue
		var separated := true
		for site: Dictionary in activities.extraction_sites:
			separated = separated and point.distance_to(site.position) >= float(site.radius) + 12.0
		for foundry in foundries:
			separated = separated and foundry.enemy.position.distance_to(point) >= 120.0
		if not separated:
			continue
		var tier := 1 + foundries.size() % 3
		var enemy: Dictionary = world.combat.model.spawn_enemy("garrison_%d" % tier, point, {"counts_toward_wave": false, "world_source": true})
		if enemy.is_empty():
			break
		var solid := {"position": point, "radius": enemy.radius, "height": 8.0, "destroyed": false, "solid": true, "kind": "garrison"}
		var record := {"enemy": enemy, "solid": solid, "index": foundries.size(), "cooldown": random.between(2, 5)}
		colliders[record.index].position = point + Vector3.UP * 4.0
		colliders[record.index].collision_layer = 1
		colliders[record.index].get_child(0).shape.radius = enemy.radius
		foundries.append(record)
		world.props.dynamic_solids.append(solid)
		for index in 2 + tier:
			var guard_angle: float = enemy.yaw + random.between(-0.45, 0.45)
			var guard_point: Vector3 = point + Vector3(sin(guard_angle), 0, cos(guard_angle)) * (enemy.radius + random.between(0.7, 2.2))
			if activities.position_clear(guard_point):
				world.combat.model.spawn_enemy("ak" if random.next() < 0.28 else "rifleman", guard_point, {"counts_toward_wave": false, "world_source": true, "source_id": enemy.id})

func _update_pending() -> void:
	for deployment in pending.duplicate():
		var source: Dictionary = deployment.source
		if source.enemy.dead or source.enemy.position.distance_to(world.vehicle.global_position) > 78:
			if not deployment.record.is_empty():
				activities.finish(deployment.record, "failed", "Foundry signal lost")
			pending.erase(deployment)
			continue
		if activities.elapsed < deployment.until:
			continue
		if not activities.position_clear(deployment.position) or deployment.position.distance_to(world.vehicle.global_position) < 5.25:
			if not deployment.record.is_empty():
				activities.finish(deployment.record, "failed", "Foundry gate obstructed")
			pending.erase(deployment)
			continue
		var kind := "rifleman"
		var roll := random.next()
		if world.combat.model.wave >= 3 and roll > 0.84:
			kind = "bazooka"
		elif world.combat.model.wave >= 2 and roll > 0.62:
			kind = "ak"
		var enemy: Dictionary = world.combat.model.spawn_enemy(kind, deployment.position, {"counts_toward_wave": false, "world_source": true, "source_id": source.enemy.id})
		if not deployment.record.is_empty():
			if enemy.is_empty():
				activities.finish(deployment.record, "failed", "Foundry reinforcement canceled")
			else:
				activities.register_dispatch(str(source.enemy.id), deployment.position, [enemy], deployment.record)
		pending.erase(deployment)

func get_state() -> Array:
	var result: Array = []
	for foundry in foundries:
		if not foundry.enemy.dead:
			result.append({"id": foundry.enemy.id, "position": foundry.enemy.position, "tier": foundry.enemy.tier, "hp": foundry.enemy.hp, "max_hp": foundry.enemy.max_hp, "reward_label": "Rare upgrade cargo"})
	return result

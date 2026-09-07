extends RefCounted
const RandomSource = preload("res://modules/world/activities/source_random.gd")
const DefenseRules = preload("res://modules/world/activities/base_defense_rules.gd")
const BaseGeometry = preload("res://modules/world/activities/base_geometry_rules.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
var world: Node3D
var activities: RefCounted
var random := RandomSource.new()
var foundries: Array[Dictionary] = []
var colliders: Array[StaticBody3D] = []
var spawned := false

func setup(runtime: Node3D, activity_system: RefCounted) -> void:
	world = runtime
	activities = activity_system
	var collision_root := Node3D.new()
	collision_root.name = "FoundryColliders"
	world.add_child(collision_root)
	for index in DefenseRules.NETWORK_SIZE:
		var collider := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE
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
	world.props.dynamic_solids.clear()
	for collider in colliders:
		collider.collision_layer = 0
	spawned = false
	random.seed_run(seed_value ^ 0x15ab74)

func step(delta: float) -> void:
	if not spawned:
		_spawn_network()
	for foundry in foundries:
		if not foundry.has("defender_queue"):
			foundry.defender_queue = []
		if foundry.enemy.dead and not foundry.get("reward_claimed", false):
			foundry.reward_claimed = true
			activities.credits += 1
			world.combat.model.player.activity_credits = activities.credits
			world.combat.model._emit("activity_completed", {"id": "%d:foundry-%d" % [world.combat.model.generation, foundry.enemy.id], "activity_type": "foundryDestroyed", "weather": world.weather.phase.type, "position": foundry.enemy.position, "loot_source": "foundry", "loot_count": 1, "reward_info": {"reward_label": "Rare upgrade cargo"}})
		foundry.solid.destroyed = foundry.enemy.dead
		colliders[foundry.index].collision_layer = 0 if foundry.enemy.dead else DefenseRules.COLLIDER_LAYER
		foundry.response_cooldown = maxf(0.0, float(foundry.get("response_cooldown", 0.0)) - delta)
		_update_defense(foundry)
	_update_defender_queue()
	for enemy: Dictionary in world.combat.model.enemies:
		var multiplier := 1.0
		if not enemy.dead and enemy.type != "garrison":
			for foundry in foundries:
				if not foundry.enemy.dead and enemy.position.distance_to(foundry.enemy.position) <= 90.0:
					multiplier = 1.2
					break
		enemy.encounter_movement_multiplier = multiplier
		enemy.encounter_cadence_multiplier = multiplier

func _spawn_network() -> void:
	spawned = true
	for attempt in DefenseRules.SPAWN_ATTEMPTS:
		if foundries.size() >= DefenseRules.NETWORK_SIZE:
			break
		var angle := random.between(0, TAU)
		var distance := sqrt(random.between(DefenseRules.MIN_DISTANCE * DefenseRules.MIN_DISTANCE, DefenseRules.MAX_DISTANCE * DefenseRules.MAX_DISTANCE))
		var point := Vector3(cos(angle), 0, sin(angle)) * distance
		if point.distance_to(world.vehicle.global_position) < DefenseRules.PLAYER_CLEARANCE or not world.props.is_clear(point, 6.0):
			continue
		var separated := true
		for site: Dictionary in activities.extraction_sites:
			separated = separated and point.distance_to(site.position) >= float(site.radius) + DefenseRules.EXTRACTION_CLEARANCE
		for foundry in foundries:
			separated = separated and foundry.enemy.position.distance_to(point) >= DefenseRules.BASE_CLEARANCE
		if not separated:
			continue
		var tier := 1 + foundries.size() % 3
		var gate_yaw := random.between(0.0, TAU)
		var enemy: Dictionary = world.combat.model.spawn_enemy("garrison_%d" % tier, point, {"counts_toward_wave": false, "world_source": true, "yaw": gate_yaw})
		if enemy.is_empty():
			break
		var solid := {"position": point, "radius": enemy.radius, "height": enemy.height, "destroyed": false, "solid": true, "kind": "garrison"}
		var record := {"enemy": enemy, "solid": solid, "index": foundries.size(), "gate_yaw": gate_yaw, "last_hp": enemy.hp, "damage_since_response": 0.0, "response_cooldown": 0.0, "defender_queue": []}
		colliders[record.index].position = point + Vector3.UP * (Terrain.height_at(point.x, point.z) + float(enemy.height) * 0.5)
		colliders[record.index].rotation.y = float(enemy.yaw)
		colliders[record.index].collision_layer = DefenseRules.COLLIDER_LAYER
		colliders[record.index].get_child(0).shape.size = enemy.hitbox_size
		foundries.append(record)
		world.props.dynamic_solids.append(solid)
		for index in 2 + tier:
			var guard_angle: float = gate_yaw + random.between(-0.45, 0.45)
			var guard_point: Vector3 = point + Vector3(sin(guard_angle), 0, cos(guard_angle)) * (enemy.radius + random.between(0.7, 2.2))
			if activities.position_clear(guard_point):
				world.combat.model.spawn_enemy("ak" if random.next() < 0.28 else "rifleman", guard_point, {"counts_toward_wave": false, "world_source": true, "source_id": enemy.id})

func _update_defense(foundry: Dictionary) -> void:
	var base: Dictionary = foundry.enemy
	var previous_hp := float(foundry.get("last_hp", base.hp))
	var damage := maxf(0.0, previous_hp - float(base.hp))
	foundry.last_hp = base.hp
	if base.dead:
		foundry.defender_queue.clear()
		return
	if damage <= 0.0:
		return
	foundry.damage_since_response = float(foundry.damage_since_response) + damage
	if float(foundry.response_cooldown) > 0.0 or float(foundry.damage_since_response) + DefenseRules.DAMAGE_THRESHOLD_EPSILON < DefenseRules.damage_threshold(float(base.max_hp)):
		return
	foundry.damage_since_response = 0.0
	foundry.response_cooldown = DefenseRules.RESPONSE_COOLDOWN
	_schedule_defenders(foundry)

func _schedule_defenders(foundry: Dictionary) -> void:
	var base: Dictionary = foundry.enemy
	var gate_yaw: float = float(foundry.get("gate_yaw", base.get("yaw", 0.0)))
	var direction: Vector3 = Vector3(sin(gate_yaw), 0, cos(gate_yaw))
	var right: Vector3 = Vector3(direction.z, 0, -direction.x)
	var count := DefenseRules.defender_count(int(base.tier))
	for index in count:
		var centered := float(index) - float(count - 1) * 0.5
		var gate: Vector3 = base.position + direction * (float(base.radius) + DefenseRules.DEFENDER_RADIUS + DefenseRules.EXIT_CLEARANCE) + right * centered * DefenseRules.EXIT_LANE_SPACING
		if world.props.is_clear(gate, DefenseRules.DEFENDER_RADIUS):
			var door: Vector3 = base.position + direction * float(BaseGeometry.profile(int(base.tier)).door_distance) + right * centered * DefenseRules.EXIT_LANE_SPACING
			foundry.defender_queue.append({"until": activities.elapsed + float(index) * DefenseRules.EXIT_SPACING, "position": gate, "door": door, "yaw": gate_yaw, "kind": DefenseRules.defender_kind(int(base.tier), int(world.combat.model.wave), random)})

func _update_defender_queue() -> void:
	for foundry in foundries:
		if foundry.enemy.dead:
			continue
		for deployment in foundry.defender_queue.duplicate():
			if activities.elapsed < float(deployment.until):
				continue
			var enemy: Dictionary = world.combat.model.spawn_enemy(str(deployment.kind), deployment.door, {"counts_toward_wave": false, "world_source": true, "source_id": foundry.enemy.id, "yaw": deployment.yaw, "spawn_timer": DefenseRules.DEPLOY_DURATION, "spawn_duration": DefenseRules.DEPLOY_DURATION, "spawn_start": deployment.door, "spawn_exit": deployment.position})
			if not enemy.is_empty():
				enemy.yaw = float(deployment.yaw)
			foundry.defender_queue.erase(deployment)

func get_state() -> Array:
	var result: Array = []
	for foundry in foundries:
		if not foundry.enemy.dead:
			result.append({"id": foundry.enemy.id, "position": foundry.enemy.position, "tier": foundry.enemy.tier, "hp": foundry.enemy.hp, "max_hp": foundry.enemy.max_hp, "reward_label": "Rare upgrade cargo"})
	return result

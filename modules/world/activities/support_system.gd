extends RefCounted
const RandomSource = preload("res://modules/world/activities/source_random.gd")
const CaseRewards = preload("res://modules/world/activities/case_rewards.gd")
var world: Node3D
var random := RandomSource.new()
var case_random := RandomSource.new()
var case_generation := 0
var airdrops: Array[Dictionary] = []
var heal_carts: Array[Dictionary] = []
var airdrop_timer := 28.0
var healer_timer := 10.0
var next_id := 1
var events: Array[Dictionary] = []

func setup(runtime: Node3D) -> void:
	world = runtime

func reset(seed_value: int) -> void:
	random.seed_run(seed_value ^ 0x44ab7c)
	case_random.seed_run(seed_value ^ 0x6cc819)
	case_generation += 1
	airdrops.clear()
	heal_carts.clear()
	events.clear()
	next_id = 1
	airdrop_timer = random.between(28, 40)
	healer_timer = 10.0

func step(delta: float) -> void:
	airdrop_timer -= delta
	healer_timer -= delta
	if airdrop_timer <= 0 and airdrops.is_empty():
		var angle := random.between(0, TAU)
		var radius := clampf(world.vehicle.global_position.length() + random.between(90, 150), 80, world.PLAYABLE_RADIUS - 18.0)
		spawn_airdrop(Vector3(cos(angle), 0, sin(angle)) * radius)
		airdrop_timer = random.between(46, 64)
	if healer_timer <= 0 and heal_carts.is_empty():
		var angle := random.between(0, TAU)
		var radius := maxf(90.0, world.PLAYABLE_RADIUS - random.between(12, 22))
		spawn_healer(Vector3(cos(angle), 0, sin(angle)) * radius)
		healer_timer = random.between(42, 58)
	_update_airdrops(delta)
	_update_healers(delta)

func spawn_airdrop(point: Vector3) -> Dictionary:
	if not airdrops.is_empty():
		return {}
	var drop := {"id": next_id, "position": point, "height": 12.0, "age": 0.0, "yaw": 0.0, "vertical_speed": -4.4, "landed": false, "life": 90.0, "dead": false, "claimed": false}
	next_id += 1
	airdrops.append(drop)
	events.append({"kind": "airdrop_spawned", "position": point, "id": drop.id})
	return drop

func spawn_healer(point: Vector3) -> Dictionary:
	if not heal_carts.is_empty():
		return {}
	var cart := {"id": next_id, "position": point, "speed": 2.8, "yaw": random.between(0, TAU), "radius": 2.05, "heal": 90.0, "life": 48.0, "dead": false, "claimed": false, "target": _point_in_disc(10, world.PLAYABLE_RADIUS - 10)}
	next_id += 1
	cart.phase = random.between(0, TAU)
	cart.age = 0.0
	heal_carts.append(cart)
	events.append({"kind": "healer_spawned", "position": point, "id": cart.id})
	return cart

func _update_airdrops(delta: float) -> void:
	for drop in airdrops:
		drop.life -= delta
		drop.age += delta
		if not drop.landed:
			drop.yaw += delta * 0.18
			drop.vertical_speed = maxf(-7.2, drop.vertical_speed - 2.2 * delta)
			drop.height = maxf(0, drop.height + drop.vertical_speed * delta)
			if drop.height <= 0:
				drop.landed = true
				drop.vertical_speed = 0.0
				events.append({"kind": "airdrop_landed", "position": drop.position, "id": drop.id})
		elif drop.position.distance_to(world.vehicle.global_position) < 4.3 and not drop.claimed:
			drop.claimed = true
			drop.dead = true
			var player: Dictionary = world.combat.model.player
			var salvage := 24 + int(player.level) * 4
			player.coins += salvage
			var xp := roundi(salvage * 0.85)
			player.xp += xp
			var previous_fuel: float = world.vehicle.fuel
			world.vehicle.fuel = minf(world.vehicle.max_fuel, world.vehicle.fuel + 32 + player.level * 3)
			player.fuel = world.vehicle.fuel
			var guaranteed := {"salvage": salvage, "xp": xp, "fuel": world.vehicle.fuel - previous_fuel, "repair": 0.0}
			var receipt := CaseRewards.award(player, world.combat.model._catalog, world.vehicle, "airdrop", "airdrop:%d:%d" % [case_generation, drop.id], case_random, guaranteed)
			var winner: Dictionary = receipt.selected
			var blueprint: String = str(winner.get("type", "")) if winner.kind == "blueprint" else ""
			events.append({"kind": "airdrop_claimed", "id": drop.id, "position": drop.position, "target_position": world.vehicle.global_position, "yaw": drop.yaw, "salvage": salvage + (int(winner.amount) if winner.kind == "salvage" else 0), "xp": xp + (int(winner.amount) if winner.kind == "xp" else 0), "fuel": world.vehicle.fuel - previous_fuel, "blueprint": blueprint, "blueprint_name": str(winner.get("name", "")) if not blueprint.is_empty() else "", "case": receipt})
		drop.dead = drop.dead or drop.life <= 0.0
	airdrops = airdrops.filter(func(drop: Dictionary) -> bool: return not drop.dead)

func _update_healers(delta: float) -> void:
	for cart in heal_carts:
		cart.life -= delta
		cart.age += delta
		cart.phase += delta * 3
		var direction: Vector3 = cart.target - cart.position
		if direction.length() < 5.0:
			cart.target = _point_in_disc(8, world.PLAYABLE_RADIUS - 8)
			direction = cart.target - cart.position
		cart.yaw = lerpf(cart.yaw, atan2(direction.x, direction.z), 1.0 - pow(0.04, delta))
		cart.position += Vector3(sin(cart.yaw), 0, cos(cart.yaw)) * cart.speed * delta
		cart.position = cart.position.limit_length(world.PLAYABLE_RADIUS - 3)
		if cart.position.distance_to(world.vehicle.global_position) < cart.radius + 3.0 and not cart.claimed:
			var player: Dictionary = world.combat.model.player
			var missing: float = maxf(0.0, world.vehicle.max_health - world.vehicle.health)
			var amount := minf(missing, cart.heal + player.level * 5)
			world.vehicle.health += amount
			player.hp = world.vehicle.health
			cart.claimed = true
			cart.dead = true
			healer_timer = random.between(34, 46)
			var receipt := CaseRewards.award(player, world.combat.model._catalog, world.vehicle, "resource_car", "healer:%d:%d" % [case_generation, cart.id], case_random, {"salvage": 0, "xp": 0, "fuel": 0.0, "repair": amount})
			events.append({"kind": "healer_claimed", "id": cart.id, "position": cart.position, "target_position": world.vehicle.global_position, "yaw": cart.yaw, "amount": amount, "case": receipt})
		if cart.life <= 0:
			cart.dead = true
			healer_timer = minf(healer_timer, 8)
	heal_carts = heal_carts.filter(func(cart: Dictionary) -> bool: return not cart.dead)

func _point_in_disc(minimum: float, maximum: float) -> Vector3:
	var angle := random.between(0, TAU)
	return Vector3(cos(angle), 0, sin(angle)) * sqrt(random.between(minimum * minimum, maximum * maximum))

func get_state() -> Dictionary:
	return {"airdrops": airdrops.duplicate(true), "heal_carts": heal_carts.duplicate(true), "airdrop_timer": airdrop_timer, "healer_timer": healer_timer}

func drain_events() -> Array[Dictionary]:
	var result := events.duplicate()
	events.clear()
	return result

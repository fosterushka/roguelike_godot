extends RefCounted

const Catalog = preload("res://modules/crew/crew_catalog.gd")
const Wagons = preload("res://modules/caravan/wagon_catalog.gd")
var events: Array[Dictionary] = []
var _claims: Dictionary = {}

func reset() -> void:
	events.clear()
	_claims.clear()

func step(delta: float, player: Dictionary, wagons: Array, crew: Array, enemies: Array, pickups: Array, hooks: Dictionary = {}) -> void:
	if not is_finite(delta) or delta <= 0.0 or float(player.get("hp", 0)) <= 0:
		return
	var remaining := delta
	while remaining > 0.00000001:
		var chunk := minf(remaining, 0.05)
		_step_chunk(chunk, player, wagons, crew, enemies, pickups, hooks)
		remaining -= chunk

func _step_chunk(dt: float, player: Dictionary, wagons: Array, crew: Array, enemies: Array, pickups: Array, hooks: Dictionary) -> void:
	_claims.clear()
	for person: Dictionary in crew:
		if not person.get("dead", false) and person.has("pickup_id"):
			_claims[str(person.pickup_id)] = person.id
	for person: Dictionary in crew:
		if person.get("airborne", false) or float(person.get("tornado_recovery", 0)) > 0 or person.get("dead", false) or float(person.get("hp", 0)) <= 0 or person.get("faction", "neutral") != "ally" or not Catalog.ROLES.has(person.get("role", "")):
			continue
		var definition: Dictionary = Catalog.ROLES[person.role]
		var carrier := _carrier(person, player, wagons)
		if carrier.is_empty() or carrier.get("dead", false) or not carrier.get("attached", true):
			person.state = "waiting_carrier"
			continue
		var anchor: Vector3 = carrier.get("position", player.get("position", Vector3.ZERO))
		person.cooldown = maxf(0, float(person.get("cooldown", 0)) - dt)
		if person.boarded:
			person.position = anchor
			person.heading = float(carrier.get("heading", player.get("heading", 0)))
		elif definition.job not in ["collect", "collect_fuel"]:
			_return(person, anchor, float(definition.speed), dt, hooks)
			continue
		var factor := Wagons.job_factor(carrier, person.role, definition.job)
		match str(definition.job):
			"repair": _repair(person, carrier, definition.power * factor * dt, hooks)
			"reload": _reload(person, player, definition.power * factor * dt, hooks)
			"shoot": _shoot(person, enemies, definition, factor, hooks)
			"collect", "collect_fuel": _collect(person, player, anchor, pickups, enemies, definition, factor, dt, hooks)

func _carrier(person: Dictionary, player: Dictionary, wagons: Array) -> Dictionary:
	if person.carrier_id == "crawler":
		return player
	for wagon: Dictionary in wagons:
		if wagon.id == person.carrier_id:
			return wagon
	return {}

func _repair(person: Dictionary, target: Dictionary, amount: float, hooks: Dictionary) -> void:
	if not person.boarded or float(target.get("hp", 0)) <= 0 or float(target.get("hp", 0)) >= float(target.get("max_hp", 0)):
		person.state = "boarded"
		return
	var repaired := minf(amount, float(target.max_hp) - float(target.hp))
	var callback: Callable = hooks.get("repair", Callable())
	if callback.is_valid():
		repaired = maxf(0, float(callback.call(target, repaired, person)))
	else:
		target.hp += repaired
	if repaired > 0:
		person.state = "repairing"
		person.work_total = float(person.get("work_total", 0)) + repaired
		_emit_work(person, "crew_repaired", repaired)

func _reload(person: Dictionary, player: Dictionary, amount: float, hooks: Dictionary) -> void:
	if not person.boarded:
		return
	var weapons: Array = player.get("modules", [])
	var callback: Callable = hooks.get("weapons", Callable())
	if callback.is_valid():
		weapons = callback.call(person.carrier_id)
	var worked := 0.0
	for weapon: Dictionary in weapons:
		if weapon.get("mount", {}).get("carrierId", "crawler") != person.carrier_id or not weapon.get("def", {}).has("projectile"):
			continue
		var reduction := minf(amount, maxf(0, float(weapon.get("cooldown", 0))))
		weapon.cooldown = maxf(0, float(weapon.get("cooldown", 0)) - reduction)
		worked += reduction
	person.state = "reloading" if worked > 0 else "boarded"
	if worked > 0:
		person.work_total = float(person.get("work_total", 0)) + worked

func _shoot(person: Dictionary, enemies: Array, definition: Dictionary, factor: float, hooks: Dictionary) -> void:
	if not person.boarded or person.cooldown > 0:
		return
	var fire: Callable = hooks.get("fire", Callable())
	if not fire.is_valid():
		person.state = "waiting_weapon"
		return
	var target := {}
	var best := float(definition.range) * float(definition.range)
	for enemy: Dictionary in enemies:
		if enemy.get("dead", false) or not enemy.get("targetable", true) or enemy.get("faction", "enemy") != "enemy" or enemy.get("allegiance", "enemy") == "friendly":
			continue
		if not definition.targets.is_empty() and not definition.targets.has(enemy.get("type", "")):
			continue
		var distance: float = person.position.distance_squared_to(enemy.position)
		if distance <= best:
			best = distance
			target = enemy
	if target.is_empty():
		person.state = "boarded"
		return
	var shot: Dictionary = definition.duplicate(true)
	shot.damage = float(shot.damage) * factor
	if bool(fire.call(person, target, shot)):
		person.cooldown = float(definition.cooldown)
		person.state = "shooting"
		person.work_total = float(person.get("work_total", 0)) + 1
		_emit_work(person, "crew_fired", 1)

func _collect(person: Dictionary, player: Dictionary, anchor: Vector3, pickups: Array, enemies: Array, definition: Dictionary, factor: float, delta: float, hooks: Dictionary) -> void:
	if person.has("carried_parcel"):
		_return(person, anchor, definition.speed * factor, delta, hooks)
		return
	var recall: bool = not bool(player.get("crew_collect", false)) or absf(float(player.get("speed", 0))) > 1.5 or bool(person.get("recall", false))
	for enemy: Dictionary in enemies:
		if not enemy.get("dead", false) and enemy.get("faction", "enemy") == "enemy" and enemy.position.distance_to(person.position) < 7.0:
			recall = true
			break
	if recall:
		_return(person, anchor, definition.speed * factor, delta, hooks)
		return
	var pickup := {}
	var best := float(definition.range) * float(definition.range)
	for candidate: Dictionary in pickups:
		if candidate.get("dead", false) or int(candidate.get("count", 1)) <= 0:
			continue
		var key := str(candidate.get("id", ""))
		if key.is_empty() or (_claims.has(key) and _claims[key] != person.id):
			continue
		var fuel: bool = str(candidate.get("kind", candidate.get("pickup_kind", ""))) in ["fuel", "fuel_cell"]
		if fuel != (definition.job == "collect_fuel"):
			continue
		var distance: float = anchor.distance_squared_to(candidate.position)
		if distance <= best:
			best = distance
			pickup = candidate
	if pickup.is_empty():
		_return(person, anchor, definition.speed * factor, delta, hooks)
		return
	var key := str(pickup.id)
	if person.has("pickup_id") and str(person.pickup_id) != key:
		_claims.erase(str(person.pickup_id))
	_claims[key] = person.id
	person.pickup_id = key
	person.boarded = false
	person.state = "collecting"
	_move(person, pickup.position, definition.speed * factor, delta, hooks)
	if person.position.distance_to(pickup.position) > 1.5:
		return
	var collect: Callable = hooks.get("collect", Callable())
	if not collect.is_valid() or not bool(collect.call(person, pickup)):
		person.recall = true
	elif not person.has("carried_parcel"):
		# Test/custom adapters can complete an atomic pickup themselves.
		person.work_total = float(person.get("work_total", 0)) + 1
		_emit_work(person, "crew_collected", 1)
	_claims.erase(key)
	person.erase("pickup_id")
	_return(person, anchor, definition.speed * factor, delta, hooks)

func _move(person: Dictionary, destination: Vector3, speed: float, delta: float, hooks: Dictionary) -> void:
	var move: Callable = hooks.get("move", Callable())
	if not move.is_valid():
		person.state = "blocked"
		return
	var point: Variant = move.call(person, destination, speed, delta)
	if point is Vector3 and point.is_finite():
		var motion: Vector3 = point - person.position
		if motion.length_squared() > 0.0001:
			person.heading = atan2(motion.x, motion.z)
		person.position = point

func _return(person: Dictionary, anchor: Vector3, speed: float, delta: float, hooks: Dictionary) -> void:
	if person.has("pickup_id"):
		_claims.erase(str(person.pickup_id))
		person.erase("pickup_id")
	if person.position.distance_to(anchor) <= 2.0:
		if person.has("carried_parcel"):
			var delivery: Callable = hooks.get("deliver", Callable())
			if not delivery.is_valid() or not bool(delivery.call(person)):
				person.boarded = false
				person.state = "cargo_full"
				return
			person.work_total = float(person.get("work_total", 0)) + 1
			_emit_work(person, "crew_collected", 1)
		person.boarded = true
		person.position = anchor
		person.state = "boarded"
		person.recall = false
	else:
		person.boarded = false
		person.state = "returning"
		_move(person, anchor, speed, delta, hooks)

func _emit_work(person: Dictionary, kind: String, amount: float) -> void:
	# Repair emits at most one update per second; fire/collection are already rate limited.
	if kind == "crew_repaired":
		person.repair_report = float(person.get("repair_report", 0)) + amount
		if person.repair_report < 2.0:
			return
		amount = person.repair_report
		person.repair_report = 0.0
	if events.size() < 256:
		events.append({"kind": kind, "id": person.id, "role": person.role, "amount": amount, "total": float(person.get("work_total", 0)), "carrier_id": person.carrier_id})

func drain_events() -> Array[Dictionary]:
	var result := events.duplicate(true)
	events.clear()
	return result

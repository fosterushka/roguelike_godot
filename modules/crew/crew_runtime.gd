extends Node3D
const Factory = preload("res://modules/crew/crew_factory.gd")
const Catalog = preload("res://modules/crew/crew_catalog.gd")
const Cargo = preload("res://modules/crew/crew_cargo.gd")
const Service = preload("res://modules/crew/crew_service.gd")
const Navigation = preload("res://modules/crew/crew_navigation.gd")
const View = preload("res://presentation/crew/crew_view.gd")
const Air = preload("res://modules/world/airborne_motion.gd")
const Policy = preload("res://modules/world/destruction_policy.gd")
const Bounds = preload("res://modules/world/world_bounds.gd")
const Ground = preload("res://modules/caravan/terrain_surface.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
signal encounter_requested(person: Dictionary)
const Encounter = preload("res://modules/crew/crew_encounter.gd")
const Boarding = preload("res://modules/crew/crew_boarding.gd")
var reactions: Array[Dictionary] = []
var pending: Dictionary = {}
var expedition: RefCounted
var combat: Node
var world: Node
var vehicle: Node3D
var raid_loot: Node3D
var recruits: Array[Dictionary] = []
var service := Service.new()
var navigation := Navigation.new()
var view: Node3D
var _seed := 0

func setup(expedition_value: RefCounted, combat_value: Node, world_value: Node, vehicle_value: Node3D, loot_value: Node3D) -> void:
	expedition = expedition_value
	combat = combat_value
	world = world_value
	vehicle = vehicle_value
	raid_loot = loot_value
	navigation.setup(world.props)
	view = View.new()
	add_child(view)
	view.set_vehicle(vehicle)
	view.prepare()
	view.interaction_requested.connect(interact_person)

func reset(seed_value: int) -> void:
	_seed = seed_value
	recruits.clear()
	reactions.clear()
	if is_instance_valid(view):
		view.update_reactions(reactions)
	pending = {}
	service.reset()
	navigation.paths.clear()
	combat.model.player.crew_collect = false
	var roles: Array = Catalog.ROLES.keys()
	for index in roles.size():
		var point := _safe_spawn(index)
		var person := Factory.create_neutral(str(roles[index]), "stranded-%d-%d" % [seed_value, index], point)
		recruits.append(person)
	_update_view(0)

func _safe_spawn(index: int) -> Vector3:
	var limit := Bounds.PLAYABLE_RADIUS - Encounter.SPAWN_EDGE_MARGIN
	for attempt in Encounter.SPAWN_ATTEMPTS:
		var key := "%d:crew:%d:%d" % [_seed, index, attempt]
		var angle := Policy.roll(key + ":angle") * TAU
		var radius := sqrt(Policy.roll(key + ":radius")) * limit
		var point := Vector3(cos(angle), 0, sin(angle)) * radius
		if Encounter.flat_distance(point, combat.model.player.position) < Encounter.SPAWN_PLAYER_CLEARANCE:
			continue
		if recruits.any(func(person): return Encounter.flat_distance(point, person.position) < Encounter.SPAWN_SEPARATION):
			continue
		if world.props.is_clear(point, 1.2):
			return point
	# Keep the fallback outside the arrival area even in unusually dense layouts.
	var fallback_angle := atan2(-combat.model.player.position.z, -combat.model.player.position.x) + float(index) / Catalog.ROLES.size()
	var fallback := Vector3(cos(fallback_angle), 0, sin(fallback_angle)) * limit
	return world.props.resolve_motion(fallback, fallback, 1.2)

func _update_view(delta: float) -> void:
	for person: Dictionary in recruits:
		person.interaction_available = _enabled() and _can_interact(person)
	view.update_people(_all_people(), delta)

func _enabled() -> bool:
	return expedition != null and expedition.active and not expedition.caravan.locked and combat.model.running and world.running and float(combat.model.player.get("hp", 0)) > 0

func step(delta: float) -> void:
	if not _enabled() or not is_finite(delta) or delta <= 0:
		return
	var reactions_changed := false
	for reaction: Dictionary in reactions.duplicate():
		reaction.time -= delta
		if reaction.time <= 0 or reaction.actor.get("dead", false):
			reactions.erase(reaction)
			reactions_changed = true
	if reactions_changed:
		view.update_reactions(reactions)
	for person: Dictionary in _all_people():
		person.reaction_time = maxf(0, float(person.get("reaction_time", 0)) - delta)
	for person: Dictionary in _all_people():
		_step_airborne(person, delta)
	for person: Dictionary in expedition.caravan.crew:
		if not person.get("dead", false) and person.carrier_id != "crawler":
			var carrier: Dictionary = expedition.caravan.find_wagon(person.carrier_id)
			if carrier.is_empty() or carrier.get("dead", false) or not carrier.get("attached", true):
				var replacement := Encounter.seat(expedition.caravan, str(person.role))
				if not replacement.is_empty():
					person.carrier_id = replacement.carrier_id
					person.seat = replacement.seat
					person.boarded = false
					person.recruit_boarding = true
					person.state = "approaching"
		Boarding.step(person, expedition.caravan, combat.model.player, navigation, delta)
	_step_refusals(delta)
	service.step(delta, combat.model.player, expedition.caravan.wagons, expedition.caravan.crew, combat.model.enemies, _pickups(), {"move": navigation.move, "collect": _collect, "deliver": _deliver, "fire": _fire})
	_update_view(delta)

func _all_people() -> Array:
	var people: Array = recruits.duplicate()
	if expedition != null:
		people.append_array(expedition.caravan.crew)
	return people

func targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _enabled():
		return result
	for person: Dictionary in _all_people():
		if not person.get("dead", false) and not person.get("boarded", false):
			result.append(person)
	return result

func friendly_targets() -> Array[Dictionary]:
	return targets()

func damage_target(id: String, amount: float, cause: String = "enemy") -> bool:
	if not _enabled() or not is_finite(amount) or amount <= 0:
		return false
	for person: Dictionary in targets():
		if str(person.id) != id:
			continue
		if person.faction == "ally":
			return expedition.caravan.damage_crew(id, amount)
		person.hp = maxf(0, float(person.hp) - amount)
		if person.hp <= 0:
			person.dead = true
			person.state = "dead"
			person.death_cause = cause
		return true
	return false

func rescue_nearest() -> bool:
	if not _enabled():
		return false
	var person := _nearest_recruit()
	if person.is_empty() or person.get("airborne", false) or float(person.get("tornado_recovery", 0)) > 0:
		return false
	if expedition.caravan.rescue(person):
		recruits.erase(person)
		_update_view(0)
		return true
	return false

func interact() -> bool:
	if not pending.is_empty():
		return true
	if not _enabled():
		return false
	var person := _nearest_recruit()
	if person.is_empty():
		return false
	pending = person
	encounter_requested.emit(person)
	return true

func interact_person(id: String) -> bool:
	if not _enabled() or not pending.is_empty():
		return false
	for person: Dictionary in recruits:
		if str(person.id) == id and _can_interact(person):
			pending = person
			encounter_requested.emit(person)
			return true
	return false

func accept_encounter() -> bool:
	if pending.is_empty() or not recruits.has(pending) or not _can_interact(pending):
		return false
	if not expedition.caravan.rescue(pending):
		return false
	pending.reaction_time = 5.0
	recruits.erase(pending)
	pending = {}
	_update_view(0)
	return true

func cancel_encounter() -> void:
	pending = {}

func decline_encounter() -> String:
	if pending.is_empty() or not recruits.has(pending) or pending.get("dead", false) or not expedition.active or expedition.caravan.locked:
		return ""
	var outcome := Encounter.refusal(Policy.roll(str(pending.id) + ":refusal"))
	pending.state = outcome
	pending.reaction_time = 5.0
	var replies := {
		"fleeing": ["Ладно… сам выберусь!", "Fine… I'll find my own way!"],
		"joining_enemy": ["Тогда поищу других попутчиков.", "Then I'll find another crew."],
		"hostile": ["Пожалеешь об этом!", "You'll regret this!"]}
	pending.reaction_text = replies[outcome]
	pending.refusal_elapsed = 0.0
	pending = {}
	return outcome

func _step_refusals(delta: float) -> void:
	for person: Dictionary in recruits.duplicate():
		if person.get("dead", false) or person.get("airborne", false):
			continue
		var state := str(person.state)
		if state not in ["fleeing", "joining_enemy", "hostile"]:
			continue
		person.refusal_elapsed = float(person.get("refusal_elapsed", 0)) + delta
		if state == "hostile":
			_turn_hostile(person)
			continue
		var away: Vector3 = person.position - combat.model.player.position
		away.y = 0
		if away.length_squared() < 0.01:
			away = Vector3.RIGHT
		var destination: Vector3 = person.position + away.normalized() * 30
		if state == "joining_enemy":
			var nearest := INF
			for enemy: Dictionary in combat.model.enemies:
				if enemy.get("dead", false) or enemy.get("allegiance", "enemy") == "friendly":
					continue
				var distance := Encounter.flat_distance(person.position, enemy.position)
				if distance < nearest:
					nearest = distance
					destination = enemy.position
			if nearest < 5 or float(person.refusal_elapsed) >= 8:
				_turn_hostile(person)
				continue
		var previous: Vector3 = person.position
		person.position = navigation.move(person, destination, 5.0, delta)
		var motion: Vector3 = person.position - previous
		if motion.length_squared() > 0.001:
			person.heading = atan2(motion.x, motion.z)
		if state == "fleeing" and float(person.refusal_elapsed) > 20 and Encounter.distance(person, combat.model.player, expedition.caravan.wagons) > 45:
			recruits.erase(person)

func _turn_hostile(person: Dictionary) -> void:
	var enemy: Dictionary = combat.model.spawn_enemy("rifleman", person.position, {"counts_toward_wave": false})
	if enemy.is_empty():
		return
	enemy.hp = person.hp
	enemy.max_hp = person.max_hp
	enemy.cooldown = 0.0
	enemy.survivor_identity = person.get("identity", 0)
	if float(person.get("reaction_time", 0)) > 0:
		reactions.append({"actor": enemy, "text": person.reaction_text, "time": person.reaction_time})
		view.update_reactions(reactions)
	recruits.erase(person)

func _can_interact(person: Dictionary) -> bool:
	return not person.get("dead", false) and person.get("state", "") == "stranded" and not person.get("airborne", false) and float(person.get("tornado_recovery", 0)) <= 0 and Encounter.distance(person, combat.model.player, expedition.caravan.wagons) <= Encounter.RANGE

func _nearest_recruit() -> Dictionary:
	var found := {}
	var distance := Encounter.RANGE
	for person: Dictionary in recruits:
		if not _can_interact(person):
			continue
		var separation := Encounter.distance(person, combat.model.player, expedition.caravan.wagons)
		if separation <= distance:
			found = person
			distance = separation
	return found

func hint() -> String:
	if not _enabled():
		return ""
	var person := _nearest_recruit()
	if not person.is_empty():
		if Encounter.seat(expedition.caravan, str(person.role)).is_empty():
			return "Нет свободных мест" if Locale.language == "ru" else "No free seats"
		return ("E: поговорить · " + str(person.name)) if Locale.language == "ru" else ("E: talk · " + str(person.name_en))
	return ""

func toggle_collection() -> bool:
	if not _enabled():
		return false
	combat.model.player.crew_collect = not bool(combat.model.player.get("crew_collect", false))
	if not combat.model.player.crew_collect:
		recall()
	return bool(combat.model.player.crew_collect)

func recall() -> void:
	if not _enabled():
		return
	combat.model.player.crew_collect = false
	for person: Dictionary in expedition.caravan.crew:
		person.recall = true

func _pickups() -> Array:
	var result: Array = []
	for pickup: Dictionary in combat.model.pickups:
		if not pickup.get("dead", false):
			var entry := pickup.duplicate()
			entry.id = "combat:" + str(pickup.id)
			entry.combat_id = pickup.id
			result.append(entry)
	for crate: Dictionary in raid_loot.crates:
		result.append({"id": str(crate.id), "position": Vector3(crate.position.x, 0, crate.position.z), "kind": "cargo", "count": crate.count, "crate_id": crate.id})
	return result

func _collect(person: Dictionary, pickup: Dictionary) -> bool:
	return _enabled() and Cargo.claim(person, pickup, raid_loot, combat.model)

func _deliver(person: Dictionary) -> bool:
	return _enabled() and Cargo.deliver(person, expedition, combat.model)

func _fire(person: Dictionary, target: Dictionary, shot: Dictionary) -> bool:
	if not _enabled() or target.get("dead", false):
		return false
	var origin: Vector3 = person.position
	origin.y = Ground.height_at(origin.x, origin.z) + (2.1 if person.get("boarded", false) else 1.5)
	var aim: Vector3 = combat.model._target_aim(target)
	var direction := aim - origin
	person.heading = atan2(direction.x, direction.z)
	combat.model.fire_projectile(str(shot.projectile), "player", origin, aim, float(shot.damage), int(target.id), {"crew_id": person.id, "module_type": "crew_" + str(person.role), "weapon_mount": {"carrierId": person.carrier_id, "slot": -1}})
	return true

func _step_airborne(person: Dictionary, delta: float) -> void:
	if person.get("dead", false) or person.get("boarded", false):
		return
	person.tornado_cooldown = maxf(0, float(person.get("tornado_cooldown", 0)) - delta)
	person.tornado_recovery = maxf(0, float(person.get("tornado_recovery", 0)) - delta)
	if person.has("tornado_flight"):
		var flight: Dictionary = person.tornado_flight
		Air.step(flight, world.tornado.position, delta)
		person.position = Vector3(flight.position.x, 0, flight.position.z)
		person.lift_height = maxf(0, flight.position.y - Ground.height_at(flight.position.x, flight.position.z))
		person.roll = flight.roll
		if flight.landed:
			person.position = world.props.resolve_motion(person.position, person.position, float(person.radius))
			person.erase("tornado_flight")
			person.airborne = false
			person.lift_height = 0.0
			person.state = str(person.get("tornado_previous_state", "stranded" if person.faction == "neutral" else "returning"))
			person.erase("tornado_previous_state")
			person.tornado_recovery = 0.8
			person.tornado_cooldown = 4.0
			person.roll = 0.0
			damage_target(str(person.id), Policy.damage_on_landing(flight.impact_speed), "tornado_landing")
		return
	if person.tornado_cooldown <= 0 and person.tornado_recovery <= 0 and world.tornado.influence(person.position).core:
		person.tornado_flight = Air.create(person.position, "%d:%s" % [_seed, person.id], world.tornado.position)
		person.airborne = true
		person.tornado_previous_state = person.state
		person.state = "airborne"

func set_warmup(enabled: bool, point: Vector3 = Vector3.ZERO) -> void:
	if is_instance_valid(view):
		view.set_warmup(enabled, point)

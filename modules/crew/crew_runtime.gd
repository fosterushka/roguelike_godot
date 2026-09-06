extends Node3D
const Factory = preload("res://modules/crew/crew_factory.gd")
const Catalog = preload("res://modules/crew/crew_catalog.gd")
const Cargo = preload("res://modules/crew/crew_cargo.gd")
const Service = preload("res://modules/crew/crew_service.gd")
const Navigation = preload("res://modules/crew/crew_navigation.gd")
const View = preload("res://presentation/crew/crew_view.gd")
const Air = preload("res://modules/world/airborne_motion.gd")
const Policy = preload("res://modules/world/destruction_policy.gd")
const Ground = preload("res://modules/caravan/terrain_surface.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
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

func reset(seed_value: int) -> void:
	_seed = seed_value
	recruits.clear()
	service.reset()
	navigation.paths.clear()
	combat.model.player.crew_collect = false
	var villages: Array = world.arena.world_layout.get("villages", [])
	var roles: Array = Catalog.ROLES.keys()
	for index in roles.size():
		var center := Vector3.ZERO
		if index > 0 and not villages.is_empty():
			var village: Dictionary = villages[(index - 1) % villages.size()]
			center = Vector3(float(village.x), 0, float(village.z))
		else:
			center = combat.model.player.position + Vector3.RIGHT.rotated(Vector3.UP, index * TAU / 7) * (18.0 if index == 0 else 60.0 + index * 15)
		var point := _safe_spawn(center, index)
		var person := Factory.create_neutral(str(roles[index]), "stranded-%d-%d" % [seed_value, index], point)
		recruits.append(person)
	view.update_people(_all_people(), 0)

func _safe_spawn(center: Vector3, index: int) -> Vector3:
	center.y = 0
	for attempt in 96:
		var angle := Policy.roll("%d:crew:%d:%d" % [_seed, index, attempt]) * TAU
		var radius := 0.0 if attempt == 0 else 3.0 + attempt * 0.6
		var point := center + Vector3(cos(angle), 0, sin(angle)) * radius
		if absf(point.x) < Ground.HALF_SIZE - 20 and absf(point.z) < Ground.HALF_SIZE - 20 and world.props.is_clear(point, 1.2):
			return point
	return world.props.resolve_motion(center, center, 1.2)

func _enabled() -> bool:
	return expedition != null and expedition.active and not expedition.caravan.locked and combat.model.running and world.running and float(combat.model.player.get("hp", 0)) > 0

func step(delta: float) -> void:
	if not _enabled() or not is_finite(delta) or delta <= 0:
		return
	for person: Dictionary in _all_people():
		_step_airborne(person, delta)
	service.step(delta, combat.model.player, expedition.caravan.wagons, expedition.caravan.crew, combat.model.enemies, _pickups(), {"move": navigation.move, "collect": _collect, "deliver": _deliver, "fire": _fire})
	view.update_people(_all_people(), delta)

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
		view.update_people(_all_people(), 0)
		return true
	return false

func interact() -> bool:
	return rescue_nearest()

func _nearest_recruit() -> Dictionary:
	var found := {}
	var distance := 6.0
	for person: Dictionary in recruits:
		if person.get("dead", false):
			continue
		var offset: Vector3 = person.position - combat.model.player.position
		offset.y = 0
		if offset.length() <= distance:
			found = person
			distance = offset.length()
	return found

func hint() -> String:
	if not _enabled():
		return ""
	var person := _nearest_recruit()
	if not person.is_empty():
		if expedition.caravan.free_seat().is_empty():
			return "Нет свободных мест" if Locale.language == "ru" else "No free seats"
		if absf(float(combat.model.player.get("speed", 0))) > 1.5:
			return "Остановитесь для спасения" if Locale.language == "ru" else "Stop to rescue"
		return ("E: спасти · " + str(person.name)) if Locale.language == "ru" else ("E: rescue · " + str(person.name_en))
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
			person.tornado_recovery = 0.8
			person.tornado_cooldown = 4.0
			person.roll = 0.0
			damage_target(str(person.id), Policy.damage_on_landing(flight.impact_speed), "tornado_landing")
		return
	if person.tornado_cooldown <= 0 and person.tornado_recovery <= 0 and world.tornado.influence(person.position).core:
		person.tornado_flight = Air.create(person.position, "%d:%s" % [_seed, person.id], world.tornado.position)
		person.airborne = true
		person.state = "airborne"

func set_warmup(enabled: bool, point: Vector3 = Vector3.ZERO) -> void:
	if is_instance_valid(view):
		view.set_warmup(enabled, point)

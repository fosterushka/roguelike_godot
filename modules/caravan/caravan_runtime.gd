extends Node

signal caravan_event(event: Dictionary)
const Formation = preload("res://modules/caravan/caravan_formation.gd")
const Loadout = preload("res://modules/caravan/caravan_loadout.gd")
const Pose = preload("res://modules/caravan/vehicle_pose.gd")
const VehicleView = preload("res://presentation/vehicles/vehicle_view.gd")
const Ground = preload("res://modules/caravan/terrain_surface.gd")
var formation := Formation.new()
var expedition: RefCounted
var progression: RefCounted
var combat: Node3D
var vehicle: CharacterBody3D
var world: Node3D
var crew_runtime: Node3D
var _contact_age := 0.0

func setup(raid: RefCounted, fight: Node3D, car: CharacterBody3D, environment: Node3D) -> void:
	expedition = raid
	progression = raid.progression
	combat = fight
	vehicle = car
	world = environment
	vehicle.physics_pose_advanced.connect(_advance_formation)
	combat.model.friendly_targets_query = targets
	combat.model.friendly_damage_query = damage_target
	combat.model.enemy_target_query = enemy_target
	combat.model.weapon_origin_query = weapon_origin
	combat.support_step = step

func reset() -> void:
	formation.reset()
	_contact_age = 0
	Loadout.hydrate(progression)
	_advance_formation(0.0)

func _advance_formation(delta: float) -> void:
	if not expedition.active or expedition.caravan.locked:
		return
	var pose: Dictionary = vehicle.current_render_pose()
	pose.wind_roll = float(vehicle.tornado_effect.get("roll", 0))
	for event: Dictionary in formation.step(pose, expedition.caravan.wagons, delta, world.props.resolve_motion):
		if event.kind == "wagon_impact":
			expedition.caravan.damage_wagon(str(event.id), float(event.amount))
		else:
			caravan_event.emit(event)
	Loadout.refresh(progression)

func step(delta: float) -> void:
	if not expedition.active or expedition.caravan.locked or delta <= 0:
		return
	Loadout.refresh(progression)
	if is_instance_valid(crew_runtime):
		crew_runtime.step(delta)
		for event: Dictionary in crew_runtime.service.drain_events():
			caravan_event.emit(event)
	_contact_age -= delta
	if _contact_age <= 0:
		_contact_age = 0.5
		for enemy: Dictionary in combat.model.enemies:
			if enemy.get("dead", false) or enemy.get("airborne", false) or float(enemy.get("lift_height", 0)) > 0.2:
				continue
			for wagon: Dictionary in expedition.caravan.wagons:
				if wagon.dead or Vector2(enemy.position.x - wagon.position.x, enemy.position.z - wagon.position.z).length() > float(wagon.radius) + float(enemy.radius):
					continue
				expedition.caravan.damage_wagon(wagon.id, maxf(1, float(enemy.get("damage", 5))) * 0.25)
				break
	_flush_events()

func _flush_events() -> void:
	for event: Dictionary in expedition.caravan.drain_events():
		caravan_event.emit(event)

func targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not expedition.active or expedition.caravan.locked:
		return result
	for wagon: Dictionary in expedition.caravan.wagons:
		if not wagon.dead and wagon.hp > 0:
			result.append({"id": wagon.id, "position": wagon.position + Vector3.UP * 1.6, "radius": float(wagon.radius) * float(combat.model.player.get("visual_scale", 0.88)), "kind": "wagon", "velocity": wagon.get("velocity", Vector3.ZERO)})
	if is_instance_valid(crew_runtime):
		for person: Dictionary in crew_runtime.targets():
			var point: Vector3 = person.position
			point.y = Ground.height_at(point.x, point.z) + 1.05 + float(person.get("lift_height", 0))
			result.append({"id": person.id, "position": point, "radius": float(person.radius), "kind": "crew"})
	return result

func damage_target(id: String, amount: float, cause: String = "projectile") -> bool:
	if not expedition.active or expedition.caravan.locked:
		return false
	var wagon: Dictionary = expedition.caravan.find_wagon(id)
	var accepted := false
	if not wagon.is_empty():
		accepted = not expedition.caravan.damage_wagon(id, amount).is_empty()
		if accepted:
			for person: Dictionary in expedition.caravan.crew:
				if person.carrier_id == id and person.boarded and not person.dead:
					expedition.caravan.damage_crew(person.id, amount * 0.16)
	elif is_instance_valid(crew_runtime):
		accepted = crew_runtime.damage_target(id, amount, cause)
	Loadout.refresh(progression)
	_flush_events()
	return accepted

func enemy_target(origin: Vector3) -> Dictionary:
	var player: Dictionary = combat.model.player
	var selected := {"position": player.position + Vector3.UP * 2.2, "velocity": player.get("velocity", Vector3.ZERO)}
	var nearest: float = origin.distance_squared_to(selected.position)
	for target: Dictionary in targets():
		var distance := origin.distance_squared_to(target.position)
		if distance < nearest:
			nearest = distance
			selected = target
	return selected

func weapon_origin(weapon: Dictionary) -> Vector3:
	var mount: Dictionary = weapon.get("mount", {"carrierId": "crawler", "slot": 0})
	var pose: Dictionary = vehicle.current_render_pose()
	var point: Vector3 = VehicleView.SLOTS[clampi(int(mount.slot), 0, 11)]
	if mount.carrierId != "crawler":
		var wagon: Dictionary = expedition.caravan.find_wagon(str(mount.carrierId))
		if not wagon.is_empty() and wagon.has("pose"):
			pose = wagon.pose
		point = VehicleView.TRAILER_SLOTS[clampi(int(mount.slot), 0, 2)]
	return Pose.transform(pose) * point + Vector3.UP * 0.6

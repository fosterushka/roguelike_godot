extends RefCounted
const Policy = preload("res://modules/world/destruction_policy.gd")
const Air = preload("res://modules/world/airborne_motion.gd")
const Damage = preload("res://modules/world/damage_context.gd")
const Ground = preload("res://modules/caravan/terrain_surface.gd")
var prop_flights: Dictionary = {}
var actor_flights: Dictionary = {}
var captured_props: Dictionary = {}
var actor_cooldowns: Dictionary = {}
var heavy_debris_next: Dictionary = {}
var player_state := {"inside": false, "entry": 0, "mode": "none", "exit_time": 0.0, "blend": 0.0, "force": Vector3.ZERO, "roll": 0.0, "lift": 0.0}
var _storm := -1

func reset(vehicle: Node = null) -> void:
	prop_flights.clear()
	actor_flights.clear()
	captured_props.clear()
	actor_cooldowns.clear()
	heavy_debris_next.clear()
	_storm = -1
	player_state = {"inside": false, "entry": 0, "mode": "none", "exit_time": 0.0, "blend": 0.0, "force": Vector3.ZERO, "roll": 0.0, "lift": 0.0}
	if is_instance_valid(vehicle):
		vehicle.tornado_effect = {}

func step(world, delta: float) -> void:
	var storm: int = world.weather.phase.get("index", 0)
	if storm != _storm:
		captured_props.clear()
		heavy_debris_next.clear()
		_storm = storm
	_step_player(world, delta)
	_step_props(world, delta)
	_step_actors(world, delta)

func _step_player(world, delta: float) -> void:
	var influence: Dictionary = world.tornado.influence(world.vehicle.global_position)
	var strength := float(influence.strength)
	if not player_state.inside and strength >= 0.045:
		player_state.inside = true
		player_state.entry += 1
		player_state.exit_time = 0.0
		player_state.mode = "shove" if Policy.roll("%d:%d:player:%d" % [world._seed, _storm, player_state.entry]) < 0.5 else "slow"
		world.world_event.emit({"kind": "tornado_player_entered", "mode": player_state.mode, "entry": player_state.entry})
	if player_state.inside:
		player_state.exit_time = float(player_state.exit_time) + delta if strength < 0.006 else 0.0
		if player_state.exit_time >= 1.0:
			player_state.inside = false
	var target := strength if player_state.inside else 0.0
	var response := 3.0 / (0.8 if target > float(player_state.blend) else 1.2)
	var smooth := 1.0 - exp(-response * delta)
	player_state.blend = lerpf(player_state.blend, target, smooth)
	var shove: bool = player_state.mode == "shove"
	var force: Vector3 = influence.force if shove else Vector3.ZERO
	player_state.force = Vector3(player_state.force).lerp(force, smooth)
	player_state.roll = lerpf(player_state.roll, sin(world.tornado.age * 2.7) * 0.22 * target if shove else 0.0, smooth)
	player_state.lift = lerpf(player_state.lift, target * 0.7 if shove else 0.0, smooth)
	world.vehicle.tornado_effect = {"force": player_state.force, "roll": player_state.roll, "lift": player_state.lift, "movement": 1.0 - float(player_state.blend) * 0.7 if not shove else 1.0, "mode": player_state.mode, "strength": player_state.blend}

func _step_props(world, delta: float) -> void:
	for id: String in prop_flights.keys():
		var flight: Dictionary = prop_flights[id]
		var prop: Dictionary = world.props.records.get(id, {})
		if prop.is_empty() or prop.destroyed:
			prop_flights.erase(id)
			continue
		Air.step(flight, world.tornado.position, delta)
		if flight.landed:
			var point: Vector3 = world.props.resolve_motion(flight.position, flight.position, float(prop.radius))
			world.props.land(prop, point, float(flight.impact_speed))
			prop_flights.erase(id)
	if world.tornado.intensity < 0.68:
		return
	for prop: Dictionary in world.props.grid.nearby(world.tornado.position, world.tornado.DANGER_RADIUS):
		var id := str(prop.id)
		if prop.destroyed or prop.get("airborne", false) or prop.kind in ["rock", "stump"] or captured_props.has(id):
			continue
		if not world.tornado.influence(prop.position).core:
			continue
		var identity := "%d:%d:%s" % [world._seed, _storm, id]
		if Policy.can_throw(prop):
			var launch := Policy.roll(identity) < 0.5
			if launch and prop_flights.size() >= int(Policy.settings().prop_airborne_limit):
				continue
			captured_props[id] = true
			if launch:
				var flight := Air.create(prop.position, identity, world.tornado.position)
				if world.props.lift(prop):
					prop_flights[id] = flight
			else:
				world.props.destroy(prop, 2.0, Damage.create("tornado", prop.position - world.tornado.position, "weather", identity))
		else:
			# Anchored heavy structures shed material under sustained wind, never fly whole.
			if float(world.tornado.age) >= float(heavy_debris_next.get(id, -INF)):
				heavy_debris_next[id] = float(world.tornado.age) + 0.75
				world.world_event.emit({"kind": "tornado_debris", "id": id, "position": prop.position, "debris_kind": prop.get("debrisKind", "stone"), "cause": "tornado"})
			prop.hp -= 28.0 * delta
			if prop.hp <= 0.0:
				captured_props[id] = true
				world.props.destroy(prop, 2.3, Damage.create("tornado", prop.position - world.tornado.position, "weather", identity))

func _step_actors(world, delta: float) -> void:
	for id in actor_cooldowns.keys():
		actor_cooldowns[id] = maxf(0.0, float(actor_cooldowns[id]) - delta)
		if actor_cooldowns[id] <= 0.0:
			actor_cooldowns.erase(id)
	for enemy: Dictionary in world.combat.model.enemies:
		var id: int = enemy.id
		if enemy.dead:
			actor_flights.erase(id)
			continue
		if actor_flights.has(id):
			var flight: Dictionary = actor_flights[id]
			Air.step(flight, world.tornado.position, delta)
			enemy.position = Vector3(flight.position.x, 0, flight.position.z)
			enemy.lift_height = maxf(0.0, flight.position.y - Ground.height_at(flight.position.x, flight.position.z))
			enemy.roll = flight.roll
			enemy.velocity = flight.velocity
			enemy.x = enemy.position.x
			enemy.z = enemy.position.z
			if flight.landed:
				enemy.position = world.props.resolve_motion(enemy.position, enemy.position, float(enemy.radius))
				enemy.airborne = false
				enemy.lift_height = 0.0
				enemy.tornado_recovery = 0.8
				enemy.tornado_recovery_roll = enemy.roll
				if enemy.get("activity_route_controlled", false):
					var offset: Vector3 = enemy.position - flight.start
					enemy.tornado_offset_x = float(enemy.get("tornado_offset_x", 0)) + offset.x
					enemy.tornado_offset_z = float(enemy.get("tornado_offset_z", 0)) + offset.z
				actor_flights.erase(id)
				actor_cooldowns[id] = 4.0
				world.combat.model.damage_enemy_natural(id, Policy.damage_on_landing(flight.impact_speed), "tornado_landing")
				world.world_event.emit({"kind": "tornado_actor_landed", "id": id, "position": enemy.position, "impact_speed": flight.impact_speed})
			continue
		if float(enemy.get("tornado_recovery", 0)) > 0.0:
			enemy.tornado_recovery = maxf(0.0, float(enemy.tornado_recovery) - delta)
			enemy.roll = float(enemy.get("tornado_recovery_roll", 0)) * float(enemy.tornado_recovery) / 0.8
			continue
		if enemy.get("boss", false) or enemy.get("airborne", false) or str(enemy.type) not in ["soldier", "bike", "buggy", "priorityVehicle"] or actor_cooldowns.has(id):
			continue
		var influence: Dictionary = world.tornado.influence(enemy.position)
		if influence.core and actor_flights.size() < int(Policy.settings().npc_airborne_limit):
			var flight := Air.create(enemy.position, "%d:%d:%d" % [world._seed, _storm, id], world.tornado.position)
			flight.start = enemy.position
			actor_flights[id] = flight
			enemy.airborne = true
			enemy.lift_height = 0.0
			world.world_event.emit({"kind": "tornado_actor_lifted", "id": id, "position": enemy.position})

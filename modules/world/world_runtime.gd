extends Node3D

signal state_changed(data: Dictionary)
signal world_event(event: Dictionary)

const Props = preload("res://modules/world/prop_system.gd")
const Weather = preload("res://modules/world/weather_state.gd")
const Rules = preload("res://modules/world/weather_rules.gd")
const Tornado = preload("res://modules/world/tornado_rules.gd")
const Grid = preload("res://modules/world/spatial_grid.gd")
const WeatherView = preload("res://presentation/world/weather_view.gd")
const Activities = preload("res://modules/world/activities/activity_system.gd")
const Support = preload("res://modules/world/activities/support_system.gd")
const Foundries = preload("res://modules/world/activities/foundry_system.gd")
const ActivityView = preload("res://presentation/world/activity_view.gd")
const PLAYABLE_RADIUS := 1248.0
const BOUNDARY_GRACE := 15.0
const STATION_RADIUS := 11.0
const STATION_REFILL := 24.0

var wind := preload("res://modules/world/wind_state.gd").new()
var ambient := preload("res://modules/world/ambient_system.gd").new()
var props := Props.new()
var activities := Activities.new()
var support := Support.new()
var foundries := Foundries.new()
var _activity_view: Node3D
var weather := Weather.new()
var tornado := Tornado.new()
var arena: Node3D
var combat: Node3D
var vehicle: CharacterBody3D
var clock_delta: Callable
var raw_weather_driven := false
var running := false
var outside_remaining := BOUNDARY_GRACE
var outside := false
var camera_dust := 0.0
var station: Dictionary = {}
var _weather_view: Node3D
var _model_properties: Dictionary = {}
var _publish_remaining := 0.0
var _seed := 72841
var rock_steering := preload("res://modules/world/navigation/rock_steering.gd").new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = -20

func setup(world_arena: Node3D, combat_runtime: Node3D, player_vehicle: CharacterBody3D) -> void:
	arena = world_arena
	combat = combat_runtime
	vehicle = player_vehicle
	vehicle.obstacle_impact_query = handle_vehicle_impact
	props.setup(arena.world_layout)
	rock_steering.setup(arena.world_layout.rockObstacles)
	for property in combat.model.get_property_list():
		_model_properties[str(property.name)] = true
	if _model_properties.has("world_collision_query"):
		combat.model.world_collision_query = handle_projectile
	if _model_properties.has("enemy_motion_query"):
		combat.model.enemy_motion_query = resolve_enemy_motion
	if _model_properties.has("enemy_steering_query"):
		combat.model.enemy_steering_query = rock_steering.direction
	if _model_properties.has("spawn_validity_query"):
		combat.model.spawn_validity_query = is_spawn_clear
	combat.combat_event.connect(_on_combat_event)
	_weather_view = WeatherView.new()
	add_child(_weather_view)
	_weather_view.setup(arena, vehicle)
	world_event.connect(_weather_view.on_event)
	activities.setup(self)
	support.setup(self)
	foundries.setup(self, activities)
	_activity_view = ActivityView.new()
	add_child(_activity_view)
	reset_run(_seed)

func set_running(enabled: bool) -> void:
	running = enabled

func reset_run(seed_value: int = 72841) -> void:
	_seed = seed_value
	for id in props.reset():
		arena.set_prop_destroyed(id, false)
	_refresh_rock_navigation()
	ambient.reset(seed_value)
	wind.reset(ambient.random)
	for village: Dictionary in arena.world_layout.villages:
		village.consumed = false
		village.intact = true
	weather.reset(seed_value)
	activities.reset(seed_value)
	support.reset(seed_value)
	foundries.reset(seed_value)
	tornado = Tornado.new()
	camera_dust = 0.0
	outside_remaining = BOUNDARY_GRACE
	outside = false
	station = {}
	_publish_remaining = 0.0
	if is_instance_valid(vehicle):
		vehicle.surface_effects = weather.surface_at(vehicle.global_position)
	_sync_weather_model()
	if is_instance_valid(_weather_view):
		_weather_view.reset_run(seed_value)
	_publish()

func _physics_process(delta: float) -> void:
	if running and is_instance_valid(combat) and combat.model.running:
		var gameplay_delta: float = float(clock_delta.call()) if clock_delta.is_valid() else delta
		if gameplay_delta > 0:
			step(gameplay_delta)

func step_ambient(delta: float) -> void:
	var wind_particles: int = wind.step(delta, weather.phase.type == "storm", ambient.random)
	for index in wind_particles:
		world_event.emit({"kind": "wind_particle", "direction": wind.direction, "strength": wind.strength})
	ambient.step(delta, combat.model.enemies, weather.phase.type == "storm", wind.strength)
	if raw_weather_driven:
		_weather_view._wind_debris._process(delta)

func step(delta: float) -> void:
	if not raw_weather_driven:
		weather.step(delta)
	step_ambient(delta)
	_consume_nearby_village()
	activities.step(delta)
	if combat.model.status in ["dead", "complete", "extracted"]:
		for event in activities.drain_events():
			world_event.emit(event)
		_publish()
		return
	support.step(delta)
	foundries.step(delta)
	for event in activities.drain_events() + support.drain_events():
		world_event.emit(event)
	_sync_weather_model()
	for enemy: Dictionary in combat.model.enemies:
		if enemy.type != "drone" and not enemy.get("airborne", false):
			if Rules.wet(str(weather.phase.type)):
				enemy.wet_until = combat.model.elapsed + Rules.WET_RETENTION
			elif float(enemy.get("wet_until", 0.0)) <= combat.model.elapsed:
				enemy.wet_until = 0.0
	vehicle.surface_effects = weather.surface_at(vehicle.global_position)
	_refill_station(delta)
	_update_boundary(delta)
	if combat.model.status in ["dead", "complete", "extracted"]:
		_publish()
		return
	var response := props.ram(vehicle.global_position, vehicle.motion.speed, float(combat.model.player.get("ram_timer", 0.0)) > 0, delta, float(combat.model.player.get("visual_scale", 0.88)))
	vehicle.motion.speed *= float(response.retention)
	_flush_prop_events()
	tornado.step(_seed, weather.phase, weather.elapsed, delta)
	_update_tornado(delta)
	if raw_weather_driven:
		_activity_view._process(delta)
		_weather_view._bolt._process(delta)
		_weather_view._tornado_view._process(delta)
	if not raw_weather_driven:
		_drain_weather_events()
	_publish_remaining -= delta
	if _publish_remaining <= 0.0:
		_publish_remaining = 0.1
		_publish()

func _sync_weather_model() -> void:
	if is_instance_valid(combat) and _model_properties.has("weather_type"):
		combat.model.weather_type = str(weather.phase.get("type", "clear"))
		if _model_properties.has("weather_fog_strength"):
			combat.model.weather_fog_strength = weather.visual_mix().y

func damage_props(point: Vector3, radius: float, amount: float) -> int:
	var destroyed := props.damage_at(point, radius, amount)
	_flush_prop_events()
	return destroyed

func handle_vehicle_impact(collider: Object, approach_speed: float) -> bool:
	if not running or not is_instance_valid(collider) or not collider.has_meta("destructible_prop_id"):
		return false
	var destroyed := props.impact(str(collider.get_meta("destructible_prop_id")), approach_speed, float(combat.model.player.get("ram_timer", 0.0)) > 0.0)
	_flush_prop_events()
	return destroyed

func handle_projectile(shot: Dictionary) -> bool:
	var hit := props.first_segment(shot.previous, shot.position, float(shot.get("radius", 0.0)))
	if hit.is_empty():
		return false
	shot.position = hit.position
	if str(shot.kind) not in ["rocket", "grenade"]:
		damage_props(hit.position, 1.2, float(shot.damage) * 1.8)
	world_event.emit({"kind": "prop_hit", "position": hit.position, "id": hit.prop.id})
	return true

func resolve_enemy_motion(enemy: Dictionary, start: Vector3, end: Vector3) -> Vector3:
	if str(enemy.get("type", "")) == "drone" or bool(enemy.get("airborne", false)):
		return end
	var effect := weather.surface_at(start)
	return props.resolve_motion(start, start + (end - start) * float(effect.movement), float(enemy.get("radius", 0.7)))

func is_spawn_clear(point: Vector3, radius: float = 2.0) -> bool:
	return props.is_clear(point, radius)

func _flush_prop_events() -> void:
	var rebuild_navigation := false
	for event in props.drain_events():
		rebuild_navigation = rebuild_navigation or bool(props.records.get(str(event.id), {}).get("rock_obstacle", false))
		arena.set_prop_destroyed(str(event.id), true)
		if int(event.salvage) > 0:
			combat.model.spawn_pickup(event.position, int(event.salvage))
		world_event.emit(event)
	if rebuild_navigation:
		_refresh_rock_navigation()

func _refresh_rock_navigation() -> void:
	rock_steering.setup(arena.world_layout.rockObstacles.filter(func(rock: Dictionary) -> bool: return not props.records.get(str(rock.id), {}).get("destroyed", false)))

func _on_combat_event(event: Dictionary) -> void:
	if str(event.get("kind", "")) == "explosion":
		damage_props(event.position, float(event.radius), float(event.get("damage", 0.0)) * 1.6)
		weather.create_mud(event.position)
	elif str(event.get("kind", "")) == "result":
		running = false
		activities.cancel_all("run ended")

func _refill_station(delta: float) -> void:
	station = {}
	for landmark: Dictionary in arena.world_layout.landmarks:
		if str(landmark.type) not in ["pumpjack", "refinery"]:
			continue
		var prop: Dictionary = props.records.get("prop:" + str(landmark.id), {})
		if not prop.is_empty() and prop.destroyed:
			continue
		var point := Vector3(landmark.x, 0, landmark.z)
		if Grid.distance_xz(vehicle.global_position, point) > STATION_RADIUS:
			continue
		var amount := minf(vehicle.max_fuel - vehicle.fuel, STATION_REFILL * delta)
		vehicle.fuel += maxf(0.0, amount)
		combat.model.player.fuel = vehicle.fuel
		station = {"id": landmark.id, "position": point, "amount": maxf(0.0, amount)}
		break

func _update_boundary(delta: float) -> void:
	outside = Vector2(vehicle.global_position.x, vehicle.global_position.z).length() > PLAYABLE_RADIUS
	outside_remaining = maxf(0.0, outside_remaining - delta) if outside else BOUNDARY_GRACE
	if outside and outside_remaining <= 0.0 and vehicle.health > 0.0:
		vehicle.health = 0.0
		combat.finish_run(false, "boundary")
		world_event.emit({"kind": "boundary_death", "position": vehicle.global_position})

func _apply_lightning(sample: Dictionary) -> void:
	var point := project_weather_point(Vector2(sample.screen_x, sample.screen_y), 0.08)
	if float(sample.target_roll) < Rules.LIGHTNING_TARGET_CHANCE:
		if float(sample.target_roll) < Rules.LIGHTNING_PLAYER_CHANCE and vehicle.health > 1:
			point = vehicle.global_position
		else:
			var candidates: Array = combat.model._target_candidates().filter(func(enemy: Dictionary) -> bool: return enemy.hp > 1.0 and not enemy.dead and enemy.get("damageable", true))
			if not candidates.is_empty():
				point = candidates[mini(candidates.size() - 1, floori(float(sample.target_index) * candidates.size()))].position
	if vehicle.health > 1.0 and Grid.distance_xz(point, vehicle.global_position) <= Rules.LIGHTNING_RADIUS:
		combat.model.player.hp = vehicle.health
		combat.model.damage_player_nonlethal(maxf(14.0, vehicle.max_health * 0.14))
		vehicle.health = combat.model.player.hp
	for enemy: Dictionary in combat.model._target_candidates():
		if not enemy.dead and enemy.hp > 1.0 and enemy.get("damageable", true) and Grid.distance_xz(point, enemy.position) <= Rules.LIGHTNING_RADIUS:
			combat.model.damage_enemy_nonlethal(enemy.id, maxf(18.0, enemy.max_hp * 0.18))
	world_event.emit({"kind": "lightning", "position": point, "nonlethal": true, "cosmetic_seed": int(sample.get("effect_seed", 0)), "distance": point.distance_to(vehicle.global_position)})

func _update_tornado(delta: float) -> void:
	var influence := tornado.influence(vehicle.global_position)
	var target_dust := float(influence.dust)
	var dust_response := 4.6 if target_dust > camera_dust else 2.4
	camera_dust += (target_dust - camera_dust) * (1.0 - exp(-dust_response * delta))
	if camera_dust < 0.001 and target_dust == 0:
		camera_dust = 0.0
	if influence.strength > 0.0:
		var position := props.resolve_motion(vehicle.global_position, vehicle.global_position + influence.force * delta, float(combat.model.player.get("radius", 3.5)))
		vehicle.global_position = position
		var buffet := sin(tornado.age * 6.7) + sin(tornado.age * 11.3 + 1.7) * 0.45
		vehicle.motion.heading += buffet * influence.strength * delta * 0.46
		vehicle.motion.move_heading += (buffet * 0.3 + 0.18) * influence.strength * delta
		vehicle.motion.yaw_velocity += buffet * influence.strength * delta * 0.75
		vehicle.motion.speed *= exp(-0.34 * influence.strength * delta)
	for enemy: Dictionary in combat.model.enemies:
		if enemy.dead or enemy.get("airborne", false) or str(enemy.type) not in ["soldier", "bike", "buggy"]:
			continue
		var effect := tornado.influence(enemy.position)
		if effect.core:
			combat.model.kill_enemy(enemy, {"grant_rewards": false, "cause": "tornado"})
		elif effect.strength > 0.0:
			if enemy.get("activity_route_controlled", false):
				var previous := Vector3(float(enemy.get("tornado_offset_x", 0)), 0, float(enemy.get("tornado_offset_z", 0)))
				var next: Vector3 = previous + effect.force * delta * 1.15
				next.x = clampf(next.x, -9, 9)
				next.z = clampf(next.z, -9, 9)
				enemy.position += next - previous
				enemy.tornado_offset_x = next.x
				enemy.tornado_offset_z = next.z
			else:
				enemy.position = props.resolve_motion(enemy.position, enemy.position + effect.force * delta * 0.34, float(enemy.radius))
				enemy.velocity += effect.force * delta * 2.15
			enemy.yaw += effect.strength * delta * 2.8

func get_state() -> Dictionary:
	return {"weather": {"type": str(weather.phase.get("type", "clear")), "phase": int(weather.phase.get("index", 0)), "remaining": maxf(0.0, float(weather.phase.get("ends_at", 0)) - weather.elapsed), "traction": weather.traction, "fog_strength": weather.visual_mix().y, "phase_data": weather.phase.duplicate(), "elapsed": weather.elapsed},
		"boundary": {"outside": outside, "remaining": outside_remaining, "radius": PLAYABLE_RADIUS},
		"station": station.duplicate(), "mud_zones": weather.mud_zones.duplicate(true),
		"tornado": {"position": tornado.position, "intensity": tornado.intensity, "age": tornado.age, "camera_dust": camera_dust},
		"wind": wind.get_state(), "seed": _seed, "ambient_count": ambient.critters.size(), "game_time": combat.model.elapsed, "elapsed": weather.elapsed, "destroyed_props": props.destroyed_ids.size(),
		"activity": activities.get_state(), "extraction": activities.get_extraction_state(), "support": support.get_state(), "foundries": foundries.get_state()}

func _publish() -> void:
	arena.set_game_time(combat.model.elapsed)
	var state := get_state()
	state_changed.emit(state)
	if is_instance_valid(_weather_view):
		_weather_view.apply_state(state)
	if is_instance_valid(_activity_view):
		_activity_view.apply_state(state)


func set_warmup_visible(enabled: bool) -> void:
	if is_instance_valid(_weather_view):
		_weather_view.set_warmup_visible(enabled)
	if is_instance_valid(_activity_view):
		_activity_view.set_warmup_visible(enabled)


func interact() -> bool:
	return activities.request_extraction()


func rebind_world(seed_value: int) -> void:
	running = false
	activities.cancel_all("world replaced")
	props.setup(arena.world_layout)
	rock_steering.setup(arena.world_layout.rockObstacles)
	activities.setup(self)
	ambient.bind(arena.source_world.context)
	reset_run(seed_value)

func _consume_nearby_village() -> void:
	if absf(vehicle.motion.speed) <= 2.2:
		return
	var visual_scale := float(combat.model.player.get("visual_scale", 0.88))
	for village: Dictionary in arena.world_layout.villages:
		if not village.get("consumed", false) and Grid.distance_xz(vehicle.global_position, Vector3(village.x, 0, village.z)) < 7.4 * visual_scale / 0.88:
			consume_village(village)

func consume_village(village: Dictionary) -> bool:
	if village.get("consumed", false):
		return false
	village.consumed = true
	village.intact = false
	var houses: Array[Vector3] = []
	for prop: Dictionary in props.records.values():
		if str(prop.get("village_id", "")) != str(village.id) or prop.destroyed:
			continue
		if prop.kind == "building":
			houses.append(prop.position)
		prop.destroyed = true
		props.destroyed_ids.append(str(prop.id))
		arena.set_prop_destroyed(str(prop.id), true)
	var center := Vector3(village.x, 0.35, village.z)
	for index in 5:
		var point := center + Vector3(ambient.random.between(-5, 5), 0, ambient.random.between(-5, 5))
		var value := maxi(2, floori(float(village.tribute) / 5.0 * 0.65 + ambient.random.between(-1, 1) + 0.5))
		combat.model.spawn_pickup(point, value)
	world_event.emit({"kind": "village_consumed", "id": village.id, "position": center, "house_positions": houses})
	return true

func project_weather_point(ndc: Vector2, height: float) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(vehicle.global_position.x, height, vehicle.global_position.z)
	var screen := (ndc * Vector2(0.5, -0.5) + Vector2.ONE * 0.5) * get_viewport().get_visible_rect().size
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if absf(direction.y) < 0.000001:
		return Vector3(origin.x, height, origin.z)
	return origin + direction * (height - origin.y) / direction.y

func prepare_run_actors() -> void:
	if not foundries.spawned:
		foundries._spawn_network()
	combat._publish()

func update_weather_raw(delta: float) -> void:
	_weather_view.externally_driven = raw_weather_driven
	_weather_view._wind_debris.set_process(not raw_weather_driven)
	_weather_view._bolt.set_process(not raw_weather_driven)
	_weather_view._tornado_view.set_process(not raw_weather_driven)
	_activity_view.set_process(not raw_weather_driven)
	weather.step(delta)
	_sync_weather_model()
	_drain_weather_events()
	_publish()
	_weather_view.advance_visual(delta)

func _drain_weather_events() -> void:
	for event in weather.drain_events():
		if event.kind == "lightning_due":
			_apply_lightning(event.sample)
		else:
			world_event.emit(event)

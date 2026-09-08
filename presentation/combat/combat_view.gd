extends Node3D
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const PickupMotion = preload("res://presentation/world/pickup_motion.gd")
signal screen_impact(power: float)

const SourceModel = preload("res://presentation/combat/source_model.gd")
const EnemyAnimation = preload("res://presentation/combat/enemy_animation.gd")
const MineViews = preload("res://presentation/combat/mine_views.gd")
const Effects = preload("res://presentation/combat/impact_effects.gd")
const EnemyCatalog = preload("res://modules/combat/enemy_catalog.gd")
static var ENEMY_MODELS: Array[String] = EnemyCatalog.model_ids()
const PROJECTILE_MODELS := ["projectile_bullet", "projectile_sabot", "projectile_rocket", "projectile_grenade", "projectile_enemy_bullet", "projectile_enemy_sabot", "projectile_enemy_rocket", "projectile_enemy_grenade"]
var _pools: Dictionary = {}
var _active_counts: Dictionary = {}
var _vehicle: Node3D
var _effects: Node3D
var _mines: Node3D
var _generation := -1
var _state: Dictionary = {}
var _warmup := false
var _animation: Dictionary = {}
var _last_elapsed := 0.0
var _projectile_age: Dictionary = {}
var _soldier_free: Dictionary = {}
var tracers: Node3D


func setup(runtime: Node3D, vehicle: Node3D) -> void:
	_vehicle = vehicle
	tracers = preload("res://presentation/combat/fx/bullet_tracers.gd").new()
	add_child(tracers)
	SourceModel.preload_models()
	for model_name in ENEMY_MODELS + PROJECTILE_MODELS + ["pickup_salvage", "pickup_fuel"]:
		var capacity := 512 if model_name.begins_with("projectile") or model_name.begins_with("pickup") else 110
		var pool := SourceModel.create_pool(model_name, capacity)
		add_child(pool.root)
		_pools[model_name] = pool
		_active_counts[model_name] = 0
	_mines = MineViews.new()
	add_child(_mines)
	_effects = Effects.new()
	add_child(_effects)
	_effects.player_view = _vehicle.get_node_or_null("VehicleView")
	if _effects.player_view != null:
		_effects.body_impact.connect(_effects.player_view.on_impact)
	_effects.screen_impact.connect(func(power: float): screen_impact.emit(power))
	runtime.state_changed.connect(apply_state)
	runtime.combat_event.connect(on_event)
	apply_state(runtime.get_state())


func set_warmup_visible(enabled: bool) -> void:
	_warmup = enabled
	tracers.set_warmup(enabled, _vehicle.global_position + Vector3.UP * 2.0)
	_mines.set_warmup(enabled, _vehicle.global_position + Vector3.UP * 1.5)
	if enabled:
		for pool in _pools.values():
			SourceModel.set_pool_instance(pool, 0, Transform3D(Basis.IDENTITY, _vehicle.global_position + Vector3.UP * 1.5), {"warmup": true})
		_effects.set_warmup_visible(true)
	else:
		for pool in _pools.values():
			SourceModel.hide_pool_instance(pool, 0)
		_effects.set_warmup_visible(false)
		apply_state(_state)


func apply_state(data: Dictionary) -> void:
	_state = data
	if _warmup:
		return
	if int(data.get("generation", 0)) != _generation:
		_generation = int(data.get("generation", 0))
		if is_instance_valid(tracers):
			tracers.reset()
		_animation.clear()
		_projectile_age.clear()
		_soldier_free.clear()
		for soldier_kind in EnemyCatalog.model_ids("soldier"):
			_soldier_free[soldier_kind] = range(83, -1, -1)
		_last_elapsed = 0.0
		if is_instance_valid(_effects):
			_effects.reset_effects()
	var elapsed := float(data.get("elapsed", 0.0))
	var delta := maxf(0.0, elapsed - _last_elapsed)
	if is_instance_valid(tracers):
		tracers.advance(delta)
	_last_elapsed = elapsed
	if is_instance_valid(_effects):
		_effects.sync_state(data, delta)
	var alive: Dictionary = {}
	var counts: Dictionary = {}
	for model_name in _pools:
		counts[model_name] = 0
	var focus_id := int(data.get("focus_id", -1))
	for enemy in _items(data.get("enemies", [])):
		var model_name := _enemy_model(enemy)
		var pose: Dictionary = _animation.get(enemy.id, {})
		if enemy.type == "soldier" and not pose.has("instance_index"):
			pose.instance_index = _soldier_free[model_name].pop_back() if not _soldier_free[model_name].is_empty() else 0
			pose.soldier_kind = model_name
		_animation[enemy.id] = pose
		alive[enemy.id] = true
		var animated := EnemyAnimation.advance(enemy, pose, delta, elapsed)
		var point: Vector3 = animated.position
		_place(model_name, point, float(enemy.get("yaw", 0.0)), counts, animated.basis, animated.pose)
		if int(enemy.id) == focus_id and is_instance_valid(_vehicle):
			var view := _vehicle.get_node_or_null("VehicleView")
			if view != null and view.has_method("set_aim"):
				view.set_aim(point)
	for id in _animation.keys():
		if not alive.has(id):
			if _animation[id].has("soldier_kind"):
				_soldier_free[_animation[id].soldier_kind].append(_animation[id].instance_index)
			_animation.erase(id)
	for component: Dictionary in data.get("boss_components", []):
		if int(component.id) == focus_id and is_instance_valid(_vehicle):
			_vehicle.get_node("VehicleView").set_aim(component.position)
	var live_projectiles := {}
	for projectile in _items(data.get("projectiles", [])):
		var kind := str(projectile.get("kind", "bullet"))
		var model_name := "projectile_" + ("enemy_" if projectile.get("team") == "enemy" else "") + (kind if kind in ["rocket", "grenade", "sabot"] else "bullet")
		live_projectiles[projectile.id] = true
		_projectile_age[projectile.id] = float(_projectile_age.get(projectile.id, 0.0)) + delta
		var velocity: Vector3 = projectile.position - projectile.get("previous", projectile.position)
		if velocity.length_squared() <= 0.000001:
			velocity = projectile.get("velocity", Vector3.FORWARD)
		var basis := Basis(Vector3.RIGHT, _projectile_age[projectile.id] * 6.0) if kind == "grenade" else Basis(Quaternion(Vector3.UP, velocity.normalized())) if velocity.length_squared() > 0.000001 else Basis.IDENTITY
		if kind == "rocket" and projectile.has("rocket_profile"):
			var profile: Dictionary = projectile.rocket_profile
			var age := float(projectile.get("rocket_age", 0.0))
			var amplitude: float = profile.amplitude * (1.0 - exp(-16.0 * age)) * exp(-profile.decay * age)
			if amplitude > 0.0001:
				basis *= Basis(Vector3.UP, profile.phase + profile.direction * profile.angular_speed * age)
		_place(model_name, projectile.position, 0.0, counts, basis)
	for id in _projectile_age.keys():
		if not live_projectiles.has(id):
			_projectile_age.erase(id)
	_mines.sync_state(_items(data.get("mines", [])))
	for pickup in _items(data.get("pickups", [])):
		var model_name := "pickup_fuel" if str(pickup.kind) == "fuel" else "pickup_salvage"
		var transform := pickup_transform(pickup, elapsed)
		_place(model_name, transform.origin, 0.0, counts, transform.basis)
	for model_name in _pools:
		for index in range(int(counts[model_name]), int(_active_counts[model_name])):
			SourceModel.hide_pool_instance(_pools[model_name], index)
		_active_counts[model_name] = counts[model_name]


func on_event(event: Dictionary) -> void:
	if event.get("kind", "") == "bullet_segment":
		if not _warmup:
			tracers.segment(event)
		return
	if not is_instance_valid(_effects):
		return
	_effects.on_event(event)
	if str(event.get("kind", "")) == "shot" and str(event.get("team", "")) == "player":
		var view := _vehicle.get_node_or_null("VehicleView")
		if view != null and view.has_method("set_aim"):
			view.on_weapon_shot(event)


func _place(model_name: String, point: Vector3, yaw: float, counts: Dictionary, orientation: Basis = Basis.IDENTITY, pose: Dictionary = {}) -> void:
	if not _pools.has(model_name):
		return
	var index := int(counts[model_name])
	var pool: Dictionary = _pools[model_name]
	if index >= int(pool.capacity):
		return
	SourceModel.set_pool_instance(pool, index, Transform3D(Basis(Vector3.UP, yaw) * orientation, point), pose)
	counts[model_name] = index + 1


func _enemy_model(enemy: Dictionary) -> String:
	if not str(enemy.get("model", "")).is_empty():
		return str(enemy.model)
	var kind := str(enemy.get("kind", enemy.get("type", "rifleman")))
	if bool(enemy.get("boss", false)) or kind == "leviathan":
		return "boss"
	if str(enemy.get("type", "")) == "garrison" or kind == "garrison":
		return "garrison_%d" % clampi(int(enemy.get("tier", 1)), 1, 3)
	if kind == "shooter":
		return "drone"
	if kind in ENEMY_MODELS:
		return kind
	if kind in ["keep", "fortress"]:
		return "raider"
	return "rifleman"


func _items(value: Variant) -> Array:
	return value.values() if value is Dictionary else value

func on_world_event(event: Dictionary) -> void:
	if is_instance_valid(_effects):
		_effects.on_world_event(event)

static func pickup_transform(pickup: Dictionary, elapsed: float) -> Transform3D:
	return PickupMotion.pose(pickup.position, elapsed, float(pickup.get("phase", 0.0)))

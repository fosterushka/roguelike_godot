extends Node3D

signal state_changed(data: Dictionary)
signal combat_event(event: Dictionary)

const CombatModel = preload("res://modules/combat/combat_model.gd")
var model = CombatModel.new()
var vehicle: CharacterBody3D
var progression: RefCounted
var clock_delta: Callable
var result_deferred: Callable
var support_step: Callable
var _delivered_result_generation := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func setup(target_vehicle: CharacterBody3D) -> void:
	vehicle = target_vehicle
	_sync_vehicle_to_model()
	_publish()

func reset_run(seed_value: int = 72841) -> void:
	model.reset_run(seed_value)
	if is_instance_valid(vehicle):
		vehicle.max_health = model.player.max_hp
		vehicle.player_stats = model.player
		vehicle.reset_vehicle()
		vehicle.set_driving_enabled(true)
		_sync_vehicle_to_model()
	_publish()

func set_running(enabled: bool) -> void:
	model.running = enabled and model.status not in ["dead", "complete", "extracted"]
	if not model.running:
		model.jammer.reset(model.player, model.jammer.seed_value)
		model.hazards.cancel_hack()
	if is_instance_valid(vehicle):
		vehicle.set_driving_enabled(model.running)
	_publish()

func finish_run(won: bool, reason: String = "") -> bool:
	if model.status in ["dead", "complete", "extracted"]:
		return false
	_sync_vehicle_to_model()
	model._finish(won, reason)
	_sync_model_to_vehicle()
	_publish()
	return true

func _physics_process(delta: float) -> void:
	if clock_delta.is_valid():
		delta = float(clock_delta.call())
	if delta <= 0.0:
		return
	if not model.running or not is_instance_valid(vehicle):
		return
	_sync_vehicle_to_model()
	if support_step.is_valid():
		support_step.call(delta)
	model.step(delta)
	_sync_model_to_vehicle()
	_publish()

func focus_next() -> void:
	model.focus_next()
	_publish()

func focus_target(id: int) -> bool:
	for target: Dictionary in model._target_candidates():
		if target.id == id:
			model.focus_id = id
			model.Protocols.mark_focus(model.player, target, model.elapsed)
			_publish()
			return true
	return false

func focus_at(world_position: Vector3) -> void:
	model.focus_at(world_position)
	_publish()

func activate_ability(slot: int) -> bool:
	var accepted: bool = model.activate_ability(slot)
	_sync_model_to_vehicle()
	_publish()
	return accepted

func buy_upgrade(id: String) -> bool:
	if progression == null or not progression.has_method("buy_upgrade"):
		return false
	var accepted: bool = progression.buy_upgrade(id)
	_sync_model_to_vehicle()
	_publish()
	return accepted

func install_weapon(type: String) -> bool:
	var accepted: bool = model.install_weapon(type)
	_publish()
	return accepted

func apply_player_stats(stats: Dictionary) -> void:
	for key: String in stats:
		if model.player.has(key):
			model.player[key] = stats[key]
	_sync_model_to_vehicle()
	_publish()

func get_state() -> Dictionary:
	return model.snapshot()

func _sync_vehicle_to_model() -> void:
	if not is_instance_valid(vehicle):
		return
	model.player.position = vehicle.global_position
	model.player.velocity = vehicle.velocity
	model.player.speed = vehicle.motion.speed
	model.player.heading = vehicle.motion.heading
	model.player.yaw_velocity = vehicle.motion.yaw_velocity
	model.player.slip_angle = vehicle.motion.slip_angle
	model.player.handbraking = Input.is_action_pressed("handbrake")
	model.player.interact = Input.is_physical_key_pressed(KEY_E) or (InputMap.has_action("interact") and Input.is_action_pressed("interact"))
	if not model.player.interact:
		model.player.interaction_claimed = false
	elif model.player.get("interaction_claimed", false):
		model.player.interact = false
	model.player.hp = vehicle.health
	model.player.max_hp = vehicle.max_health
	model.player.fuel = vehicle.fuel
	model.player.max_fuel = vehicle.max_fuel

func _sync_model_to_vehicle() -> void:
	if not is_instance_valid(vehicle):
		return
	vehicle.player_stats = model.player
	vehicle.global_position = model.player.position
	vehicle.motion.x = model.player.position.x
	vehicle.motion.z = model.player.position.z
	vehicle.motion.speed = model.player.speed
	vehicle.health = model.player.hp
	vehicle.max_health = model.player.max_hp
	vehicle.fuel = model.player.fuel
	vehicle.max_fuel = model.player.max_fuel
	vehicle.set_driving_enabled(model.running)

func _publish() -> void:
	model.refresh_build_protocols()
	for event: Dictionary in model.drain_events():
		if event.get("kind", "") == "result":
			if result_deferred.is_valid() and result_deferred.call(event):
				continue
			_delivered_result_generation = model.generation
		combat_event.emit(event)
	state_changed.emit(get_state())

func deliver_result(event: Dictionary) -> void:
	if int(event.get("generation", -1)) != model.generation or _delivered_result_generation == model.generation:
		return
	_delivered_result_generation = model.generation
	combat_event.emit(event)
	state_changed.emit(get_state())

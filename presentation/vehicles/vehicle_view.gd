extends Node3D

const Pose = preload("res://modules/caravan/vehicle_pose.gd")
const VisualMotion = preload("res://presentation/vehicles/vehicle_visual_motion.gd")
const WheeledRig = preload("res://presentation/vehicles/wheeled_rig.gd")
const Suspension = preload("res://modules/caravan/wheel_suspension.gd")
const Equipment = preload("res://presentation/vehicles/equipment_model.gd")
const Attachments = preload("res://presentation/vehicles/attachment_view.gd")
const SLOTS := [Vector3(-1.4, 2.2, -2.2), Vector3(1.4, 2.2, -2.2), Vector3(-1.65, 2.1, 0.0), Vector3(1.65, 2.1, 0.0), Vector3(-1.55, 2.05, 2.4), Vector3(1.55, 2.05, 2.4), Vector3(0, 3.18, 0.2), Vector3(0, 1.95, 2.7), Vector3(-1.6, 2.2, -1.4), Vector3(1.6, 2.2, -1.4), Vector3(-1.6, 2.1, 1.4), Vector3(1.6, 2.1, 1.4)]
const TRAILER_SLOTS := [Vector3(-0.85, 1.48, 0.7), Vector3(0.85, 1.48, 0.7), Vector3(0, 1.48, -0.85)]
var time_delta: Callable
var _previous_pose: Dictionary = {}
var _current_pose: Dictionary = {}
var _rendered_pose: Dictionary = {}
var _physics_source := false
var _suspension := Suspension.create()
var _model: Node3D
var _wheels: Array[Node3D] = []
var _modules: Dictionary = {}
var _trailers: Dictionary = {}
var _attachments: Dictionary = {}
var _evolutions: Array[Node3D] = []
var _speed := 0.0
var _steer := 0.0
var _aim_yaw := 0.0
var _has_aim := false
var _evolution_tier := 1
var _generation := -1
var _elapsed := 0.0
var _player: Dictionary = {}
var _body := {"last_speed": 0.0, "pitch": 0.0, "roll": 0.0, "impact_pitch": 0.0, "impact_roll": 0.0, "elapsed": 0.0, "bob": 0.0, "speed_amount": 0.0, "wheel_angle": 0.0, "wheel_phase": 0.0}
var _view_position := Vector3.ZERO

func _ready() -> void:
	_model = WheeledRig.build_player()
	add_child(_model)
	_view_position = global_position
	_wheels.assign(_model.get_meta("wheels"))
	var parent := get_parent()
	_physics_source = parent.has_signal("physics_pose_advanced")
	if _physics_source:
		parent.physics_pose_advanced.connect(_advance_physics)

func set_telemetry(data: Dictionary) -> void:
	_speed = float(data.get("speed", 0.0))
	_steer = float(data.get("steer", 0.0))

func set_aim(target: Vector3) -> void:
	var direction := target - global_position
	_aim_yaw = atan2(direction.x, direction.z) - global_rotation.y
	_has_aim = true

func apply_player_state(player: Dictionary, generation: int) -> void:
	_player = player
	if generation != _generation:
		_generation = generation
		for module: Node3D in _modules.values():
			module.queue_free()
		_modules.clear()
		for trailer: Node3D in _trailers.values():
			trailer.queue_free()
		_trailers.clear()
		_attachments.clear()
		for evolution: Node3D in _evolutions:
			evolution.queue_free()
		_evolutions.clear()
		_evolution_tier = 1
		_suspension = Suspension.create()
		_current_pose.clear()
		_previous_pose.clear()
		_has_aim = false
		_elapsed = 0.0
		_body = {"last_speed": 0.0, "pitch": 0.0, "roll": 0.0, "impact_pitch": 0.0, "impact_roll": 0.0, "elapsed": 0.0, "bob": 0.0, "speed_amount": 0.0, "wheel_angle": 0.0, "wheel_phase": 0.0}
		_view_position = get_parent().global_position if get_parent() is Node3D else global_position
	set_evolution_tier(int(player.get("evolution_tier", 1)))
	var leader: Node3D = self
	for carrier: Dictionary in player.get("carriers", []):
		if not _trailers.has(carrier.id):
			var trailer := Node3D.new()
			trailer.top_level = true
			add_child(trailer)
			trailer.add_child(WheeledRig.build_trailer(str(carrier.get("type", "cargo"))))
			trailer.set_meta("suspension", Suspension.create())
			trailer.set_meta("wheel_angle", 0.0)
			trailer.set_meta("previous_pose", {})
			trailer.set_meta("current_pose", {})
			trailer.global_position = leader.global_position - leader.global_basis.z.normalized() * ((7.03 if leader == self else 5.35) * float(player.get("visual_scale", 0.88)))
			trailer.global_rotation.y = leader.global_rotation.y
			trailer.set_meta("pose", {"x": trailer.global_position.x, "z": trailer.global_position.z, "heading": trailer.global_rotation.y})
			_trailers[carrier.id] = trailer
		leader = _trailers[carrier.id]
		leader.global_basis = Basis(Vector3.UP, leader.global_rotation.y).scaled(Vector3.ONE * float(player.get("visual_scale", 0.88)))
	_sync_attachments(player)
	var current: Dictionary = {}
	for module: Dictionary in player.get("modules", []):
		var mount: Dictionary = module.get("mount", {"carrierId": "crawler", "slot": 0})
		var key := "%s:%s:%s" % [mount.carrierId, mount.slot, module.type]
		current[key] = true
		if _modules.has(key):
			continue
		var visual := Equipment.build(str(module.type))
		var crawler: bool = mount.carrierId == "crawler"
		var parent: Node3D = self if crawler else _trailers.get(mount.carrierId, self)
		parent.add_child(visual)
		var slot: int = int(mount.slot)
		visual.position = Vector3(0, 1.25, 3.85) if module.type == "bumper" else SLOTS[clampi(slot, 0, 11)] if crawler else TRAILER_SLOTS[clampi(slot, 0, 2)]
		visual.rotation.y = 0.0
		visual.set_meta("module_type", module.type)
		visual.set_meta("weapon", module.get("def", {}).has("projectile"))
		visual.set_meta("aim", {"yaw": visual.rotation.y, "pitch": 0.0, "current_pitch": 0.0, "recoil": 0.0, "base_position": visual.position})
		_modules[key] = visual
	if _current_pose.is_empty():
		_advance_physics(0.0)
		render_interpolated(1.0)
	for key: String in _modules.keys():
		if not current.has(key):
			_modules[key].queue_free()
			_modules.erase(key)

func set_evolution_tier(tier: int) -> void:
	for next_tier in range(_evolution_tier + 1, mini(tier, 4) + 1):
		var upgrade := Node3D.new()
		upgrade.name = "WheelVehicleEvolution%d" % next_tier
		WheeledRig._box(upgrade, "ReinforcedEquipmentRack", Vector3(3.0, 0.13, 0.15), Vector3(0, 3.12, -0.65 + next_tier * 0.3), "8b8e76")
		_model.add_child(upgrade)
		_evolutions.append(upgrade)
	_evolution_tier = maxi(tier, _evolution_tier)

func _process(delta: float) -> void:
	if time_delta.is_valid():
		delta = maxf(0.0, float(time_delta.call(delta)))
	if delta <= 0.0:
		return
	if _player.is_empty():
		return
	_elapsed += delta
	_player.steer = _steer
	VisualMotion.body(_body, _player, delta)
	if not _physics_source:
		_advance_physics(delta)
	render_interpolated(Engine.get_physics_interpolation_fraction() if _physics_source else 1.0)
	for module: Node3D in _modules.values():
		var aim: Dictionary = module.get_meta("aim")
		aim.recoil *= pow(0.004, delta)
		if module.get_meta("weapon", false):
			module.rotation.y = lerp_angle(module.rotation.y, aim.yaw, 1.0 - exp(-18.0 * delta))
			aim.current_pitch = lerpf(aim.current_pitch, aim.pitch, 1.0 - exp(-14.0 * delta))
			Equipment.animate(module, aim.current_pitch, aim.recoil)
		if module.get_meta("module_type", "") == "counterDroneJammer":
			Equipment.animate(module, 0.0)
		module.position = aim.base_position

func _advance_physics(delta: float) -> void:
	if _player.is_empty():
		return
	var parent := get_parent() as Node3D
	var visual_scale := float(_player.get("visual_scale", 0.88))
	_previous_pose = _current_pose
	if _physics_source:
		_current_pose = parent.current_render_pose()
	else:
		var point: Vector3 = _player.get("position", Vector3.ZERO)
		Suspension.step(_suspension, point, float(_player.get("heading", 0)), _speed, 0, delta, visual_scale)
		point.y = _suspension.height
		_current_pose = Pose.capture(point, float(_player.get("heading", 0)), visual_scale, _speed, _steer, _body.wheel_angle / (0.9 * Suspension.RADIUS * visual_scale), _suspension)
	if _previous_pose.is_empty() or delta <= 0.0:
		_previous_pose = _current_pose.duplicate(true)
	var leader := {"x": _current_pose.position.x, "z": _current_pose.position.z, "heading": _current_pose.heading, "scale": visual_scale, "rear_hitch": 3.78}
	var index := 0
	for trailer: Node3D in _trailers.values():
		var carrier := _carrier_for(trailer)
		if _physics_source and carrier.has("hp"):
			var canonical: Dictionary = carrier.get("pose", {})
			if not canonical.is_empty():
				trailer.set_meta("current_pose", canonical)
				trailer.set_meta("previous_pose", carrier.get("previous_pose", canonical))
				leader = {"x": canonical.position.x, "z": canonical.position.z, "heading": canonical.heading, "scale": visual_scale, "rear_hitch": 2.1}
			index += 1
			continue
		var pose: Dictionary = trailer.get_meta("pose")
		var suspension: Dictionary = trailer.get_meta("suspension")
		VisualMotion.trailer(pose, leader, delta, 7.03 if index == 0 else 5.35)
		Suspension.step(suspension, Vector3(pose.x, 0, pose.z), pose.heading, float(pose.get("speed", 0)), float(pose.get("yaw_rate", 0)), delta, visual_scale, true)
		var wheel_angle := float(trailer.get_meta("wheel_angle")) + float(pose.get("speed", 0)) * delta / (Suspension.RADIUS * visual_scale)
		trailer.set_meta("wheel_angle", wheel_angle)
		var current := Pose.capture(Vector3(pose.x, suspension.height, pose.z), pose.heading, visual_scale, float(pose.get("speed", 0)), float(pose.get("steer", 0)), wheel_angle, suspension)
		var previous: Dictionary = trailer.get_meta("current_pose")
		trailer.set_meta("previous_pose", current if previous.is_empty() or delta <= 0 else previous)
		trailer.set_meta("current_pose", current)
		leader = {"x": pose.x, "z": pose.z, "heading": pose.heading, "scale": visual_scale, "rear_hitch": 2.1}
		index += 1

func render_interpolated(fraction: float) -> void:
	if _current_pose.is_empty():
		return
	_rendered_pose = Pose.interpolate(_previous_pose, _current_pose, fraction)
	global_transform = Pose.transform(_rendered_pose)
	_view_position = global_position
	_suspension = _rendered_pose.suspension
	WheeledRig.animate(_model, _suspension, _rendered_pose.steer, _rendered_pose.speed, _rendered_pose.wheel_angle)
	var leader: Node3D = self
	var rear_hitch := 3.78
	for trailer: Node3D in _trailers.values():
		var carrier := _carrier_for(trailer)
		var canonical: bool = _physics_source and carrier.has("hp")
		trailer.visible = not carrier.get("dead", false) and (not canonical or not carrier.get("pose", {}).is_empty())
		if not trailer.visible:
			continue
		if canonical:
			trailer.set_meta("current_pose", carrier.pose)
			trailer.set_meta("previous_pose", carrier.get("previous_pose", carrier.pose))
		var current: Dictionary = trailer.get_meta("current_pose")
		if current.is_empty():
			continue
		var pose := Pose.interpolate(trailer.get_meta("previous_pose"), current, fraction)
		trailer.global_transform = Pose.transform(pose)
		trailer.set_meta("rendered_pose", pose)
		var rig: Node3D = trailer.get_child(0)
		WheeledRig.animate(rig, pose.suspension, pose.steer, pose.speed, pose.wheel_angle, true)
		var drawbar: Node3D = rig.get_meta("drawbar")
		drawbar.visible = not canonical or carrier.get("attached", true)
		if not drawbar.visible:
			continue
		var hitch := leader.to_global(Vector3(0, 1.0, -rear_hitch))
		drawbar.scale = Vector3.ONE
		if drawbar.global_position.distance_to(hitch) > 0.01:
			drawbar.look_at(hitch, Vector3.UP, true)
		leader = trailer
		rear_hitch = 2.1

func get_tire_contacts() -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	if _rendered_pose.is_empty():
		return contacts
	_append_contacts(contacts, "crawler", _model, _rendered_pose)
	for id in _trailers:
		var trailer: Node3D = _trailers[id]
		if not trailer.visible:
			continue
		var pose: Dictionary = trailer.get_meta("rendered_pose", {})
		if not pose.is_empty():
			_append_contacts(contacts, str(id), trailer.get_child(0), pose)
	return contacts

func _append_contacts(contacts: Array[Dictionary], id: String, rig: Node3D, pose: Dictionary) -> void:
	var wheels: Array = rig.get_meta("wheels")
	for index in wheels.size():
		var wheel: Node3D = wheels[index]
		var point := wheel.global_position
		point.y -= Suspension.RADIUS * float(pose.scale)
		contacts.append({"id": "%s:wheel%d" % [id, index], "position": point, "heading": wheel.global_rotation.y, "grounded": pose.suspension.get("wheel_contacts", [true, true, true, true])[index], "radius": Suspension.RADIUS * float(pose.scale)})

func update_motion(_speed_value: float, _steer_value: float, _delta: float) -> void:
	WheeledRig.animate(_model, _suspension, _steer, _speed, _body.wheel_angle / (0.9 * Suspension.RADIUS * float(_player.get("visual_scale", 0.88))))

func on_weapon_shot(event: Dictionary) -> void:
	var mount: Dictionary = event.get("weapon_mount", {})
	var type := str(event.get("module_type", ""))
	for key: String in _modules:
		if not key.ends_with(":" + type):
			continue
		if not mount.is_empty() and key != "%s:%s:%s" % [mount.get("carrierId", "crawler"), mount.get("slot", 0), type]:
			continue
		var module: Node3D = _modules[key]
		var origin: Vector3 = event.get("position", module.global_position)
		var target: Vector3 = origin + Vector3(event.velocity) if event.has("velocity") else event.get("target_position", origin + Vector3.FORWARD)
		var parent := module.get_parent() as Node3D
		var angles := VisualMotion.aim_angles(parent.to_local(origin), parent.to_local(target))
		var aim: Dictionary = module.get_meta("aim")
		aim.yaw = angles.x
		aim.pitch = angles.y
		aim.recoil = 1.0

func on_impact(_pitch: float, _roll: float) -> void:
	_body.impact_pitch = 0.0
	_body.impact_roll = 0.0

func get_weapon_origin(weapon: Dictionary) -> Vector3:
	var mount: Dictionary = weapon.get("mount", {"carrierId": "crawler", "slot": 0})
	var key := "%s:%s:%s" % [mount.carrierId, mount.slot, weapon.type]
	var visual: Node3D = _modules.get(key)
	if is_instance_valid(visual):
		return visual.global_position + Vector3.UP * 0.6
	var carrier: Node3D = self if mount.carrierId == "crawler" else _trailers.get(mount.carrierId, self)
	var point: Vector3 = SLOTS[clampi(int(mount.slot), 0, 11)] if mount.carrierId == "crawler" else TRAILER_SLOTS[clampi(int(mount.slot), 0, 2)]
	return carrier.to_global(point) + Vector3.UP * 0.6

func get_render_pose() -> Dictionary:
	return _rendered_pose

func _carrier_for(trailer: Node3D) -> Dictionary:
	for carrier: Dictionary in _player.get("carriers", []):
		if _trailers.get(carrier.id) == trailer:
			return carrier
	return {}

func _sync_attachments(player: Dictionary) -> void:
	var current: Dictionary = {}
	for carrier: Dictionary in player.get("carriers", []):
		if not _trailers.has(carrier.id):
			continue
		for installation: Dictionary in carrier.get("attachments", []):
			var slot := int(installation.get("slot", -1))
			if slot < 0 or slot >= TRAILER_SLOTS.size():
				continue
			var key := "%s:%d:%s" % [carrier.id, slot, installation.type]
			current[key] = true
			if not _attachments.has(key):
				var visual := Attachments.build(str(installation.type))
				visual.position = TRAILER_SLOTS[slot]
				_trailers[carrier.id].add_child(visual)
				_attachments[key] = visual
	for key: String in _attachments.keys():
		if not current.has(key):
			_attachments[key].queue_free()
			_attachments.erase(key)

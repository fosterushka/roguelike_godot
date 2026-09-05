extends SubViewportContainer

const VehicleView = preload("res://presentation/vehicles/vehicle_view.gd")
const SourceModel = preload("res://presentation/combat/source_model.gd")
const WheeledRig = preload("res://presentation/vehicles/wheeled_rig.gd")
var viewport: SubViewport
var assembly: Node3D
var selected: Node3D
var vehicle_view: Node3D
var camera: Camera3D
var _player: Dictionary = {}
var yaw := 0.75
var pitch := 0.52
var zoom := 1.0
var _dragging := false
var _active := false
var _fit_size := 13.0
var _target := Vector3(0, 2.0, 0)
var _mount_target: Dictionary = {}
var _selected_type := ""
var _build_version := 0

func _ready() -> void:
	custom_minimum_size = Vector2(330, 240)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	focus_mode = Control.FOCUS_ALL
	viewport = SubViewport.new()
	viewport.size = Vector2i(660, 540)
	viewport.gui_disable_input = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	assembly = Node3D.new()
	scene.add_child(assembly)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	camera.position = Vector3(11, 10, 12)
	scene.add_child(camera)
	_apply_view()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -30, 0)
	light.light_energy = 1.5
	scene.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202823")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c1cabe")
	environment.environment.ambient_light_energy = 0.6
	scene.add_child(environment)

func prepare_models() -> void:
	if not is_instance_valid(vehicle_view):
		vehicle_view = VehicleView.new()
		assembly.add_child(vehicle_view)
		vehicle_view.set_process(false)

func set_active(value: bool) -> void:
	_active = value
	if not value:
		_dragging = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	set_process(value)

func show_module(type: String) -> void:
	_selected_type = type
	_fit_size = 13.0 + _player.get("carriers", []).size() * 6.0
	if is_instance_valid(selected):
		selected.queue_free()
	selected = null
	if _player.get("modules", []).any(func(module: Dictionary) -> bool: return module.type == type):
		_apply_view()
		return
	var model_name := "walker_trailer" if type == "walkerTrailer" else "weapon_" + type
	selected = WheeledRig.build_trailer() if type == "walkerTrailer" else SourceModel.instantiate(model_name)
	assembly.add_child(selected)
	if type == "walkerTrailer":
		selected.position = Vector3(0, 0, -7.2 - _player.get("carriers", []).size() * 5.6)
		_fit_size = 19.0 + _player.get("carriers", []).size() * 6.0
	else:
		var mount := _preview_mount()
		var crawler: bool = mount.get("carrierId", "crawler") == "crawler"
		var slot := int(mount.get("slot", 0))
		if crawler:
			selected.position = Vector3(0, 1.25, 3.85) if type == "bumper" else VehicleView.SLOTS[clampi(slot, 0, 11)]
		else:
			var trailer_index := 0
			for index in _player.get("carriers", []).size():
				if _player.carriers[index].id == mount.carrierId:
					trailer_index = index
			selected.position = Vector3(0, 0, -7.2 - trailer_index * 5.6) + VehicleView.TRAILER_SLOTS[clampi(slot, 0, 2)]
		selected.rotation.y = 0.0 if type == "bumper" else atan2(selected.position.x, selected.position.z)
		selected.set_meta("mount", mount)
	selected.scale = Vector3.ONE
	_apply_view()

func set_mount_target(mount: Dictionary) -> void:
	_mount_target = mount.duplicate()
	if not _selected_type.is_empty():
		show_module(_selected_type)

func _preview_mount() -> Dictionary:
	if _selected_type == "bumper":
		return {"carrierId": "crawler", "slot": 12}
	if not _mount_target.is_empty():
		return _mount_target
	var carriers: Array = _player.get("carriers", []).duplicate()
	carriers.append({"id": "crawler", "slotCount": 12})
	for carrier: Dictionary in carriers:
		for slot_index in int(carrier.get("slotCount", 3)):
			if not _player.get("modules", []).any(func(module: Dictionary) -> bool: return module.get("mount", {}) == {"carrierId": carrier.id, "slot": slot_index}):
				return {"carrierId": carrier.id, "slot": slot_index}
	return {"carrierId": "crawler", "slot": 0}

func reset_view() -> void:
	yaw = 0.75
	pitch = 0.52
	zoom = 1.0
	_fit_size = 13.0 + _player.get("carriers", []).size() * 6.0
	_apply_view()

func _apply_view() -> void:
	if not is_instance_valid(camera):
		return
	camera.size = _fit_size / zoom
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 28.0
	camera.position = _target + offset
	camera.look_at(_target)

func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.double_click:
				reset_view()
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), 0.6, 2.5)
			_apply_view()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		yaw -= event.relative.x * 0.009
		pitch = clampf(pitch + event.relative.y * 0.007, 0.12, 1.35)
		_apply_view()
		accept_event()

func show_build(player: Dictionary) -> void:
	prepare_models()
	_player = player
	_build_version += 1
	vehicle_view.apply_player_state(player, _build_version)
	var trailers: int = player.get("carriers", []).size()
	_fit_size = 13.0 + trailers * 6.0
	_target = Vector3(0, 2, -trailers * 3.0)
	_apply_view()

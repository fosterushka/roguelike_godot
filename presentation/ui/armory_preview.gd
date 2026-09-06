extends SubViewportContainer

const AttachmentView = preload("res://presentation/vehicles/attachment_view.gd")
const VehicleView = preload("res://presentation/vehicles/vehicle_view.gd")
const Equipment = preload("res://presentation/vehicles/equipment_model.gd")
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
	custom_minimum_size = Vector2(300, 174)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	focus_mode = Control.FOCUS_ALL
	viewport = SubViewport.new()
	viewport.size = Vector2i(660, 400)
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
		vehicle_view = Node3D.new()
		vehicle_view.name = "LocalUnit"
		assembly.add_child(vehicle_view)

func selected_carrier() -> String:
	return str(_mount_target.get("carrierId", "crawler"))

func _rebuild_unit() -> void:
	prepare_models()
	for child in vehicle_view.get_children():
		vehicle_view.remove_child(child)
		child.queue_free()
	var crawler := selected_carrier() == "crawler"
	var trailer_type := "cargo"
	for carrier: Dictionary in _player.get("carriers", []):
		if str(carrier.id) == selected_carrier():
			trailer_type = str(carrier.get("type", "cargo"))
	vehicle_view.add_child(WheeledRig.build_player() if crawler else WheeledRig.build_trailer(trailer_type))
	for module: Dictionary in _player.get("modules", []):
		if str(module.get("mount", {}).get("carrierId", "crawler")) != selected_carrier():
			continue
		var model := Equipment.build(str(module.type))
		vehicle_view.add_child(model)
		_place_module(model, str(module.type), module.mount)
	for carrier: Dictionary in _player.get("carriers", []):
		if str(carrier.id) == selected_carrier():
			for entry: Dictionary in carrier.get("attachments", []):
				var model := AttachmentView.build(str(entry.type))
				vehicle_view.add_child(model)
				model.position = VehicleView.TRAILER_SLOTS[clampi(int(entry.slot), 0, 2)]
	_fit_size = 11.0 if crawler else 8.0
	_target = Vector3(0, 1.7 if crawler else 1.2, 0)
	_apply_view()

func _place_module(model: Node3D, type: String, mount: Dictionary) -> void:
	var slot := int(mount.get("slot", 0))
	var crawler := selected_carrier() == "crawler"
	model.position = Vector3(0, 1.25, 3.85) if type == "bumper" else VehicleView.SLOTS[clampi(slot, 0, 11)] if crawler else VehicleView.TRAILER_SLOTS[clampi(slot, 0, 2)]
	model.rotation.y = 0.0
	model.set_meta("mount", mount.duplicate())

func set_active(value: bool) -> void:
	_active = value
	if not value:
		_dragging = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	set_process(value)

func show_module(type: String) -> void:
	_selected_type = type
	if is_instance_valid(selected):
		selected.get_parent().remove_child(selected)
		selected.queue_free()
	selected = null
	if type == "walkerTrailer" or (type == "bumper" and selected_carrier() != "crawler"):
		_apply_view()
		return
	if _player.get("modules", []).any(func(module: Dictionary) -> bool: return module.type == type and module.get("mount", {}).get("carrierId", "crawler") == selected_carrier()):
		_apply_view()
		return
	var mount := _preview_mount()
	if int(mount.get("slot", -1)) < 0:
		return
	selected = Equipment.build(type)
	assembly.add_child(selected)
	_place_module(selected, type, mount)
	_apply_view()

func set_mount_target(mount: Dictionary) -> void:
	var changed := str(mount.get("carrierId", "crawler")) != selected_carrier()
	_mount_target = mount.duplicate()
	if changed:
		_rebuild_unit()
	if not _selected_type.is_empty():
		show_attachment(_selected_type.trim_prefix("attachment:")) if _selected_type.begins_with("attachment:") else show_module(_selected_type)

func _preview_mount() -> Dictionary:
	if _selected_type == "bumper":
		return {"carrierId": "crawler", "slot": 12}
	return _mount_target if not _mount_target.is_empty() else {"carrierId": "crawler", "slot": 0}

func reset_view() -> void:
	yaw = 0.75
	pitch = 0.52
	zoom = 1.0
	_fit_size = 11.0 if selected_carrier() == "crawler" else 8.0
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
	_player = player.duplicate(true)
	_build_version += 1
	_rebuild_unit()

func show_attachment(type: String) -> void:
	if is_instance_valid(selected):
		selected.get_parent().remove_child(selected)
		selected.queue_free()
	selected = null
	_selected_type = "attachment:" + type
	if selected_carrier() == "crawler":
		return
	for carrier: Dictionary in _player.get("carriers", []):
		if str(carrier.id) == selected_carrier() and carrier.get("attachments", []).any(func(item: Dictionary) -> bool: return item.type == type):
			return
	var mount := _preview_mount()
	if int(mount.get("slot", -1)) < 0:
		return
	selected = AttachmentView.build(type)
	assembly.add_child(selected)
	_place_module(selected, type, mount)

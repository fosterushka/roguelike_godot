extends Node3D

const Ground = preload("res://presentation/debug/vehicle_playground_terrain.gd")
const Controller = preload("res://modules/caravan/vehicle_controller.gd")
const View = preload("res://presentation/vehicles/vehicle_view.gd")
const Camera = preload("res://presentation/camera/follow_camera.gd")
const Inputs = preload("res://app/input_actions.gd")
const CAMERA_OFFSETS := [Vector3(18, 16, -22), Vector3(24, 6, 3)]
const CAMERA_ZOOM := 13.0
const RESET_MARGIN := 8.0
const CAPTURE_PATH := "/tmp/vehicle-playground.png"
var vehicle: CharacterBody3D
var view: Node3D
var camera: Camera3D
var telemetry: Label
var lane := 0
var camera_mode := 0
var air_time := 0.0
var last_air_time := 0.0

func _ready() -> void:
	DisplayServer.window_set_title("Vehicle Physics Playground | DEBUG")
	Inputs.register()
	var terrain := MeshInstance3D.new()
	terrain.mesh = Ground.create_mesh()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	terrain.material_override = material
	add_child(terrain)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("78929e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d5deeb")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -25, 0)
	light.light_energy = 1.6
	light.shadow_enabled = true
	add_child(light)
	for index in Ground.LANES.size():
		var label := Label3D.new()
		label.text = Ground.NAMES[index]
		label.position = Vector3(Ground.LANES[index], 3, -14)
		label.font_size = 40
		label.pixel_size = 0.025
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
	vehicle = Controller.new()
	vehicle.name = "Vehicle"
	vehicle.position = Vector3(Ground.LANES[lane], 0, Ground.SPAWN_Z)
	vehicle.terrain_sampler = Ground.height_at
	vehicle.player_stats = {"visual_scale": Controller.Dimensions.BASE_SCALE, "weight": Controller.Fuel.BASE_WEIGHT, "fuel_burn_mult": 0.0}
	add_child(vehicle)
	view = View.new()
	view.name = "VehicleView"
	vehicle.add_child(view)
	vehicle.telemetry_changed.connect(view.set_telemetry)
	view.apply_player_state({"position": vehicle.position, "heading": 0.0, "visual_scale": Controller.Dimensions.BASE_SCALE, "modules": [], "carriers": []}, 1)
	camera = Camera.new()
	camera.target = vehicle
	camera.follow_offset = CAMERA_OFFSETS[camera_mode]
	camera.half_height = CAMERA_ZOOM
	add_child(camera)
	camera._intro = 0.0
	vehicle.physics_pose_advanced.connect(_record_airtime)
	_build_overlay()
	print("PLAYGROUND_READY: WASD drive, Space handbrake, R reset, 1-4 lanes, C camera, wheel zoom, Esc quit")
	if "--playground-capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		for frame in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(CAPTURE_PATH)
		print("PLAYGROUND_CAPTURE: ", CAPTURE_PATH)

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hints := Label.new()
	hints.position = Vector2(18, 14)
	hints.text = "ПОЛИГОН ФИЗИКИ\nWASD: движение   Space: ручник   R: вернуть машину\n1–4: выбрать полосу   C: вид камеры   Колесо мыши: масштаб   Esc: выйти\nРазгонитесь перед кочкой. Здесь нет врагов, урона и расхода топлива."
	_style_label(hints)
	layer.add_child(hints)
	telemetry = Label.new()
	telemetry.position = Vector2(18, 118)
	_style_label(telemetry)
	layer.add_child(telemetry)

func _style_label(label: Label) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color("14201f"))
	label.add_theme_constant_override("outline_size", 5)

func _process(_delta: float) -> void:
	var suspension: Dictionary = vehicle.suspension
	telemetry.text = "%s\n%.0f км/ч    Колёса на земле: %d/4    %s\nНаклон: %.1f° / %.1f°    Вертикальная скорость: %.2f м/с    Последний полёт: %.2f с" % [Ground.NAMES[lane], absf(vehicle.motion.speed) * Controller.Fuel.KPH_PER_MPS, suspension.contacts, "В ВОЗДУХЕ" if suspension.contacts == 0 else "КОНТАКТ", rad_to_deg(suspension.pitch), rad_to_deg(suspension.roll), suspension.velocity, last_air_time]
	if maxf(absf(vehicle.position.x), absf(vehicle.position.z)) > Ground.HALF_SIZE - RESET_MARGIN:
		reset_lane(lane)

func _record_airtime(delta: float) -> void:
	if vehicle.suspension.contacts == 0:
		air_time += delta
	elif air_time > 0:
		last_air_time = air_time
		air_time = 0.0

func reset_lane(index: int) -> void:
	lane = clampi(index, 0, Ground.LANES.size() - 1)
	for action in ["drive_forward", "drive_backward", "drive_left", "drive_right", "handbrake"]:
		Input.action_release(action)
	vehicle._spawn_position = Vector3(Ground.LANES[lane], 0, Ground.SPAWN_Z)
	vehicle.reset_vehicle()
	vehicle.physics_pose_advanced.emit(0.0)
	view.render_interpolated(1.0)
	camera.reset_view()
	camera._intro = 0.0
	air_time = 0.0
	last_air_time = 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		camera.half_height = clampf(camera.half_height + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1), 7, 30)
		get_viewport().set_input_as_handled()
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_R: reset_lane(lane)
		KEY_1, KEY_2, KEY_3, KEY_4: reset_lane(event.physical_keycode - KEY_1)
		KEY_C:
			camera_mode = (camera_mode + 1) % CAMERA_OFFSETS.size()
			camera.follow_offset = CAMERA_OFFSETS[camera_mode]
		KEY_ESCAPE: get_tree().quit()
	get_viewport().set_input_as_handled()

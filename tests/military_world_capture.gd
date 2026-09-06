extends Node

# Staging render: real SourceModel templates arranged for visual review, not gameplay.
const SourceModel = preload("res://presentation/combat/source_model.gd")
const WheeledRig = preload("res://presentation/vehicles/wheeled_rig.gd")
const OUTPUT := "res://docs/validation/military-world"
const INFANTRY := ["rifleman", "ak", "bazooka", "bomber"]
const ENEMIES := ["bike", "buggy", "drone", "kamikaze", "raider", "jammerTruck", "repairCrawler", "minelayer", "boss"]
const PROPS := ["garrison_1", "garrison_2", "garrison_3", "mine_enemy", "heal_cart", "airdrop"]

var stage := Node3D.new()
var camera := Camera3D.new()
var captures := 0
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	get_window().size = Vector2i(1280, 800)
	get_tree().root.content_scale_size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	add_child(stage)
	_build_world()
	await _settle(8)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 56.0
	camera.position = Vector3(26, 29, 32)
	camera.look_at_from_position(camera.position, Vector3(0, 1.1, 2.0), Vector3.UP)
	await _capture("staging-lineup")
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 32.0
	camera.position = Vector3(17, 13, 22)
	camera.look_at_from_position(camera.position, Vector3(1.5, 1.2, 1.0), Vector3.UP)
	await _capture("staging-close")
	camera.size = 10.0
	camera.position = Vector3(6, 8, 27)
	camera.look_at_from_position(camera.position, Vector3(-1.5, 1.0, 17.0), Vector3.UP)
	await _capture("infantry-close")
	check(captures == 3, "Three staging images were saved")
	print("MILITARY_WORLD_CAPTURE: %d images, %d failures, infantry=%d enemies=%d props=%d" % [captures, failures, INFANTRY.size(), ENEMIES.size(), PROPS.size()])
	get_tree().quit(0 if failures == 0 else 1)

func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9fb6bc")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c9d6c4")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54, -36, 0)
	sun.light_color = Color("ffe1ad")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-32, 144, 0)
	fill.light_color = Color("9ec5d0")
	fill.light_energy = 0.55
	stage.add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(70, 54)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("7a765b")
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	stage.add_child(ground)
	_add_road()
	for index in INFANTRY.size():
		_add_source(INFANTRY[index], Vector3(-6.0 + index * 3.0, 0.0, 17.0), 0.0)
	var positions := [Vector3(-15, 0, 5), Vector3(-10, 0, 5), Vector3(-5, 3.8, 5), Vector3(0, 3.1, 5), Vector3(7, 0, 5), Vector3(15, 0, 5), Vector3(-13, 0, -8), Vector3(-2, 0, -8), Vector3(11, 0, -10)]
	for index in ENEMIES.size():
		_add_source(ENEMIES[index], positions[index], 0.0)
	_add_source("garrison_1", Vector3(-23, 0, -15), 0.15)
	_add_source("garrison_2", Vector3(-23, 0, 1), -0.12)
	_add_source("garrison_3", Vector3(23, 0, -15), -0.20)
	_add_source("mine_enemy", Vector3(6.0, 0.04, 17.0), 0.0)
	_add_source("heal_cart", Vector3(9.0, 0.0, 13.5), -0.25)
	_add_source("airdrop", Vector3(17.0, 0.0, 13.5), 0.1)
	var pickup := WheeledRig.build_player()
	pickup.name = "StagingPickup"
	pickup.position = Vector3(-14, 0, 14.0)
	pickup.rotation.y = PI
	stage.add_child(pickup)
	camera.current = true
	stage.add_child(camera)

func _add_road() -> void:
	var road := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(17, 0.025, 40)
	road.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("4b5147")
	material.roughness = 0.94
	road.material_override = material
	road.position.y = -0.018
	stage.add_child(road)
	for z in range(-16, 20, 5):
		var dash := MeshInstance3D.new()
		var dash_mesh := BoxMesh.new()
		dash_mesh.size = Vector3(0.22, 0.03, 2.1)
		dash.mesh = dash_mesh
		var dash_material := StandardMaterial3D.new()
		dash_material.albedo_color = Color("dbc376")
		dash.material_override = dash_material
		dash.position = Vector3(0, 0.01, z)
		stage.add_child(dash)

func _add_source(model_name: String, position_value: Vector3, yaw: float) -> void:
	var visual := SourceModel.instantiate(model_name)
	visual.position = position_value
	visual.rotation.y = yaw
	stage.add_child(visual)
	check(visual.get_child_count() > 0, model_name + " was instantiated from SourceModel")

func _settle(frames: int) -> void:
	for frame in frames:
		await get_tree().process_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	var destination := "%s/%s.png" % [OUTPUT, label]
	var status := frame.save_png(destination)
	check(status == OK and frame.get_size() == Vector2i(1280, 800), label + " saved at 1280x800")
	print("MILITARY_WORLD_CAPTURE %s status=%d size=%s" % [destination, status, frame.get_size()])
	captures += 1

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

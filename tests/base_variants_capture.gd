extends SceneTree

const Source = preload("res://presentation/combat/source_model.gd")
const OUTPUT := "/private/tmp/iron-base-variants.png"
const MODEL_NAMES := ["garrison_1", "garrison_2", "garrison_3"]
const MODEL_POSITIONS := [Vector3(-10, 0, 0), Vector3(0, 0, 0), Vector3(10, 0, 0)]
const WINDOW_SIZE := Vector2i(1200, 640)

func _init() -> void:
	_capture.call_deferred()

func _capture() -> void:
	root.size = WINDOW_SIZE
	root.content_scale_size = WINDOW_SIZE
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("70828a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d7e0d2")
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("ffe0ac")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var floor := PlaneMesh.new()
	floor.size = Vector2(42, 22)
	ground.mesh = floor
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("6f6d58")
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	stage.add_child(ground)
	Source.preload_models()
	for index in MODEL_NAMES.size():
		var model := Source.instantiate(MODEL_NAMES[index])
		model.position = MODEL_POSITIONS[index]
		stage.add_child(model)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19.0
	camera.position = Vector3(21, 16, 26)
	camera.look_at_from_position(camera.position, Vector3(0, 2.7, 0), Vector3.UP)
	stage.add_child(camera)
	camera.current = true
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var status := image.save_png(OUTPUT)
	print("BASE_VARIANTS_CAPTURE path=%s status=%d size=%s" % [OUTPUT, status, image.get_size()])
	quit(0 if status == OK and image.get_size() == WINDOW_SIZE else 1)

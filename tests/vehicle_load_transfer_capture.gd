extends SceneTree

const Suspension = preload("res://modules/caravan/wheel_suspension.gd")
const Pose = preload("res://modules/caravan/vehicle_pose.gd")
const Rig = preload("res://presentation/vehicles/wheeled_rig.gd")
const OUTPUT := "res://docs/validation/handling-revision"
const STEP := 1.0 / 60.0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1200, 720)
	var world := Node3D.new()
	root.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 2.0
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("536778")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(50, 50)
	floor_mesh.mesh = plane
	world.add_child(floor_mesh)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(12, 5, 8)
	camera.look_at(Vector3(0, 1.3, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11
	camera.current = true
	var rig := Rig.build_player()
	world.add_child(rig)
	var state := Suspension.create()
	var flat := func(_x: float, _z: float) -> float: return 0.0
	Suspension.step(state, Vector3.ZERO, 0, 0, 0, STEP, 1, false, flat)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for phase in ["stationary", "acceleration", "braking"]:
		for frame in 60:
			var speed := 0.0 if phase == "stationary" else float(frame + 1) * 0.1 if phase == "acceleration" else maxf(0, 6.0 - float(frame + 1) * 0.1)
			Suspension.step(state, Vector3.ZERO, 0, speed, 0, STEP, 1, false, flat)
			rig.transform = Pose.transform(Pose.capture(Vector3(0, state.height, 0), 0, 1, speed, 0, 0, state))
			Rig.animate(rig, state, 0, speed, 0)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT.path_join(phase + ".png"))
		print(phase, " pitch=", rad_to_deg(state.pitch), " contacts=", state.contacts)
	world.queue_free()
	await process_frame
	quit()

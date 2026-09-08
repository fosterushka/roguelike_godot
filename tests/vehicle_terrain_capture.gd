extends SceneTree

const Suspension = preload("res://modules/caravan/wheel_suspension.gd")
const Pose = preload("res://modules/caravan/vehicle_pose.gd")
const Rig = preload("res://presentation/vehicles/wheeled_rig.gd")
const OUTPUT := "res://docs/validation/suspension-terrain"
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for phase in ["flat", "uphill", "side_slope", "diagonal", "single_wheel", "after_bump"]:
		var sampler := func(x: float, z: float) -> float:
			match phase:
				"uphill": return z * 0.2
				"side_slope": return x * 0.2
				"diagonal": return x * 0.14 + z * 0.16
				"single_wheel": return 0.4 if x > 0.8 and x < 3.0 and z > 1.2 and z < 3.8 else 0.0
			return 0.0
		floor_mesh.mesh = _terrain_mesh(sampler)
		for frame in 120:
			Suspension.step(state, Vector3.ZERO, 0, 0, 0, STEP, 1, false, sampler)
			rig.transform = Pose.transform(Pose.capture(Vector3(0, state.height, 0), 0, 1, 0, 0, 0, state))
			Rig.animate(rig, state, 0, 0, 0)
			await process_frame
			if phase == "single_wheel" and frame in [5, 15, 30]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUTPUT.path_join("bump-frame-%d.png" % frame))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT.path_join(phase + ".png"))
		print(phase, " pitch=", rad_to_deg(state.pitch), " roll=", rad_to_deg(state.roll), " contacts=", state.contacts)
	await _capture_jump(rig, camera, floor_mesh)
	await _capture_controls()
	world.queue_free()
	await process_frame
	quit()

func _terrain_mesh(sampler: Callable, first_z: int = -35, last_z: int = 35) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const GRID_STEP := 0.2
	for ix in range(-35, 35):
		for iz in range(first_z, last_z):
			var x := ix * GRID_STEP
			var z := iz * GRID_STEP
			for corner in [Vector2(x,z), Vector2(x+GRID_STEP,z), Vector2(x,z+GRID_STEP), Vector2(x+GRID_STEP,z), Vector2(x+GRID_STEP,z+GRID_STEP), Vector2(x,z+GRID_STEP)]:
				surface.add_vertex(Vector3(corner.x, sampler.call(corner.x, corner.y), corner.y))
	surface.generate_normals()
	return surface.commit()

func _capture_jump(rig: Node3D, camera: Camera3D, floor_mesh: MeshInstance3D) -> void:
	var sample := func(_x: float, z: float) -> float: return 0.9 * exp(-pow(z / 2.2, 2))
	floor_mesh.mesh = _terrain_mesh(sample, -100, 250)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("777461")
	floor_mesh.material_override = material
	var state := Suspension.create()
	const SPEED := 14.0
	var captured_air := false
	var captured_landing := false
	var max_gap := 0.0
	for tick in 210:
		var point := Vector3(0, 0, minf(25, -12 + tick * STEP * SPEED))
		Suspension.step(state, point, 0, SPEED, 0, STEP, 1, false, sample)
		point.y = state.height
		rig.transform = Pose.transform(Pose.capture(point, 0, 1, SPEED, 0, tick * STEP * SPEED / Suspension.RADIUS, state))
		Rig.animate(rig, state, 0, SPEED, tick * STEP * SPEED / Suspension.RADIUS)
		camera.position = Vector3(12, 4, point.z + 8)
		camera.look_at(Vector3(0, 1.0, point.z))
		await process_frame
		if state.contacts == 0:
			var gap := INF
			for wheel: Node3D in rig.get_meta("wheels"):
				var p := wheel.global_position
				gap = minf(gap, p.y - Suspension.RADIUS - sample.call(p.x, p.z))
			if gap > max_gap:
				max_gap = gap
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUTPUT.path_join("jump-airborne.png"))
				captured_air = true
		elif captured_air and not captured_landing:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT.path_join("jump-landing.png"))
			captured_landing = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT.path_join("jump-settled.png"))
	print("RENDER_JUMP gap=", max_gap, " landed=", captured_landing, " final_contacts=", state.contacts)

func _capture_controls() -> void:
	var locale = preload("res://presentation/ui/ui_locale.gd")
	locale.settings_path = "/tmp/vehicle-controls-capture.cfg"
	var hud := preload("res://presentation/ui/hud.gd").new()
	root.add_child(hud)
	hud.set_loading(false)
	hud.set_gameplay_active(true)
	for language in ["en", "ru"]:
		hud.set_language(language)
		hud.set_paused(true)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT.path_join("controls-" + language + ".png"))
	hud.queue_free()
	await process_frame

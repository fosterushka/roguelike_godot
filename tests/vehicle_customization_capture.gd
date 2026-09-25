extends SceneTree

const Rig = preload("res://presentation/vehicles/wheeled_rig.gd")
const OUTPUT := "res://docs/validation/qol-2026-09-12"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 900)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("172124")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("afbec0")
	environment.environment.ambient_light_energy = 0.6
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_node := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(100, 100)
	floor_node.mesh = floor_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("36403b")
	material.roughness = 0.95
	floor_node.material_override = material
	world.add_child(floor_node)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(10, 15, 23)
	camera.look_at(Vector3(0, 1.1, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.current = true
	var selections := [{}, {"paint": "sand", "emblem": "stripe", "tires": "road_tires"}, {"paint": "oxide", "emblem": "cross", "tires": "mud_tires", "fog_lamps": true}]
	var labels := ["FIELD / STANDARD", "SAND / ROAD", "OXIDE / MUD / FOG LAMPS"]
	var rigs: Array[Node3D] = []
	var titles: Array[Label3D] = []
	for index in selections.size():
		var rig := Rig.build_player(selections[index])
		rig.position.x = (index - 1) * 7.3
		world.add_child(rig)
		rigs.append(rig)
		var label := Label3D.new()
		label.text = labels[index]
		label.font_size = 36
		label.pixel_size = 0.012
		label.position = Vector3(rig.position.x, 0.2, 6.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
		titles.append(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT.path_join("customization-comparison.png"))
	for rig: Node3D in rigs:
		rig.visible = rig == rigs.back()
	for title: Label3D in titles:
		title.visible = title == titles.back()
	camera.position = rigs.back().position + Vector3(7, 7, 12)
	camera.look_at(rigs.back().position + Vector3(0, 1.3, 2))
	camera.size = 13
	sun.light_energy = 0.3
	environment.environment.ambient_light_energy = 0.2
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT.path_join("fog-lamps-model.png"))
	world.queue_free()
	await process_frame
	print("CUSTOMIZATION_CAPTURE_OK")
	quit()

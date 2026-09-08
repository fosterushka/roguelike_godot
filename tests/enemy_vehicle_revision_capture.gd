extends SceneTree
const Enemies = preload("res://presentation/combat/military_enemies.gd")
const Library = preload("res://presentation/world/environment_library.gd")
const OUTPUT := "res://docs/enemy-vehicle-review/"
var stage: Node3D
var camera: Camera3D
func _init() -> void:
	root.size = Vector2i(1440, 800)
	root.msaa_3d = Viewport.MSAA_4X
	_run.call_deferred()
func _run() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("353e40")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("d4dfdf")
	world.environment.ambient_light_energy = 0.65
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, -32, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("444e4a")
	mat.roughness = 1.0
	plane.material = mat
	ground.mesh = plane
	ground.position.y = -0.03
	root.add_child(ground)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16
	root.add_child(camera)
	camera.look_at_from_position(Vector3(0, 10, 19), Vector3(0, 1.6, 0))
	var styles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_vehicle_styles.json"))
	for model: String in styles.models:
		stage = Node3D.new()
		root.add_child(stage)
		for index in 2:
			var vehicle := Node3D.new()
			stage.add_child(vehicle)
			var bounds := AABB()
			var variant := "field" if index == 0 else "armored"
			for part: Dictionary in Enemies.templates(model, variant):
				var visual := MeshInstance3D.new()
				visual.mesh = part.mesh
				visual.transform = part.transform
				vehicle.add_child(visual)
				bounds = bounds.merge(part.transform * part.mesh.get_aabb())
			var amount := 5.5 / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
			vehicle.scale = Vector3.ONE * amount
			vehicle.position = Vector3(-4.1 if index == 0 else 4.1, 0, 0)
			vehicle.rotation.y = -0.55
		await capture(model + "-godot.png")
		if model == "boss":
			stage.get_child(0).visible = false
			var hero: Node3D = stage.get_child(1)
			hero.position = Vector3.ZERO
			hero.rotation.y = 0
			camera.size = 8.2
			camera.look_at_from_position(Vector3(9, 6, 12), Vector3(0, 0.9, 0))
			await capture("boss-hero-godot.png")
			camera.look_at_from_position(Vector3(-9, 6, -12), Vector3(0, 0.9, 0))
			await capture("boss-rear-godot.png")
			camera.look_at_from_position(Vector3(3, 13, 7), Vector3(0, 0.8, 0))
			await capture("boss-top-godot.png")
			camera.size = 16
			camera.look_at_from_position(Vector3(0, 10, 19), Vector3(0, 1.6, 0))
		stage.queue_free()
		await process_frame
	stage = Node3D.new()
	root.add_child(stage)
	for index in 2:
		var tree := MeshInstance3D.new()
		tree.mesh = Library.mesh_for("spruceTrees" if index == 0 else "birchTrees")
		tree.position.x = -4.5 if index == 0 else 4.5
		stage.add_child(tree)
	camera.size = 18
	camera.look_at_from_position(Vector3(0, 11, 22), Vector3(0, 4.1, 0))
	await capture("trees-godot.png")
	for node in root.get_children(): node.queue_free()
	await process_frame
	await process_frame
	quit()
func capture(file: String) -> void:
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var status := root.get_texture().get_image().save_png(OUTPUT + file)
	print("ENEMY_REVISION_CAPTURE ", file, " status=", status)

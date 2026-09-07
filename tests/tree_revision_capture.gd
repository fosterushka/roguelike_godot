extends SceneTree
const Library = preload("res://presentation/world/environment_library.gd")
func add_mesh(pool: String, position: Vector3, scale := Vector3.ONE) -> void:
	var node := MeshInstance3D.new()
	node.mesh = Library.mesh_for(pool)
	node.position = position
	node.scale = scale
	root.add_child(node)
func _init() -> void:
	root.size = Vector2i(1280, 800)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new(); environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color("31382d"); environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color = Color("d5ddd4"); environment.environment.ambient_light_energy = 0.65; root.add_child(environment)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-48, -28, 0); sun.light_energy = 1.0; sun.shadow_enabled = true; root.add_child(sun)
	var ground := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(30, 24); var ground_material := StandardMaterial3D.new(); ground_material.albedo_color = Color("766c51"); ground_material.roughness = 1; plane.material = ground_material; ground.mesh = plane; root.add_child(ground)
	add_mesh("spruceTrees", Vector3(-5,0,2)); add_mesh("birchTrees", Vector3(4,0,1)); add_mesh("scrubInstances", Vector3(-2,0,4), Vector3(1.3,1.3,1.3)); add_mesh("deadBrushInstances", Vector3(1,0,4)); add_mesh("grassTufts", Vector3(-.5,0,2), Vector3(1.4,1.4,1.4)); add_mesh("flowerInstances", Vector3(2.4,0,3), Vector3(1.4,1.4,1.4))
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 15; camera.position = Vector3(12, 10, 18); root.add_child(camera); camera.look_at_from_position(camera.position, Vector3(0,4,1)); camera.current = true
	capture.call_deferred()
func capture() -> void:
	for frame in 8: await process_frame
	var status := root.get_texture().get_image().save_png("res://docs/validation/trees-rebuilt/trees.png")
	print("ENVIRONMENT_LIBRARY_CAPTURE status=", status)
	for child in root.get_children(): child.queue_free()
	await process_frame
	await process_frame
	quit()

extends SceneTree

const Source = preload("res://presentation/combat/source_model.gd")
const Seats = preload("res://presentation/crew/crew_seats.gd")
const Appearance = preload("res://presentation/crew/crew_appearance.gd")
const Rig = preload("res://presentation/vehicles/wheeled_rig.gd")
const FollowCamera = preload("res://presentation/camera/follow_camera.gd")
var output := "res://docs/validation/model-quality/actors"
var stage: Node3D
var camera: Camera3D
var content: Node3D
var audit := false
var metrics := {}
var camera_reference := {}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--audit":
			audit = true
		if argument.begins_with("--camera-reference="):
			camera_reference = JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--camera-reference=")))
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440, 900)
	stage = Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("393d37")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = 0.72
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	stage.add_child(sun)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	content = Node3D.new()
	stage.add_child(content)
	var people := ["rifleman", "ak", "bazooka", "bomber"]
	for index in people.size():
		_add(Source.instantiate(people[index]), Vector3((index-1.5)*1.7,0,0))
	await _capture("infantry", Vector3(0,1.1,0), 8.2)
	var gameplay_camera := FollowCamera.new()
	camera.size = gameplay_camera.half_height * 2.0
	camera.position = Vector3(0,1.1,0) + gameplay_camera.follow_offset
	camera.look_at(Vector3(0,1.1,0))
	await _save("infantry-game-scale")
	gameplay_camera.free()
	_clear()
	var roles := ["mechanic", "shooter", "loader", "looter", "fuel", "anti_tank", "anti_air", "civilian"]
	for index in roles.size():
		var body := Source.instantiate("rifleman")
		Appearance.apply(body, roles[index])
		for part in body.get_children():
			if part.has_meta("source_part") and part.get_meta("source_part").rig.get("role", "") == "weapon": part.visible = false
		_add(body, Vector3((index%4-1.5)*1.8,0,(index/4)*2.8))
	await _capture("crew-front", Vector3(0,1,1.3), 9.2)
	camera.position = Vector3(-5,4,-9)
	camera.look_at(Vector3(0,1,1.3))
	await _save("crew-back")
	_clear()
	for index in 4:
		var body := Seats.build()
		Seats.apply_role(body, roles[index], "ally")
		_add(body, Vector3((index-1.5)*1.5,0,0))
	await _capture("seated", Vector3(0,.9,0), 7.0)
	_clear()
	var vehicles := ["bike", "buggy", "drone", "kamikaze", "jammerTruck", "minelayer", "repairCrawler", "raider", "boss", "wreck_buggy"]
	for kind in vehicles:
		var model := Source.instantiate(kind)
		_add(model, Vector3.ZERO)
		var bounds := _bounds(model)
		await _capture(kind, bounds.get_center(), maxf(bounds.size.length() * 1.12,3.5))
		_clear()
	if audit:
		await _audit_extra()
	var report := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics, "\t") + "\n")
	report.close()
	print("ACTOR_QUALITY_CAPTURES ", output)
	stage.queue_free()
	await process_frame
	quit()

func _add(model: Node3D, point: Vector3) -> void:
	content.add_child(model)
	model.position = point

func _clear() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func _capture(label: String, center: Vector3, span: float) -> void:
	camera.size = span
	camera.position = center + Vector3(0.44,0.42,1.0) * span
	camera.look_at(center)
	await _save(label)

func _save(label: String) -> void:
	if camera_reference.has(label):
		var previous: Dictionary = camera_reference[label]
		camera.size = previous.camera_size
		camera.position = Vector3(previous.camera_position[0], previous.camera_position[1], previous.camera_position[2])
		camera.rotation = Vector3(previous.camera_rotation[0], previous.camera_rotation[1], previous.camera_rotation[2])
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output + "/" + label + ".png")
	assert(result == OK, "Capture could not be saved: " + label)
	var measurement := {"triangles": 0, "mesh_instances": 0, "surfaces": 0}
	_measure(content, measurement)
	measurement.camera_size = camera.size
	measurement.camera_position = [camera.position.x, camera.position.y, camera.position.z]
	measurement.camera_rotation = [camera.rotation.x, camera.rotation.y, camera.rotation.z]
	measurement.draw_calls = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	measurement.rendered_primitives = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	metrics[label] = measurement

func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	for child in node.get_children():
		if child is MeshInstance3D:
			result = result.merge(child.transform * child.mesh.get_aabb())
	return result

func _measure(node: Node, measurement: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		measurement.mesh_instances += 1
		measurement.triangles += node.mesh.get_faces().size() / 3
		measurement.surfaces += node.mesh.get_surface_count()
	for child in node.get_children():
		_measure(child, measurement)

func _audit_extra() -> void:
	var enemies = preload("res://presentation/combat/military_enemies.gd")
	var styles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_vehicle_styles.json"))
	for kind: String in styles.models:
		for variant: String in styles.variants:
			var model := Node3D.new()
			for part: Dictionary in enemies.templates(kind, variant):
				var visual := MeshInstance3D.new()
				visual.mesh = part.mesh
				visual.transform = part.transform
				model.add_child(visual)
			_add(model, Vector3.ZERO)
			var bounds := _bounds(model)
			await _capture(kind + "-" + variant, bounds.get_center(), maxf(bounds.size.length() * 1.12, 3.5))
			await _game_scale(kind + "-" + variant + "-game", bounds.get_center())
			_clear()
	var pickup := Rig.build_player()
	_add(pickup, Vector3.ZERO)
	await _capture("player", Vector3(0,1.2,0), 9.0)
	await _game_scale("player-game", Vector3(0,1.2,0))
	_clear()
	for kind in ["cargo", "repair", "weapon", "fuel", "anti_tank", "anti_air"]:
		_add(Rig.build_trailer(kind), Vector3.ZERO)
		await _capture("wagon-" + kind, Vector3(0,1.5,0), 8.5)
		_clear()

func _game_scale(label: String, center: Vector3) -> void:
	var gameplay_camera := FollowCamera.new()
	camera.size = gameplay_camera.half_height * 2.0
	camera.position = center + gameplay_camera.follow_offset
	camera.look_at(center)
	await _save(label)
	gameplay_camera.free()

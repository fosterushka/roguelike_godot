extends SceneTree

const Source = preload("res://presentation/combat/source_model.gd")
const Seats = preload("res://presentation/crew/crew_seats.gd")
const Appearance = preload("res://presentation/crew/crew_appearance.gd")
const Rig = preload("res://presentation/vehicles/wheeled_rig.gd")
const OUT := "res://docs/validation/model-quality/actors"
var stage: Node3D
var camera: Camera3D
var content: Node3D

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
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
	print("ACTOR_QUALITY_CAPTURES ", OUT)
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
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + label + ".png")

func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	for child in node.get_children():
		if child is MeshInstance3D:
			result = result.merge(child.transform * child.mesh.get_aabb())
	return result

extends SceneTree
const Source = preload("res://presentation/combat/source_model.gd")
const Equipment = preload("res://presentation/vehicles/equipment_model.gd")
const Effects = preload("res://presentation/combat/impact_effects.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("333a37")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = 0.7
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.8
	stage.add_child(sun)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18
	camera.position = Vector3(7, 10, 21)
	camera.look_at(Vector3(0, 1, 0))
	var models := [Source.instantiate("bike"), Equipment.build("bazooka"), Equipment.build("anti_air_station"), Source.instantiate("airdrop")]
	var positions := [Vector3(-5,0,-4),Vector3(0,0,-2),Vector3(4,0,-2),Vector3(-5,-12,5)]
	for index in models.size():
		stage.add_child(models[index])
		models[index].position = positions[index]
		if index in [1,2]: models[index].scale = Vector3.ONE * 1.6
		if index == 3:
			for part: MeshInstance3D in models[index].get_children():
				if part.get_meta("source_part").bindings.size() > 0: part.visible = false
	var smoke := preload("res://presentation/world/airdrop_flare_smoke.gd").new()
	stage.add_child(smoke)
	smoke.apply_drop({"position":Vector3(-5,0,5),"height":0},1.2)
	var fx := Effects.new()
	stage.add_child(fx)
	fx.set_process(false)
	for frame in 8: await process_frame
	fx.on_event({"kind":"death","type":"soldier","position":Vector3(1,0,4)})
	fx.on_event({"kind":"hit","team":"player","position":Vector3(4,0,4)})
	fx.advance_cinematic(0.08)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/combat-upgrades.png")
	print("CAPTURE /tmp/combat-upgrades.png")
	stage.queue_free()
	await process_frame
	quit()

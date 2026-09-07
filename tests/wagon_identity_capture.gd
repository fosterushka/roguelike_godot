extends SceneTree

const Wagon = preload("res://presentation/vehicles/military_wagon.gd")
const Attachment = preload("res://presentation/vehicles/attachment_view.gd")
const Seats = preload("res://presentation/crew/crew_seats.gd")
const VehicleView = preload("res://presentation/vehicles/vehicle_view.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#24292b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#d4dde2")
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.4
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22
	stage.add_child(camera)
	camera.position = Vector3(0, 19, 23)
	camera.look_at(Vector3(0, 0, 0))
	var types := ["cargo", "repair", "weapon", "fuel", "anti_tank", "anti_air"]
	for index in types.size():
		var wagon := Wagon.build(types[index])
		stage.add_child(wagon)
		wagon.position = Vector3((index % 3 - 1) * 7, 0, (index / 3 - 0.5) * 8)
		wagon.rotation.y = -0.55
		if "--equipped" in OS.get_cmdline_user_args():
			var equipment := ["cargo_rack", "repair_station", "turret", "fuel_pump", "anti_tank_station", "anti_air_station"]
			var mounted := Attachment.build(equipment[index])
			wagon.add_child(mounted)
			mounted.position = VehicleView.TRAILER_SLOTS[0]
			for seat in 2:
				var person := Seats.build()
				wagon.add_child(person)
				person.position = Seats.anchor("wagon-showcase", seat)
		var label := Label3D.new()
		label.text = types[index].to_upper().replace("_", " ")
		label.font_size = 48
		label.pixel_size = 0.009
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		stage.add_child(label)
		label.position = wagon.position + Vector3(0, 0, 3.5)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "/private/tmp/wagon-shapes-equipped.png" if "--equipped" in OS.get_cmdline_user_args() else "/private/tmp/wagon-identities.png"
	root.get_texture().get_image().save_png(path)
	print("WAGON_IDENTITY_CAPTURE " + path)
	stage.queue_free()
	await process_frame
	quit()

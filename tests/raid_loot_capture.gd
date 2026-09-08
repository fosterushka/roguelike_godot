extends SceneTree

const Loot = preload("res://presentation/world/raid_loot.gd")
const Catalog = preload("res://modules/meta/expedition_catalog.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const OUT := "res://docs/validation/loot"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1440, 900)
	Locale.initialize()
	Locale.language = "en"
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("393d37")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.72
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	stage.add_child(sun)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 28
	camera.position = Vector3(0, 19, 24)
	camera.look_at(Vector3(0, 1, 0))
	var floor_view := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(80, 80)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("555b48")
	floor_mesh.material = material
	floor_view.mesh = floor_mesh
	stage.add_child(floor_view)
	var loot := Loot.new()
	stage.add_child(loot)
	loot.set_process(false)
	var index := 0
	for item: String in Catalog.ITEMS:
		var position := Vector3((index % 3 - 1) * 8.0, 0, (index / 3 - 0.5) * 9.0)
		loot.spawn_items(item, position, {item: 1})
		index += 1
	for language: String in ["en", "ru"]:
		Locale.language = language
		loot.advance(0.13)
		for frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := OUT + "/items-" + language + ".png"
		var error := root.get_texture().get_image().save_png(path)
		print("LOOT_CAPTURE %s error=%d" % [path, error])
	stage.free()
	await process_frame
	quit()

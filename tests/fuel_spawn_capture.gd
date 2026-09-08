extends SceneTree

const Generator = preload("res://modules/world/generation/world_generator.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
const Ground = preload("res://modules/caravan/terrain_surface.gd")
const OUT := "res://docs/validation/fuel-stations/procedural-pump.png"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 900)
	var arena := preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	var context := Generator.generate(72841, Authored.new())
	paused = true
	assert(arena.rebuild_from_context(context))
	paused = false
	var pumps: Array = context.layout.monuments.filter(func(site): return str(site.id).begins_with("fuel-stop-"))
	pumps.sort_custom(func(left, right): return Vector2(left.x, left.z).length_squared() < Vector2(right.x, right.z).length_squared())
	var site: Dictionary = pumps[0]
	var center := Vector3(site.x, Ground.height_at(site.x, site.z), site.z)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 70
	camera.position = center + Vector3(35, 48, 45)
	camera.look_at(center)
	for frame in 8:
		await process_frame
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	root.get_texture().get_image().save_png(OUT)
	print("Procedural fuel capture: seed 72841, %s, distance %.1f m" % [site.id, Vector2(site.x, site.z).length()])
	arena.free()
	camera.free()
	await process_frame
	quit()

extends SceneTree
const Generator = preload("res://modules/world/generation/world_generator.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
const OUTPUT := "res://docs/validation/model-quality"
const SETTLE_FRAMES := 45
const SAMPLE_FRAMES := 120
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var output := OUTPUT if arguments.is_empty() else arguments[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280,800)
	var arena := preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	var context := Generator.generate(72841, Authored.new())
	paused = true
	assert(arena.rebuild_from_context(context), "Quality capture must render the generated world")
	paused = false
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 70
	root.add_child(camera)
	camera.position = Vector3(40,45,75)
	camera.look_at(Vector3(0,0,35))
	camera.current = true
	for frame in SETTLE_FRAMES:
		await process_frame
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in SAMPLE_FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now-previous)/1000.0)
		previous = now
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("world-live.png"))
	samples.sort()
	var result := {"scenario":"Generated seed72841, static camera, Metal rendering; no combat load or before/after comparison", "frames":SAMPLE_FRAMES, "median_frame_ms":samples[SAMPLE_FRAMES/2], "p95_frame_ms":samples[int(SAMPLE_FRAMES*.95)], "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "rendered_primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	var file := FileAccess.open(output.path_join("world-render-sample.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"));file.close()
	print("MODEL_QUALITY_WORLD_RENDER: ",result)
	arena.queue_free();camera.queue_free()
	await process_frame
	await process_frame
	quit()

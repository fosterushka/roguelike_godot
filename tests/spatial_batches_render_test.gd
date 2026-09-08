extends SceneTree

const Generator = preload("res://modules/world/generation/world_generator.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
const View = preload("res://presentation/world/generated_world_view.gd")
const SAMPLE_FRAMES := 180
const SETTLE_FRAMES := 45
const FRAME_BUDGET_MS := 1000.0 / 60.0
var output := "/tmp/iron-spatial-render"
var capped := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Requires actual rendering")
		quit(1)
		return
	var factory: Script = View
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("baseline="):
			factory = load(arg.trim_prefix("baseline="))
		elif arg == "capped":
			capped = true
		elif arg.begins_with("output="):
			output = arg.trim_prefix("output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 800)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if capped else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60 if capped else 0
	RenderingServer.render_loop_enabled = false
	var arena := preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	if factory != View:
		var ground: MeshInstance3D = arena.get_node("OriginalTerrainSurface")
		for chunk: Node in ground.get_children():
			chunk.free()
		ground.mesh = preload("res://modules/caravan/terrain_surface.gd").create_mesh()
	var start := Time.get_ticks_usec()
	var context := Generator.generate(72841, Authored.new())
	var generation_ms := (Time.get_ticks_usec() - start) / 1000.0
	start = Time.get_ticks_usec()
	var view: Node3D = factory.new()
	var layout: Dictionary = view.build(context)
	arena.source_world.free()
	arena.source_world = view
	arena.world_layout = layout
	arena.add_child(view)
	var application_ms := (Time.get_ticks_usec() - start) / 1000.0
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	root.add_child(camera)
	var report := {"adapter": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "resolution": [1280, 800], "vsync": "enabled, 60 FPS cap" if capped else "disabled", "seed": 72841, "generation_ms": generation_ms, "application_ms": application_ms, "resident_world_children": view.get_child_count(), "phases": []}
	var village: Dictionary = layout.villages[0]
	var route := [{"name": "start", "target": Vector3(0, 0, 35), "zoom": 70.0}, {"name": "negative_boundary", "target": Vector3(-128, 0, -128), "zoom": 70.0}, {"name": "village", "target": Vector3(village.x, 0, village.z), "zoom": 70.0}, {"name": "zoom_out", "target": Vector3(128, 0, 128), "zoom": 140.0}, {"name": "return", "target": Vector3(0, 0, 35), "zoom": 70.0}]
	for phase: Dictionary in route:
		print("SPATIAL_PHASE ", phase.name)
		camera.size = phase.zoom
		camera.position = phase.target + Vector3(40, 45, 40)
		camera.look_at(phase.target)
		var samples: Array[float] = []
		var previous := Time.get_ticks_usec()
		var first_visit_max := 0.0
		for frame in SETTLE_FRAMES:
			await process_frame
			RenderingServer.force_draw()
			var now := Time.get_ticks_usec()
			first_visit_max = maxf(first_visit_max, (now - previous) / 1000.0)
			previous = now
		var over_budget := 0
		for frame in SAMPLE_FRAMES:
			await process_frame
			RenderingServer.force_draw()
			var now := Time.get_ticks_usec()
			var elapsed := (now - previous) / 1000.0
			samples.append(elapsed)
			if elapsed > FRAME_BUDGET_MS:
				over_budget += 1
			previous = now
		samples.sort()
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(output.path_join(phase.name + ".png"))
		report.phases.append({"name": phase.name, "p50": samples[89], "p95": samples[170], "p99": samples[178], "max": samples[-1], "first_visit_max": first_visit_max, "over_budget": over_budget, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), "static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	arena.queue_free()
	camera.queue_free()
	await process_frame
	print("Spatial render: 0 failures; ", output)
	quit()

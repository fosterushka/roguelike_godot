extends Node

const Main = preload("res://tests/combat_performance_host.gd")
const Frames = preload("res://infrastructure/diagnostics/frame_metrics.gd")
const Profiler = preload("res://infrastructure/diagnostics/runtime_profiler.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const SAMPLE_FRAMES := 240
const PREVIEW_FRAMES := 30
const SUSTAINED_FRAMES := 3600
const SUSTAINED_WARMUP_FRAMES := 600
const WARMUP_FRAMES := 45
const NPC_COUNT := 80
const SEED := 72841
const TEST_HEALTH := 1000000000.0
const OUTPUT := "res://docs/validation/combat-optimization/"
var game: Node3D
var results: Array[Dictionary] = []
var shot_count := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	Locale.settings_path = "/private/tmp/combat-audit-language-%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("en")
	get_window().size = Vector2i(1280, 800)
	game = Main.new()
	game.profile_path = "/private/tmp/combat-audit-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = SEED
	get_tree().root.add_child(game)
	await game.game_ready
	await game.restart_run()
	game.session_flow.clock.intro_remaining = 0.0
	game.session_flow.clock.phase = "running"
	game.camera._intro = 0.0
	game.combat.combat_event.connect(func(event: Dictionary):
		if event.kind == "shot" and event.team == "player": shot_count += 1)
	# Isolate combat in the real rendered world; world activities cannot add test actors.
	game.world.set_physics_process(false)
	game.world.weather.phase = {"type": "clear", "index": 0, "ends_at": 999999.0}
	game.world._sync_weather_model()
	game.sound.set_enabled(true)
	game.performance_bar.set_open(true)
	game.performance_bar.set_process(false)
	if "--sustained" in OS.get_cmdline_user_args():
		await _phase("80_npc_2_miniguns_sustained", NPC_COUNT, 2)
	elif "--preview" in OS.get_cmdline_user_args():
		await _phase("bar-gameplay-final", NPC_COUNT, 2)
	else:
		await _phase("empty", 0, 0)
		await _phase("80_npc_0_miniguns", NPC_COUNT, 0)
		await _phase("80_npc_1_minigun", NPC_COUNT, 1)
		await _phase("80_npc_2_miniguns", NPC_COUNT, 2)
		game.combat.state_changed.disconnect(game.combat_view.apply_state)
		game.combat.combat_event.disconnect(game.combat_view.on_event)
		game.combat_view.visible = false
		game.combat_view.process_mode = Node.PROCESS_MODE_DISABLED
		await _phase("80_npc_2_miniguns_no_combat_presentation", NPC_COUNT, 2)
		game.combat.state_changed.connect(game.combat_view.apply_state)
		game.combat.combat_event.connect(game.combat_view.on_event)
		game.combat_view.visible = true
		game.combat_view.process_mode = Node.PROCESS_MODE_PAUSABLE
		await _phase("empty_after_combat", 0, 0)
	var file := FileAccess.open(OUTPUT + ("sustained.json" if "--sustained" in OS.get_cmdline_user_args() else "preview.json" if "--preview" in OS.get_cmdline_user_args() else "rendered.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(), "seed": SEED, "sample_frames": SUSTAINED_FRAMES if "--sustained" in OS.get_cmdline_user_args() else PREVIEW_FRAMES if "--preview" in OS.get_cmdline_user_args() else SAMPLE_FRAMES, "warmup_frames": SUSTAINED_WARMUP_FRAMES if "--sustained" in OS.get_cmdline_user_args() else WARMUP_FRAMES, "conditions": "1280x800 debug editor binary, real world, stationary player, invulnerable actors, world physics activities disabled, sound on, vsync unchanged, other pre-existing Godot editor/headless processes present; no isolated machine, release-build or long-session leak claim", "phases": results}, "\t"))
	file.close()
	print("COMBAT_PERFORMANCE_CAPTURE_DONE")
	game.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	get_tree().quit()

func _phase(title: String, count: int, guns: int) -> void:
	var sample_frames := SUSTAINED_FRAMES if "--sustained" in OS.get_cmdline_user_args() else PREVIEW_FRAMES if "--preview" in OS.get_cmdline_user_args() else SAMPLE_FRAMES
	var warmup_frames := SUSTAINED_WARMUP_FRAMES if "--sustained" in OS.get_cmdline_user_args() else WARMUP_FRAMES
	var model = game.combat.model
	model.reset_run(SEED)
	game.progression.reset_run()
	model.running = true
	model.spawn_queue.clear()
	model._wave_age = -TEST_HEALTH
	model.player.hp = TEST_HEALTH
	model.player.max_hp = TEST_HEALTH
	game.vehicle.health = TEST_HEALTH
	game.vehicle.max_health = TEST_HEALTH
	model.weapons.clear()
	model.player.modules.clear()
	for index in guns:
		model.install_weapon("minigun")
		model.weapons[-1].mount = {"carrierId": "crawler", "slot": index}
		model.player.modules.append(model.weapons[-1])
	for index in count:
		var angle := TAU * index / maxi(1, count)
		var distance := 20.0 + float(index % 4)
		var enemy: Dictionary = model.spawn_enemy("rifleman" if index < count - 8 else "shooter", Vector3(cos(angle), 0, sin(angle)) * distance)
		enemy.hp = TEST_HEALTH
		enemy.max_hp = TEST_HEALTH
	game.combat._publish()
	for frame in warmup_frames:
		await get_tree().process_frame
	game.performance_bar.frames.reset()
	Profiler.take()
	shot_count = 0
	var totals: Dictionary = {}
	var peak_shots := 0
	var start_memory := _memory()
	var previous := Time.get_ticks_usec()
	for frame in sample_frames:
		await get_tree().process_frame
		if game.screen_state != "running" or get_tree().paused:
			push_error("Benchmark interrupted: " + game.screen_state)
			get_tree().quit(1)
			return
		var now := Time.get_ticks_usec()
		game.performance_bar.frames.record(float(now - previous) / Frames.USEC_PER_MS)
		game.performance_bar.process_metrics.poll(float(now - previous) / 1000000.0)
		previous = now
		peak_shots = maxi(peak_shots, model.projectiles.size())
		var sections := Profiler.take()
		for section in sections:
			var row: Dictionary = totals.get(section, {"usec": 0, "calls": 0, "max_usec": 0})
			row.usec += sections[section].usec
			row.calls += sections[section].calls
			row.max_usec = maxi(row.max_usec, sections[section].max_usec)
			totals[section] = row
		if frame % 30 == 0:
			game.performance_bar.sections = totals
			game.performance_bar.sampled_frames = frame + 1
			game.performance_bar._refresh()
			game.performance_bar.graph.queue_redraw()
	game.performance_bar.sections = totals
	game.performance_bar.sampled_frames = sample_frames
	game.performance_bar._refresh()
	game.performance_bar.graph.queue_redraw()
	var stages := {}
	for section in totals:
		stages[section] = {"ms_per_frame": float(totals[section].usec) / Frames.USEC_PER_MS / sample_frames, "calls": totals[section].calls, "max_call_ms": float(totals[section].max_usec) / Frames.USEC_PER_MS}
	assert(game.screen_state == "running" and not get_tree().paused, "Benchmark must remain running")
	assert(guns == 0 or shot_count > 0, "Miniguns must actually fire")
	var result := {"name": title, "window_size": str(get_window().size), "viewport_size": str(get_viewport().get_visible_rect().size), "render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()), "render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()), "frames": game.performance_bar.frames.summary(), "sections": stages, "peak_shots": peak_shots, "player_shots": shot_count, "npc_end": model.enemies.size(), "memory_start": start_memory, "memory_end": _memory(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	results.append(result)
	print("AUDIT_PHASE " + JSON.stringify(result))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT + title + ".png")

func _memory() -> Dictionary:
	return {"static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "objects": Performance.get_monitor(Performance.OBJECT_COUNT), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "orphan": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), "os": game.performance_bar.process_metrics.latest.duplicate()}

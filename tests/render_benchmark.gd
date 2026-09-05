extends SceneTree
const Main = preload("res://app/main.tscn")
var report: Dictionary = {"renderer": "", "phases": [], "restart_memory": []}
var game: Node3D
var sample_count := 180
var first_shot_us := -1
var shot_start_us := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Benchmark requires an actual graphical renderer")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("frames="):
			sample_count = maxi(30, argument.trim_prefix("frames=").to_int())
	report.renderer = RenderingServer.get_video_adapter_name()
	report.rendering_method = RenderingServer.get_current_rendering_method()
	report.resolution = [root.size.x, root.size.y]
	var start := Time.get_ticks_usec()
	game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-benchmark-profile-%d.json" % start
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	report.cold_boot_ms = (Time.get_ticks_usec() - start) / 1000.0
	start = Time.get_ticks_usec()
	await game.restart_run()
	report.first_run_ready_ms = (Time.get_ticks_usec() - start) / 1000.0
	game.camera._intro = 0
	game.combat.combat_event.connect(func(event: Dictionary) -> void:
		if event.kind == "shot" and first_shot_us < 0:
			first_shot_us = Time.get_ticks_usec() - shot_start_us)
	shot_start_us = Time.get_ticks_usec()
	game.combat.model.spawn_enemy("rifleman", Vector3(12, 0, 12))
	await _sample("first_shots")
	report.first_shot_ms = first_shot_us / 1000.0 if first_shot_us >= 0 else null
	var village: Dictionary = game.arena.world_layout.villages[0]
	game.vehicle.position = Vector3(village.x, 0, village.z)
	game.vehicle.motion.x = village.x
	game.vehicle.motion.z = village.z
	game.camera.reset_view()
	game.camera._intro = 0
	await _sample("city")
	game.world.consume_village(village)
	await _sample("first_settlement_destruction")
	game.world.weather.phase.type = "storm"
	game.world.weather.next_strike = game.world.weather.elapsed + 0.05
	game.world.world_event.emit({"kind": "lightning", "position": game.vehicle.position + Vector3(5, 0, 5), "nonlethal": true, "cosmetic_seed": 991827})
	game.world.tornado.intensity = 1.0
	await _sample("storm_lightning")
	game.combat.model.enemies.clear()
	for index in 84:
		var angle := float(index) * 2.399963
		game.combat.model.spawn_enemy("rifleman", game.vehicle.position + Vector3(cos(angle), 0, sin(angle)) * (12 + index % 16))
	for index in 12:
		game.combat.model.spawn_enemy("shooter", game.vehicle.position + Vector3(index * 3 - 18, 0, 18))
	for index in 10:
		game.combat.model.spawn_enemy("buggy", game.vehicle.position + Vector3(index * 5 - 25, 0, -22))
	await _sample("source_actor_caps")
	for index in 3:
		game.run_seed_override = [0, 991827, 72841][index]
		start = Time.get_ticks_usec()
		await game.restart_run()
		await RenderingServer.frame_post_draw
		await process_frame
		report.restart_memory.append({"seed": game.run_seed, "run_ready_ms": (Time.get_ticks_usec() - start) / 1000.0, "memory": _memory(), "world_nodes": game.arena.source_world.get_child_count(), "runtime_nodes": game.world.get_child_count()})
	report.notes = "Actual frame intervals include CPU and GPU synchronization. Static allocator and renderer video memory are reported; these are not process RSS. Cold boot is one sample, with imported caches present. No audio listening or release-export claim."
	var destination := "/private/tmp/iron-caravan-render-benchmark.json"
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("RENDER_BENCHMARK_COMPLETE ", destination)
	game.queue_free()
	await process_frame
	quit()

func _sample(label: String) -> void:
	print("BENCHMARK phase ", label)
	var values: Array[float] = []
	var cpu: Array[float] = []
	var draw_calls := 0
	var previous := Time.get_ticks_usec()
	for index in sample_count:
		if game.screen_state != "running":
			game._set_screen("running")
		game.vehicle.health = game.vehicle.max_health
		game.combat.model.player.hp = game.vehicle.max_health
		game.combat.model.player.xp = 0
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		values.append((now - previous) / 1000.0)
		previous = now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		draw_calls = maxi(draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		await process_frame
	values.sort()
	cpu.sort()
	report.phases.append({"name": label, "frames": values.size(), "frame_ms": {"p50": _percentile(values, 0.5), "p95": _percentile(values, 0.95), "p99": _percentile(values, 0.99), "max": values[-1]}, "cpu_process_p95_ms": _percentile(cpu, 0.95), "max_draw_calls": draw_calls, "actors_end": game.combat.model.enemies.size(), "memory": _memory()})

func _percentile(values: Array[float], fraction: float) -> float:
	return values[clampi(ceili(values.size() * fraction) - 1, 0, values.size() - 1)]

func _memory() -> Dictionary:
	return {"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)), "video_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)), "texture_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)), "buffer_bytes": int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)), "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))}

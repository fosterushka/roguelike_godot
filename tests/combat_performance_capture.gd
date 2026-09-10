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
const NPC_SCALING_COUNTS: Array[int] = [0, 20, 40, 60, 80]
# Test-only inspection points. Production code keeps its own owners for these nodes.
const UI_TARGETS: Array[String] = ["radar", "markers", "jammer_vhs", "jammer_overlay", "boundary", "stats", "target_label", "hotbar", "reward_notice", "status_label", "gameplay_hud"]
var output := "res://docs/validation/combat-optimization/"
var game: Node3D
var results: Array[Dictionary] = []
var shot_count := 0
var npc_count := NPC_COUNT
var gate: UiGate

# Visibility is rewritten by update_state/update_world/_process, so one hide before a phase
# does not stay effective. This gate re-applies it after every HUD update and counts how
# often the owner tried to show the node again.
class UiGate extends Node:
	var hidden: Array = []
	var label := ""
	var corrections := 0

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = 500

	func apply(nodes: Array, name: String) -> void:
		hidden = nodes
		label = name
		corrections = 0
		_enforce()

	func clear() -> void:
		for node in hidden:
			if is_instance_valid(node):
				node.visible = true
		hidden = []
		label = ""
		corrections = 0

	func _process(_delta: float) -> void:
		_enforce()

	func _enforce() -> void:
		for node in hidden:
			if is_instance_valid(node) and node.visible:
				node.visible = false
				corrections += 1

	func all_hidden() -> bool:
		for node in hidden:
			if not is_instance_valid(node) or node.visible:
				return false
		return true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	print("AUDIT_PID ", OS.get_process_id())
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	Locale.settings_path = "/private/tmp/combat-audit-language-%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("en")
	get_window().size = Vector2i(1280, 800)
	game = Main.new()
	game.profile_path = "/private/tmp/combat-audit-profile-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = SEED
	get_tree().root.add_child(game)
	await game.game_ready
	await game.restart_run()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-size="):
			var dimensions := argument.trim_prefix("--capture-size=").split("x")
			assert(dimensions.size() == 2)
			get_window().mode = Window.MODE_WINDOWED
			get_window().size = Vector2i(int(dimensions[0]), int(dimensions[1]))
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
	npc_count = int(_argument_value("--npc-count=", str(NPC_COUNT)))
	gate = UiGate.new()
	add_child(gate)
	if "--render-check" in OS.get_cmdline_user_args():
		await _phase("full", npc_count, 2)
		get_viewport().scaling_3d_scale = 0.5
		await _phase("half_resolution", npc_count, 2)
		get_viewport().scaling_3d_scale = 1.0
		game.arena.get_node("WastelandSun").shadow_enabled = false
		await _phase("no_shadows", npc_count, 2)
	elif "--world-check" in OS.get_cmdline_user_args():
		await _phase("warmup_discard", npc_count, 2)
		await _phase("world_visible", npc_count, 2)
		game.arena.visible = false
		await _phase("world_hidden", npc_count, 2)
		game.arena.visible = true
		game.arena.get_node("WastelandSun").shadow_enabled = false
		await _phase("world_visible_no_shadows", npc_count, 2)
		game.arena.get_node("WastelandSun").shadow_enabled = true
		await _phase("world_visible_again", npc_count, 2)
	elif "--pacing-check" in OS.get_cmdline_user_args():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		await _phase("vsync_on", npc_count, 2)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		await _phase("vsync_off", npc_count, 2)
	elif "--isolate" in OS.get_cmdline_user_args():
		await _phase("full", npc_count, 2)
		game.combat_view._effects.visible = false
		game.combat_view.tracers.visible = false
		await _phase("effects_hidden_gpu_only", npc_count, 2)
		game.combat.state_changed.disconnect(game.combat_view.apply_state)
		game.combat.combat_event.disconnect(game.combat_view.on_event)
		game.combat_view.visible = false
		game.combat_view.process_mode = Node.PROCESS_MODE_DISABLED
		await _phase("no_combat_presentation", npc_count, 2)
	elif "--npc-scaling" in OS.get_cmdline_user_args():
		await _phase("warmup_discard", npc_count, 2)
		for count in _requested_counts():
			await _phase("npc_%d" % count, count, 2)
	elif "--role-check" in OS.get_cmdline_user_args():
		await _phase("warmup_discard", npc_count, 2)
		await _phase("riflemen_only", npc_count, 2, ["rifleman"])
		await _phase("shooters_only", npc_count, 2, ["shooter"])
		await _phase("final_wave_mixed", npc_count, 2, _final_wave_roster())
	elif "--ui-check" in OS.get_cmdline_user_args():
		# The first measured phase after startup carries shader/pipeline warmup spikes.
		await _phase("warmup_discard", npc_count, 2)
		await _phase("ui_baseline_a", npc_count, 2)
		for target in _requested_ui_targets():
			gate.apply(_ui_nodes(target), target)
			await _phase("ui_without_" + target, npc_count, 2)
			gate.clear()
		await _phase("ui_baseline_b", npc_count, 2)
	elif "--fps-cap-check" in OS.get_cmdline_user_args():
		await _phase("warmup_discard", npc_count, 2)
		for cap in _requested_caps():
			Engine.max_fps = cap
			await _phase("fps_uncapped" if cap == 0 else "fps_cap_%d" % cap, npc_count, 2)
		Engine.max_fps = 0
	elif "--f3-check" in OS.get_cmdline_user_args():
		await _phase("warmup_discard", npc_count, 2)
		await _phase("f3_panel_visible", npc_count, 2)
		gate.apply([game.performance_bar], "f3_panel")
		await _phase("f3_panel_hidden_profiling_on", npc_count, 2)
		gate.clear()
		await _phase("f3_panel_visible_again", npc_count, 2)
	elif "--late-waves" in OS.get_cmdline_user_args():
		await _phase("late_waves", npc_count, 2)
	elif "--sustained" in OS.get_cmdline_user_args():
		await _phase("80_npc_2_miniguns_sustained", npc_count, 2)
	elif "--preview" in OS.get_cmdline_user_args():
		await _phase("bar-gameplay-final", npc_count, 2)
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
	if "--verify-feedback" in OS.get_cmdline_user_args():
		await _verify_feedback()
	var file := FileAccess.open(output + ("sustained.json" if "--sustained" in OS.get_cmdline_user_args() else "preview.json" if "--preview" in OS.get_cmdline_user_args() else "rendered.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(), "seed": SEED, "sample_frames": SUSTAINED_FRAMES if "--sustained" in OS.get_cmdline_user_args() else PREVIEW_FRAMES if "--preview" in OS.get_cmdline_user_args() else SAMPLE_FRAMES, "warmup_frames": SUSTAINED_WARMUP_FRAMES if "--sustained" in OS.get_cmdline_user_args() else WARMUP_FRAMES, "conditions": "Debug editor binary; actual window size, vsync and 3D scale are recorded per phase. Real world, stationary player, invulnerable actors, world physics activities disabled, sound on. Diagnostic hide/scale flags affect only named phases. Other applications and pre-existing headless processes remain active; no isolated-machine or release-build claim", "phases": results}, "\t"))
	file.close()
	print("COMBAT_PERFORMANCE_CAPTURE_DONE")
	game.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	get_tree().quit()

func _phase(base_title: String, count: int, guns: int, kinds: Array = []) -> void:
	# Repeated scenarios must not overwrite each other's trace file and screenshot.
	var repeats := 0
	for row: Dictionary in results:
		if str(row.get("base_title", "")) == base_title:
			repeats += 1
	var title := base_title if repeats == 0 else "%s_%d" % [base_title, repeats + 1]
	game.performance_bar.scenario = title
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
	var roster: Array = kinds
	if roster.is_empty() and "--late-waves" in OS.get_cmdline_user_args():
		roster = _final_wave_roster()
	var spawned_kinds: Dictionary = {}
	for index in count:
		var angle := TAU * index / maxi(1, count)
		var distance := 20.0 + float(index % 4)
		var kind: String = "rifleman" if index < count - 8 else "shooter"
		if not roster.is_empty():
			kind = roster[index % roster.size()]
		var enemy: Dictionary = model.spawn_enemy(kind, Vector3(cos(angle), 0, sin(angle)) * distance)
		if enemy.is_empty():
			continue
		enemy.hp = TEST_HEALTH
		enemy.max_hp = TEST_HEALTH
		spawned_kinds[kind] = int(spawned_kinds.get(kind, 0)) + 1
	var spawned: int = model.enemies.size()
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
	var previous_physics := Engine.get_physics_frames()
	var trace_start_physics := previous_physics
	var frame_trace: Array[Dictionary] = []
	var engine_physics_total := 0.0
	var engine_physics_frames := 0
	var engine_process_total := 0.0
	for frame in sample_frames:
		await get_tree().process_frame
		if game.screen_state != "running" or get_tree().paused:
			push_error("Benchmark interrupted: " + game.screen_state)
			get_tree().quit(1)
			return
		var now := Time.get_ticks_usec()
		var frame_ms := float(now - previous) / Frames.USEC_PER_MS
		var physics_ticks := Engine.get_physics_frames() - previous_physics
		previous_physics = Engine.get_physics_frames()
		# Engine-side timings: TIME_PHYSICS_PROCESS covers the whole physics frame, including
		# the physics server step that no Profiler section can see.
		var engine_physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * Frames.MS_PER_SECOND
		var engine_process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * Frames.MS_PER_SECOND
		if physics_ticks > 0:
			engine_physics_total += engine_physics_ms
			engine_physics_frames += 1
		engine_process_total += engine_process_ms
		game.performance_bar.frames.record(float(now - previous) / Frames.USEC_PER_MS)
		game.performance_bar.process_metrics.poll(float(now - previous) / 1000000.0)
		previous = now
		peak_shots = maxi(peak_shots, model.projectiles.size())
		var sections := Profiler.take()
		if "--frame-trace" in OS.get_cmdline_user_args():
			frame_trace.append({"frame": frame, "ms": frame_ms, "physics_ticks": physics_ticks, "engine_physics_ms": engine_physics_ms, "engine_process_ms": engine_process_ms, "sections": sections})
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
	# A zero-target phase legitimately fires nothing: weapons only shoot when an enemy exists.
	assert(guns == 0 or spawned == 0 or shot_count > 0, "Miniguns must fire whenever targets exist")
	var result := {"name": title, "window_size": str(get_window().size), "viewport_size": str(get_viewport().get_visible_rect().size), "render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()), "render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()), "frames": game.performance_bar.frames.summary(), "sections": stages, "peak_shots": peak_shots, "player_shots": shot_count, "npc_end": model.enemies.size(), "memory_start": start_memory, "memory_end": _memory(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	result.rendered_objects = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	result.base_title = base_title
	result.requested_npc = count
	result.spawned_npc = spawned
	result.npc_kinds = spawned_kinds
	result.projectiles_end = model.projectiles.size()
	result.mines = model.hazards.mines.size()
	result.pickups = model.pickups.size()
	result.ui_disabled = gate.label
	result.ui_mode = "render_only" if not gate.hidden.is_empty() else "none"
	result.ui_gate_corrections = gate.corrections
	result.engine_physics_ms_per_tick = engine_physics_total / maxi(1, engine_physics_frames)
	result.engine_process_ms_per_frame = engine_process_total / sample_frames
	result.physics_bodies = Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	result.collision_pairs = Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)
	result.physics_ticks = Engine.get_physics_frames() - trace_start_physics
	result.render_scale = get_viewport().scaling_3d_scale
	result.msaa = get_viewport().msaa_3d
	result.vsync = DisplayServer.window_get_vsync_mode()
	result.fps_limit = Engine.max_fps
	if not frame_trace.is_empty():
		var trace_file := FileAccess.open(output + title + "-frames.json", FileAccess.WRITE)
		trace_file.store_string(JSON.stringify(frame_trace))
		trace_file.close()
	results.append(result)
	await RenderingServer.frame_post_draw
	# Owners re-show their nodes during the physics tick; the gate runs after every _process,
	# so the only state that matters is what was visible when the frame was drawn.
	result.ui_hidden_at_draw = gate.all_hidden() if not gate.hidden.is_empty() else true
	assert(result.ui_hidden_at_draw, "Gated UI must be hidden at draw time")
	print("AUDIT_PHASE " + JSON.stringify(result))
	get_viewport().get_texture().get_image().save_png(output + title + ".png")

func _memory() -> Dictionary:
	return {"static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "objects": Performance.get_monitor(Performance.OBJECT_COUNT), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "orphan": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), "os": game.performance_bar.process_metrics.latest.duplicate()}

func _verify_feedback() -> void:
	game.performance_bar.set_open(false)
	game.hud.set_status("")
	game.combat.model.player.nitro_cooldown = 0.0
	game.selected_ability = 0
	var event := InputEventAction.new()
	event.action = "activate_ability"
	event.pressed = true
	game._input(event)
	var cooldown: float = game.combat.model.player.nitro_cooldown
	assert(cooldown > 0.0, "First nitro attempt must activate the ability")
	game._input(event)
	assert(game.combat.model.player.nitro_cooldown == cooldown, "Second nitro attempt must remain on cooldown")
	assert(not game.hud._status_label.visible, "Unavailable nitro must not show top status text")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output + "nitro-feedback.png")
	var pickup_id: int = game.combat.model.spawn_pickup(game.vehicle.global_position, 1, "salvage")
	assert(game.combat.model.collect_pickup(pickup_id), "Feedback check must collect a real pickup")
	game.combat._publish()
	assert(not game.hud._status_label.visible, "Pickup must not show top status text")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output + "pickup-feedback.png")


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _requested_counts() -> Array[int]:
	var raw := _argument_value("--npc-counts=", "")
	if raw.is_empty():
		return NPC_SCALING_COUNTS
	var counts: Array[int] = []
	for part in raw.split(",", false):
		counts.append(int(part))
	return counts


func _requested_caps() -> Array[int]:
	var caps: Array[int] = []
	for part in _argument_value("--fps-caps=", "0,60,120,0").split(",", false):
		caps.append(int(part))
	return caps


func _requested_ui_targets() -> Array[String]:
	var raw := _argument_value("--ui-targets=", "")
	if raw.is_empty():
		return UI_TARGETS
	var targets: Array[String] = []
	for part in raw.split(",", false):
		assert(part in UI_TARGETS, "Unknown UI isolation target: " + part)
		targets.append(part)
	return targets


func _final_wave_roster() -> Array:
	return game.combat.model.Waves.queue_for(game.combat.model.Waves.FINAL_WAVE)


# Rendering-only isolation: the node keeps receiving signals and running its update methods,
# it only stops drawing. Work removal is a separate, explicitly named experiment.
func _ui_nodes(target: String) -> Array:
	var hud = game.hud
	match target:
		"radar": return [hud.radar]
		"markers": return [hud.markers]
		"jammer_vhs": return [hud.jammer_vhs]
		"jammer_overlay": return [hud.jammer_overlay]
		"boundary": return [hud.boundary_desaturation]
		"stats": return [hud._stats_panel]
		"target_label": return [hud._target_label]
		"hotbar": return [hud._hotbar]
		"reward_notice": return [hud.reward_notice]
		"status_label": return [hud._status_label]
		"gameplay_hud": return [hud._gameplay]
	assert(false, "Unknown UI isolation target: " + target)
	return []

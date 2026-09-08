extends CanvasLayer

const Frames = preload("res://infrastructure/diagnostics/frame_metrics.gd")
const Profiler = preload("res://infrastructure/diagnostics/runtime_profiler.gd")
const ProcessMetrics = preload("res://infrastructure/diagnostics/process_metrics.gd")
const REFRESH_SECONDS := 0.25
const MIB := 1048576.0
const PANEL_HEIGHT := 250.0
const FONT_SIZE := 14
const GRAPH_FRAMES := 180
const GRAPH_HEIGHT := 36.0
const TEXT_PADDING := 20.0
const FRAME_BUDGET_MS := 1000.0 / 60.0
const GRAPH_CEILING_MS := 50.0
var frames := Frames.new()
var process_metrics := ProcessMetrics.new()
var game: Node
var panel: ColorRect
var label: Label
var graph: Control
var last_usec := 0
var refresh_remaining := 0.0
var sampled_frames := 0
var sections: Dictionary = {}
var last_summary: Dictionary = {}
var generation := -1

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = ColorRect.new()
	panel.color = Color(0.035, 0.045, 0.055, 0.96)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -PANEL_HEIGHT
	add_child(panel)
	label = Label.new()
	label.position = Vector2(12, 6)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 12
	label.offset_top = 6
	label.offset_right = -12
	label.offset_bottom = -GRAPH_HEIGHT - 10
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color("d9e7e8"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	graph = Control.new()
	graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	graph.offset_left = 12
	graph.offset_right = -12
	graph.offset_top = -GRAPH_HEIGHT - 4
	graph.offset_bottom = -4
	panel.add_child(graph)
	graph.draw.connect(_draw_graph)
	label.minimum_size_changed.connect(_fit_panel)
	visible = false
	set_process(false)

func _fit_panel() -> void:
	panel.offset_top = -maxf(PANEL_HEIGHT, label.get_minimum_size().y + GRAPH_HEIGHT + TEXT_PADDING)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo or not event.pressed:
		return
	if event.physical_keycode == KEY_F3 or event.keycode == KEY_F3:
		if event.shift_pressed:
			reset_metrics()
		else:
			set_open(not visible)
		get_viewport().set_input_as_handled()

func set_open(value: bool) -> void:
	visible = value
	Profiler.enabled = value
	if DisplayServer.get_name() != "headless":
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), value)
	set_process(value)
	if value:
		reset_metrics()

func reset_metrics() -> void:
	frames.reset()
	Profiler.take()
	sections.clear()
	last_summary.clear()
	graph.queue_redraw()
	sampled_frames = 0
	last_usec = 0
	refresh_remaining = 0.0
	label.text = "F3 DEBUG | collecting frame timings... | Shift+F3 reset"

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if is_instance_valid(game) and is_instance_valid(game.combat):
		if generation != game.combat.model.generation:
			generation = game.combat.model.generation
			reset_metrics()
	if last_usec == 0:
		last_usec = now
		return
	var elapsed := float(now - last_usec) / Frames.USEC_PER_MS
	last_usec = now
	frames.record(elapsed)
	sampled_frames += 1
	process_metrics.poll(elapsed / Frames.MS_PER_SECOND)
	refresh_remaining -= elapsed / Frames.MS_PER_SECOND
	if refresh_remaining <= 0.0:
		refresh_remaining = REFRESH_SECONDS
		sections = Profiler.take()
		_refresh()
		sampled_frames = 0
		graph.queue_redraw()

func _refresh() -> void:
	last_summary = frames.summary()
	if last_summary.is_empty():
		return
	var s := last_summary
	var low := "warming (<1000 frames)" if s.low_01 < 0 else "%.1f" % s.low_01
	var os_data := process_metrics.latest
	var cpu := "n/a" if os_data.is_empty() else "%.1f%%" % os_data.cpu_percent
	var rss := "n/a" if os_data.is_empty() else "%.0f MiB" % os_data.rss_mib
	var viewport := get_viewport().get_viewport_rid()
	var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(viewport)
	var render_cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(viewport)
	var debug_memory := "Godot %.0f MiB   peak %.0f" % [_monitor(Performance.MEMORY_STATIC) / MIB, _monitor(Performance.MEMORY_STATIC_MAX) / MIB] if OS.is_debug_build() else "Godot n/a (release)"
	var orphan := str(int(_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))) if OS.is_debug_build() else "n/a"
	var rows: Array[String] = [
		"F3 DEBUG | Shift+F3 reset | last %d frames / %.1fs | %s" % [s.count, s.seconds, str(game.screen_state) if is_instance_valid(game) else "capture"],
		"FPS  current %.1f   min %.1f   max %.1f   avg %.1f   1%% low %.1f   0.1%% low %s" % [Frames.MS_PER_SECOND / s.current_ms, s.min_fps, s.max_fps, s.average_fps, s.low_1, low],
		"Frame ms  current %.2f   min %.2f   max %.2f   avg %.2f | process %.2f ms   physics %.2f ms" % [s.current_ms, s.min_ms, s.max_ms, s.average_ms, _monitor(Performance.TIME_PROCESS) * Frames.MS_PER_SECOND, _monitor(Performance.TIME_PHYSICS_PROCESS) * Frames.MS_PER_SECOND],
		"CPU process %s (OS, 100%% = 1 core) | RAM RSS %s | %s | VRAM %.0f MiB" % [cpu, rss, debug_memory, _monitor(Performance.RENDER_VIDEO_MEM_USED) / MIB],
		"Draw calls %d   primitives %d | nodes %d   objects %d   resources %d   orphan %s" % [_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), _monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), _monitor(Performance.OBJECT_NODE_COUNT), _monitor(Performance.OBJECT_COUNT), _monitor(Performance.OBJECT_RESOURCE_COUNT), orphan],
		"Main viewport render: CPU %s ms   GPU %s ms | physics bodies %d   collision pairs %d" % ["%.2f" % render_cpu_ms if render_cpu_ms > 0 else "n/a", "%.2f" % gpu_ms if gpu_ms > 0 else "n/a", _monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), _monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)],
		_actor_text(),
		"ms/frame (inclusive): " + _section_text(["ai", "weapons", "projectiles", "snapshot", "hud"]),
		_section_text(["simulation", "publish", "cargo", "combat_view", "fx"]) + " | graph: 16.7 ms line; scale >=50 ms"
	]
	label.text = "\n".join(rows)

func _actor_text() -> String:
	if not is_instance_valid(game) or not is_instance_valid(game.combat):
		return "Actors: n/a"
	var model = game.combat.model
	var effects := 0
	if is_instance_valid(game.combat_view):
		var fx = game.combat_view._effects
		for pool in [fx.transient, fx.fireballs, fx.traces, fx.smoke, fx.hulls.pool, fx.dust.pool]:
			effects += pool.active_count()
	return "NPC %d/%d   shots %d/%d   pickups %d   mines %d   main FX %d   queued events %d" % [model.enemies.size(), model.MAX_ENEMIES, model.projectiles.size(), model.MAX_PROJECTILES, model.pickups.size(), model.hazards.mines.size(), effects, model.events.size()]

func _section_text(names: Array) -> String:
	var parts: Array[String] = []
	for section: String in names:
		var row: Dictionary = sections.get(section, {})
		parts.append("%s %.2f" % [section, float(row.get("usec", 0)) / Frames.USEC_PER_MS / maxi(1, sampled_frames)])
	return "   ".join(parts)

func _monitor(id: int) -> float:
	return Performance.get_monitor(id as Performance.Monitor)

func _draw_graph() -> void:
	var values := frames.recent(GRAPH_FRAMES)
	if values.size() < 2:
		return
	var ceiling := GRAPH_CEILING_MS
	for value in values:
		ceiling = maxf(ceiling, value)
	var width := graph.size.x
	var height := graph.size.y
	var budget_y := height * (1.0 - FRAME_BUDGET_MS / ceiling)
	graph.draw_line(Vector2(0, budget_y), Vector2(width, budget_y), Color("776746"))
	var points := PackedVector2Array()
	for index in values.size():
		points.append(Vector2(width * index / (values.size() - 1), height * (1.0 - values[index] / ceiling)))
	graph.draw_polyline(points, Color("79d7ba"), 1.0, true)

func _exit_tree() -> void:
	if DisplayServer.get_name() != "headless":
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
	Profiler.enabled = false
	Profiler.take()
	process_metrics.close()

extends SceneTree
const Frames = preload("res://infrastructure/diagnostics/frame_metrics.gd")
const Profiler = preload("res://infrastructure/diagnostics/runtime_profiler.gd")
const Model = preload("res://modules/combat/combat_model.gd")
const Bar = preload("res://presentation/debug/performance_bar.gd")
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var frames := Frames.new()
	for index in 999:
		frames.record(10.0)
	check(frames.summary().low_01 < 0, "0.1 percent low waits for a meaningful sample")
	frames.record(100.0)
	var summary := frames.summary()
	check(is_equal_approx(summary.low_01, 10.0), "0.1 percent low captures the slowest frame")
	check(is_equal_approx(summary.low_1, 1000.0 / 19.0), "1 percent low averages slowest frame durations")
	check(is_equal_approx(summary.average_fps, 1000000.0 / 10090.0), "Average FPS uses total frames / wall time")
	for index in Frames.CAPACITY:
		frames.record(20.0)
	check(frames.samples.size() == Frames.CAPACITY and frames.summary().min_ms == 20.0, "History is bounded and old spikes expire")
	check(frames.recent(3) == PackedFloat64Array([20.0, 20.0, 20.0]), "Graph preserves ring order")
	frames.record(0.0)
	frames.record(-1.0)
	frames.record(NAN)
	check(frames.samples.size() == Frames.CAPACITY, "Invalid timing is rejected")
	var reference := Model.new()
	var profiled := Model.new()
	reference.running = true
	profiled.running = true
	for index in 120:
		Profiler.enabled = false
		reference.step(1.0 / 60.0)
		Profiler.enabled = true
		profiled.step(1.0 / 60.0)
	check(reference.snapshot() == profiled.snapshot(), "Profiling preserves seeded simulation state")
	check(reference.drain_events() == profiled.drain_events(), "Profiling preserves combat events")
	var timings := Profiler.take()
	check(timings.has("ai") and timings.ai.calls == 120, "Profiler counts each simulated step")
	check(Profiler.take().is_empty(), "Reading profiler clears interval accumulators")
	Profiler.enabled = false
	var bar := Bar.new()
	root.add_child(bar)
	check(not bar.visible and not Profiler.enabled, "Debug work starts disabled")
	paused = true
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F3
	event.pressed = true
	bar._input(event)
	await process_frame
	check(bar.visible and Profiler.enabled, "F3 opens while paused")
	bar.set_process(false) # Avoid spawning an OS sampler in a headless unit test.
	bar.frames.record(42)
	event.shift_pressed = true
	bar._input(event)
	check(bar.frames.samples.is_empty(), "Shift F3 resets history")
	bar.frames.record(16.0)
	bar.scenario = "ui_without_radar"
	bar._refresh()
	check("scenario ui_without_radar" in bar.label.text, "F3 names the active diagnostic scenario")
	bar.scenario = ""
	bar._refresh()
	check(not "scenario" in bar.label.text, "Normal play leaves the scenario name out")
	event.shift_pressed = false
	bar._input(event)
	check(not bar.visible and not Profiler.enabled, "F3 closes and disables profiling")
	bar.queue_free()
	await process_frame
	paused = false
	print("Performance bar: 0 failures" if failures == 0 else "Performance bar: %d failures" % failures)
	quit(0 if failures == 0 else 1)

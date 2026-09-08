extends SceneTree
const Bar = preload("res://presentation/debug/performance_bar.gd")
const OUTPUT := "res://docs/validation/combat-performance/"

func _init() -> void:
	_run.call_deferred()

func key(shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F3
	event.pressed = true
	event.shift_pressed = shift
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var bar := Bar.new()
	root.add_child(bar)
	await process_frame
	paused = true
	key()
	await process_frame
	assert(bar.visible, "Actual F3 input must open the overlay while paused")
	for index in 1001:
		bar.frames.record(16.7 if index < 1000 else 65.0)
	for frame in 30:
		await process_frame
	for dimensions in [Vector2i(1280, 800), Vector2i(960, 600)]:
		root.size = dimensions
		for frame in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(bar.label.get_minimum_size().x <= bar.panel.size.x, "Debug text must fit window width")
		assert(bar.label.global_position.y + bar.label.get_minimum_size().y <= bar.graph.global_position.y, "Text and graph must not overlap")
		root.get_texture().get_image().save_png(OUTPUT + "bar-%d.png" % dimensions.x)
	key(true)
	assert(bar.frames.samples.is_empty(), "Actual Shift F3 input must reset the sample")
	key()
	assert(not bar.visible, "Actual F3 input must close the overlay")
	bar.queue_free()
	await process_frame
	paused = false
	print("PERFORMANCE_BAR_CAPTURE: 0 failures")
	quit()

extends SceneTree

const Sound = preload("res://presentation/audio/sound_system.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
	await process_frame
	await process_frame

func _run() -> void:
	root.size = Vector2i(640, 360)
	var stage := Control.new()
	stage.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(stage)
	var button := Button.new()
	button.position = Vector2(20, 20)
	button.size = Vector2(180, 50)
	button.text = "UI audio test"
	stage.add_child(button)
	var sound := Sound.new()
	stage.add_child(sound)
	sound.bind_ui(stage)
	sound.bind_ui(stage)
	paused = true
	await process_frame
	await process_frame
	await _click(Vector2(80, 40))
	check(sound.accepted_events == 1, "Paused menu click sounds exactly once even after repeated binding")
	button.disabled = true
	await _click(Vector2(80, 40))
	check(sound.accepted_events == 1, "Disabled button does not sound")
	button.disabled = false
	sound.set_enabled(false)
	await _click(Vector2(80, 40))
	check(sound.accepted_events == 1, "Muted UI stays silent")
	sound.set_enabled(true)
	var dynamic := Button.new()
	dynamic.position = Vector2(20, 100)
	dynamic.size = Vector2(180, 50)
	stage.add_child(dynamic)
	dynamic.pressed.connect(func(): sound.set_running(false); sound.reset_run(); dynamic.queue_free())
	await process_frame
	await process_frame
	await _click(Vector2(80, 120))
	check(sound.accepted_events == 2, "Dynamic button sounds after transition and deletion")
	var option := OptionButton.new()
	option.add_item("First")
	option.add_item("Second")
	stage.add_child(option)
	option.get_popup().id_pressed.emit(1)
	await process_frame
	await process_frame
	check(sound.accepted_events == 3, "Dropdown selection sounds")
	var slider := HSlider.new()
	stage.add_child(slider)
	slider.drag_started.emit()
	await process_frame
	await process_frame
	check(sound.accepted_events == 4, "Slider gesture starts with one click")
	slider.value = 50
	await process_frame
	await process_frame
	check(sound.accepted_events == 4, "Programmatic slider refresh stays silent")
	if DisplayServer.get_name() != "headless":
		var bus := AudioServer.get_bus_index("Caravan")
		var capture := AudioEffectCapture.new()
		var effect_index := AudioServer.get_bus_effect_count(bus)
		AudioServer.add_bus_effect(bus, capture)
		await create_timer(0.1).timeout
		capture.clear_buffer()
		await _click(Vector2(80, 40))
		await create_timer(0.15).timeout
		var samples := capture.get_buffer(capture.get_frames_available())
		var peak := 0.0
		for sample in samples:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		check(peak > 0.00001, "Actual UI click reaches the audio output bus during pause")
		print("UI_AUDIO_RENDERED_PEAK ", peak)
		AudioServer.remove_bus_effect(bus, effect_index)
	paused = false
	stage.queue_free()
	await process_frame
	await process_frame
	print("UI audio: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

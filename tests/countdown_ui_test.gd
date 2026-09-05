extends SceneTree

const Countdown = preload("res://presentation/ui/run_countdown.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/iron-countdown-locale-%d.cfg" % Time.get_ticks_usec()
	Locale.initialize()
	var overlay := Countdown.new()
	root.add_child(overlay)
	overlay.set_process(false)
	for step in [3, 2, 1]:
		overlay.set_step(step, true)
		check(overlay.glyph.text == str(step) and overlay.subtitle.text == "PREPARE THE CRAWLER", "Source number and subtitle at step %d" % step)
		overlay._process(0.1)
		check(overlay.glyph.modulate.a < 1, "Number pulse animates")
	overlay.set_step(0, true)
	check(overlay.glyph.text == "RIDE!" and overlay.subtitle.text == "BREAK THE SIEGE", "Final source glyph is RIDE, never zero")
	overlay.finish()
	overlay._process(0.15)
	check(overlay.visible and is_equal_approx(overlay.modulate.a, 0.5), "Source 300ms fade remains visible halfway")
	overlay._process(0.15)
	check(not overlay.visible, "Fade completes and uncovers gameplay")
	Locale.language = "ru"
	overlay.set_step(0, true)
	check(overlay.glyph.text == "ВПЕРЁД!" and overlay.subtitle.text == "ПРОРВИТЕ ОСАДУ", "Russian countdown translation")
	overlay.set_step(0, false)
	check(not overlay.visible, "Cancellation hides overlay immediately")
	overlay.set_step(3, true)
	check(overlay.visible and overlay.modulate.a == 1, "Restart resets previous fade")
	overlay.queue_free()
	await process_frame
	print("Countdown UI: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

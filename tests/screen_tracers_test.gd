extends SceneTree

const Screen = preload("res://presentation/ui/jammer_vhs.gd")
const Tracers = preload("res://presentation/combat/fx/bullet_tracers.gd")
const Combat = preload("res://modules/combat/combat_model.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _run() -> void:
	var screen := Screen.new()
	root.add_child(screen)
	screen.set_process(false)
	screen.update_weather({"weather": {"type": "storm"}})
	screen.advance(1.8)
	check(screen.wetness == 1 and screen.visible, "Storm wets lens without jammer")
	screen.update_state({"player": {"hp": 100, "jammed": true, "jammer_strength": 0.8}})
	check(screen.intensity == 0.8 and screen.wetness == 1, "Rain and jammer coexist in same screen pass")
	screen.update_weather({"weather": {"type": "sunny"}})
	screen.advance(3)
	check(is_equal_approx(screen.wetness, 0.5), "Droplets dry gradually after rain")
	screen.advance(3)
	check(screen.visible and screen.wetness == 0, "Drying does not hide active jammer")
	screen.update_state({"player": {"hp": 100}})
	check(not screen.visible, "Clear unjammed screen has no rendering surface")
	var traces := Tracers.new()
	root.add_child(traces)
	var model := Combat.new()
	model.spawn_queue.clear()
	model.player.position = Vector3(200, 0, 200)
	var enemy := model.spawn_enemy("rifleman", Vector3(1, 0, 0))
	model.fire_projectile("bullet", "player", Vector3(0, 1.05, 0), Vector3(5, 1.05, 0), 100, enemy.id)
	model._update_projectiles(0.1)
	var segments: Array = model.drain_events().filter(func(event: Dictionary) -> bool: return event.kind == "bullet_segment")
	check(segments.size() == 1 and model.projectiles.is_empty(), "A bullet born and hit in one tick still emits one visible segment")
	check(segments[0].to.x < 1.1, "Tracer ends at actual impact")
	traces.segment(segments[0])
	traces.segment({"from": Vector3.ZERO, "to": Vector3(3, 1, 0), "team": "enemy"})
	check(traces.ages.player[0] > 0 and traces.ages.enemy[0] > 0, "Both factions have visible tracer slots")
	var before: Array = traces.ages.player.duplicate()
	traces.advance(0)
	check(traces.ages.player == before, "Pause freezes tracers")
	traces.advance(0.2)
	check(traces.ages.player[0] == 0 and traces.ages.enemy[0] == 0, "Trails expire without scene node growth")
	screen.queue_free()
	traces.queue_free()
	await process_frame
	print("Screen tracer tests: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

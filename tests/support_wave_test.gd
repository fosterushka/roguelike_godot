extends SceneTree
const Waves = preload("res://modules/combat/wave_rules.gd")
const Model = preload("res://modules/combat/combat_model.gd")
var checks := 0
var failures := 0

func _init() -> void:
	for wave in range(1, 7):
		var queue := Waves.queue_for(wave)
		check(queue.size() == [9, 18, 26, 33, 38, 46][wave - 1], "Wave %d has expected count including support" % wave)
		for kind: String in Waves.SUPPORT_UNLOCKS:
			check(queue.count(kind) == (1 if wave >= Waves.SUPPORT_UNLOCKS[kind] else 0), "Exactly one support per unlocked wave: " + kind)
		check(queue.count("leviathan") == (1 if wave == 6 else 0), "Support does not replace final boss")
		var model := Model.new()
		model.reset_run(193 + wave)
		model.wave = wave
		model.spawn_queue = queue.duplicate()
		model.running = true
		model.weapons.clear()
		model.player.hp = 1000000
		model.player.max_hp = 1000000
		var ticks := 0
		while not model.spawn_queue.is_empty() and ticks < 600:
			model.step(0.1)
			ticks += 1
		check(model.spawn_queue.is_empty(), "Actual spawn rules/capacities do not block wave %d" % wave)
		for kind: String in Waves.SUPPORT_UNLOCKS:
			var spawned := model.events.filter(func(event: Dictionary) -> bool: return event.kind == "spawn" and event.get("enemy_kind", "") == kind)
			check(spawned.size() == (1 if wave >= Waves.SUPPORT_UNLOCKS[kind] else 0), "Actual runtime creates support: " + kind)
	print("Support waves: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

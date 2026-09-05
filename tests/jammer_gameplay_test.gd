extends SceneTree
const Jammer = preload("res://modules/combat/jammer_rules.gd")
const Priority = preload("res://modules/combat/priority_rules.gd")
const Combat = preload("res://modules/combat/combat_model.gd")
const Runtime = preload("res://modules/combat/combat_runtime.gd")
const Controller = preload("res://modules/caravan/vehicle_controller.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	for action in ["drive_forward", "drive_backward", "drive_left", "drive_right", "handbrake"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var player := {"position": Vector3.ZERO, "hp": 250}
	var source := {"id": 7, "kind": "jammerTruck", "position": Vector3(20, 100, 0), "hp": 100, "dead": false, "stagger_remaining": 0.0}
	var enemies: Array[Dictionary] = [source]
	var jammer := Jammer.new()
	jammer.reset(player, 777)
	check(Priority.jammed(player, enemies), "Jammer uses terrain-independent XZ radius")
	jammer.step(player, enemies, 0.1)
	check(player.jammed and player.jammer_strength > 0 and player.jammer_strength < 0.21 and not player.jammer_reversed, "Entry fades in and allows reaction before reversal")
	var normal := {"throttle": 1.0, "steer": 0.75, "handbrake": true}
	var samples: Array[Dictionary] = []
	for rate in [30, 60, 144]:
		jammer.reset(player, 777)
		var reversed_seconds := 0.0
		var max_change := 0.0
		var last_gain := 1.0
		for frame in rate * 8:
			jammer.step(player, enemies, 1.0 / rate)
			var gain := Jammer.input_gain(player)
			max_change = maxf(max_change, absf(gain - last_gain))
			last_gain = gain
			if player.jammer_reversed:
				reversed_seconds += 1.0 / rate
		samples.append({"strength": player.jammer_strength, "pulse": player.jammer_pulse, "reversed_seconds": reversed_seconds})
		check(reversed_seconds > 0.6 and reversed_seconds < 1.0, "Only two short reversed pulses in first8s at%dHz" % rate)
		check(max_change < 0.72, "Pulse edges ramp controls without per-frame sign noise at%dHz" % rate)
	check(absf(samples[0].strength - samples[2].strength) < 0.000001 and absf(samples[0].pulse - samples[2].pulse) < 0.000001, "Jammer envelope and pulse independent of simulation partition")
	jammer.reset(player, 777)
	jammer.step(player, enemies, 1.85)
	var disrupted := Jammer.controls(normal, player)
	check(player.jammer_reversed and disrupted.throttle < 0 and disrupted.steer < 0, "Pulse really reverses both input axes")
	check(disrupted.handbrake and normal.throttle == 1.0, "Handbrake stays usable and original input is not mutated")
	check(Jammer.controls({"throttle": 0.0, "steer": 0.0}, player).steer == 0, "Jammer does not create unsolicited steering")
	var before := player.duplicate(true)
	jammer.step(player, enemies, 0)
	check(player == before, "Zero delta freezes envelope and pulse")
	for reason in ["dead", "stagger", "outside", "friendly", "zero_hp"]:
		source.dead = false
		source.hp = 100
		source.stagger_remaining = 0.0
		source.position = Vector3(20, 0, 0)
		source.allegiance = "enemy"
		jammer.reset(player, 777)
		jammer.step(player, enemies, 1.85)
		match reason:
			"dead": source.dead = true
			"stagger": source.stagger_remaining = 1.0
			"outside": source.position.x = 48.01
			"friendly": source.allegiance = "friendly"
			"zero_hp": source.hp = 0
		jammer.step(player, enemies, 0)
		check(not player.jammed and not player.jammer_reversed and Jammer.controls(normal, player) == normal, "%s disables gameplay immediately" % reason)
		check(Jammer.new().aim(Vector3.ZERO, Vector3(0, 0, 30), player, 2) == Vector3(0, 0, 30), "%s immediately restores accuracy despite cosmetic fade" % reason)
		jammer.step(player, enemies, 2)
		check(player.jammer_strength == 0 and player.jammer_source_id == -1, "Visual fade ends and forgets source")
	source.hp = 100
	source.position = Vector3(42, 0, 0)
	jammer.reset(player, 777)
	jammer.step(player, enemies, 10)
	check(player.jammer_strength < 0.16 and Jammer.input_gain(player) > 0, "Outer zone is gentle and cannot reverse input")
	var model := Combat.new()
	model.weapons.clear()
	model.player.jammed = true
	model.player.jammer_strength = 1.0
	var original_rng := model.random.state
	var largest := 0.0
	var aim := Vector3(0, 2.8, 40)
	var origin := Vector3(0, 2.8, 0)
	for shot_id in 40:
		var shifted := model.jammer.aim(origin, aim, model.player, shot_id)
		var angle := absf((shifted - origin).signed_angle_to(aim - origin, Vector3.UP))
		largest = maxf(largest, angle)
		check(angle <= Jammer.MAX_SPREAD + 0.000001, "Accuracy spread stays inside6degrees")
		check(shifted == model.jammer.aim(origin, aim, model.player, shot_id), "Same seed and shot produce exact same aim")
	check(largest > deg_to_rad(4.0) and model.random.state == original_rng, "Dispersion is meaningful and does not disturb combat RNG")
	var expected := model.jammer.aim(origin, aim, model.player, model._next_id)
	model.fire_projectile("bullet", "player", origin, aim, 10)
	check(model.projectiles.back().velocity.normalized().distance_to((expected - origin).normalized()) < 0.000001, "Actual player projectile uses disrupted aim")
	model.fire_projectile("bullet", "enemy", origin, aim, 10)
	check(model.projectiles.back().velocity.normalized() == (aim - origin).normalized(), "Enemy projectile accuracy is unaffected")
	var near := model.spawn_enemy("jammerTruck", Vector3(12, 0, 0))
	model._update_weapons(1.85)
	check(model.player.jammed and model.player.jammer_source_id == near.id, "Weapon tick publishes live jammer metadata")
	near.dead = true
	model._update_weapons(0)
	check(not model.player.jammed, "Killing selected jammer ends model interference")
	model.reset_run(1)
	check(not model.player.jammed and model.player.jammer_strength == 0 and not model.player.jammer_reversed, "New run clears all jammer fields")
	var controller := Controller.new()
	root.add_child(controller)
	controller.set_physics_process(false)
	controller.player_stats = {"jammed": true, "jammer_strength": 1.0, "jammer_pulse": 1.0}
	Input.action_press("drive_forward")
	Input.action_press("drive_left")
	for frame in 12:
		controller._physics_process(1.0 / 60.0)
	Input.action_release("drive_forward")
	Input.action_release("drive_left")
	check(controller.motion.throttle < 0 and controller.motion.steer < 0, "Actual vehicle physics consumes inverted controls")
	check(absf(controller.rotation.x) < 0.000001 and absf(controller.rotation.z) < 0.000001 and controller.scale.is_equal_approx(Vector3.ONE), "Interference never tilts or scales vehicle transform")
	controller.reset_vehicle()
	check(Jammer.input_gain(controller.player_stats) == 1, "Standalone vehicle reset removes stale input disruption")
	var runtime := Runtime.new()
	root.add_child(runtime)
	runtime.set_physics_process(false)
	runtime.setup(controller)
	runtime.model.player.jammed = true
	runtime.model.player.jammer_strength = 1
	runtime.model.player.jammer_reversed = true
	runtime._sync_model_to_vehicle()
	check(controller.player_stats.jammer_strength == 1, "Runtime sync supplies gameplay state to controller")
	runtime.set_running(false)
	check(not runtime.model.player.jammed and runtime.model.player.jammer_strength == 0 and not runtime.model.player.jammer_reversed, "Pause clears visual and input interference immediately")
	runtime.free()
	controller.free()
	print("Jammer gameplay: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

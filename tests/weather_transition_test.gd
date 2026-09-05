extends SceneTree

const Rules = preload("res://modules/world/weather_rules.gd")
const Weather = preload("res://modules/world/weather_state.gd")
const View = preload("res://presentation/world/weather_view.gd")
const Combat = preload("res://modules/combat/combat_model.gd")
const Radar = preload("res://presentation/ui/radar.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var starts := {}
	for seed_value in 64:
		var phase := Rules.phase_at(seed_value, 0)
		starts[phase.type] = true
		check(Rules.mix_for_phase(phase, 0) == Rules.type_mix(phase.type), "Random initial weather is fully present under loading")
		for index in 8:
			var next := Rules.phase_at(seed_value, float(phase.ends_at) + 0.001)
			check(next.type != phase.type and next.duration >= 120 and next.duration <= 180, "Seeded switches vary weather every120–180s")
			check(next.previous_type == phase.type, "Transition retains actual previous weather")
			phase = next
	check(starts.size() == 4, "Seed variety produces clear, fog, rain and storm starts")
	for previous: String in Rules.TYPES:
		for current: String in Rules.TYPES:
			if previous == current:
				continue
			var phase := {"type": current, "previous_type": previous, "starts_at": 100.0}
			check(Rules.mix_for_phase(phase, 100) == Rules.type_mix(previous), "No visual jump at phase boundary")
			check(Rules.mix_for_phase(phase, 124) == Rules.type_mix(current), "Fade reaches exact next weather")
			check(Rules.mix_for_phase(phase, 100.01).distance_to(Rules.type_mix(previous)) < 0.000001, "Fade starts with negligible slope")
			check(Rules.mix_for_phase(phase, 123.99).distance_to(Rules.type_mix(current)) < 0.000001, "Fade settles with negligible slope")
			for fps in [30, 60, 144]:
				var elapsed := 100.0
				var maximum_step := 0.0
				var last := Rules.mix_for_phase(phase, elapsed)
				for frame in fps * 24:
					elapsed += 1.0 / fps
					var mix := Rules.mix_for_phase(phase, elapsed)
					maximum_step = maxf(maximum_step, mix.distance_to(last))
					last = mix
				check(maximum_step < 0.0038 and last.distance_to(Rules.type_mix(current)) < 0.000001, "Continuous fade at%dHz" % fps)
	var weather_a := Weather.new()
	var weather_b := Weather.new()
	weather_a.reset(72841)
	weather_b.reset(72841)
	var end := float(weather_a.phase.ends_at)
	weather_a.step(end + 3)
	weather_b.step(end - 0.25)
	weather_b.step(3.25)
	check(weather_a.visual_mix().is_equal_approx(weather_b.visual_mix()), "Weather fade independent of timestep crossing boundary")
	check(is_equal_approx(weather_a.traction, weather_b.traction), "Traction crossing boundary also independent of timestep")
	weather_a.step(0)
	check(weather_a.visual_mix().is_equal_approx(weather_b.visual_mix()), "Paused weather does not drift")
	weather_a.step(900)
	weather_b.step(450)
	weather_b.step(450)
	check(weather_a.visual_mix().is_equal_approx(weather_b.visual_mix()), "Large catchup reaches same deterministic mixture")
	var model := Combat.new()
	for entering in [true, false]:
		var phase := {"type": "foggy" if entering else "sunny", "previous_type": "sunny" if entering else "foggy", "starts_at": 0}
		model.weather_type = phase.type
		var first := 1.0 if entering else 0.68
		var last := 0.68 if entering else 1.0
		model.weather_fog_strength = Rules.mix_for_phase(phase, 0).y
		check(is_equal_approx(model.weather_range_multiplier(), first), "Target type switch does not jump weapon visibility")
		model.weather_fog_strength = Rules.mix_for_phase(phase, 12).y
		check(is_equal_approx(model.weather_range_multiplier(), 0.84), "Weapon visibility interpolates through fog entry and exit")
		check(is_equal_approx(model.weather_range_multiplier(false, true), 0.86), "NPC acquisition uses same progressive fog")
		check(is_equal_approx(model.weather_range_multiplier(true), 0.92), "Radar retains partial fog compensation")
		model.weather_fog_strength = Rules.mix_for_phase(phase, 24).y
		check(is_equal_approx(model.weather_range_multiplier(), last), "Weapon visibility settles exactly")
	model.weather_type = "foggy"
	model.weather_fog_strength = 1.0
	model.reset_run(99)
	check(model.weather_type == "clear" and model.weather_fog_strength == -1 and model.weather_range_multiplier() == 1, "Restart clears previous run fog before world synchronization")
	var radar := Radar.new()
	root.add_child(radar)
	var data := {"player": {"position": Vector3.ZERO, "hp": 250, "radar_range": 260}, "enemies": []}
	radar.update_world({"weather": {"type": "sunny", "fog_strength": 0.5}})
	radar.update_state(data, null)
	check(is_equal_approx(radar.effective_range, 239.2), "Radar uses continuous fog even after target type changed to sunny")
	radar.free()
	var arena := Node3D.new()
	root.add_child(arena)
	var world_environment := WorldEnvironment.new()
	world_environment.environment = Environment.new()
	arena.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "WastelandSun"
	arena.add_child(sun)
	var vehicle := CharacterBody3D.new()
	arena.add_child(vehicle)
	var view := View.new()
	arena.add_child(view)
	view.setup(arena, vehicle)
	view.externally_driven = true
	var clear_density := 0.0
	for elapsed in [0.0, 6.0, 12.0, 18.0, 24.0]:
		var phase := {"type": "foggy", "previous_type": "rainy", "starts_at": 0}
		view.apply_state({"weather": {"type": "foggy", "elapsed": elapsed, "phase_data": phase}, "elapsed": elapsed, "tornado": {}, "mud_zones": []})
		view.advance_visual(1.0 / 60.0)
		var mix := Rules.mix_for_phase(phase, elapsed)
		check(is_equal_approx(view._rain.fog, mix.y) and is_equal_approx(view._rain.rain, mix.z * 0.72), "Actual precipitation shares exact lighting and gameplay transition")
		var density := float(View.PRESETS.foggy.density) * mix.y + float(View.PRESETS.rainy.density) * mix.z
		check(is_equal_approx(world_environment.environment.fog_density, density * density * 65), "Native fog follows shared continuous mixture")
		check(is_equal_approx(sun.light_energy, (2.15 * mix.y + 1.95 * mix.z) / PI), "Light shares same fade without second smoothing")
	clear_density = float(View.PRESETS.sunny.density) ** 2 * 65
	var fog_density := world_environment.environment.fog_density
	check(exp(-fog_density * 65) < 0.5 and exp(-clear_density * 65) > 0.94, "Fog reduces theoretical65m transmission below50% versus clear94%+")
	check(not view._rain.layers[0].visible and view._rain.layers[2].visible, "Settled fog stops rain and retains mist")
	view.apply_state({"weather": {"type": "sunny"}, "elapsed": 0, "tornado": {}, "mud_zones": []})
	view.advance_visual(0)
	check(view._rain.layers.all(func(layer: MultiMeshInstance3D) -> bool: return not layer.visible), "Dry clear end disables all settled precipitation layers")
	arena.free()
	print("Weather transition: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

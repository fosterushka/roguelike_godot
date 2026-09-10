extends SceneTree
const Lightning = preload("res://presentation/world/lightning_view.gd")
const Wind = preload("res://presentation/world/wind_debris.gd")
const Matrix = preload("res://presentation/world/generated_world_view.gd")
const Random = preload("res://modules/world/activities/source_random.gd")
const Gust = preload("res://modules/world/wind_state.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		if failures <= 5 or checks > 1800:
			push_error(message)

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/weather_view.json"))
	var bolt := Lightning.new()
	root.add_child(bolt)
	for scenario: Dictionary in fixture.bolts:
		bolt.strike(Vector3.ZERO, int(scenario.seed))
		check(bolt.pieces.size() == 31 and bolt.life == scenario.life, "Source bolt has13core/glowsegments+5branches and.55life")
		for index in 31:
			var actual := Matrix.matrix(bolt.pieces[index].global_transform)
			for item in 16:
				check(absf(actual[item] - scenario.matrices[index][item]) < 0.00008, "Original Three lightning matrix")
	bolt._process(0.2)
	check(absf(bolt.life - 0.35) < 0.000001, "Bolt uses elapsed simulation time")
	bolt.reset_run()
	check(not bolt.visible and bolt.light.light_energy == 0, "Bolt reset clearslight")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 62
	camera.far = 500
	root.add_child(camera)
	camera.position = Vector3(34, 45, 39)
	camera.look_at(Vector3(0, 0, 5))
	camera.current = true
	var wind := Wind.new()
	root.add_child(wind)
	wind.reset_run(991827)
	for index in 8:
		wind.spawn(Vector3(0.6, 0, 0.8), 30)
	for frame in 60:
		wind._process(1.0 / 60.0)
	for index in 8:
		var actual := Matrix.matrix(Wind.pose_for(wind.records[index]))
		for item in 16:
			check(absf(actual[item] - fixture.wind[index].matrix[item]) < 0.0005, "Original Three wind trajectory and tumble")
		var color: Color = wind.records[index].color
		for channel in 3:
			check(absf(color[channel] - fixture.wind[index].color[channel]) < 0.000001, "Source linear wind palette")
	for index in 200:
		wind.spawn(Vector3.RIGHT, 30)
	check(wind.records.size() == 84 and wind.cursor < 84, "Wind source84capacity is bounded")
	wind.reset_run(1)
	check(wind.records.all(func(item: Dictionary) -> bool: return item.life == 0), "Wind reset clearsallslots")
	var random := Random.new()
	random.state = 1
	var gust := Gust.new()
	gust.reset(random)
	check(gust.remaining >= 5 and gust.remaining <= 10 and gust.strength == 0, "Source initialgustdelay5..10")
	gust.step(gust.remaining + 0.01, true, random)
	check(gust.strength >= 28 and gust.strength <= 42 and gust.duration >= 10 and gust.duration <= 18, "Source stormgust ranges")
	check(gust.step(0.01, true, random) == 1, "First wind particle is spawned onnextactivegusttick")
	gust.duration = 0.001
	gust.step(0.002, true, random)
	check(gust.strength == 0 and gust.remaining >= 3 and gust.remaining <= 7, "Source stormgust stops and waits3..7")
	var sound := preload("res://presentation/audio/sound_system.gd").new()
	root.add_child(sound)
	sound.set_running(true)
	sound.on_world_event({"kind": "lightning", "distance": 343.0})
	check(sound.pending_thunder.size() == 1 and sound.pending_thunder[0].remaining == 1, "Thunder delay follows343unitspersecond")
	sound._process(0.9)
	check(sound.accepted_events == 0, "Thunder doesnotplayearly")
	sound._process(0.11)
	check(sound.accepted_events == 1 and sound.pending_thunder.is_empty(), "Thunder playsafterexactdelay")
	sound.on_world_event({"kind": "lightning", "distance": 500.0})
	sound.set_running(false)
	check(sound.pending_thunder.is_empty(), "Pause cancels queued thunder")
	var weather := preload("res://modules/world/weather_state.gd").new()
	weather.reset(72841)
	check(weather.traction == 1.0, "Source new run traction begins at one")
	weather.step(3)
	check(absf(weather.traction - 0.95) < 0.000001, "Source storm traction smoothstep at quarter transition")
	weather.step(3)
	check(absf(weather.traction - 0.84) < 0.000001, "Source storm traction midpoint")
	weather.step(6)
	check(absf(weather.traction - 0.68) < 0.000001, "Source storm traction reaches target after12seconds")
	var rain := preload("res://presentation/world/weather_particles.gd").new()
	root.add_child(rain)
	for layer in 3:
		check(rain.layers[layer].multimesh.instance_count == fixture.particles[layer].capacity, "Original weather particle capacity")
		for particle in 8:
			var custom: Color = rain.particle_data(particle, rain.RADII[layer])
			for channel in 4:
				check(absf(custom[channel] - fixture.particles[layer].data[particle * 4 + channel]) < 0.00001, "Original seeded weather attributes")
	for scenario: Dictionary in fixture.rain:
		if scenario.type == "flash":
			rain.flash_lightning()
			rain.advance(0.1, Vector3(12, 0, -4), Vector3(3, 0, 7), Vector3(0.6, 0, 0.8), 30)
		else:
			rain.set_weather(scenario.type)
			for frame in 60:
				rain.advance(1.0 / 60.0, Vector3(12, 0, -4), Vector3(3, 0, 7), Vector3(0.6, 0, 0.8), 30)
		for pair in [[rain.elapsed, scenario.time], [rain.rain, scenario.rain], [rain.storm, scenario.storm], [rain.fog, scenario.fog], [rain.lightning_life / 0.28, scenario.lightning], [rain.drift.x, scenario.drift[0]], [rain.drift.y, scenario.drift[1]]]:
			check(absf(pair[0] - pair[1]) < 0.00003, "Original weather fade/drift/flash over exact frame sequence %s" % [pair])
		for layer in 3:
			check(rain.layers[layer].visible == scenario.visible[layer], "Source weather layer visibility")
	rain.set_warmup_visible(true, Vector3.ZERO)
	var frozen_time: float = rain.elapsed
	rain.advance(4, Vector3.ZERO, Vector3.ZERO, Vector3.RIGHT, 30)
	check(rain.elapsed == frozen_time and rain.layers.all(func(layer: Node3D) -> bool: return layer.visible), "Warmup renders every layer without advancing time")
	rain.set_warmup_visible(false, Vector3.ZERO)
	check(rain.elapsed == 0 and rain.drift == Vector2.ZERO and rain.layers.all(func(layer: Node3D) -> bool: return not layer.visible), "Weather restart clears time, drift and all layers")
	var support := preload("res://presentation/world/activity_view.gd").new()
	root.add_child(support)
	var points: Array = [{"x": 0.0, "z": 0.0}, {"x": 0.0, "z": 64.0}]
	var route_state := {"seed": 1, "activity": {"records": [{"type": "raiderSupplyConvoy", "state": "announced", "position": Vector3.ZERO, "route": points}]}}
	support.apply_state(route_state)
	var route: MultiMeshInstance3D = support._routes[0]
	var cached: Dictionary = route.get_meta("route_cache")
	check(route.multimesh.visible_instance_count == 8, "Route builds the expected ground dashes")
	support.apply_state(route_state)
	check(is_same(cached, route.get_meta("route_cache")), "Repeated world snapshot reuses unchanged route geometry")
	support.apply_state({"seed": 1})
	check(route.multimesh.visible_instance_count == 0, "Removed route becomes hidden")
	support.apply_state(route_state)
	check(route.multimesh.visible_instance_count == 8, "Cached route becomes visible again without rebuilding")
	points[1].z = 128.0
	support.apply_state(route_state)
	check(route.multimesh.visible_instance_count == 16, "In-place route point changes rebuild geometry")
	cached = route.get_meta("route_cache")
	route_state.seed = 2
	support.apply_state(route_state)
	check(not is_same(cached, route.get_meta("route_cache")), "World replacement rebuilds route grounding")
	var drop := {"position": Vector3(3, 0, 4), "height": 12.0, "landed": false, "age": 0.0, "yaw": 0.0}
	var support_state := {"elapsed": 0.0, "activity": {"records": []}, "support": {"airdrops": [drop], "heal_carts": []}}
	support.apply_state(support_state)
	var animation := preload("res://presentation/combat/source_animation.gd")
	var flight_pose := {"binding_overrides": support.airdrop_overrides(drop, 0)}
	var flight_transforms: Array[Transform3D] = []
	for batch: Dictionary in support._airdrop.batches:
		flight_transforms.append(animation.transform_for(batch, flight_pose))
	check(not support._flare_light.visible, "Source flight hides landed flare")
	drop.landed = true
	drop.height = 0
	support_state.elapsed = 2.0
	support.apply_state(support_state)
	check(support._flare_light.visible and absf(support._flare_light.light_energy - (3.6 + (0.5 + sin(15) * 0.5) * 2.8)) < 0.00001, "Landed support flare uses source pulse intensity")
	var changed := 0
	for index in flight_transforms.size():
		if not animation.transform_for(support._airdrop.batches[index], {"binding_overrides": support.airdrop_overrides(drop, 2)}).is_equal_approx(flight_transforms[index]):
			changed += 1
	check(changed > 0, "Landing updates actual source canopy and flare transforms")
	drop.landed = false
	drop.height = 12
	support_state.elapsed = 0
	support.apply_state(support_state)
	for index in flight_transforms.size():
		check(animation.transform_for(support._airdrop.batches[index], {"binding_overrides": support.airdrop_overrides(drop, 0)}).is_equal_approx(flight_transforms[index]), "New airdrop restores original flying canopy transform")
	paused = true
	var elapsed_before: float = support._since_state
	await process_frame
	await process_frame
	check(support._since_state == elapsed_before, "Pause freezes support mesh animation")
	paused = false
	print("World presentation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

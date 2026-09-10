extends SceneTree
const Collapse = preload("res://presentation/combat/fx/fort_collapse.gd")
const Effects = preload("res://presentation/combat/impact_effects.gd")
const MathRules = preload("res://presentation/combat/fx/effect_math.gd")
const Rng = preload("res://presentation/combat/fx/visual_random.gd")
const AnimationRules = preload("res://presentation/combat/source_animation.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.00001, label + ": %s != %s" % [actual, expected])
func vec(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_fx.json"))
	for sample: Dictionary in fixtures.fireball:
		var actual := MathRules.fireball(sample.life)
		for key in ["progress", "opacity"]:
			near(actual[key], sample.state[key], "Source fireball " + key)
		near(actual.width, sample.state.widthScale, "Source fireball width")
		near(actual.height, sample.state.heightScale, "Source fireball height")
		near(actual.light, sample.state.lightStrength, "Source fireball flash")
	for sample: Dictionary in fixtures.rocket:
		var actual := MathRules.rocket(sample.age, 1.7, 0.64, 0.92)
		near(actual.opacity, sample.state.opacity, "Source rocket opacity")
		near(actual.scale, sample.state.scale, "Source rocket expansion")
	var segment := MathRules.sample_segment(Vector3(1, 2, 3), Vector3(8, 4, 9), 0.21, 0.2, 8)
	near(segment.carry, fixtures.segment.distanceCarry, "Source trail distance remainder")
	check(segment.samples.size() == 8, "Source trail bounded fast projectile sampling")
	for index in 8:
		var expected: Dictionary = fixtures.segment.samples[index]
		check(segment.samples[index].position.distance_to(Vector3(expected.x, expected.y, expected.z)) < 0.00001, "Source trail sample position")
		near(segment.samples[index].age, expected.ageOffset, "Source trail frame-rate compensation")
	var effects := Effects.new()
	root.add_child(effects)
	effects.set_process(false)
	for sample: Dictionary in fixtures.debris + fixtures.collapse:
		effects.reset_effects()
		effects.random = Rng.new(sample.seed)
		if sample.has("type"):
			Collapse.spawn(effects, {"type": sample.type, "boss": sample.boss, "radius": 5.0, "position": Vector3(3, 0, 8)})
		else:
			effects.spawn_crash_debris(Vector3(3, 0, 8), sample.intensity, sample.kind)
		var label := str(sample.get("type", sample.get("kind", "")))
		check(effects.transient.active_count() >= sample.effects.size(), "Source piece count " + label)
		check(effects.random.state == int(sample.random_state), "Source consumes identical random sequence " + label)
		for index in sample.effects.size():
			var actual: Dictionary = effects.transient.entries[index]
			var expected: Dictionary = sample.effects[index]
			for key in ["position", "rotation", "scale"]:
				check(Vector3(actual.visual.get(key)).distance_to(vec(expected[key])) < 0.00001, "Source debris transform " + key)
			for key in ["velocity", "spin"]:
				check(Vector3(actual[key]).distance_to(vec(expected[key])) < 0.00001, "Source debris motion " + key)
			near(actual.life, expected.life, "Source debris lifetime")
			near(actual.floor_y, expected.floor_y, "Source debris floor")
			check(actual.bounces == expected.bounces, "Source debris bounce count")
			var part_count := 0
			for part: MeshInstance3D in actual.parts:
				if part.visible:
					part_count += 1
			check(part_count == expected.parts.size(), "Source material debris part count")
			for part_index in expected.parts.size():
				var actual_part: MeshInstance3D = actual.parts[part_index]
				var expected_transform := AnimationRules.matrix(expected.parts[part_index].matrix)
				check(actual_part.transform.origin.distance_to(expected_transform.origin) < 0.00001 and actual_part.basis.x.distance_to(expected_transform.basis.x) < 0.00001 and actual_part.basis.y.distance_to(expected_transform.basis.y) < 0.00001, "Source detailed debris part matrix")
				check(actual_part.material_override.albedo_color.to_html(false) == expected.parts[part_index].color, "Source detailed debris material color")
	effects.reset_effects()
	var trail = effects.rockets
	trail._spawn(Vector3(3, 2, 4), 0.2)
	check(trail.active_count() == 1, "GPU trail allocates one particle")
	var batch: MultiMesh = trail._batch.multimesh
	var particle := batch.get_instance_custom_data(0)
	# Headless dummy RenderingServer does not retain custom MultiMesh data.
	if DisplayServer.get_name() != "headless":
		near(particle.r, -0.2, "GPU birth time retains sub-frame emission age")
		check(particle.g > 0.2 and particle.a > 0.0, "GPU lifetime and opacity are uploaded at birth")
	var transform := batch.get_instance_transform(0)
	trail.advance(0.25)
	check(batch.get_instance_transform(0) == transform and batch.get_instance_custom_data(0) == particle, "Advancing smoke changes neither CPU transforms nor per-particle shader data")
	near(trail._material.get_shader_parameter("uTime"), 0.25, "One shared clock drives GPU smoke")
	trail.advance(0.0)
	near(trail.elapsed, 0.25, "Pause freezes GPU smoke clock")
	var before_preview: int = trail.random.state
	trail.set_warmup(true, Vector3.UP)
	check(trail.active_count() == 1 and trail.random.state == before_preview, "Warmup has a separate GPU instance and does not consume live slots")
	trail.set_warmup(false, Vector3.UP)
	trail.advance(3.0)
	check(trail.active_count() == 0 and batch.visible_instance_count == 0, "Expired GPU particles stop drawing")
	for index in trail.CAPACITY + 5:
		trail._spawn(Vector3(index, 0, 0))
	check(trail.active_count() == trail.CAPACITY and batch.visible_instance_count == trail.CAPACITY, "GPU smoke ring remains bounded when overwritten")
	trail.reset()
	check(trail.active_count() == 0 and batch.visible_instance_count == 0, "GPU reset clears old smoke")
	trail._spawn(Vector3.ZERO)
	check(trail.active_count() == 1 and batch.visible_instance_count == 1, "New run cannot reveal stale GPU particles")
	trail.reset()
	var random_before: int = effects.random.state
	var smoke_random_before: int = effects.rockets.random.state
	effects.set_warmup_visible(true)
	effects.on_event({"kind": "explosion", "position": Vector3.ZERO})
	effects.advance_cinematic(10.0)
	effects.set_warmup_visible(false)
	check(effects.transient.active_count() == 0 and effects.fireballs.active_count() == 0, "GPU warmup never creates gameplay effects")
	check(effects.random.state == random_before and effects.rockets.random.state == smoke_random_before, "GPU warmup consumes neither visual RNG stream")
	effects.on_event({"kind": "shot", "projectile_kind": "rocket", "position": Vector3.ZERO})
	near(effects.transient.entries[0].life, 0.11, "Source muzzle flash duration")
	effects.advance_cinematic(0.0)
	near(effects.transient.entries[0].life, 0.11, "Paused effect clock freezes flash")
	effects.advance_cinematic(0.12)
	check(effects.transient.active_count() == 0, "Expired flash returns to pool")
	effects.reset_effects()
	for index in 40:
		effects.spawn_scorch(Vector3(index, 0, 0), 1.0)
	check(effects.traces.active_count() == 24, "Source desktop ground trace retention cap")
	effects.advance_cinematic(112.0)
	near(effects.traces.entries[0].parts[0].transparency, 0.0, "Scorch remains opaque before final 8 seconds")
	effects.advance_cinematic(4.0)
	near(effects.traces.entries[0].parts[0].transparency, 0.5, "Scorch final 8-second fade")
	effects.reset_effects()
	for index in 12:
		effects.explosion(Vector3.ZERO)
	check(effects.fireballs.active_count() == 6, "Source desktop simultaneous fireball cap")
	effects.reset_effects()
	effects.on_event({"kind": "death", "type": "buggy", "cause": "tornado"})
	check(effects.fireballs.active_count() == 1 and effects.transient.active_count() > 0, "Source tornado death keeps ordinary visual destruction without rewards")
	check(effects.rockets.emitters.is_empty() and effects.rockets.active_count() == 0, "Reset clears all trail emitters and particles")
	effects.reset_effects()
	for index in 12:
		effects.wrecks.spawn({"id": index, "type": "bike", "enemy_kind": "bike", "position": Vector3(index, 0, 0), "heading": 0.4})
	check(effects.wrecks.active_count() == 8, "Source eight retained vehicle wrecks")
	effects.wrecks.advance(119.0)
	check(effects.wrecks.active_count() == 8, "Wrecks stay through full 120 second retention")
	effects.wrecks.advance(1.0)
	check(effects.wrecks.active_count() == 0, "Expired wrecks return to pool")
	var player_view := preload("res://presentation/vehicles/vehicle_view.gd").new()
	root.add_child(player_view)
	player_view.set_process(false)
	effects.player_destruction.spawn(player_view, Vector3.ZERO, 0.3, effects.random)
	var captured_wheels := 0
	for wheel: Node3D in player_view._model.get_meta("wheels"):
		var tire: MeshInstance3D = wheel.get_node("WheelRotation/AllTerrainTire")
		var expected: Transform3D = player_view.global_transform.affine_inverse() * tire.global_transform
		for index in effects.player_destruction._count:
			var part: MeshInstance3D = effects.player_destruction.parts[index]
			if part.mesh == tire.mesh and part.transform.is_equal_approx(expected):
				captured_wheels += 1
				break
	check(captured_wheels == 4 and effects.player_destruction._count <= effects.player_destruction.parts.size(), "Death retains all four current articulated wheels in prepared hull slots")
	var burned_material: ShaderMaterial = effects.player_destruction.parts[0].material_override
	check(burned_material.get_shader_parameter("has_base_texture") and burned_material.get_shader_parameter("base_texture") != null, "Destroyed pickup retains its palette texture")
	effects.player_destruction.advance(1.25)
	near(effects.player_destruction.rotation.x, 0.12, "Source wreck fall pitch")
	near(absf(effects.player_destruction.rotation.z), 0.24, "Source wreck fall roll")
	near(effects.player_destruction.position.y, -0.16, "Source wreck fall depth")
	near(effects.player_destruction.parts[0].material_override.get_shader_parameter("burn"), 1.25 / 2.1, "Source hull burn progress")
	effects.player_destruction.advance(6.75)
	near(effects.player_destruction.life, 0.0, "Source player hull lifetime8seconds")
	player_view.queue_free()
	effects.reset_effects()
	var state := {"player": {"position": Vector3(5, 0, 6), "heading": 0.0, "speed": 6.0, "slip_angle": 0.0}, "enemies": [], "weather_type": "rainy"}
	effects.tracks.sync_state(state, 0.1, effects)
	check(effects.tracks.count == 0, "First observed player pose does not invent tire movement")
	state.player.position.z += 0.3
	effects.tracks.sync_state(state, 0.1, effects)
	var first: Transform3D = effects.tracks.submitted_stamps[0]
	check(first.origin.distance_to((state.player.position + preload("res://modules/caravan/wheel_suspension.gd").ANCHORS[0] * 0.88 + Vector3.UP * 0.04)) < 0.00001, "Player distance samples use actual four-wheel anchor scale")
	check(effects.dust.pool.active_count() == 0, "Rain suppresses driving dust")
	effects.tracks.sync_state(state, 0.0, effects)
	check(effects.tracks.count == 4, "Paused track clock produces no stamps")
	for index in 1810:
		effects.tracks.stamp(effects.random, Vector3.ZERO, 0, 0, 0, 1)
	check(effects.tracks.count == 1800, "Source track memory cap1800")
	effects.reset_effects()
	check(effects.tracks.count == 0 and effects.wrecks.active_count() == 0, "Restart clears scars and wrecks")
	effects.queue_free()
	await process_frame
	print("Source combat VFX: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

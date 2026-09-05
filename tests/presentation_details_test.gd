extends SceneTree
const Mines = preload("res://presentation/combat/mine_views.gd")
const Effects = preload("res://presentation/combat/impact_effects.gd")
const Model = preload("res://modules/combat/combat_model.gd")
const CombatView = preload("res://presentation/combat/combat_view.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func near(value: float, expected: float, label: String) -> void:
	check(absf(value - expected) < 0.00001, label)
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var mines := Mines.new()
	root.add_child(mines)
	var mine := {"position": Vector3(4, 0, 9), "life": 25.0, "armed": true, "hack_progress": 1.5, "allegiance": "enemy"}
	mines.sync_state([mine])
	var entry: Dictionary = mines.entries[0]
	check(entry.visual.visible and entry.track.visible and entry.fill.visible, "Active hack exposes both progress meshes")
	near(entry.fill.scale.x, 0.5, "Hack fill uses normalized seconds")
	near(entry.fill.position.x, -0.27, "Hack bar anchored left")
	near(entry.signal.material_override.albedo_color.a, 0.72 + sin(90.0) * 0.18, "Source armed pulse at full life")
	var source_color := Color("ff382e").srgb_to_linear().lerp(Color("ffbf3f").srgb_to_linear(), 0.5).linear_to_srgb()
	check(entry.signal.material_override.albedo_color.to_html(false) == source_color.to_html(false), "Source linear color interpolation during hack")
	mine.life = 12.5
	mines.sync_state([mine])
	near(entry.signal.material_override.albedo_color.a, 0.72 + sin(45.0) * 0.18, "Mine pulse updates when remaining life changes")
	mine.allegiance = "friendly"
	mines.sync_state([mine])
	check(not entry.track.visible and not entry.fill.visible, "Completed hack hides progress")
	near(entry.signal.scale.x, 1.16, "Friendly source signal scale")
	near(entry.signal.material_override.albedo_color.a, 0.82 + sin(32.0) * 0.12, "Friendly source lifetime pulse")
	mine.allegiance = "enemy"
	mine.armed = false
	mine.hack_progress = 0
	mines.sync_state([mine])
	near(entry.signal.scale.x, 0.78, "Unarmed source signal scale")
	near(entry.signal.material_override.albedo_color.a, 0.34 + sin(19.0) * 0.14, "Unarmed source lifetime pulse")
	mine.dead = true
	mines.sync_state([mine])
	check(not entry.visual.visible, "Expired mine hidden")
	mines.set_warmup(true, Vector3(2, 3, 4))
	check(entry.visual.visible and entry.track.visible and entry.fill.visible, "Warmup includes every mine material")
	mines.set_warmup(false, Vector3.ZERO)
	check(not entry.visual.visible, "Warmup previews removed")
	var effects := Effects.new()
	root.add_child(effects)
	effects.set_process(false)
	effects.explosion(Vector3.ZERO)
	var fire: Dictionary = effects.fireballs.entries[0]
	near(fire.parts[0].material_override.get_shader_parameter("angle"), fire.angle, "Fireball initial random billboard rotation")
	near(fire.parts[1].material_override.get_shader_parameter("angle"), fire.angle + PI * 0.37, "Fireball source core rotation offset")
	effects.advance_cinematic(0.26)
	near(fire.parts[0].material_override.get_shader_parameter("angle"), fire.angle + 0.04, "Outer fireball rotates with elapsed progress")
	near(fire.parts[1].material_override.get_shader_parameter("angle"), fire.angle + PI * 0.37 - 0.06, "Core counter rotation")
	near(fire.parts[1].material_override.get_shader_parameter("alpha_threshold"), 0.026, "Source additive alpha threshold")
	effects.reset_effects()
	effects.spawn_embedded_projectile({"projectile_kind": "sabot", "position": Vector3(2, -0.1, 5), "velocity": Vector3(0, -2, 10)})
	var spent: Dictionary = effects.transient.entries[0]
	check(spent.life >= 1.8 and spent.life <= 3.3, "Source retained projectile lifetime")
	near(spent.visual.position.y, 0.16, "Source embedded ground height")
	near(spent.parts[0].scale.y, 1.05, "Source embedded sabot dimensions")
	check(spent.parts[0].material_override.albedo_color.to_html(false) == "34383a", "Source iron material color")
	check(spent.visual.basis.is_equal_approx(Basis(Quaternion(Vector3.UP, Vector3.BACK)) * Basis(Vector3.RIGHT, 0.28)), "Source embedded horizontal orientation and lean")
	var original_life: float = spent.life
	effects.advance_cinematic(0.0)
	near(spent.life, original_life, "Pause retains embedded projectile")
	effects.advance_cinematic(0.1)
	near(spent.visual.scale.x, 0.992, "Embedded projectile slowly shrinks")
	effects.advance_cinematic(4.0)
	check(not spent.visual.visible, "Embedded projectile retires after lifetime")
	effects.reset_effects()
	effects.wrecks.spawn({"enemy_kind": "buggy", "id": 123456})
	near(effects.wrecks.entries[0].seed_value, 0.0, "Native numeric ID does not invent source singleplayer ID length")
	effects.wrecks.spawn({"enemy_kind": "buggy", "source_id": "enemy-7"})
	near(effects.wrecks.entries[1].seed_value, 7.0 * 0.137 + 0.293, "Explicit source identity contributes original string length")
	for index in 7:
		effects.wrecks.spawn({"enemy_kind": "buggy"})
	near(effects.wrecks.entries[0].seed_value, 8.0 * 0.293, "Wreck rollover seeds from pre-retirement source count")
	effects.reset_effects()
	var enemy := {"id": 1, "type": "buggy", "kind": "buggy", "position": Vector3.ZERO, "yaw": 0.0, "hit_time": 1.0 / 12.0}
	var state := {"enemies": [enemy]}
	effects.tracks.sync_state(state, 0.1, effects)
	enemy.position = Vector3(0, 0, 1)
	effects.tracks.sync_state(state, 0.1, effects)
	check(effects.tracks.count == effects.tracks.wheels.buggy.size() * 3, "Moving enemy stamps each actual wheel at fixed distance intervals")
	var wheels: Array = effects.tracks.wheels.buggy
	near(effects.tracks.submitted_stamps[0].origin.z, 0.3 + wheels[0].z * 1.06, "Enemy track offsets include source hit pulse scale")
	effects.spawn_dust(Vector3.ZERO, 1, 1)
	var expected_ratio := float(root.get_texture().get_width()) / maxf(1.0, root.get_visible_rect().size.x)
	near(effects.dust.pool.entries[0].parts[0].material_override.get_shader_parameter("pixel_ratio"), expected_ratio if expected_ratio > 0 else 1.0, "Actual viewport render ratio propagated to dust shader")
	var model := Model.new()
	model.reset_run(17)
	model.running = true
	model.fire_projectile("sabot", "player", Vector3(20, 0.02, 20), Vector3(20, -1, 21), 1)
	model._update_projectiles(0.01)
	check(model.projectiles.is_empty(), "Ground impact removes active gameplay projectile")
	var ground_events := model.drain_events().filter(func(event: Dictionary) -> bool: return event.kind == "projectile_ground")
	check(ground_events.size() == 1 and ground_events[0].projectile_kind == "sabot" and ground_events[0].has("velocity"), "Ground impact publishes retained visual data")
	mines.queue_free()
	effects.queue_free()
	await process_frame
	print("Presentation details tests: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

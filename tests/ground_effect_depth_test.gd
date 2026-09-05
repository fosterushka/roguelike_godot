extends SceneTree
const Effects = preload("res://presentation/combat/impact_effects.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var effects := Effects.new()
	root.add_child(effects)
	effects.set_process(false)
	for index in 24:
		effects.spawn_scorch(Vector3(index * 0.04, 5, index * 0.03), 5.0)
		var entry: Dictionary = effects.traces.entries[index]
		var part: MeshInstance3D = entry.parts[0]
		check(part.global_basis.z.normalized().dot(Vector3.UP) > 0.999999, "Scorch normal remains vertical for every random heading")
		for corner: Vector3 in [Vector3(-0.5,-0.5,0), Vector3(-0.5,0.5,0), Vector3(0.5,-0.5,0), Vector3(0.5,0.5,0)]:
			check(absf((part.global_transform * corner).y - 0.024) < 0.00001, "Entire scorch stays below actors and coins")
		check(not part.material_override.no_depth_test and part.material_override.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED, "Scorches test opaque geometry depth without writing alpha depth")
	var snapshots := {}
	for entry: Dictionary in effects.traces.entries:
		snapshots[entry.sequence] = {"transform": entry.parts[0].global_transform, "texture": entry.parts[0].material_override.albedo_texture, "priority": entry.parts[0].material_override.render_priority}
	for index in 40:
		effects.on_event({"kind": "ram_impact", "position": Vector3.ZERO, "speed": 8.0, "bumper": index % 2 == 0})
	for entry: Dictionary in effects.traces.entries:
		var snapshot: Dictionary = snapshots[entry.sequence]
		check(entry.life > 0 and entry.parts[0].global_transform.is_equal_approx(snapshot.transform), "Repeated collisions preserve retained ground geometry")
		check(entry.parts[0].material_override.albedo_texture == snapshot.texture, "Collisions never swap retained scorch textures")
		check(entry.parts[0].material_override.render_priority == snapshot.priority, "Collision camera shakes cannot change scorch overlap order")
		check(entry.parts[0].material_override.render_priority < 0, "All scars sort before airborne transparent actors and pickup glow")
	var previous_sequence: int = effects.traces.entries[0].sequence
	effects.spawn_scorch(Vector3.ZERO, 4.0)
	check(effects.traces.active_count() == 24 and effects.traces.entries[0].sequence != previous_sequence, "Scorch rollover only replaces oldest retained slot")
	var ordered: Array = effects.traces.entries.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.sequence < b.sequence)
	for index in range(1, ordered.size()):
		check(ordered[index].parts[0].material_override.render_priority > ordered[index-1].parts[0].material_override.render_priority, "Newer overlapping scars sort consistently after older scars across pool wrap")
	for entry: Dictionary in effects.traces.entries:
		if snapshots.has(entry.sequence):
			check(entry.parts[0].material_override.albedo_texture == snapshots[entry.sequence].texture, "Pool wrap leaves surviving scar textures intact")
	effects.reset_effects()
	effects.spawn_blood_mark(Vector3.ZERO, 4.0)
	var blood: MeshInstance3D = effects.transient.entries[0].parts[0]
	check(blood.global_basis.z.normalized().dot(Vector3.UP) > 0.999999, "Blood uses the same corrected ground rotation")
	check(blood.material_override.render_priority < 0, "Blood does not cover airborne alpha visuals")
	effects.transient.cursor = 0
	effects.spawn_muzzle_flash(Vector3.UP, "bullet")
	check(blood.material_override.render_priority == 0 and blood.material_override.albedo_texture == null, "Reused transient material clears decal priority and texture")
	check(blood.material_override.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY and not blood.material_override.no_depth_test, "Reused airborne effects restore ordinary depth policy")
	effects.explosion(Vector3.ZERO)
	var fire: Dictionary = effects.fireballs.entries[0]
	for part: MeshInstance3D in fire.parts:
		check(part.material_override.render_priority == 0, "Fireball does not force itself above all nearby transparent objects")
		check(not part.material_override.shader.code.contains("depth_test_disabled"), "Fireball preserves normal scene depth testing")
	check(fire.parts[1].sorting_offset > 0 and fire.parts[1].sorting_offset < 0.2, "Core overlap uses only a small local depth sort offset")
	check(effects.smoke.entries[0].parts[0].material_override.render_priority == 0, "Smoke uses scene depth sorting")
	effects.queue_free()
	await process_frame
	print("Ground effect depth tests: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

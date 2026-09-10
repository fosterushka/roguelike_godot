extends SceneTree
const Jammer = preload("res://modules/combat/jammer_rules.gd")
const Effects = preload("res://presentation/combat/impact_effects.gd")
const Hud = preload("res://presentation/ui/hud.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
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
	Locale.settings_path = "/private/tmp/jammer-language-%d.cfg" % Time.get_ticks_usec()
	Locale._initialized = false
	Locale.initialize()
	var hud := Hud.new()
	root.add_child(hud)
	hud.set_loading(false)
	hud.set_gameplay_active(true)
	var effects := Effects.new()
	root.add_child(effects)
	effects.set_process(false)
	var field: Node3D = effects.jammer_field
	var overlay: Control = hud.jammer_overlay
	var vhs: ColorRect = hud.jammer_vhs
	var player := {"position": Vector3.ZERO, "hp": 100.0}
	var enemy := {"id": 8, "kind": "jammerTruck", "position": Vector3(20, 0, 0), "hp": 150.0}
	var enemies: Array[Dictionary] = [enemy]
	var rules := Jammer.new()
	rules.reset(player, 23)
	var state := {"player": player}
	effects.sync_state(state, 0)
	hud.update_run(state, null, 0)
	check(not overlay.visible and not field.rings[0].visible, "Reset player starts without jammer visuals")
	check(not vhs.visible, "Reset player has no screen distortion")
	check(vhs.get_index() < hud.markers.get_index() and not hud.markers.occluders.has(vhs), "VHS draws beneath HUD and does not occlude world markers")
	check(vhs.mouse_filter == Control.MOUSE_FILTER_IGNORE and vhs.anchor_right == 1 and vhs.anchor_bottom == 1, "VHS covers viewport without intercepting controls")
	rules.step(player, enemies, 1.85)
	effects.sync_state(state, 0)
	hud.update_run(state, null, 0)
	check(vhs.intensity == 0 and vhs.target_intensity > 0, "Entering jammer starts fade without snapping")
	vhs.advance(0.2)
	check(vhs.intensity > 0 and vhs.intensity < vhs.target_intensity, "Interference fades in gradually")
	vhs.advance(1.0)
	check(player.jammer_reversed and overlay.reversed and overlay.detail.visible, "Reversal caption follows actual gameplay pulse")
	check(vhs.visible and vhs.intensity > 0.9 and vhs.material.get_shader_parameter("pulse") > 0.9, "Real jammer radius drives full-screen shader and reversal pulse")
	check(overlay.caption.text == "SIGNAL JAMMED" and overlay.detail.text == "CONTROLS REVERSED", "Jammer status defaults to English")
	check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.get_child_count() == 2, "Compact text status creates no modal or panel input surface")
	check(overlay.size.x <= 280 and overlay.size.y <= 40, "Jammer status occupies a small HUD corner")
	check(field.rings.size() == 3 and field.sparks.size() == 6, "Transmitter and player effects have fixed mesh budgets")
	var child_count := field.get_child_count()
	for visual: MeshInstance3D in field.rings + field.sparks:
		check(visual.visible, "In-range jammer exposes preallocated effect")
		var material: StandardMaterial3D = visual.material_override
		check(not material.no_depth_test and material.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED and material.render_priority == 0, "Airborne signal transparency obeys opaque actor depth")
		check(material.albedo_color.a <= 0.48, "Interference remains translucent without a solid flash")
	for ring: MeshInstance3D in field.rings:
		check(is_equal_approx(ring.position.x, 20) and ring.position.y >= 3.5999 and ring.scale.x <= player.jammer_radius * 0.18, "Transmitter waves anchor above real source and remain local")
	for spark: MeshInstance3D in field.sparks:
		check(spark.position.y >= 1.5 and Vector2(spark.position.x, spark.position.z).length() <= 2.001, "Player interference stays near chassis roof rather than screen or ground")
	var source_data := player.duplicate(true)
	var frozen: Transform3D = field.rings[0].transform
	var age: float = field.elapsed
	effects.set_warmup_visible(true)
	effects.sync_state({"player": {}}, 0)
	effects.advance_cinematic(0.5)
	check(field._preview.visible and field._preview.get_child_count() == 2, "Warmup includes ring and spark mesh variants")
	check(field.elapsed == age and field.rings[0].transform == frozen and player == source_data, "Warmup mutates neither live jammer pose nor gameplay state")
	effects.set_warmup_visible(false)
	check(not field._preview.visible and field.rings[0].transform == frozen, "Dedicated jammer warmup preview cleans without erasing live state")
	effects.advance_cinematic(0)
	check(field.rings[0].transform == frozen, "Zero simulation delta freezes signal wave")
	effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	effects.set_process(true)
	paused = true
	await process_frame
	await process_frame
	check(field.elapsed == age and field.rings[0].transform == frozen, "Real SceneTree pause freezes effect process")
	effects.set_process(false)
	paused = false
	hud.set_paused(true)
	check(not overlay.is_visible_in_tree(), "Jammer HUD is hidden behind pause menu")
	check(not vhs.is_visible_in_tree(), "Pause hides full-screen interference")
	hud.set_paused(false)
	hud.set_language("ru")
	check(overlay.caption.text == "СИГНАЛ ПОДАВЛЕН" and overlay.detail.text == "УПРАВЛЕНИЕ ИНВЕРТИРОВАНО", "Visible jammer labels switch immediately to Russian")
	player.position = Vector3(20, 0, 60)
	rules.step(player, enemies, 0.2)
	effects.sync_state(state, 0)
	hud.update_run(state, null, 0)
	check(not player.jammed and not overlay.detail.visible and field.strength > 0, "Leaving real radius immediately removes reversal and retains only short visual fade")
	rules.step(player, enemies, 3)
	effects.sync_state(state, 0)
	hud.update_run(state, null, 0)
	check(not overlay.visible and not field.rings[0].visible and not field.sparks[0].visible, "Outside-range fade fully hides world and HUD interference")
	check(vhs.visible, "Leaving keeps screen alive for fade-out")
	vhs.advance(2.0)
	check(not vhs.visible and vhs.intensity == 0, "Leaving radius clears VHS after fade")
	player.position = Vector3(20, 0, 47.9)
	rules.step(player, enemies, 0.016)
	hud.update_run(state, null, 0)
	vhs.advance(1.0)
	check(player.jammed and vhs.visible and vhs.intensity >= vhs.EDGE_STRENGTH, "Outer edge of actual radius already displays visible interference")
	player.position = Vector3.ZERO
	rules.step(player, enemies, 1)
	effects.sync_state(state, 0)
	check(field.rings[0].visible, "Re-entering radius reuses visible effect")
	for index in 50:
		effects.sync_state(state, 0)
		effects.advance_cinematic(0.016)
	check(field.get_child_count() == child_count, "Repeated jammer snapshots and frames allocate no extra scene nodes")
	player.hp = 0
	effects.sync_state(state, 0)
	hud.update_run(state, null, 0)
	check(not overlay.visible and not field.rings[0].visible, "Player death hides stale jammer state immediately")
	check(not vhs.visible, "Death clears VHS even with stale jammer strength")
	rules.reset(player)
	hud.update_run(state, null, 0)
	check(not vhs.visible and vhs.intensity == 0, "Run reset clears screen interference")
	effects.reset_effects()
	check(field.strength == 0 and field.elapsed == 0 and field._player.is_empty(), "Run reset clears all retained visual jammer state")
	hud.queue_free()
	effects.queue_free()
	await process_frame
	DirAccess.remove_absolute(Locale.settings_path)
	print("Jammer feedback tests: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

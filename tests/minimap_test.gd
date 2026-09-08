extends SceneTree

const Radar = preload("res://presentation/ui/radar.gd")
const Markers = preload("res://presentation/ui/world_markers.gd")
const Geometry = preload("res://presentation/ui/map_geometry.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var radar := Radar.new()
	radar.size = Vector2(176, 208)
	root.add_child(radar)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 60
	var markers := Markers.new()
	root.add_child(markers)
	markers.camera = camera
	var data := {"generation": 1, "running": true, "status": "combat", "player": {"position": Vector3.ZERO, "hp": 250, "radar_range": 260.0, "heading": 0.0}, "enemies": []}
	data.player.radar_range = 0.0
	radar.update_state(data, camera)
	_check(radar.visible and radar.effective_range == 18 and is_equal_approx(radar.display_range, 64.8), "Fresh run reveals only18m on compact local map")
	_check(radar.explored(Vector3.ZERO), "Basic map reveals immediate surroundings")
	data.player.radar_range = 260.0
	radar.update_state(data, camera)
	_check(radar.effective_range == 260 and radar.display_range == 468, "Radar upgrade extends basic map detection and display range")
	for heading in [0.0, PI * 0.25, PI * 0.5, PI, PI * 1.5]:
		var forward := Vector3(sin(heading), 0, cos(heading))
		camera.position = -forward * 20 + Vector3.UP * 20
		camera.look_at(Vector3.ZERO)
		radar.update_state(data, camera)
		var right := camera.global_basis.x * 30
		var projected := camera.unproject_position(right) - camera.unproject_position(Vector3.ZERO)
		var mapped: Vector2 = radar._point(right) - radar._point(Vector3.ZERO)
		_check(projected.x > 0 and mapped.x > 0 and absf(mapped.y) < 0.001, "Camera right stays radar right at heading %s" % heading)
		_check(radar._point(forward * 30).y < radar._point(Vector3.ZERO).y, "Camera ground forward stays radar up")
		await process_frame
	_check(radar.explored(Vector3.ZERO) and not radar.explored(Vector3(1000, 0, 1000)), "Exploration reveals only local terrain")
	_check(not radar.explored(Vector3(2000, 0, 0)), "Coordinates outside map do not alias explored boundary cells")
	_check(radar._map_rect.end.y <= radar.size.y - 34, "Compact map leaves footer space")
	radar.step_zoom(-1)
	_check(radar.zoom_index == 3 and radar.zoom_label() == "133%", "Zoom button uses source scale")
	paused = true
	radar.step_zoom(-1)
	_check(radar.zoom_index == 3, "Pause blocks radar zoom")
	paused = false
	radar.hide()
	radar.step_zoom(-1)
	_check(radar.zoom_index == 3, "Hidden HUD blocks radar zoom")
	radar.show()
	data.player.position = Vector3(900, 0, 900)
	radar.update_state(data, camera)
	_check(radar.explored(Vector3.ZERO) and radar.explored(data.player.position), "Explored terrain persists while driving")
	data.generation = 2
	radar.update_state(data, camera)
	_check(not radar.explored(Vector3.ZERO) and radar.explored(data.player.position) and radar.zoom_index == 4, "Restart clears exploration and restores default zoom")
	data.player.position = Vector3.ZERO
	data.enemies = [{"position": Vector3(20, 100, 0), "kind": "jammerTruck", "dead": false}]
	radar.update_state(data, camera)
	_check(radar.jammed and is_equal_approx(radar.effective_range, 143), "Jammer range uses ground distance")
	radar.update_world({"weather": {"type": "foggy"}})
	_check(is_equal_approx(radar.effective_range, 260 * 0.55 * 0.84), "Weather update immediately refreshes radar interference")
	data.enemies[0].stagger_remaining = 1.0
	radar.update_state(data, camera)
	_check(not radar.jammed and is_equal_approx(radar.effective_range, 260 * 0.84), "Staggered jammer stops interference")
	data.enemies[0].stagger_remaining = 0.0
	for disabled: Dictionary in [{"dead": true}, {"hp": 0.0}, {"allegiance": "friendly"}, {"counts_as_hostile": false}]:
		var original: Dictionary = data.enemies[0].duplicate()
		data.enemies[0].merge(disabled, true)
		radar.update_state(data, camera)
		_check(not radar.jammed, "Radar ignores inactive/nonhostile jammer consistently with driving")
		data.enemies[0] = original
	data.enemies[0].stagger_remaining = 1.0
	radar.update_state(data, camera)
	radar.update_world({"weather": {"type": "sunny", "fog_strength": 0.5}})
	var indicator_range := preload("res://presentation/ui/enemy_detection.gd").range_for(data, radar.world_state)
	_check(is_equal_approx(indicator_range, radar.effective_range) and is_equal_approx(indicator_range, 239.2), "Enemy indicators share radar's fading fog range")
	_check(Geometry.distance_squared(Vector3(3, 100, 4), Vector3.ZERO) == 25, "Airborne radar contacts use XZ distance")
	var bounds := Rect2(0, 0, 10, 10)
	var line := Geometry.clip_line(Vector2(-5, 5), Vector2(15, 5), bounds)
	_check(line == PackedVector2Array([Vector2(0, 5), Vector2(10, 5)]), "Road crossing two map edges remains visible")
	_check(Geometry.clip_line(Vector2(-5, -5), Vector2(15, -5), bounds).is_empty(), "Road outside map remains clipped")
	line = Geometry.clip_line(Vector2(5, 5), Vector2(15, 15), bounds)
	_check(line == PackedVector2Array([Vector2(5, 5), Vector2(10, 10)]), "Diagonal road reaches map corner")
	var diamond := PackedVector2Array([Vector2(5, -5), Vector2(15, 5), Vector2(5, 15), Vector2(-5, 5)])
	var clipped := Geometry.clip_polygon(diamond, bounds)
	var valid := clipped.size() >= 4
	for point in clipped:
		valid = valid and bounds.grow(0.001).has_point(point)
	_check(valid and not Geometry2D.triangulate_polygon(clipped).is_empty(), "Rotated exploration polygon clips without distorted corners")
	_check(Geometry.clip_polygon(PackedVector2Array([Vector2(-5, -5), Vector2(-3, -5), Vector2(-3, -3)]), bounds).is_empty(), "Offscreen fog cell contributes no polygon")
	_check(Geometry.edge_point(Vector2(100, 5), bounds).is_equal_approx(Vector2(10, 5)), "Extraction target clamps to correct edge")
	camera.position = Vector3(0, 20, 20)
	camera.look_at(Vector3.ZERO)
	var behind_right := camera.global_position + camera.global_basis.z * 50 + camera.global_basis.x * 20
	var raw := camera.unproject_position(behind_right)
	_check(camera.is_position_behind(behind_right) and markers.projected_position(behind_right).is_equal_approx(raw), "Orthographic behind-camera target is never mirrored")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	raw = camera.unproject_position(behind_right)
	var expected := camera.get_viewport().get_visible_rect().get_center() * 2 - raw
	_check(markers.projected_position(behind_right).is_equal_approx(expected), "Perspective behind-camera target corrects projection reversal")
	data.enemies[0].stagger_remaining = 0.0
	data.enemies[0].allegiance = "friendly"
	radar.update_state(data, camera)
	_check(not radar.jammed, "Friendly jammer does not interfere with player radar")
	data.enemies.clear()
	await _test_edge_hints(markers, camera, data)
	radar.layout = {"roads": [[{"x": -500, "z": 0}, {"x": 500, "z": 0}]], "villages": [{"x": 20, "z": 0, "consumed": true}], "landmarks": []}
	radar.update_world({"boundary": {"radius": 200.0}, "activity": {"records": [{"state": "completed", "position": Vector3.ZERO}]}, "extraction": {"visible": true, "position": Vector3(1000, 0, 1000)}})
	radar.update_state(data, camera)
	await process_frame
	await process_frame
	_check(true, "Headless draw callbacks exercise roads, fog, boundary and extraction without engine errors")
	radar.queue_free()
	markers.queue_free()
	camera.queue_free()
	await process_frame
	print("Minimap: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_edge_hints(markers: Control, camera: Camera3D, data: Dictionary) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 20, 20)
	camera.look_at(Vector3.ZERO)
	markers.size = root.get_visible_rect().size
	data.player.radar_range = 1000.0
	data.enemies = [
		{"id": 1, "position": Vector3(500, 0, 0), "kind": "rifleman"},
		{"id": 2, "position": Vector3(800, 0, 0), "kind": "rifleman"},
		{"id": 3, "position": Vector3(600, 0, 0), "kind": "jammerTruck"},
		{"id": 4, "position": Vector3(-600, 0, 0), "kind": "repairCrawler"},
		{"id": 5, "position": Vector3(0, 0, 600), "kind": "leviathan", "boss": true},
		{"id": 6, "position": Vector3(0, 0, -300), "kind": "rifleman", "dead": true},
		{"id": 7, "position": Vector3(-300, 0, 0), "kind": "rifleman", "allegiance": "friendly"},
		{"id": 8, "position": Vector3.ZERO, "kind": "rifleman"},
	]
	data.focus_id = -1
	markers.update_state(data, camera)
	var candidates: Array = markers.edge_candidates()
	var ids: Array = candidates.map(func(candidate: Dictionary) -> String: return candidate.id)
	_check(ids.has("enemy:1") and not ids.has("enemy:2"), "Upgraded radar shows nearest offscreen hostile only")
	_check(ids.has("enemy:3") and not ids.has("enemy:4"), "Nearest priority vehicle has independent edge guidance")
	_check(ids.has("enemy:5"), "Offscreen boss has guidance without a selected target")
	_check(not ids.has("enemy:6") and not ids.has("enemy:7") and not ids.has("enemy:8"), "Dead, friendly and onscreen enemies produce no edge hints")
	data.focus_id = 2
	markers.update_state(data, camera)
	candidates = markers.edge_candidates()
	_check(candidates[0].id == "enemy:2", "Selected target takes first edge-hint priority")
	markers.update_world({
		"extraction": {"visible": true, "position": Vector3(-1000, 0, 0)},
		"activity": {"records": [
			{"id": "live", "state": "announced", "type": "scavengerRoute", "position": Vector3(0, 0, 800)},
			{"id": "done", "state": "completed", "type": "scavengerRoute", "position": Vector3(0, 0, 800)}]},
		"support": {"heal_carts": [{"id": "cart", "position": Vector3(0, 0, -800)}], "airdrops": [{"id": "drop", "position": Vector3(-800, 0, 0)}]}
	})
	candidates = markers.edge_candidates()
	ids = candidates.map(func(candidate: Dictionary) -> String: return candidate.id)
	_check(ids.has("extraction:active") and ids.has("activity:live") and not ids.has("activity:done"), "Active objectives and extraction appear; finished activity disappears")
	_check(ids.has("heal_carts:cart") and ids.has("airdrops:drop"), "Rescue and supply sources provide offscreen guidance")
	var radar_blocker := Control.new()
	radar_blocker.position = markers.size - Vector2(200, 220)
	radar_blocker.size = Vector2(188, 208)
	root.add_child(radar_blocker)
	var top_blocker := Control.new()
	top_blocker.size = Vector2(markers.size.x, 60)
	root.add_child(top_blocker)
	markers.occluders.assign([radar_blocker, top_blocker])
	markers.advance_signals(0.6)
	var hints: Array = markers.edge_hints()
	_check(hints.size() == markers.MAX_EDGE_HINTS, "Crowded world is bounded to six readable edge hints")
	var separated := true
	var inside := true
	var viewport := Rect2(Vector2.ZERO, markers.size)
	for index in hints.size():
		var rectangle: Rect2 = hints[index].rect
		inside = inside and viewport.encloses(rectangle)
		separated = separated and not rectangle.intersects(radar_blocker.get_global_rect()) and not rectangle.intersects(top_blocker.get_global_rect())
		for other in range(index):
			separated = separated and not rectangle.intersects(hints[other].rect)
	_check(inside and separated, "Hint labels stay in viewport and avoid radar, top HUD and each other")
	var right_hint: Dictionary = {}
	for hint: Dictionary in hints:
		if hint.id == "enemy:2":
			right_hint = hint
	_check(not right_hint.is_empty() and right_hint.direction.x > 0, "Offscreen right target keeps arrow pointing right after safe-zone placement")
	data.player.radar_level = 0
	markers.update_state(data, camera)
	for candidate: Dictionary in markers.edge_candidates():
		if candidate.get("signal", false):
			_check(candidate.label.is_empty() and candidate.icon == "?", "Low radar signals hide target identity")
	markers.advance_signals(3.0)
	_check(markers.edge_hints().all(func(hint: Dictionary) -> bool: return not hint.get("signal", false)), "Objective ripples disappear between transmissions")
	data.player.radar_level = 3
	markers.update_state(data, camera)
	for candidate: Dictionary in markers.edge_candidates():
		if candidate.id == "activity:live":
			_check(candidate.identified and not candidate.label.is_empty(), "Radar three identifies mission transmissions")
		if candidate.id == "extraction:active":
			_check(not candidate.identified, "Radar three keeps extraction signals anonymous")
	markers.advance_signals(20.0)
	markers.advance_signals(0.6)
	_check(markers.edge_hints().any(func(hint: Dictionary) -> bool: return hint.get("signal", false)), "Signals repeat after their distance based interval")
	markers.hide()
	_check(markers.edge_hints().is_empty(), "Hidden gameplay UI suppresses edge hints in menus")
	markers.show()
	await process_frame
	await process_frame
	markers.occluders.clear()
	radar_blocker.queue_free()
	top_blocker.queue_free()
	markers.update_world({})
	data.enemies.clear()

extends SceneTree
const Ground = preload("res://presentation/world/ground_surface_view.gd")
const Weather = preload("res://modules/world/weather_state.gd")
const WeatherView = preload("res://presentation/world/weather_view.gd")
const Effects = preload("res://presentation/combat/impact_effects.gd")
const Road = preload("res://presentation/world/road_view.gd")
var reference_winding := 0.0
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _init() -> void:
	_run.call_deferred()
func _surface_check(visual: MeshInstance3D, offset: float, label: String) -> void:
	var arrays := visual.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	check(vertices.size() >= 3 and indices.size() >= 3, label + " has clipped surface geometry")
	for index in vertices.size():
		var point := visual.global_transform * vertices[index]
		check(absf(point.y - Ground.Terrain.height_at(point.x, point.z) - offset) < 0.0002, label + " vertex lies on terrain")
		check(uvs[index].x >= -0.00001 and uvs[index].x <= 1.00001 and uvs[index].y >= -0.00001 and uvs[index].y <= 1.00001, label + " clipped UV remains in texture footprint")
	for index in range(0, indices.size(), 3):
		var center := Vector3.ZERO
		for vertex in 3:
			center += visual.global_transform * vertices[indices[index + vertex]] / 3.0
		check(absf(center.y - Ground.Terrain.height_at(center.x, center.z) - offset) < 0.0003, label + " triangle interior follows exact terrain face")
		var a := visual.global_transform * vertices[indices[index]]
		var b := visual.global_transform * vertices[indices[index + 1]]
		var c := visual.global_transform * vertices[indices[index + 2]]
		check((b - a).cross(c - a).y * reference_winding > 0, label + " face winding matches upward native PlaneMesh")
	check(not visual.material_override.no_depth_test and visual.material_override.render_priority < 0, label + " retains depth testing below airborne transparency")
func _run() -> void:
	var reference := PlaneMesh.new().surface_get_arrays(0)
	var rv: PackedVector3Array = reference[Mesh.ARRAY_VERTEX]
	var ri: PackedInt32Array = reference[Mesh.ARRAY_INDEX]
	reference_winding = (rv[ri[1]] - rv[ri[0]]).cross(rv[ri[2]] - rv[ri[0]]).y
	Ground.Terrain.configure({})
	var weather := Weather.new()
	weather.reset(72841)
	weather.phase = {"type": "rainy"}
	for point: Vector3 in [Vector3(53, 3, 49), Vector3(59, 9, 50), Vector3(63, -8, 45)]:
		check(weather.create_mud(point), "Wet aerial impact creates mud")
		var zone: Dictionary = weather.mud_zones.back()
		check(absf(zone.position.y - Ground.Terrain.height_at(point.x, point.z)) < 0.00001, "Mud domain discards projectile impact altitude")
	var arena := Node3D.new()
	var vehicle := CharacterBody3D.new()
	var view := WeatherView.new()
	root.add_child(arena)
	root.add_child(vehicle)
	root.add_child(view)
	view.set_process(false)
	view.setup(arena, vehicle)
	var state := {"weather": {"type": "rainy"}, "tornado": {}, "mud_zones": weather.mud_zones.duplicate(true), "elapsed": 0.0}
	state.mud_zones[0].position.y = 45.0
	view.apply_state(state)
	for index in 3:
		_surface_check(view._mud[index], Ground.MUD_OFFSET, "Mud %d" % index)
		check(view._mud[index].global_position.y < 1.0, "View also rejects stale airborne mud record altitude")
	var texture: Texture2D = view._mud[1].material_override.albedo_texture
	state.mud_zones.pop_front()
	view.apply_state(state)
	check(view._mud[0].material_override.albedo_texture == texture, "Surviving mud keeps its texture after earlier pool entry expires")
	var retained_mesh: Mesh = view._mud[0].mesh
	view.apply_state(state)
	check(view._mud[0].mesh == retained_mesh, "Unchanged mud state reuses conformed geometry")
	view.reset_run()
	state.mud_zones[0].position.x += 20.0
	view.apply_state(state)
	check(absf(view._mud[0].position.x - state.mud_zones[0].position.x) < 0.00001, "Restart invalidates reused mud identity and position")
	_surface_check(view._mud[0], Ground.MUD_OFFSET, "Reused mud")
	var effects := Effects.new()
	root.add_child(effects)
	effects.set_process(false)
	effects.spawn_scorch(Vector3(50, 12, 48), 8.0)
	effects.spawn_blood_mark(Vector3(57, 4, 52), 7.0)
	_surface_check(effects.traces.entries[0].parts[0], Ground.SCORCH_OFFSET, "Scorch")
	_surface_check(effects.transient.entries[0].parts[0], Ground.BLOOD_OFFSET, "Blood")
	effects.tracks.stamp(effects.random, Vector3(53, 22, 49), 0.7, 0, 0, 1)
	var stamp: Transform3D = effects.tracks.submitted_stamps[0]
	check(stamp.origin.y >= Ground.Terrain.height_at(53, 49) + Ground.TRACK_OFFSET - 0.00001, "Wheel trace ignores actor altitude and follows ground")
	check(stamp.basis.y.normalized().dot(Ground.Terrain.normal_at(53, 49)) > 0.99999, "Wheel trace tilts only with terrain normal")
	check(Road._material(false).render_priority < effects.tracks.batch.multimesh.mesh.material.render_priority, "Road draws before ground tracks")
	check(effects.tracks.batch.multimesh.mesh.material.render_priority > view._mud[0].material_override.render_priority, "Tire traces draw over mud below actors")
	effects.explosion(Vector3(53, 7, 49))
	check(effects.fireballs.entries[0].visual.position.y > 7.0, "Actual airborne fireball retains impact altitude")
	check(effects.smoke.entries[0].visual.position.y > 7.0, "Actual airborne smoke retains impact altitude")
	effects.wrecks.spawn({"enemy_kind": "buggy", "position": Vector3(53, 22, 49)})
	check(absf(effects.wrecks.entries[0].visual.position.y - Ground.Terrain.height_at(53,49)) < 0.00001, "Ground vehicle wreck uses actual terrain height")
	var source := preload("res://presentation/vehicles/wheeled_rig.gd").build_player()
	root.add_child(source)
	effects.player_destruction.spawn(source, Vector3(53, 0.63, 49), 0, effects.random)
	check(absf(effects.player_destruction.position.y - 0.63) < 0.00001, "Player destruction preserves elevated chassis at first frame")
	effects.player_destruction.advance(1.25)
	check(absf(effects.player_destruction.position.y - 0.47) < 0.00001, "Player wreck sink is relative to its original terrain height")
	check(effects.player_destruction._preview.has_meta("wheels"), "Destruction warmup uses active wheeled chassis")
	source.queue_free()
	view.queue_free()
	vehicle.queue_free()
	arena.queue_free()
	effects.queue_free()
	await process_frame
	Ground.Terrain.heights = PackedFloat32Array()
	print("Ground surface tests: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

extends Node3D
const Ground = preload("res://presentation/world/ground_surface_view.gd")
const Surface = preload("res://presentation/world/track_surface.gd")
const EnemyMotion = preload("res://presentation/combat/enemy_animation.gd")
const Source = preload("res://presentation/combat/source_model.gd")
const CAPACITY := 1800
const SPACING := 0.3
const MAX_FRAME_STAMPS := 128
const TELEPORT_DISTANCE := 24.0
var batch: MultiMeshInstance3D
var cursor := 0
var count := 0
var submitted_stamps: Array[Transform3D] = []
var submitted_surfaces := PackedInt32Array()
var dust_timer := 0.0
var wheels: Dictionary = {}
var _paths: Dictionary = {}
var _wet := false
var _scorches: Array = []
var _budget := MAX_FRAME_STAMPS
var _warmup: MultiMeshInstance3D

func _ready() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.62, 0.36)
	var material := ShaderMaterial.new()
	material.shader = preload("res://presentation/combat/fx/tire_tread.gdshader")
	material.render_priority = Ground.TRACK_PRIORITY
	mesh.material = material
	batch = _batch(mesh, CAPACITY)
	_warmup = _batch(mesh, 1)
	_warmup.visible = false
	for kind in ["bike", "buggy", "raider", "boss", "jammerTruck", "repairCrawler", "minelayer"]:
		var source := Source.instantiate(kind)
		var positions: Array[Vector3] = []
		for part: MeshInstance3D in source.get_children():
			for binding: Dictionary in part.get_meta("source_part").get("bindings", []):
				if binding.role == "wheel":
					var point: Vector3 = binding.rest_inverse.affine_inverse().origin
					if point not in positions:
						positions.append(point)
		wheels[kind] = positions
		source.free()
	submitted_stamps.resize(CAPACITY)
	submitted_surfaces.resize(CAPACITY)
	reset()

func _batch(mesh: Mesh, capacity: int) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = 0
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = multimesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	return visual

func stamp(_random, position_value: Vector3, heading: float, lateral: float, longitudinal: float, stretch: float, width: float = 1.0) -> void:
	var point := position_value + Vector3(cos(heading), 0, -sin(heading)) * lateral + Vector3(sin(heading), 0, cos(heading)) * longitudinal
	point = Ground.point_at(point, Ground.TRACK_OFFSET)
	var up := Ground.Terrain.normal_at(point.x, point.z)
	var forward := Vector3(sin(heading), 0, cos(heading))
	var right := up.cross(forward).normalized()
	var basis := Basis(right * width, up, right.cross(up) * stretch)
	var clearance := 0.0
	for corner: Vector3 in [Vector3(-0.31, 0, -0.18), Vector3(0.31, 0, -0.18), Vector3(-0.31, 0, 0.18), Vector3(0.31, 0, 0.18)]:
		var contact := point + basis * corner
		clearance = maxf(clearance, Ground.Terrain.height_at(contact.x, contact.z) + Ground.TRACK_OFFSET - contact.y)
	point.y += clearance
	var kind := Surface.kind_at(point, _wet, _scorches)
	submitted_stamps[cursor] = Transform3D(basis, point)
	submitted_surfaces[cursor] = kind
	batch.multimesh.set_instance_transform(cursor, submitted_stamps[cursor])
	batch.multimesh.set_instance_color(cursor, Surface.color_for(kind))
	batch.multimesh.set_instance_custom_data(cursor, Color(0, float(kind), 0, 0))
	cursor = (cursor + 1) % CAPACITY
	count = mini(CAPACITY, count + 1)
	batch.multimesh.visible_instance_count = count

func sync_state(state: Dictionary, delta: float, effects) -> void:
	if delta <= 0.0:
		return
	_budget = MAX_FRAME_STAMPS
	_wet = state.get("weather_type", "clear") in ["rainy", "storm"]
	_scorches = effects.traces.entries
	var alive := {}
	var contacts: Array = []
	if is_instance_valid(effects.player_view) and effects.player_view.has_method("get_tire_contacts"):
		contacts = effects.player_view.get_tire_contacts()
	elif state.has("player"):
		var player: Dictionary = state.player
		var scale_value := float(player.get("visual_scale", 0.88))
		var heading := float(player.get("heading", 0.0))
		for index in 4:
			var anchor: Vector3 = preload("res://modules/caravan/wheel_suspension.gd").ANCHORS[index]
			contacts.append({"id": "crawler:wheel%d" % index, "position": player.position + Basis(Vector3.UP, heading) * anchor * scale_value, "heading": heading, "grounded": true, "radius": 0.88 * scale_value})
	for contact: Dictionary in contacts:
		alive[contact.id] = true
		_follow(contact.id, contact.position, float(contact.heading), bool(contact.grounded), float(contact.get("radius", 0.88)) / 0.88 * 0.7 / 0.62, effects)
	for enemy: Dictionary in state.get("enemies", []):
		var kind := "boss" if enemy.get("boss", false) else "raider" if enemy.get("type") == "keep" else str(enemy.get("kind", ""))
		if enemy.get("dead", false) or not wheels.has(kind):
			continue
		var heading := float(enemy.get("yaw", 0.0))
		var pose := EnemyMotion.advance(enemy, {}, 0.0, float(state.get("elapsed", 0.0)))
		var scale_value: float = pose.basis.get_scale().x
		for index in wheels[kind].size():
			var id := "enemy:%s:wheel%d" % [enemy.id, index]
			alive[id] = true
			var point: Vector3 = enemy.position + Basis(Vector3.UP, heading) * wheels[kind][index] * scale_value
			_follow(id, point, heading, true, 0.72 if kind == "bike" else 1.0, effects)
	for id in _paths.keys():
		if not alive.has(id):
			_paths.erase(id)
	_dust(state, delta, effects)

func _follow(id: String, point: Vector3, heading: float, grounded: bool, width: float, effects) -> void:
	if not _paths.has(id):
		_paths[id] = {"point": point, "heading": heading, "carry": 0.0}
		return
	var path: Dictionary = _paths[id]
	var start: Vector3 = path.point
	var distance := Vector2(point.x - start.x, point.z - start.z).length()
	if not grounded or distance > TELEPORT_DISTANCE:
		path.point = point
		path.heading = heading
		path.carry = 0.0
		return
	if distance < 0.00001:
		return
	var next := SPACING - float(path.carry)
	while next <= distance + 0.000001 and _budget > 0:
		var fraction := clampf(next / distance, 0, 1)
		stamp(effects.random, start.lerp(point, fraction), lerp_angle(path.heading, heading, fraction), 0, 0, 1, width)
		_budget -= 1
		next += SPACING
	path.carry = fposmod(float(path.carry) + distance, SPACING)
	if path.carry > SPACING - 0.00001 or path.carry < 0.00001:
		path.carry = 0.0
	path.point = point
	path.heading = heading

func _dust(state: Dictionary, delta: float, effects) -> void:
	dust_timer -= delta
	var player: Dictionary = state.get("player", {})
	if player.is_empty() or _wet or dust_timer > 0:
		return
	var speed := float(player.get("speed", 0.0))
	if absf(speed) <= 2.7:
		return
	var heading := float(player.get("heading", 0.0))
	var rear: Vector3 = player.position + Vector3(sin(heading), 0, cos(heading)) * (-2.7 if speed >= 0 else 2.7)
	rear = Ground.point_at(rear, 0.04)
	var drifting := absf(float(player.get("slip_angle", 0.0))) > 0.12
	effects.spawn_dust(rear, 4 if drifting else 2, clampf(absf(speed) / 8.0, 0.55, 1.15))
	dust_timer = 0.085 if drifting else 0.14

func reset() -> void:
	cursor = 0
	count = 0
	dust_timer = 0.0
	_paths.clear()
	_scorches = []
	batch.multimesh.visible_instance_count = 0

func set_warmup(enabled: bool, point: Vector3) -> void:
	_warmup.visible = enabled
	_warmup.multimesh.visible_instance_count = 1 if enabled else 0
	if enabled:
		_warmup.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, point))
		_warmup.multimesh.set_instance_color(0, Surface.color_for(Surface.Kind.SAND))
		_warmup.multimesh.set_instance_custom_data(0, Color(0, 0, 0, 0))

extends Node3D
const Policy = preload("res://modules/world/destruction_policy.gd")
const Ground = preload("res://modules/caravan/terrain_surface.gd")
const LIMIT := 48
var arena: Node3D
var moving: Dictionary = {}
var stumps: Dictionary = {}
var _stump_batch: MultiMeshInstance3D
var _free_stumps: Array[int] = []
var _free_visuals: Array[Node3D] = []
var _visual_pool: Array[Node3D] = []
var _warmup_nodes: Array[Node3D] = []

func setup(value: Node3D) -> void:
	arena = value
	for index in LIMIT:
		var visual := Node3D.new()
		for part in 4:
			visual.add_child(MeshInstance3D.new())
		add_child(visual)
		_visual_pool.append(visual)
	_stump_batch = MultiMeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.82
	mesh.bottom_radius = 1.0
	mesh.height = 0.65
	mesh.radial_segments = 7
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("795639")
	material.roughness = 1.0
	mesh.material = material
	_stump_batch.multimesh = MultiMesh.new()
	_stump_batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_stump_batch.multimesh.mesh = mesh
	_stump_batch.multimesh.instance_count = int(Policy.settings().stump_limit)
	add_child(_stump_batch)
	reset()

func reset() -> void:
	_free_visuals.clear()
	for visual: Node3D in _visual_pool:
		visual.visible = false
		_free_visuals.append(visual)
	moving.clear()
	stumps.clear()
	_free_stumps.clear()
	if _stump_batch != null:
		for index in _stump_batch.multimesh.instance_count:
			_stump_batch.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			_free_stumps.append(index)

func on_event(event: Dictionary) -> void:
	var id := str(event.get("id", ""))
	match str(event.get("kind", "")):
		"prop_lifted": _begin(id, false, Vector3.ZERO)
		"prop_landed": _remove(id)
		"prop_destroyed":
			_remove(id)
			_remove_stump(id)
			if event.get("tree_fall", false):
				_begin(id, true, event.get("direction", Vector3.FORWARD))
		"stump_created":
			if not _free_stumps.is_empty():
				var slot: int = _free_stumps.pop_back()
				stumps[id] = slot
				var point: Vector3 = event.position
				point.y = Ground.height_at(point.x, point.z) + 0.325
				_stump_batch.multimesh.set_instance_transform(slot, Transform3D(Basis.from_scale(Vector3(event.radius, 1, event.radius)), point))
		"remnant_removed": _remove_stump(id)

func _begin(id: String, falling: bool, direction: Vector3) -> void:
	if moving.has(id):
		return
	if moving.size() >= LIMIT:
		for key: String in moving.keys():
			if moving[key].falling:
				_remove(key)
				break
	if _free_visuals.is_empty():
		return
	var available: Node3D = _free_visuals.pop_back()
	var visual: Node3D = arena.clone_prop(id, available)
	if visual == null:
		_free_visuals.append(available)
		return
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = Vector3.RIGHT
	moving[id] = {"node": visual, "falling": falling, "age": 0.0, "axis": Vector3.UP.cross(direction.normalized()), "base": visual.position}

func step(delta: float, flights: Dictionary) -> void:
	for id: String in moving.keys():
		var entry: Dictionary = moving[id]
		if entry.falling:
			entry.age += delta
			var progress := clampf(float(entry.age) / float(Policy.settings().tree_fall_seconds), 0.0, 1.0)
			entry.node.basis = Basis(entry.axis, progress * progress * PI * 0.49)
			if entry.age >= 9.0:
				_remove(id)
		elif flights.has(id):
			entry.node.position = flights[id].position
			entry.node.basis = Basis(Vector3.BACK, flights[id].roll)

func _remove(id: String) -> void:
	if moving.has(id):
		moving[id].node.visible = false
		_free_visuals.append(moving[id].node)
		moving.erase(id)

func _remove_stump(id: String) -> void:
	if stumps.has(id):
		var slot: int = stumps[id]
		_stump_batch.multimesh.set_instance_transform(slot, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		_free_stumps.append(slot)
		stumps.erase(id)

func explosion(point: Vector3, radius: float) -> void:
	for id: String in moving.keys():
		var entry: Dictionary = moving[id]
		if entry.falling and Vector2(entry.base.x - point.x, entry.base.z - point.z).length() <= radius + 6.0:
			_remove(id)

func set_warmup_visible(enabled: bool, point: Vector3) -> void:
	for node: Node3D in _warmup_nodes:
		node.free()
	_warmup_nodes.clear()
	if not enabled:
		if not stumps.values().has(0):
			_stump_batch.multimesh.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		return
	_stump_batch.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, point))
	var prepared: Dictionary = {}
	for prop: Dictionary in arena._prop_records.values():
		if not Policy.can_throw(prop):
			continue
		for part: Dictionary in prop.get("parts", []):
			var key := str(part.mesh)
			if prepared.has(key):
				continue
			prepared[key] = true
			var visual: Node3D = arena.clone_prop(str(prop.id))
			if visual != null:
				add_child(visual)
				visual.position = point
				_warmup_nodes.append(visual)

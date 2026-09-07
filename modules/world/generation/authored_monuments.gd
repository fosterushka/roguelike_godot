extends RefCounted
const Primitives = preload("res://presentation/world/world_primitive_catalog.gd")
const Quality = preload("res://presentation/world/world_quality_models.gd")
var ctx: RefCounted
var natural: RefCounted
var rng: RefCounted

func setup(context: RefCounted, nature: RefCounted) -> void:
	ctx = context
	natural = nature
	rng = context.random
	Primitives.prepare()

func _group(x: float, z: float, angle: float = 0, size: float = 1) -> Node3D:
	var group := Node3D.new()
	group.rotation_order = EULER_ORDER_XYZ
	group.position = Vector3(x, 0, z)
	group.rotation.y = angle
	group.scale = Vector3.ONE * size
	return group

func _shape(parent: Node3D, kind: String, dimensions: Array, material: String, position := Vector3.ZERO, rotation := Vector3.ZERO, size := Vector3.ONE) -> MeshInstance3D:
	var mesh := Primitives.create(kind, dimensions, material, position, rotation, size)
	parent.add_child(mesh)
	return mesh

func _box(parent: Node3D, dimensions: Array, material: String, position := Vector3.ZERO, rotation := Vector3.ZERO) -> MeshInstance3D:
	return _shape(parent, "box", dimensions, material, position, rotation)

func _quality(parent: Node3D, model: String) -> MeshInstance3D:
	var visual := Quality.create(model)
	parent.add_child(visual)
	return visual

func _finish(group: Node3D) -> void:
	preload("res://presentation/world/structure_batch.gd").compact(group)
	_no_shadows(group)
	ctx.groups.append(group)

func _no_shadows(node: Node3D) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		if child is Node3D:
			_no_shadows(child)

func _land(pool: String, x: float, z: float, ox: float, y: float, oz: float, w: float, h: float, d: float, angle: float = 0, tilt: float = 0) -> void:
	ctx.landmark_box(pool, x, z, ox, y, oz, w, h, d, angle, tilt)

func watchtower(x: float, z: float, angle: float = 0) -> void:
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_land("ironStructure", x, z, sx * 1.35, 2.55, sz * 1.35, 0.24, 5.1, 0.24, angle, sx * sz * 0.035)
	_land("woodStructure", x, z, 0, 4.92, 0, 3.7, 0.24, 3.7, angle)
	_land("metalStructure", x, z, 0, 6.12, 0, 4.35, 0.18, 4.35, angle, 0.025)
	for side in [-1, 1]:
		_land("ironStructure", x, z, side * 1.62, 5.58, 0, 0.12, 1.15, 3.3, angle)
		_land("ironStructure", x, z, 0, 5.58, side * 1.62, 3.3, 1.15, 0.12, angle)
	_land("ironStructure", x, z, 0, 7.4, 0, 0.16, 2.8, 0.16, angle)
	_land("redStructure", x, z, 0.48, 8.22, 0, 0.9, 0.52, 0.08, angle, -0.08)
	for index in 7:
		var a: float = float(index) / 7 * TAU + rng.between(-0.18, 0.18)
		var radius: float = rng.between(5.5, 9.5)
		natural.boulder(x + cos(a) * radius, z + sin(a) * radius, rng.between(0.45, 0.95), index % 3 == 0)
		if index % 2 == 0:
			natural.scrub(x + cos(a) * radius * 0.8, z + sin(a) * radius * 0.8, rng.between(0.7, 1.2), true)

	_military_details("watchtower", x, z, angle)

func pumpjack(x: float, z: float, angle: float = 0) -> void:
	_land("ironStructure", x, z, 0, 0.18, 0, 4.8, 0.36, 3.8, angle)
	for side in [-1, 1]:
		_land("ironStructure", x, z, side * 1.15, 1.55, 0, 0.25, 2.9, 0.25, angle, side * -0.22)
	_land("metalStructure", x, z, 0, 2.7, 0, 3.05, 0.28, 0.35, angle)
	var point: Dictionary = ctx.rotate_offset(x, z, -0.25, 0, angle)
	var pivot := _group(point.x, point.z, angle)
	pivot.position.y = 3.3
	_quality(pivot, "pumpjack_arm")
	_finish(pivot)
	ctx.ambient_animators.append({"type": "pumpjack", "object": pivot, "phase": rng.between(0, TAU), "speed": rng.between(0.55, 0.85), "amplitude": rng.between(0.11, 0.2)})
	var tank: Dictionary = ctx.rotate_offset(x, z, -4, 2.2, angle)
	ctx.append("tankInstances", Vector3(tank.x, 1.05, tank.z), Vector3(0, angle, PI / 2), Vector3(1.55, 2.6, 1.55))
	natural.fence(x + rng.between(-4, 4), z + rng.between(-4, 4), angle, 5)
	call("prop_cluster", x + rng.between(-4, 4), z + rng.between(-4, 4), 0.9)
	_industrial_details("pumpjack", x, z, angle)

func rock_spire(x: float, z: float) -> void:
	natural.boulder(x, z, rng.between(3.8, 5.2))
	for index in 16:
		var angle: float = float(index) / 16 * TAU + rng.between(-0.2, 0.2)
		var radius: float = rng.between(3.5, 13)
		natural.boulder(x + cos(angle) * radius, z + sin(angle) * radius, rng.between(0.65, 2.2), index % 4 == 0)
		if index % 2 == 0:
			natural.scrub(x + cos(angle) * radius * 1.12, z + sin(angle) * radius * 1.12, rng.between(0.65, 1.35), true)

func dead_grove(x: float, z: float) -> void:
	var count: int = rng.integer(9, 15)
	for index in count:
		var angle: float = float(index) / count * TAU + rng.between(-0.45, 0.45)
		var radius: float = rng.between(2.5, 14)
		var tx := x + cos(angle) * radius
		var tz := z + sin(angle) * radius
		natural.dead_tree(tx, tz, rng.between(0.75, 1.55))
		natural.scrub(tx + rng.between(-1.8, 1.8), tz + rng.between(-1.8, 1.8), rng.between(0.55, 1.05), true)
	for index in 5:
		natural.boulder(x + rng.between(-9, 9), z + rng.between(-9, 9), rng.between(0.55, 1.1))

func scrap_yard(x: float, z: float, angle: float = 0) -> void:
	var first: Dictionary = ctx.rotate_offset(x, z, 0, -7, angle)
	var opposite: Dictionary = ctx.rotate_offset(x, z, 0, 7, angle)
	natural.fence(first.x, first.z, angle, 8)
	natural.fence(opposite.x, opposite.z, angle + PI, 8)
	for index in 14:
		var point: Dictionary = ctx.rotate_offset(x, z, rng.between(-7, 7), rng.between(-5, 5), angle)
		var pool := "redStructure" if index % 3 == 0 else ("metalStructure" if index % 2 == 0 else "ironStructure")
		ctx.structure(pool, point.x, rng.between(0.08, 0.32), point.z, rng.between(0.4, 1.4), rng.between(0.1, 0.38), rng.between(0.35, 1.25), rng.between(0, TAU), rng.between(-0.28, 0.28))
	for index in 3:
		call("prop_cluster", x + rng.between(-5, 5), z + rng.between(-5, 5), rng.between(0.75, 1.05))
	call("wreck", x + rng.between(-5, 5), z + rng.between(-5, 5), rng.between(0.8, 1.15))

func water_tower(x: float, z: float, angle: float = 0) -> void:
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_land("ironStructure", x, z, sx * 1.15, 2.5, sz * 1.15, 0.18, 5, 0.18, angle, sx * sz * 0.06)
	ctx.append("tankInstances", Vector3(x, 5.45, z), Vector3(0, angle, 0), Vector3(3.35, 2.4, 3.35))
	_land("metalStructure", x, z, 0, 6.72, 0, 3.6, 0.15, 3.6, angle, 0.02)
	_land("redStructure", x, z, 0, 5.55, 1.72, 1.45, 0.72, 0.08, angle, -0.07)
	for index in 6:
		natural.scrub(x + rng.between(-7, 7), z + rng.between(-7, 7), rng.between(0.7, 1.2), index % 2 == 0)

	_military_details("water_tower", x, z, angle)

func recycling_factory(x: float, z: float, angle: float = 0) -> void:
	_land("ironStructure", x, z, 0, 1.5, 0, 10, 3, 7, angle)
	_land("metalStructure", x, z, 0, 3.25, 0, 10.8, 0.35, 7.8, angle, 0.03)
	_land("redStructure", x, z, 0, 3.5, 3.72, 4.2, 1.1, 0.12, angle, -0.05)
	for side in [-1, 1]:
		var point: Dictionary = ctx.rotate_offset(x, z, side * 3.6, -2.4, angle)
		var stack := Primitives.create("cylinder", [0.42, 0.62, 5.4, 10], "woodDark", Vector3(point.x, 4.5, point.z))
		ctx.groups.append(stack)
	var conveyor: Dictionary = ctx.rotate_offset(x, z, 7, -0.6, angle)
	ctx.structure("metalStructure", conveyor.x, 1.15, conveyor.z, 6, 0.4, 1.5, angle, -0.18)
	var scrap: Dictionary = ctx.rotate_offset(x, z, -6.5, 1.5, angle)
	call("prop_cluster", scrap.x, scrap.z, 1.2)
	natural.fence(x, z - 7, angle, 7)
	_industrial_details("factory", x, z, angle)

func cargo_crane(x: float, z: float, angle: float = 0) -> void:
	for side in [-1, 1]:
		_land("ironStructure", x, z, side * 2.7, 3.5, 0, 0.5, 7, 0.5, angle, side * 0.04)
	_land("metalStructure", x, z, 0, 6.8, 0, 7.2, 0.5, 0.7, angle)
	_land("ironStructure", x, z, 2.5, 6.35, 0, 0.16, 1.2, 0.16, angle)
	_land("redStructure", x, z, 2.5, 5.55, 0, 1.4, 1.1, 1.4, angle)
	for index in 7:
		var point: Dictionary = ctx.rotate_offset(x, z, rng.between(-7, 7), rng.between(-5, 5), angle)
		ctx.structure("metalStructure" if index % 2 else "redStructure", point.x, 0.65, point.z, rng.between(1.5, 3), 1.3, rng.between(1.8, 3.4), angle + rng.between(-0.15, 0.15))
	_industrial_details("crane", x, z, angle)

func refinery(x: float, z: float, angle: float = 0) -> void:
	for offset in [[-3.2, -1.8], [0.2, 1.5], [3.4, -1]]:
		var point: Dictionary = ctx.rotate_offset(x, z, offset[0], offset[1], angle)
		ctx.append("tankInstances", Vector3(point.x, rng.between(1.8, 2.6), point.z), Vector3(0, angle, 0), Vector3(rng.between(2.2, 3.1), rng.between(3.4, 5), rng.between(2.2, 3.1)))
	_land("ironStructure", x, z, 0, 4.2, -4.2, 0.6, 8.4, 0.6, angle)
	_land("metalStructure", x, z, 0, 6.8, -4.2, 4.6, 0.3, 0.35, angle)
	natural.fence(x, z + 7, angle, 8)
	_industrial_details("refinery", x, z, angle)

func satellite_array(x: float, z: float, angle: float = 0) -> void:
	for index in 3:
		var point: Dictionary = ctx.rotate_offset(x, z, (index - 1) * 5, rng.between(-2, 2), angle)
		var group := _group(point.x, point.z, angle + index * 0.35)
		var dish := _quality(group, "satellite_dish")
		dish.rotation.z = rng.between(-0.55, 0.55)
		ctx.groups.append(group)
	_industrial_details("satellite", x, z, angle)

func _industrial_details(kind: String, x: float, z: float, angle: float) -> void:
	var group := _group(x, z, angle)
	group.name = "MilitarySiteDetails"
	group.set_meta("military_detail", true)
	var quality_model := "detail_" + kind
	if Quality.has_model(quality_model):
		_quality(group, quality_model)
		_finish(group)
		return
	var palette = preload("res://presentation/world/military_environment_palette.gd")
	var iron: Material = palette.material_for("iron")
	var metal: Material = palette.material_for("metal")
	var sand: Material = palette.material_for("sand")
	var accent: Material = palette.material_for("signal")
	match kind:
		"factory":
			_detail_box(group, Vector3(0, 1.35, 3.53), Vector3(3, 2.5, 0.12), iron)
			for index in 7:
				_detail_box(group, Vector3(0, 0.35 + index * 0.32, 3.61), Vector3(2.85, 0.055, 0.05), metal)
			for side in [-1, 1]:
				_detail_box(group, Vector3(side * 1.62, 1.35, 3.65), Vector3(0.16, 2.65, 0.16), accent)
				_detail_box(group, Vector3(side * 3.65, 2.15, 3.55), Vector3(1.3, 0.6, 0.14), sand)
			for index in 4:
				_detail_box(group, Vector3(-3.6 + index * 2.4, 3.55, 0), Vector3(0.16, 0.2, 6.8), metal)
			_detail_box(group, Vector3(2.3, 3.83, -0.5), Vector3(2.1, 0.65, 1.35), iron)
			for index in 5:
				_detail_box(group, Vector3(1.55 + index * 0.37, 4.18, -0.5), Vector3(0.08, 0.06, 1.2), metal)
		"crane":
			for side in [-1, 1]:
				_detail_box(group, Vector3(side * 2.7, 0.13, 0), Vector3(0.7, 0.26, 5.4), iron)
				_detail_box(group, Vector3(side * 2.7, 1.1, 0), Vector3(1.25, 0.2, 1.2), accent)
				_detail_box(group, Vector3(0, 7.35, side * 0.38), Vector3(7.2, 0.08, 0.08), metal)
				for index in 5:
					_detail_box(group, Vector3(-3.4 + index * 1.7, 7.1, side * 0.38), Vector3(0.07, 0.5, 0.07), metal)
			_detail_box(group, Vector3(-2.7, 5.85, 0), Vector3(1.4, 1.3, 1.4), sand)
			_detail_box(group, Vector3(-2.7, 6.1, 0.72), Vector3(1.1, 0.52, 0.04), iron)
			for rung in 17:
				_detail_box(group, Vector3(-2.7, 0.3 + rung * 0.32, 0.85), Vector3(0.75, 0.06, 0.10), metal)
		"refinery":
			for side in [-1, 1]:
				_detail_box(group, Vector3(0, 0.55, side * 3.1), Vector3(9.0, 0.23, 0.23), metal)
				for index in 4:
					_detail_box(group, Vector3(-3.8 + index * 2.5, 0.3, side * 3.1), Vector3(0.35, 0.6, 0.65), iron)
				_detail_box(group, Vector3(side * 4.4, 1.1, 0), Vector3(0.25, 0.25, 6.4), metal)
				_detail_box(group, Vector3(side * 4.4, 0.8, -3.1), Vector3(0.3, 0.8, 0.3), accent)
			_detail_box(group, Vector3(0, 0.75, 4.8), Vector3(2.2, 1.5, 0.65), sand)
			for index in 3:
				_detail_box(group, Vector3(-0.65 + index * 0.65, 1.05, 5.14), Vector3(0.38, 0.35, 0.05), iron)
		"pumpjack":
			_detail_box(group, Vector3(-1.5, 0.8, 0), Vector3(1.8, 1.15, 1.2), sand)
			for index in 6:
				_detail_box(group, Vector3(-2.18 + index * 0.25, 1.4, 0), Vector3(0.08, 0.06, 1.0), iron)
			_detail_box(group, Vector3(3.3, 1.1, 0), Vector3(0.14, 2.2, 0.14), metal)
			_detail_box(group, Vector3(3.3, 0.16, 0), Vector3(1.0, 0.32, 1.0), iron)
		"satellite":
			_detail_box(group, Vector3(0, 0.85, 4), Vector3(2.8, 1.7, 1.5), sand)
			for side in [-1, 1]:
				_detail_box(group, Vector3(side * 0.68, 1.15, 4.77), Vector3(0.92, 0.6, 0.05), iron)
				for index in 3:
					_detail_box(group, Vector3(side * 0.68, 0.5 + index * 0.11, 4.8), Vector3(0.84, 0.04, 0.06), metal)
			_detail_box(group, Vector3(1.2, 2.2, 4), Vector3(0.07, 1.8, 0.07), iron)
	_finish(group)

func _military_details(kind: String, x: float, z: float, angle: float) -> void:
	var group := _group(x, z, angle)
	group.name = "MilitarySiteDetails"
	group.set_meta("military_detail", true)
	var quality_model := "detail_" + kind
	if Quality.has_model(quality_model):
		_quality(group, quality_model)
		_finish(group)
		return
	var height := 4.9 if kind == "watchtower" else 5.8
	var depth := 1.65 if kind == "watchtower" else 1.9
	var palette = preload("res://presentation/world/military_environment_palette.gd")
	for rung in 14:
		_detail_box(group, Vector3(0, 0.32 + rung * height / 14, depth), Vector3(0.82, 0.065, 0.10), palette.material_for("iron"))
	for side in [-1, 1]:
		_detail_box(group, Vector3(side * 0.45, height / 2, depth), Vector3(0.08, height, 0.12), palette.material_for("metal"))
		var brace := _detail_box(group, Vector3(side * 1.4, 2.4, 0), Vector3(0.12, 4.4, 0.12), palette.material_for("iron"))
		brace.rotation.z = side * 0.5
	_finish(group)

func _detail_box(group: Node3D, point: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position = point
	group.add_child(visual)
	return visual

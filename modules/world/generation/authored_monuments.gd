extends RefCounted
const Primitives = preload("res://presentation/world/world_primitive_catalog.gd")
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

func _finish(group: Node3D) -> void:
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

func pumpjack(x: float, z: float, angle: float = 0) -> void:
	_land("ironStructure", x, z, 0, 0.18, 0, 4.8, 0.36, 3.8, angle)
	for side in [-1, 1]:
		_land("ironStructure", x, z, side * 1.15, 1.55, 0, 0.25, 2.9, 0.25, angle, side * -0.22)
	_land("metalStructure", x, z, 0, 2.7, 0, 3.05, 0.28, 0.35, angle)
	var point: Dictionary = ctx.rotate_offset(x, z, -0.25, 0, angle)
	var pivot := _group(point.x, point.z, angle)
	pivot.position.y = 3.3
	_box(pivot, [4.8, 0.26, 0.32], "iron", Vector3(1.4, 0, 0))
	_box(pivot, [0.72, 1.5, 0.5], "enemyRed", Vector3(3.58, -0.62, 0))
	_finish(pivot)
	ctx.ambient_animators.append({"type": "pumpjack", "object": pivot, "phase": rng.between(0, TAU), "speed": rng.between(0.55, 0.85), "amplitude": rng.between(0.11, 0.2)})
	var tank: Dictionary = ctx.rotate_offset(x, z, -4, 2.2, angle)
	ctx.append("tankInstances", Vector3(tank.x, 1.05, tank.z), Vector3(0, angle, PI / 2), Vector3(1.55, 2.6, 1.55))
	natural.fence(x + rng.between(-4, 4), z + rng.between(-4, 4), angle, 5)
	call("prop_cluster", x + rng.between(-4, 4), z + rng.between(-4, 4), 0.9)

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

func cargo_crane(x: float, z: float, angle: float = 0) -> void:
	for side in [-1, 1]:
		_land("ironStructure", x, z, side * 2.7, 3.5, 0, 0.5, 7, 0.5, angle, side * 0.04)
	_land("metalStructure", x, z, 0, 6.8, 0, 7.2, 0.5, 0.7, angle)
	_land("ironStructure", x, z, 2.5, 6.35, 0, 0.16, 1.2, 0.16, angle)
	_land("redStructure", x, z, 2.5, 5.55, 0, 1.4, 1.1, 1.4, angle)
	for index in 7:
		var point: Dictionary = ctx.rotate_offset(x, z, rng.between(-7, 7), rng.between(-5, 5), angle)
		ctx.structure("metalStructure" if index % 2 else "redStructure", point.x, 0.65, point.z, rng.between(1.5, 3), 1.3, rng.between(1.8, 3.4), angle + rng.between(-0.15, 0.15))

func refinery(x: float, z: float, angle: float = 0) -> void:
	for offset in [[-3.2, -1.8], [0.2, 1.5], [3.4, -1]]:
		var point: Dictionary = ctx.rotate_offset(x, z, offset[0], offset[1], angle)
		ctx.append("tankInstances", Vector3(point.x, rng.between(1.8, 2.6), point.z), Vector3(0, angle, 0), Vector3(rng.between(2.2, 3.1), rng.between(3.4, 5), rng.between(2.2, 3.1)))
	_land("ironStructure", x, z, 0, 4.2, -4.2, 0.6, 8.4, 0.6, angle)
	_land("metalStructure", x, z, 0, 6.8, -4.2, 4.6, 0.3, 0.35, angle)
	natural.fence(x, z + 7, angle, 8)

func satellite_array(x: float, z: float, angle: float = 0) -> void:
	for index in 3:
		var point: Dictionary = ctx.rotate_offset(x, z, (index - 1) * 5, rng.between(-2, 2), angle)
		var group := _group(point.x, point.z, angle + index * 0.35)
		_shape(group, "cylinder", [0.18, 0.3, 3.4, 8], "iron", Vector3(0, 1.7, 0))
		_shape(group, "cylinder", [1.65, 1.65, 0.22, 18], "metal", Vector3(0, 3.6, 0), Vector3(PI / 2, 0, rng.between(-0.55, 0.55)))
		_shape(group, "sphere", [0.2], "gold", Vector3(0, 3.8, 0.6))
		ctx.groups.append(group)

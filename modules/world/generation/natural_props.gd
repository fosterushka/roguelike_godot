extends RefCounted
var context: RefCounted
var random: RefCounted

func setup(value: RefCounted) -> void:
	context = value
	random = value.random

func tree(x: float, z: float, scale: float = 1, sparse: bool = false, destructible: bool = true) -> void:
	var rotation := Vector3(0, random.between(0, TAU), random.between(-0.06, 0.06))
	var trunk_scale := Vector3(scale, scale * random.between(0.88, 1.18), scale)
	var parts: Array = []
	parts.append(context.append("treeTrunks", Vector3(x, 1.14 * trunk_scale.y, z), rotation, trunk_scale))
	var crown_pool := "treeCrowns" if random.next() < 0.5 else "treeCrownsAlt"
	var crown_scale := Vector3(scale * random.between(0.82, 1.12), scale * random.between(0.82, 1.18), scale * random.between(0.82, 1.12))
	parts.append(context.append(crown_pool, Vector3(x, 2.65 * scale, z), rotation, crown_scale))
	var branch_rotation := Vector3(random.between(-0.35, 0.35), rotation.y, random.between(0.72, 1.05))
	parts.append(context.append("treeBranches", Vector3(x + 0.28 * scale, 2.1 * scale, z), branch_rotation, Vector3.ONE * scale))
	if not sparse and random.next() < 0.42:
		var side: float = random.between(-0.55, 0.55) * scale
		parts.append(context.append(crown_pool, Vector3(x + side, 3.35 * scale, z - side * 0.4), rotation, crown_scale * 0.62))
	if destructible:
		context.register_prop("tree", x, z, scale, {"parts": parts}, {"salvage": 1 if random.next() < 0.16 else 0})

func boulder(x: float, z: float, scale: float = 1, light: bool = false) -> void:
	var pool := "stoneInstances" if light else "rockInstances"
	var parts: Array = []
	parts.append(context.append(pool, Vector3(x, scale * 0.42, z), Vector3(random.between(-0.22, 0.22), random.between(0, TAU), random.between(-0.22, 0.22)), Vector3(scale * random.between(0.75, 1.3), scale * random.between(0.55, 1.08), scale * random.between(0.8, 1.35))))
	if scale > 0.9 and random.next() < 0.42:
		var secondary_pool := "rockInstances" if light else "stoneInstances"
		parts.append(context.append(secondary_pool, Vector3(x + random.between(-0.45, 0.45) * scale, scale * 0.2, z + random.between(-0.45, 0.45) * scale), Vector3(random.between(-0.3, 0.3), random.between(0, TAU), random.between(-0.3, 0.3)), Vector3(scale * 0.42, scale * 0.3, scale * 0.55)))
	context.register_prop("boulder", x, z, scale, {"parts": parts})

func scrub(x: float, z: float, scale: float = 1, dead: bool = false) -> void:
	var pool := "deadBrushInstances" if dead else "scrubInstances"
	var part: Dictionary = context.append(pool, Vector3(x, scale * 0.32, z), Vector3(0, random.between(0, TAU), random.between(-0.12, 0.12)), Vector3(scale * random.between(0.75, 1.2), scale * random.between(0.7, 1.25), scale * random.between(0.75, 1.2)))
	context.register_prop("scrub", x, z, scale, {"parts": [part]})

func dead_tree(x: float, z: float, scale: float = 1) -> void:
	var rotation: float = random.between(0, TAU)
	var parts: Array = []
	parts.append(context.append("treeTrunks", Vector3(x, 1.55 * scale, z), Vector3(0, rotation, random.between(-0.08, 0.08)), Vector3(scale * 0.82, scale * 1.42, scale * 0.82)))
	parts.append(context.landmark_box("woodStructure", x, z, 0.38 * scale, 2.42 * scale, 0, 1.2 * scale, 0.13 * scale, 0.14 * scale, rotation, 0.38))
	if random.next() < 0.68:
		parts.append(context.landmark_box("woodStructure", x, z, -0.25 * scale, 2.9 * scale, 0, 0.92 * scale, 0.11 * scale, 0.12 * scale, rotation, -0.46))
	context.register_prop("deadTree", x, z, scale, {"parts": parts})

func fence(x: float, z: float, rotation: float = 0, count: int = 5) -> void:
	var right_x := cos(rotation)
	var right_z := -sin(rotation)
	for index in count + 1:
		var point_x := x + right_x * (index - count * 0.5) * 1.75
		var point_z := z + right_z * (index - count * 0.5) * 1.75
		var post: Dictionary = context.append("fencePosts", Vector3(point_x, 0.57, point_z), Vector3(0, rotation, 0), Vector3.ONE)
		if index < count:
			var middle_x := point_x + right_x * 0.875
			var middle_z := point_z + right_z * 0.875
			var lower: Dictionary = context.append("fenceRails", Vector3(middle_x, 0.45, middle_z), Vector3(0, rotation, 0), Vector3.ONE)
			var upper: Dictionary = context.append("fenceRails", Vector3(middle_x, 0.88, middle_z), Vector3(0, rotation, 0), Vector3.ONE)
			context.register_prop("fence", middle_x, middle_z, 1, {"parts": [post, lower, upper]})
		else:
			context.register_prop("fence", point_x, point_z, 0.55, {"parts": [post]})

func ground_cover(x: float, z: float, radius: float, count: int, flowers: bool = false) -> void:
	for index in count:
		var angle: float = random.between(0, TAU)
		var distance: float = sqrt(random.next()) * radius
		var point_x := x + cos(angle) * distance
		var point_z := z + sin(angle) * distance
		if not context.open_dressing_point(point_x, point_z, 5.8):
			continue
		var scale: float = random.between(0.65, 1.35)
		context.append("grassTufts", Vector3(point_x, 0.23 * scale, point_z), Vector3(0, random.between(0, TAU), random.between(-0.12, 0.12)), Vector3(scale, scale * random.between(0.85, 1.25), scale))
		if flowers and index % 4 == 0:
			context.append("flowerInstances", Vector3(point_x + random.between(-0.28, 0.28), 0.18, point_z + random.between(-0.28, 0.28)), Vector3.ZERO, Vector3(random.between(0.8, 1.3), random.between(0.8, 1.3), random.between(0.8, 1.3)))

extends RefCounted
var context: RefCounted
var natural: RefCounted
var authored: RefCounted
var random: RefCounted

func setup(value: RefCounted, natural_factory: RefCounted, authored_factory: RefCounted) -> void:
	context = value
	random = value.random
	natural = natural_factory
	authored = authored_factory

func forest(site: Dictionary) -> int:
	var rendered := 0
	for index in int(site.treeCount):
		var angle: float = random.between(0, TAU)
		var distance: float = sqrt(random.next()) * site.radius
		var x: float = site.x + cos(angle) * distance
		var z: float = site.z + sin(angle) * distance
		if not context.open_dressing_point(x, z, 11, 72) or context.near_village(x, z, 20):
			continue
		if random.next() < 0.09:
			natural.dead_tree(x, z, random.between(0.8, 1.45))
		else:
			natural.tree(x, z, random.between(0.78, 1.42), random.next() < 0.28)
		rendered += 1
		if index % 5 == 0:
			natural.scrub(x + random.between(-2, 2), z + random.between(-2, 2), random.between(0.7, 1.3))
	natural.ground_cover(site.x, site.z, site.radius, floori(site.treeCount * 1.4 + 0.5), true)
	var grazer_angle: float = random.between(0, TAU)
	var grazer_distance: float = random.between(site.radius * 0.15, site.radius * 0.48)
	authored.grazer(site.x + cos(grazer_angle) * grazer_distance, site.z + sin(grazer_angle) * grazer_distance)
	return rendered

func ruined_house(x: float, z: float, rotation: float, scale: float) -> void:
	var parts: Array = [context.structure("scarStructure", x, 0.06, z, 4.4 * scale, 0.12, 4 * scale, rotation)]
	parts.append(context.landmark_box("ruinStructure", x, z, -1.55 * scale, 1.05 * scale, 0, 0.34 * scale, 2.1 * scale, 3.7 * scale, rotation, random.between(-0.08, 0.08)))
	parts.append(context.landmark_box("ruinStructure", x, z, 0.45 * scale, 0.72 * scale, -1.68 * scale, 2.5 * scale, 1.44 * scale, 0.3 * scale, rotation, random.between(-0.12, 0.12)))
	if random.next() < 0.7:
		parts.append(context.landmark_box("metalStructure", x, z, 0.5 * scale, 1.35 * scale, 0.3 * scale, 2.9 * scale, 0.14 * scale, 2.2 * scale, rotation, random.between(-0.32, 0.32)))
	context.register_prop("ruin", x, z, scale, {"parts": parts}, {"salvage": 2})
	for index in 5:
		var point: Dictionary = context.rotate_offset(x, z, random.between(-2.7, 2.7) * scale, random.between(-2.5, 2.5) * scale, rotation)
		natural.boulder(point.x, point.z, random.between(0.28, 0.72) * scale, index % 3 == 0)

func ruined_village(site: Dictionary) -> int:
	var rendered := 0
	for index in int(site.buildingCount):
		var angle: float = site.rotation + float(index) / site.buildingCount * TAU + random.between(-0.24, 0.24)
		var distance: float = random.between(site.radius * 0.28, site.radius * 0.82)
		var x: float = site.x + cos(angle) * distance
		var z: float = site.z + sin(angle) * distance
		if not context.open_dressing_point(x, z, 12, 76) or context.near_village(x, z, 18):
			continue
		ruined_house(x, z, random.between(0, TAU), random.between(0.85, 1.3))
		rendered += 1
	authored.wreck(site.x + random.between(-8, 8), site.z + random.between(-8, 8), random.between(1.05, 1.45))
	natural.fence(site.x + random.between(-12, 12), site.z + random.between(-12, 12), site.rotation, random.integer(6, 10))
	authored.critter(site.x + random.between(-10, 10), site.z + random.between(-10, 10))
	return rendered

func trench(site: Dictionary) -> int:
	var count := maxi(1, floori(site.length / 9))
	var rendered := 0
	for index in count:
		var along := (index - (count - 1) * 0.5) * 9
		var zigzag := sin(index * PI * 0.5) * 3.4
		var point: Dictionary = context.rotate_offset(site.x, site.z, zigzag, along, site.rotation)
		if not context.open_dressing_point(point.x, point.z, 14, 82) or context.near_village(point.x, point.z, 19):
			continue
		context.append("trenches", Vector3(point.x, 0.018, point.z), Vector3(0, site.rotation, 0), Vector3(5.2, 1, 10.2))
		char_traces(point, 2, maxf(1, 5.2 * 0.62))
		rendered += 1
		for side in [-1.0, 1.0]:
			var berm: Dictionary = context.rotate_offset(point.x, point.z, side * 3.55, 0, site.rotation)
			context.structure("earthStructure", berm.x, 0.3, berm.z, 1.8, random.between(0.42, 0.68), 10.35, site.rotation, side * random.between(-0.08, 0.08))
		if index % 2 == 0:
			var brace: Dictionary = context.rotate_offset(point.x, point.z, 0, random.between(-2.7, 2.7), site.rotation)
			context.structure("woodStructure", brace.x, 0.45, brace.z, 5.7, 0.16, 0.2, site.rotation)
		if index % 3 == 0:
			natural.boulder(point.x + random.between(-4.8, 4.8), point.z + random.between(-4.8, 4.8), random.between(0.35, 0.7))
	return rendered

func crater(site: Dictionary) -> bool:
	if not context.open_dressing_point(site.x, site.z, 7, 58) or context.near_village(site.x, site.z, 13):
		return false
	var scale_x: float = site.radius * random.between(0.82, 1.12)
	var scale_z: float = site.radius * random.between(0.82, 1.12)
	context.append("bowls", Vector3(site.x, 0.01, site.z), Vector3(0, site.rotation, 0), Vector3(scale_x, 1.1, scale_z))
	context.append("rims", Vector3(site.x, 0.025, site.z), Vector3(0, site.rotation, 0), Vector3(scale_x, maxf(0.75, site.radius * 0.42), scale_z))
	context.append("decals", Vector3(site.x, 0.032, site.z), Vector3(0, site.rotation, 0), Vector3(scale_x * 1.15, 1, scale_z * 1.15))
	char_traces(site, 3, site.radius)
	var count := maxi(5, floori(site.radius * 1.35 + 0.5))
	for index in count:
		var angle: float = float(index) / count * TAU + random.between(-0.24, 0.24)
		var radius: float = site.radius * random.between(0.84, 1.08)
		var x: float = site.x + cos(angle) * radius
		var z: float = site.z + sin(angle) * radius
		context.structure("earthStructure", x, random.between(0.12, 0.28), z, random.between(0.7, 1.5), random.between(0.22, 0.48), random.between(0.65, 1.35), angle, random.between(-0.22, 0.22))
	if site.radius > 5 and random.next() < 0.65:
		natural.dead_tree(site.x + random.between(-site.radius, site.radius), site.z + random.between(-site.radius, site.radius), random.between(0.55, 0.9))
	return true

func char_traces(site: Dictionary, count: int, scale: float) -> void:
	for index in count:
		var key: float = site.x * 0.71 + site.z * 1.37 + index * 11.9
		var angle := stable_unit(key, 1) * TAU
		var distance := scale * (0.28 + stable_unit(key, 2) * 0.57)
		context.append("char", Vector3(site.x + cos(angle) * distance, 0.055, site.z + sin(angle) * distance), Vector3(0, angle + stable_unit(key, 3) * 1.2, 0), Vector3(scale * (0.42 + stable_unit(key, 4) * 0.34), 1, 0.7 + stable_unit(key, 5) * 0.65))

static func stable_unit(value: float, salt: int) -> float:
	var number := sin(value * 12.9898 + salt * 78.233) * 43758.5453
	return number - floorf(number)

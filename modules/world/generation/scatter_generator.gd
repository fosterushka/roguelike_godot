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

func biomes() -> void:
	for index in 220:
		var center: Dictionary = context.find_open_point(62, 1208, 12, 28)
		if center.is_empty():
			continue
		context.biome_centers.append(center)
		var type := index % 5
		var count: int = random.integer(11, 20)
		for item in count:
			var angle: float = random.between(0, TAU)
			var distance: float = sqrt(random.next()) * random.between(8, 18)
			var x: float = center.x + cos(angle) * distance
			var z: float = center.z + sin(angle) * distance
			if not context.open_dressing_point(x, z, 8) or context.near_village(x, z, 16):
				continue
			match type:
				0: natural.tree(x, z, random.between(0.65, 1.25))
				1: natural.boulder(x, z, random.between(0.5, 1.55), item % 4 == 0)
				2: natural.scrub(x, z, random.between(0.7, 1.45), item % 3 == 0)
				3:
					if item % 3 == 0: natural.dead_tree(x, z, random.between(0.7, 1.15))
					else: natural.scrub(x, z, random.between(0.65, 1.25), true)
				4:
					if item % 4 == 0: natural.boulder(x, z, random.between(0.55, 1.15))
					else: natural.tree(x, z, random.between(0.55, 1.05), true)
		natural.ground_cover(center.x, center.z, 19, random.integer(13, 22), type == 0 or type == 4)

func roadsides() -> void:
	for road: Dictionary in context.layout.roads:
		for segment in road.points.size() - 1:
			var start: Dictionary = road.points[segment]
			var end: Dictionary = road.points[segment + 1]
			var dx: float = end.x - start.x
			var dz: float = end.z - start.z
			var length := sqrt(dx * dx + dz * dz)
			var nx := -dz / length
			var nz := dx / length
			var heading := atan2(dx, dz)
			var travelled: float = random.between(24, 46)
			while travelled < length - 14:
				var progress := travelled / length
				var side := -1.0 if random.next() < 0.5 else 1.0
				var offset: float = random.between(10, 22) * side
				var x: float = start.x + dx * progress + nx * offset
				var z: float = start.z + dz * progress + nz * offset
				if context.open_dressing_point(x, z, 7.5) and not context.near_village(x, z, 15):
					context.roadside_anchors.append({"x": x, "z": z})
					var pick: float = random.next()
					if pick < 0.24: natural.tree(x, z, random.between(0.65, 1.1), true)
					elif pick < 0.5: natural.boulder(x, z, random.between(0.5, 1.15))
					else: natural.scrub(x, z, random.between(0.75, 1.35), pick > 0.82)
					natural.ground_cover(x, z, 5.5, random.integer(4, 8), false)
					if context.roadside_anchors.size() % 7 == 0:
						authored.utility_pole(x, z, random.between(0.78, 1.08), heading)
				travelled += random.between(34, 58)

func start_area() -> void:
	for index in 90:
		var point: Dictionary = context.find_open_point(23, 210, 9, 16)
		if point.is_empty():
			continue
		if index % 8 == 0: natural.boulder(point.x, point.z, random.between(0.55, 1.1))
		else: natural.scrub(point.x, point.z, random.between(0.6, 1.2), index % 3 == 0)
		natural.ground_cover(point.x, point.z, 3.2, random.integer(2, 5), index % 11 == 0)
	for index in 36:
		var angle: float = float(index) / 36 * TAU + random.between(-0.06, 0.06)
		var radius: float = random.between(24, 46)
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		if not context.open_dressing_point(x, z, 8.5):
			continue
		if index % 9 == 0 and radius > 34: natural.tree(x, z, random.between(0.55, 0.78), true)
		elif index % 6 == 0: natural.boulder(x, z, random.between(0.5, 0.9))
		else: natural.scrub(x, z, random.between(0.55, 1), index % 2 == 0)
		natural.ground_cover(x, z, 3.2, random.integer(3, 6), index % 9 == 0)

func ambient_tufts() -> void:
	var budget := floori(1450 + ((0.82 - 0.5) / 0.35) * 950 + 0.5)
	for index in budget:
		var point: Dictionary = context.find_open_point(16, 1630, 6, 14)
		if point.is_empty():
			continue
		var scale: float = random.between(0.55, 1.2)
		context.append("grassTufts", Vector3(point.x, 0.23 * scale, point.z), Vector3(0, random.between(0, TAU), random.between(-0.12, 0.12)), Vector3(scale, scale * random.between(0.85, 1.3), scale))

func village_details() -> void:
	for village: Dictionary in context.villages:
		authored.well(village.x + random.between(-3, 3), village.z + random.between(-3, 3))
		authored.market_stall(village.x + random.between(-7, 7), village.z + random.between(-7, 7), random.between(0, TAU))
		authored.prop_cluster(village.x + random.between(-8, 8), village.z + random.between(-8, 8), random.between(0.8, 1.15))
		natural.fence(village.x + random.between(-9, 9), village.z + random.between(-9, 9), random.between(0, TAU), random.integer(3, 6))
		for index in 2:
			authored.critter(village.x + random.between(-10, 10), village.z + random.between(-10, 10))
	for index in context.layout.villages.size():
		if index % 3 != 0:
			continue
		var village: Dictionary = context.layout.villages[index]
		authored.windmill(village.x + random.between(18, 28), village.z + random.between(18, 28), random.between(0, TAU))

func monuments() -> void:
	for site: Dictionary in context.layout.monuments:
		var starts: Dictionary = {}
		for pool: String in context.POOLS:
			starts[pool] = context.instances[pool].size()
		var group_start: int = context.groups.size()
		context.aggregate_destructible = true
		match str(site.type):
			"watchtower": authored.watchtower(site.x, site.z, site.rotation)
			"pumpjack": authored.pumpjack(site.x, site.z, site.rotation)
			"rock-spire": authored.rock_spire(site.x, site.z)
			"dead-grove": authored.dead_grove(site.x, site.z)
			"scrap-yard": authored.scrap_yard(site.x, site.z, site.rotation)
			"water-tower": authored.water_tower(site.x, site.z, site.rotation)
			"recycling-factory": authored.recycling_factory(site.x, site.z, site.rotation)
			"cargo-crane": authored.cargo_crane(site.x, site.z, site.rotation)
			"refinery": authored.refinery(site.x, site.z, site.rotation)
			_: authored.satellite_array(site.x, site.z, site.rotation)
		context.aggregate_destructible = false
		natural.ground_cover(site.x, site.z, 18, random.integer(16, 28), site.type == "dead-grove")
		var parts: Array = []
		for pool: String in context.POOLS:
			for index in range(starts[pool], context.instances[pool].size()):
				parts.append({"pool": pool, "instance": index, "transform": context.instances[pool][index]})
		var factory: bool = site.type == "recycling-factory"
		context.register_prop("monument", site.x, site.z, 1, {"parts": parts, "groups": context.groups.slice(group_start)}, {"id": "prop:" + site.id, "radius": 10 if factory else 7, "hp": 260 if factory else 150, "salvage": 18 if factory else 10})
		context.landmarks.append({"id": site.id, "x": site.x, "z": site.z, "type": site.type})

func outer_dressing() -> void:
	for index in 180:
		var point: Dictionary = context.find_open_point(1224, 1630, 9, 16)
		if point.is_empty():
			continue
		if random.next() < 0.55: natural.boulder(point.x, point.z, random.between(0.65, 1.6), index % 5 == 0)
		else: natural.dead_tree(point.x, point.z, random.between(0.75, 1.35))
		if index % 4 == 0:
			authored.prop_cluster(point.x + random.between(-3, 3), point.z + random.between(-3, 3), random.between(0.7, 1.05))

func pebbles() -> void:
	var total := 0
	var budget := floori(900 + ((0.82 - 0.5) / 0.35) * 800 + 0.5)
	for index in budget:
		var point: Dictionary = context.point_in_disc(16, 1636)
		if not context.open_dressing_point(point.x, point.z, 4.6, 16):
			continue
		var scale: float = random.between(0.1, 0.28)
		var pool := "stoneInstances" if index % 4 == 0 else "rockInstances"
		var part: Dictionary = context.append(pool, Vector3(point.x, scale * 0.22, point.z), Vector3(random.between(-0.18, 0.18), random.between(0, TAU), random.between(-0.18, 0.18)), Vector3(scale * random.between(0.75, 1.45), scale * random.between(0.22, 0.5), scale * random.between(0.7, 1.5)))
		total += int(part.instance >= 0)
	context.terrain_details.surfacePebbles = total

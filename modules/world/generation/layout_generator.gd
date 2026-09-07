extends RefCounted

const Random = preload("res://modules/world/activities/source_random.gd")
const ROAD_WIDTH_SCALE := 1.22
const RADIUS := 1248.0
const MONUMENT_TYPES := ["watchtower", "pumpjack", "rock-spire", "dead-grove", "scrap-yard", "water-tower", "recycling-factory", "cargo-crane", "refinery", "satellite-array"]
const ADJECTIVES := ["Ashen", "Broken", "Copper", "Dustbound", "Hollow", "Iron", "Rust", "Shattered"]
const NOUNS := ["Badlands", "Basin", "Crossing", "Expanse", "March", "Reach", "Wastes", "Wilds"]

static func distance(left: Dictionary, right: Dictionary) -> float:
	var x: float = left.x - right.x
	var z: float = left.z - right.z
	return sqrt(x * x + z * z)

static func spaced_point(random: RefCounted, existing: Array, minimum: float, maximum: float, clearance: float, accept: Callable = Callable()) -> Dictionary:
	for attempt in 360:
		var angle: float = random.between(0, TAU)
		var radius: float = sqrt(random.between(minimum * minimum, maximum * maximum))
		var point := {"x": cos(angle) * radius, "z": sin(angle) * radius}
		if accept.is_valid() and not accept.call(point):
			continue
		var clear := true
		for other: Dictionary in existing:
			if distance(point, other) < clearance:
				clear = false
				break
		if clear:
			return point
	return {}

static func distance_to_road(point: Dictionary, roads: Array) -> float:
	var closest := INF
	for road: Dictionary in roads:
		for index in road.points.size() - 1:
			var start: Dictionary = road.points[index]
			var end: Dictionary = road.points[index + 1]
			var dx: float = end.x - start.x
			var dz: float = end.z - start.z
			var length_squared := dx * dx + dz * dz
			var progress := clampf(((point.x - start.x) * dx + (point.z - start.z) * dz) / length_squared, 0, 1)
			closest = minf(closest, distance(point, {"x": start.x + dx * progress, "z": start.z + dz * progress}))
	return closest

static func generate(seed_value: int) -> Dictionary:
	var normalized := seed_value & 0xffffffff
	var random := Random.new()
	random.state = (normalized ^ 0xa53c9e17) & 0xffffffff
	var phase := random.between(0, TAU)
	var road_count := random.integer(5, 8)
	var road_limit := RADIUS - 54
	var roads: Array = []
	for road_index in road_count:
		var angle := phase + road_index * PI / road_count + random.between(-0.18, 0.18)
		var tx := cos(angle)
		var tz := sin(angle)
		var nx := -tz
		var nz := tx
		var lane := floori(float(road_index - 1) / 2)
		var offset_sign := -1.0 if road_index % 2 == 0 else 1.0
		var offset := 0.0 if road_index == 0 else offset_sign * (235 + lane * 92 + random.between(-18, 18))
		var center_x := nx * offset
		var center_z := nz * offset
		var chord_reach := sqrt(maxf(1, road_limit * road_limit - offset * offset))
		var local_reach := chord_reach * random.between(0.9, 0.98)
		var bend_strength := random.between(55, 105) * (-1.0 if random.next() < 0.5 else 1.0) if road_index == 0 else random.between(38, 92) * offset_sign
		var secondary_bend := random.between(-24, 24)
		var points: Array = []
		for point_index in range(-4, 5):
			var progress := float(point_index) / 4
			var along := progress * local_reach
			var bend := (sin(progress * PI) if road_index == 0 else absf(sin(progress * PI))) * bend_strength + sin(progress * PI * 2) * secondary_bend
			var x := center_x + tx * along + nx * bend
			var z := center_z + tz * along + nz * bend
			var from_center := sqrt(x * x + z * z)
			if from_center > road_limit:
				x = x / from_center * road_limit
				z = z / from_center * road_limit
			points.append({"x": x, "z": z})
		roads.append({"id": "road-%02d" % road_index, "points": points, "width": random.between(7.2, 10.2) * ROAD_WIDTH_SCALE})
	var villages: Array = []
	var village_target := random.integer(28, 36)
	for index in village_target:
		var point := spaced_point(random, villages, 105, RADIUS - 125, 82)
		if not point.is_empty():
			point.merge({"id": "village-%02d" % villages.size(), "count": random.integer(3, 6)})
			villages.append(point)
	var monuments: Array = []
	var occupied := villages.duplicate()
	var monument_target := random.integer(38, 48)
	for index in monument_target:
		var point := spaced_point(random, occupied, 92, RADIUS - 90, 62)
		if point.is_empty():
			continue
		var type: String = "recycling-factory" if index == 0 else MONUMENT_TYPES[(index + random.integer(0, MONUMENT_TYPES.size() - 1)) % MONUMENT_TYPES.size()]
		point.merge({"id": "site-%02d" % monuments.size(), "type": type, "rotation": random.between(0, TAU)})
		monuments.append(point)
		occupied.append(point)
	var forests: Array = []
	var forest_target := random.integer(10, 14)
	for index in forest_target:
		var radius := random.between(48, 78)
		var point := spaced_point(random, occupied, 150, RADIUS - radius - 18, 118, func(candidate: Dictionary) -> bool: return distance_to_road(candidate, roads) > radius + 12)
		if point.is_empty():
			continue
		point.merge({"id": "forest-%02d" % forests.size(), "radius": radius, "treeCount": random.integer(42, 68)})
		forests.append(point)
		occupied.append(point)
	var ruins: Array = []
	var ruin_target := random.integer(8, 12)
	for index in ruin_target:
		var radius := random.between(28, 43)
		var point := spaced_point(random, occupied, 130, RADIUS - radius - 18, 98, func(candidate: Dictionary) -> bool: return distance_to_road(candidate, roads) > radius + 14)
		if point.is_empty():
			continue
		point.merge({"id": "ruins-%02d" % ruins.size(), "radius": radius, "buildingCount": random.integer(7, 11), "rotation": random.between(0, TAU)})
		ruins.append(point)
		occupied.append(point)
	var trenches: Array = []
	var trench_target := random.integer(10, 14)
	for index in trench_target:
		var length := random.between(84, 148)
		var point := spaced_point(random, occupied, length * 0.5 + 86, RADIUS - length * 0.5 - 24, 96, func(candidate: Dictionary) -> bool: return distance_to_road(candidate, roads) > length * 0.5 + 18)
		if point.is_empty():
			continue
		point.merge({"id": "trench-%02d" % trenches.size(), "length": length, "rotation": random.between(0, TAU)})
		trenches.append(point)
		occupied.append(point)
	var formations: Array = []
	var formation_target := random.integer(24, 32)
	for index in formation_target:
		var radius := random.between(8, 15)
		var point := spaced_point(random, occupied, 105, RADIUS - radius - 32, radius + 40, func(candidate: Dictionary) -> bool: return distance_to_road(candidate, roads) > radius + 15)
		if point.is_empty():
			continue
		point.merge({"id": "rock-formation-%02d" % formations.size(), "radius": radius, "rotation": random.between(0, TAU)})
		formations.append(point)
		occupied.append(point)
	var craters: Array = []
	var crater_target := random.integer(112, 152)
	for index in crater_target:
		var radius := random.between(2.4, 7.2)
		var point := spaced_point(random, occupied + craters, 60, RADIUS - radius - 10, 14, func(candidate: Dictionary) -> bool: return distance_to_road(candidate, roads) > radius + 7)
		if point.is_empty():
			continue
		point.merge({"id": "crater-%03d" % craters.size(), "radius": radius, "rotation": random.between(0, TAU)})
		craters.append(point)
	return {"seed": normalized, "name": ADJECTIVES[random.integer(0, 7)] + " " + NOUNS[random.integer(0, 7)], "roads": roads, "villages": villages, "monuments": monuments, "forests": forests, "ruinedVillages": ruins, "trenches": trenches, "rockFormations": formations, "craters": craters}

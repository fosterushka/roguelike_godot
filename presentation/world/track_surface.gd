extends RefCounted

enum Kind { SAND, SOIL, ROAD, WET_MUD, SCORCH }
const PALETTE := [Color("b29a65"), Color("89704e"), Color("aa9270"), Color("9c8060"), Color("a19a88")]
const OPACITY := [0.34, 0.38, 0.29, 0.46, 0.42]
const CELL := 32.0
static var _roads: Dictionary = {}
static var mud_zones: Array = []

static func configure_roads(roads: Array) -> void:
	_roads.clear()
	for road: Dictionary in roads:
		var points: Array = road.get("points", [])
		var radius := float(road.get("width", 9.0)) * 0.5
		for index in range(1, points.size()):
			var first := Vector2(points[index - 1].x, points[index - 1].z)
			var last := Vector2(points[index].x, points[index].z)
			var low := Vector2i(floori((minf(first.x, last.x) - radius) / CELL), floori((minf(first.y, last.y) - radius) / CELL))
			var high := Vector2i(floori((maxf(first.x, last.x) + radius) / CELL), floori((maxf(first.y, last.y) + radius) / CELL))
			var segment := {"first": first, "last": last, "radius_squared": radius * radius}
			for row in range(low.y, high.y + 1):
				for column in range(low.x, high.x + 1):
					var cell := Vector2i(column, row)
					if not _roads.has(cell):
						_roads[cell] = []
					_roads[cell].append(segment)

static func kind_at(point: Vector3, wet: bool, scorch_entries: Array = []) -> int:
	for entry: Dictionary in scorch_entries:
		if float(entry.get("life", 0.0)) <= 0.0:
			continue
		var local: Vector3 = entry.parts[0].global_transform.affine_inverse() * point
		if absf(local.x) < 0.46 and absf(local.y) < 0.46:
			return Kind.SCORCH
	for zone: Dictionary in mud_zones:
		var position: Vector3 = zone.position
		if Vector2(point.x - position.x, point.z - position.z).length_squared() < pow(float(zone.get("radius", 5.0)), 2.0):
			return Kind.WET_MUD
	var p := Vector2(point.x, point.z)
	var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for road: Dictionary in _roads.get(key, []):
		var along: Vector2 = road.last - road.first
		var fraction := clampf((p - road.first).dot(along) / maxf(0.00001, along.length_squared()), 0, 1)
		if p.distance_squared_to(road.first + along * fraction) <= road.radius_squared:
			return Kind.ROAD
	var soil := soil_amount(p)
	return Kind.WET_MUD if wet and soil > 0.3 else Kind.SOIL if soil > 0.45 else Kind.SAND

static func color_for(kind: int) -> Color:
	var color: Color = PALETTE[clampi(kind, 0, PALETTE.size() - 1)].srgb_to_linear()
	color.a = OPACITY[clampi(kind, 0, OPACITY.size() - 1)]
	return color

static func soil_amount(point: Vector2) -> float:
	return smoothstep(0.5, 0.78, _noise(point * 0.028) + _noise(point * 0.11 + Vector2(17, 4)) * 0.28)

static func _noise(point: Vector2) -> float:
	var cell := point.floor()
	var fraction := point - cell
	fraction = fraction * fraction * (Vector2.ONE * 3.0 - fraction * 2.0)
	return lerpf(lerpf(_hash(cell), _hash(cell + Vector2.RIGHT), fraction.x), lerpf(_hash(cell + Vector2.DOWN), _hash(cell + Vector2.ONE), fraction.x), fraction.y)

static func _hash(point: Vector2) -> float:
	point *= Vector2(123.34, 456.21)
	point = Vector2(fposmod(point.x, 1), fposmod(point.y, 1))
	point += Vector2.ONE * point.dot(point + Vector2.ONE * 45.32)
	return fposmod(point.x * point.y, 1)

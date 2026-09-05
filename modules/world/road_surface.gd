extends RefCounted

const SPEED_MULTIPLIER := 1.5
const CELL := 32.0
static var _cells: Dictionary = {}

static func configure(roads: Array) -> void:
	_cells.clear()
	for road: Variant in roads:
		var points: Array = road.get("points", []) if road is Dictionary else road
		var radius := maxf(0.0, float(road.get("width", 9.0))) * 0.5 if road is Dictionary else 4.5
		for index in range(1, points.size()):
			var first := Vector2(points[index - 1].x, points[index - 1].z)
			var last := Vector2(points[index].x, points[index].z)
			var low := Vector2i(floori((minf(first.x, last.x) - radius) / CELL), floori((minf(first.y, last.y) - radius) / CELL))
			var high := Vector2i(floori((maxf(first.x, last.x) + radius) / CELL), floori((maxf(first.y, last.y) + radius) / CELL))
			var segment := {"first": first, "last": last, "radius_squared": radius * radius}
			for row in range(low.y, high.y + 1):
				for column in range(low.x, high.x + 1):
					var cell := Vector2i(column, row)
					if not _cells.has(cell):
						_cells[cell] = []
					_cells[cell].append(segment)

static func contains(point: Vector3) -> bool:
	var p := Vector2(point.x, point.z)
	var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for road: Dictionary in _cells.get(key, []):
		var along: Vector2 = road.last - road.first
		var fraction := clampf((p - road.first).dot(along) / maxf(0.00001, along.length_squared()), 0, 1)
		if p.distance_squared_to(road.first + along * fraction) <= road.radius_squared:
			return true
	return false

static func speed_multiplier_at(point: Vector3) -> float:
	return SPEED_MULTIPLIER if contains(point) else 1.0

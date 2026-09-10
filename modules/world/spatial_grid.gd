extends RefCounted

const CELL_SIZE := 32.0
const MAX_CACHED_REGIONS := 128
var buckets: Dictionary = {}
var maximum_radius := 0.0
var _regions: Dictionary = {}

func remove(record: Dictionary) -> void:
	_regions.clear()
	var point: Vector3 = record.position
	var key := Vector2i(floori(point.x / CELL_SIZE), floori(point.z / CELL_SIZE))
	if buckets.has(key):
		buckets[key].erase(record)
		if buckets[key].is_empty():
			buckets.erase(key)

func insert(record: Dictionary) -> void:
	_regions.clear()
	var point: Vector3 = record.position
	var key := Vector2i(floori(point.x / CELL_SIZE), floori(point.z / CELL_SIZE))
	if not buckets.has(key):
		buckets[key] = []
	buckets[key].append(record)
	maximum_radius = maxf(maximum_radius, float(record.radius))

func nearby(point: Vector3, radius: float) -> Array:
	var reach := radius + maximum_radius
	var first := Vector2i(floori((point.x - reach) / CELL_SIZE), floori((point.z - reach) / CELL_SIZE))
	var last := Vector2i(floori((point.x + reach) / CELL_SIZE), floori((point.z + reach) / CELL_SIZE))
	var region := Rect2i(first, last - first + Vector2i.ONE)
	if not _regions.has(region):
		if _regions.size() >= MAX_CACHED_REGIONS:
			_regions.clear()
		var result: Array = []
		for x in range(first.x, last.x + 1):
			for z in range(first.y, last.y + 1):
				result.append_array(buckets.get(Vector2i(x, z), []))
		_regions[region] = result
	# Callers append dynamic obstacles; never expose the cached array itself.
	return _regions[region].duplicate()

static func distance_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func segment_hit(start: Vector3, end: Vector3, center: Vector3, radius: float) -> float:
	var from_center := Vector2(start.x - center.x, start.z - center.z)
	var direction := Vector2(end.x - start.x, end.z - start.z)
	var a := direction.length_squared()
	var c := from_center.length_squared() - radius * radius
	if c <= 0.0:
		return 0.0
	if a < 0.000001:
		return -1.0
	var b := 2.0 * from_center.dot(direction)
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var fraction := (-b - sqrt(discriminant)) / (2.0 * a)
	return fraction if fraction >= 0.0 and fraction <= 1.0 else -1.0

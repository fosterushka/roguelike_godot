extends RefCounted

const CELL_SIZE := 32.0
var buckets: Dictionary = {}
var maximum_radius := 0.0

func remove(record: Dictionary) -> void:
	var point: Vector3 = record.position
	var key := Vector2i(floori(point.x / CELL_SIZE), floori(point.z / CELL_SIZE))
	if buckets.has(key):
		buckets[key].erase(record)
		if buckets[key].is_empty():
			buckets.erase(key)

func insert(record: Dictionary) -> void:
	var point: Vector3 = record.position
	var key := Vector2i(floori(point.x / CELL_SIZE), floori(point.z / CELL_SIZE))
	if not buckets.has(key):
		buckets[key] = []
	buckets[key].append(record)
	maximum_radius = maxf(maximum_radius, float(record.radius))

func nearby(point: Vector3, radius: float) -> Array:
	var result: Array = []
	var reach := radius + maximum_radius
	for x in range(floori((point.x - reach) / CELL_SIZE), floori((point.x + reach) / CELL_SIZE) + 1):
		for z in range(floori((point.z - reach) / CELL_SIZE), floori((point.z + reach) / CELL_SIZE) + 1):
			result.append_array(buckets.get(Vector2i(x, z), []))
	return result

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

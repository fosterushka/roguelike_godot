extends RefCounted

const HALF_SIZE := 1730.4
const CELLS := 512
const STEP := HALF_SIZE * 2.0 / CELLS
static var heights := PackedFloat32Array()

static func configure(layout: Dictionary, roads: Array = []) -> void:
	heights.resize((CELLS + 1) * (CELLS + 1))
	for row in CELLS + 1:
		var z := row * STEP - HALF_SIZE
		for column in CELLS + 1:
			var x := column * STEP - HALF_SIZE
			var hummocks := sin(x * 0.23 + z * 0.09) * sin(z * 0.19 - x * 0.035) * 0.48
			var swells := sin(x * 0.063) * sin(z * 0.078) * 0.26
			heights[row * (CELLS + 1) + column] = hummocks + swells
	_flatten(Vector2.ZERO, 12.0)
	for prop: Dictionary in layout.get("props", []):
		var point: Variant = prop.get("position", Vector3.ZERO)
		_flatten(Vector2(float(point.x), float(point.z)), maxf(1.5, float(prop.get("radius", 1.0)) + 1.0))
	for rock: Dictionary in layout.get("rockObstacles", []):
		_flatten(Vector2(rock.x, rock.z), float(rock.get("radius", 2.0)) + 1.0)
	for road: Variant in roads if not roads.is_empty() else layout.get("roads", []):
		var points: Array = road.get("points", []) if road is Dictionary else road
		var radius := float(road.get("width", 9.0)) * 0.65 if road is Dictionary else 6.0
		for index in range(1, points.size()):
			var first := Vector2(points[index - 1].x, points[index - 1].z)
			var last := Vector2(points[index].x, points[index].z)
			var samples := maxi(1, ceili(first.distance_to(last) / (STEP * 0.75)))
			for sample in samples + 1:
				_flatten(first.lerp(last, sample / float(samples)), radius)

static func _flatten(point: Vector2, radius: float) -> void:
	radius += STEP * sqrt(2.0)
	var reach := radius + STEP * 1.8
	var first := Vector2i(floori((point.x - reach + HALF_SIZE) / STEP), floori((point.y - reach + HALF_SIZE) / STEP))
	var last := Vector2i(ceili((point.x + reach + HALF_SIZE) / STEP), ceili((point.y + reach + HALF_SIZE) / STEP))
	for row in range(maxi(0, first.y), mini(CELLS, last.y) + 1):
		for column in range(maxi(0, first.x), mini(CELLS, last.x) + 1):
			var distance := Vector2(column * STEP - HALF_SIZE, row * STEP - HALF_SIZE).distance_to(point)
			var weight := smoothstep(radius, reach, distance)
			heights[row * (CELLS + 1) + column] *= weight

static func height_at(x: float, z: float) -> float:
	if heights.is_empty():
		return 0.0
	var coordinate := Vector2(clampf((x + HALF_SIZE) / STEP, 0, CELLS - 0.00001), clampf((z + HALF_SIZE) / STEP, 0, CELLS - 0.00001))
	var column := clampi(floori(coordinate.x), 0, CELLS - 1)
	var row := clampi(floori(coordinate.y), 0, CELLS - 1)
	var fraction := coordinate - Vector2(column, row)
	var a := heights[row * (CELLS + 1) + column]
	var b := heights[row * (CELLS + 1) + column + 1]
	var c := heights[(row + 1) * (CELLS + 1) + column]
	var d := heights[(row + 1) * (CELLS + 1) + column + 1]
	if fraction.x + fraction.y <= 1.0:
		return a + (b - a) * fraction.x + (c - a) * fraction.y
	return d + (c - d) * (1.0 - fraction.x) + (b - d) * (1.0 - fraction.y)

static func normal_at(x: float, z: float) -> Vector3:
	return Vector3(height_at(x - 0.2, z) - height_at(x + 0.2, z), 0.4, height_at(x, z - 0.2) - height_at(x, z + 0.2)).normalized()

static func create_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize((CELLS + 1) * (CELLS + 1))
	normals.resize(vertices.size())
	uvs.resize(vertices.size())
	indices.resize(CELLS * CELLS * 6)
	for row in CELLS + 1:
		for column in CELLS + 1:
			var index := row * (CELLS + 1) + column
			var x := column * STEP - HALF_SIZE
			var z := row * STEP - HALF_SIZE
			vertices[index] = Vector3(x, heights[index], z)
			normals[index] = normal_at(x, z)
			uvs[index] = Vector2(column, row) / CELLS
			if row < CELLS and column < CELLS:
				var offset := (row * CELLS + column) * 6
				var triangle := [index, index + 1, index + CELLS + 1, index + 1, index + CELLS + 2, index + CELLS + 1]
				for vertex in 6:
					indices[offset + vertex] = triangle[vertex]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

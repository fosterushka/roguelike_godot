extends RefCounted

const HALF_SIZE := 80.0
const STEP := 0.5
const CELLS := int(HALF_SIZE * 2.0 / STEP)
const LANES := [-24.0, -8.0, 8.0, 24.0]
const NAMES := ["1  КОЧКА / ПОДЛЁТ", "2  ЛЕВЫЕ / ПРАВЫЕ КОЛЁСА", "3  БОКОВОЙ СКЛОН", "4  ТРАМПЛИН"]
const SPAWN_Z := -28.0
const LANE_WIDTH := 5.5
const BUMP_HEIGHT := 0.9
const BUMP_WIDTH := 2.2
const RAMP_HEIGHT := 2.0
const RAMP_START := -6.0
const RAMP_END := 3.0
const LANDING_END := 7.0

static func _profile(x: float, z: float) -> float:
	var lane := 0
	for index in LANES.size():
		if absf(x - LANES[index]) < absf(x - LANES[lane]):
			lane = index
	var local_x: float = x - LANES[lane]
	var edge := 1.0 - smoothstep(LANE_WIDTH, LANE_WIDTH + 2.0, absf(local_x))
	match lane:
		0: return edge * BUMP_HEIGHT * exp(-pow(z / BUMP_WIDTH, 2))
		1:
			var center := -3.0 if local_x < 0 else 3.0
			return edge * BUMP_HEIGHT * 0.6 * exp(-pow((z - center) / BUMP_WIDTH, 2))
		2: return edge * local_x * 0.22 * smoothstep(-12, -4, z) * (1.0 - smoothstep(12, 20, z))
		3:
			return edge * RAMP_HEIGHT * clampf((z - RAMP_START) / (RAMP_END - RAMP_START), 0, 1) * (1.0 - smoothstep(RAMP_END, LANDING_END, z))
	return 0.0

# Sample the exact same triangles used by the rendered mesh.
static func height_at(x: float, z: float) -> float:
	var cell := Vector2(floorf(x / STEP), floorf(z / STEP)) * STEP
	var fraction := Vector2(x - cell.x, z - cell.y) / STEP
	var a := _profile(cell.x, cell.y)
	var b := _profile(cell.x + STEP, cell.y)
	var c := _profile(cell.x, cell.y + STEP)
	var d := _profile(cell.x + STEP, cell.y + STEP)
	if fraction.x + fraction.y <= 1.0:
		return a + (b - a) * fraction.x + (c - a) * fraction.y
	return d + (c - d) * (1.0 - fraction.x) + (b - d) * (1.0 - fraction.y)

static func create_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for row in CELLS + 1:
		for column in CELLS + 1:
			var x := column * STEP - HALF_SIZE
			var z := row * STEP - HALF_SIZE
			vertices.append(Vector3(x, _profile(x, z), z))
			normals.append(Vector3(_profile(x - STEP, z) - _profile(x + STEP, z), STEP * 2, _profile(x, z - STEP) - _profile(x, z + STEP)).normalized())
			var color := Color("526153")
			for lane: float in LANES:
				if absf(x - lane) < LANE_WIDTH:
					color = Color("9b947b") if posmod(row, 8) < 4 else Color("89846f")
				elif absf(absf(x - lane) - LANE_WIDTH) < STEP:
					color = Color("e7c678")
			colors.append(color)
			if row < CELLS and column < CELLS:
				var index := row * (CELLS + 1) + column
				indices.append_array(PackedInt32Array([index, index + 1, index + CELLS + 1, index + 1, index + CELLS + 2, index + CELLS + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

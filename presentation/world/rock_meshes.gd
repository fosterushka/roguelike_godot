extends RefCounted

static var _meshes: Dictionary = {}
static var _material: StandardMaterial3D
const SIDES := 13
const LEVELS := [-0.045, 0.09, 0.29, 0.51, 0.73, 0.9]
const PROFILES := [
	[0.86, 0.99, 0.94, 0.9, 0.8, 0.53],
	[0.82, 0.98, 0.91, 0.85, 0.5, 0.31],
	[0.9, 0.98, 0.91, 0.82, 0.8, 0.55],
	[0.8, 0.94, 0.97, 0.91, 0.72, 0.48],
	[0.87, 0.99, 0.92, 0.78, 0.5, 0.27],
	[0.84, 0.97, 0.88, 0.84, 0.78, 0.43],
]

static func mesh_for(pool: String) -> ArrayMesh:
	if not pool.begins_with("rockMass") and pool not in ["rockInstances", "stoneInstances"]:
		return null
	if not _meshes.has(pool):
		var variant := int(pool.trim_prefix("rockMass")) if pool.begins_with("rockMass") else 7 if pool == "stoneInstances" else 6
		_meshes[pool] = _build(variant, not pool.begins_with("rockMass"))
	return _meshes[pool]

static func _build(variant: int, small: bool) -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = 8039 + variant * 1357
	var phase := random.randf_range(0, TAU)
	var rings: Array[PackedVector3Array] = []
	var edges := PackedFloat32Array()
	for side in SIDES:
		edges.append(random.randf_range(0.73, 1.0))
	for level in LEVELS.size():
		var ring := PackedVector3Array()
		var drift := Vector2(sin(phase + level * 0.7), cos(phase * 0.6 + level * 0.4)) * float(level) * 0.022
		for side in SIDES:
			var angle := TAU * side / SIDES + phase + random.randf_range(-0.045, 0.045)
			var radius: float = PROFILES[variant % PROFILES.size()][level] * edges[side] * random.randf_range(0.9, 1.0)
			var y: float = LEVELS[level]
			if level > 0:
				y += sin(angle * 2.0 + phase) * 0.045 + random.randf_range(-0.035, 0.035)
			ring.append(Vector3(cos(angle) * radius + drift.x, y, sin(angle) * radius + drift.y))
		rings.append(ring)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var palette := [Color("777767"), Color("7c7b70"), Color("827c6c"), Color("71786b"), Color("898273"), Color("7c8073")]
	var base: Color = palette[variant % palette.size()]
	for level in rings.size() - 1:
		for side in SIDES:
			var next_side := (side + 1) % SIDES
			var a: Vector3 = rings[level][side]
			var b: Vector3 = rings[level][next_side]
			var c: Vector3 = rings[level + 1][side]
			var d: Vector3 = rings[level + 1][next_side]
			if (level + side + variant) % 2 == 0:
				_triangle(a, b, c, small, base, random, vertices, normals, colors)
				_triangle(b, d, c, small, base, random, vertices, normals, colors)
			else:
				_triangle(a, b, d, small, base, random, vertices, normals, colors)
				_triangle(a, d, c, small, base, random, vertices, normals, colors)
	var peak := Vector3(sin(phase) * 0.12, 1.0, cos(phase) * 0.1)
	var bottom := Vector3(0, -0.045, 0)
	for side in SIDES:
		_triangle(rings[-1][side], rings[-1][(side + 1) % SIDES], peak, small, base, random, vertices, normals, colors)
		_triangle(rings[0][(side + 1) % SIDES], rings[0][side], bottom, small, base, random, vertices, normals, colors)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.disable_receive_shadows = true
		_material.roughness = 1.0
		_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.surface_set_material(0, _material)
	return mesh

static func _triangle(a: Vector3, b: Vector3, c: Vector3, small: bool, base: Color, random: RandomNumberGenerator, vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray) -> void:
	var center := (a + b + c) / 3.0
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot(center - Vector3(0, 0.43, 0)) < 0:
		normal = -normal
	else:
		var swap := b
		b = c
		c = swap
	var shade := base.lerp(Color("919777"), clampf(normal.y, 0.0, 1.0) * 0.3)
	shade = shade.darkened(random.randf_range(0.0, 0.09))
	for point: Vector3 in [a, b, c]:
		vertices.append(Vector3(point.x * 0.68, (point.y - 0.46) * 0.98, point.z * 0.68) if small else point)
		normals.append(Vector3(normal.x / 0.68, normal.y / 0.98, normal.z / 0.68).normalized() if small else normal)
		colors.append(shade)

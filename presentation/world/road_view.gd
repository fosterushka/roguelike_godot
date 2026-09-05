extends Node3D
const ROAD_SHADER = preload("res://presentation/world/road.gdshader")
const ROAD_TEXTURE = preload("res://assets/textures/world/dirt-road-v2.png")
var roads: Array = []

func setup(definitions: Array) -> void:
	roads = definitions
	for child in get_children():
		child.free()
	var ribbon_material := _material(false)
	var junction_material := _material(true)
	var junctions: Dictionary = {}
	for road: Dictionary in roads:
		var mesh := MeshInstance3D.new()
		mesh.name = str(road.id)
		mesh.mesh = ribbon_mesh(road.points, float(road.width))
		mesh.material_override = ribbon_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		for point: Dictionary in road.points:
			var key := "%.3f:%.3f" % [point.x, point.z]
			if not junctions.has(key) or junctions[key].width < road.width:
				junctions[key] = {"point": point, "width": road.width}
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = junction_mesh()
	instances.instance_count = junctions.size()
	var index := 0
	for junction: Dictionary in junctions.values():
		var radius: float = junction.width * 0.64
		instances.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * radius), Vector3(junction.point.x, 0.014, junction.point.z)))
		index += 1
	var junction_view := MultiMeshInstance3D.new()
	junction_view.name = "OriginalRoadJunctions"
	junction_view.multimesh = instances
	junction_view.material_override = junction_material
	junction_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(junction_view)

static func _material(junction: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ROAD_SHADER
	material.render_priority = -127
	material.set_shader_parameter("road_texture", ROAD_TEXTURE)
	material.set_shader_parameter("junction", junction)
	material.set_shader_parameter("road_color", Color("c7a17d") if junction else Color("d0b08a"))
	return material

static func ribbon_data(points: Array, width: float) -> Dictionary:
	var positions := PackedVector3Array()
	var uvs := PackedVector2Array()
	var sides := PackedVector2Array()
	var indices := PackedInt32Array()
	var travelled := 0.0
	for index in points.size():
		var point: Dictionary = points[index]
		var previous: Dictionary = points[maxi(0, index - 1)]
		var next: Dictionary = points[mini(points.size() - 1, index + 1)]
		var incoming_x: float = point.x - previous.x
		var incoming_z: float = point.z - previous.z
		var outgoing_x: float = next.x - point.x
		var outgoing_z: float = next.z - point.z
		var incoming_length := sqrt(incoming_x * incoming_x + incoming_z * incoming_z)
		var outgoing_length := sqrt(outgoing_x * outgoing_x + outgoing_z * outgoing_z)
		if index > 0:
			travelled += incoming_length
		var direction_x := incoming_x / maxf(0.001, incoming_length) + outgoing_x / maxf(0.001, outgoing_length)
		var direction_z := incoming_z / maxf(0.001, incoming_length) + outgoing_z / maxf(0.001, outgoing_length)
		var direction_length := maxf(0.001, sqrt(direction_x * direction_x + direction_z * direction_z))
		var normal_x := -direction_z / direction_length
		var normal_z := direction_x / direction_length
		for side in [-1.0, 1.0]:
			positions.append(Vector3(point.x + normal_x * width * 0.5 * side, 0.008, point.z + normal_z * width * 0.5 * side))
			uvs.append(Vector2((side + 1) * 0.5 * width / 7, travelled / 7))
			sides.append(Vector2(side, 0))
		if index < points.size() - 1:
			var vertex := index * 2
			indices.append_array([vertex, vertex + 2, vertex + 1, vertex + 1, vertex + 2, vertex + 3])
	return {"positions": positions, "uvs": uvs, "sides": sides, "indices": indices}

static func ribbon_mesh(points: Array, width: float) -> ArrayMesh:
	return _mesh(ribbon_data(points, width))

static func junction_mesh() -> ArrayMesh:
	var data := {"positions": PackedVector3Array([Vector3.ZERO]), "uvs": PackedVector2Array([Vector2.ONE * 0.5]), "sides": PackedVector2Array([Vector2.ZERO]), "indices": PackedInt32Array()}
	for index in 29:
		var angle := float(index) / 28 * TAU
		data.positions.append(Vector3(cos(angle), 0, -sin(angle)))
		data.uvs.append(Vector2((cos(angle) + 1) * 0.5, (sin(angle) + 1) * 0.5))
		data.sides.append(Vector2.ZERO)
		if index > 0:
			data.indices.append_array([0, index + 1, index])
	return _mesh(data)

static func _mesh(data: Dictionary) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.positions
	var normals := PackedVector3Array()
	normals.resize(data.positions.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = data.uvs
	arrays[Mesh.ARRAY_TEX_UV2] = data.sides
	arrays[Mesh.ARRAY_INDEX] = data.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

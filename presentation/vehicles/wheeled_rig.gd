extends RefCounted

const Suspension = preload("res://modules/caravan/wheel_suspension.gd")
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}

static func build_player() -> Node3D:
	return preload("res://presentation/vehicles/military_pickup.gd").build()

static func build_trailer(type: String = "cargo") -> Node3D:
	var adapter := preload("res://presentation/vehicles/military_wagon.gd")
	var rig: Node3D = adapter.build(type)
	var wheels: Array[Node3D] = adapter.wheel_nodes(rig)
	var springs: Array[Node3D] = adapter.spring_nodes(rig)
	rig.set_meta("wheels", wheels)
	rig.set_meta("springs", springs)
	var drawbar_candidates := rig.find_children("SteeringDrawbar*", "Node3D", true, false)
	var drawbar := drawbar_candidates[0] as Node3D if not drawbar_candidates.is_empty() else null
	if drawbar == null:
		drawbar = Node3D.new()
		drawbar.name = "SteeringDrawbar"
		drawbar.position = Vector3(0, 0.95, 1.55)
		rig.add_child(drawbar)
	rig.set_meta("drawbar", drawbar)
	return rig

static func animate(rig: Node3D, suspension: Dictionary, steer: float, speed: float, wheel_angle: float, trailer: bool = false) -> void:
	# Counter-rotate wheel hubs so load transfer tilts the chassis, not tire contacts.
	var wheel_basis := Basis(Vector3.RIGHT, -float(suspension.get("pitch", 0.0)))
	var angles := Suspension.steering_angles(steer, speed, trailer)
	var wheels: Array = rig.get_meta("wheels", [])
	var springs: Array = rig.get_meta("springs", [])
	for index in wheels.size():
		var pivot: Node3D = wheels[index]
		pivot.position = wheel_basis * (Vector3(pivot.get_meta("anchor")) + Vector3.UP * float(suspension.wheel_offsets[index]))
		pivot.basis = wheel_basis * Basis(Vector3.UP, angles[index] if index < 2 else 0.0)
		pivot.get_child(0).rotation.x = wheel_angle
		var spring: Node3D = springs[index]
		spring.position = spring.get_meta("anchor") + Vector3.UP * float(suspension.wheel_offsets[index]) * 0.5
		spring.scale.y = maxf(0.25, 1.0 - float(suspension.wheel_offsets[index]) / 0.66)
	if trailer:
		rig.get_meta("drawbar").rotation.y = clampf(steer * 0.55, -0.75, 0.75)

static func _box(parent: Node3D, label: String, dimensions: Vector3, at: Vector3, color: String, rotation_value := Vector3.ZERO, glow := false) -> MeshInstance3D:
	var key := "box:" + str(dimensions)
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = dimensions
		_meshes[key] = mesh
	return _part(parent, label, _meshes[key], at, color, rotation_value, glow)

static func _cylinder(parent: Node3D, label: String, radius: float, height: float, at: Vector3, color: String, rotation_value := Vector3.ZERO) -> MeshInstance3D:
	var key := "cylinder:%s:%s" % [radius, height]
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 16
		_meshes[key] = mesh
	return _part(parent, label, _meshes[key], at, color, rotation_value, false)

static func _part(parent: Node3D, label: String, mesh: Mesh, at: Vector3, color: String, rotation_value: Vector3, glow: bool) -> MeshInstance3D:
	var key := color + str(glow)
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color)
		material.roughness = 0.78
		material.metallic = 0.22
		if glow:
			material.emission_enabled = true
			material.emission = Color(color)
			material.emission_energy_multiplier = 0.7
		_materials[key] = material
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = _materials[key]
	node.position = at
	node.rotation = rotation_value
	parent.add_child(node)
	return node

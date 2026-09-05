extends RefCounted

const Suspension = preload("res://modules/caravan/wheel_suspension.gd")
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}

static func build_player() -> Node3D:
	var rig := _base(false)
	rig.name = "ArmoredWheelVehicle"
	_box(rig, "ArmoredFloor", Vector3(4.7, 0.36, 6.7), Vector3(0, 1.2, -0.1), "374448")
	_box(rig, "RearEquipmentDeck", Vector3(4.4, 0.48, 2.0), Vector3(0, 1.72, -2.1), "526468")
	_box(rig, "EngineHood", Vector3(3.55, 0.66, 2.1), Vector3(0, 2.0, 2.1), "59696b", Vector3(-0.1, 0, 0))
	_box(rig, "Cabin", Vector3(3.22, 1.42, 2.22), Vector3(0, 2.73, -0.04), "435357")
	_box(rig, "RoofArmor", Vector3(3.65, 0.22, 2.55), Vector3(0, 3.53, -0.04), "73807b")
	for side in [-1, 1]:
		_box(rig, "Windshield", Vector3(1.28, 0.64, 0.09), Vector3(side * 0.72, 2.99, 1.12), "203c43", Vector3(-0.13, 0, 0))
		_box(rig, "DoorWindow", Vector3(0.07, 0.6, 1.08), Vector3(side * 1.64, 2.98, 0.22), "203c43")
		_box(rig, "DoorArmor", Vector3(0.14, 0.63, 1.58), Vector3(side * 1.68, 2.26, -0.1), "657474")
		_box(rig, "DoorHandle", Vector3(0.12, 0.09, 0.3), Vector3(side * 1.79, 2.6, -0.48), "b4aa8a")
		_box(rig, "MirrorArm", Vector3(0.52, 0.09, 0.09), Vector3(side * 1.94, 2.9, 0.95), "273336")
		_box(rig, "Mirror", Vector3(0.18, 0.35, 0.29), Vector3(side * 2.2, 2.98, 0.95), "899b9e")
		_box(rig, "SideStep", Vector3(0.62, 0.14, 1.7), Vector3(side * 2.04, 1.09, 0.02), "252d2e")
		for z in [-2.35, 2.35]:
			_box(rig, "WheelFender", Vector3(1.1, 0.16, 1.6), Vector3(side * 2.43, 2.03, z), "59696b")
			_box(rig, "Mudflap", Vector3(0.87, 0.58, 0.09), Vector3(side * 2.4, 1.22, z - 0.91), "202726")
		_box(rig, "RearStorage", Vector3(0.66, 0.67, 1.6), Vector3(side * 1.63, 2.23, -2.05), "4c5752")
		for z in [-2.6, -1.5]:
			_box(rig, "StorageLatch", Vector3(0.1, 0.17, 0.12), Vector3(side * 2.01, 2.28, z), "bdac7e")
		_cylinder(rig, "Exhaust", 0.13, 2.1, Vector3(side * 1.94, 2.5, -1.1), "303b3a")
		_box(rig, "ExhaustGuard", Vector3(0.34, 0.9, 0.34), Vector3(side * 1.94, 2.33, -1.1), "697574")
		_box(rig, "HeadlightHousing", Vector3(0.62, 0.4, 0.2), Vector3(side * 1.28, 1.83, 3.24), "222d31")
		_box(rig, "HeadlightLens", Vector3(0.44, 0.25, 0.07), Vector3(side * 1.28, 1.85, 3.37), "e9d69a", Vector3.ZERO, true)
		_box(rig, "RearLamp", Vector3(0.44, 0.2, 0.08), Vector3(side * 1.77, 1.57, -3.52), "b85e47", Vector3.ZERO, true)
	_box(rig, "FrontBumper", Vector3(4.6, 0.38, 0.3), Vector3(0, 1.2, 3.54), "303c3f")
	_box(rig, "RearBumper", Vector3(4.5, 0.28, 0.26), Vector3(0, 1.15, -3.56), "303c3f")
	for bar in 7:
		_box(rig, "RadiatorGrille", Vector3(0.12, 0.48, 0.12), Vector3((bar - 3) * 0.25, 1.87, 3.25), "263333")
	for z in [-0.8, 0.8]:
		_box(rig, "RoofRail", Vector3(3.6, 0.09, 0.09), Vector3(0, 3.73, z), "293537")
	_cylinder(rig, "RoofHardpoint", 0.65, 0.15, Vector3(0, 3.73, -0.05), "8c846a")
	for side in [-1, 1]:
		for z in [-2.0, 0.1, 2.0]:
			_cylinder(rig, "EquipmentSocket", 0.24, 0.12, Vector3(side * 2.2, 2.26, z), "b7a470")
	_box(rig, "TowReceiver", Vector3(0.55, 0.27, 0.78), Vector3(0, 1.0, -3.78), "a4aaa0")
	return rig

static func build_trailer() -> Node3D:
	var rig := _base(true)
	rig.name = "SteeringWheelTrailer"
	_box(rig, "EquipmentPlatform", Vector3(3.25, 0.34, 3.65), Vector3(0, 1.13, 0), "596963")
	for side in [-1, 1]:
		_box(rig, "SideRail", Vector3(0.12, 0.42, 3.5), Vector3(side * 1.64, 1.5, 0), "93917a")
		for z in [-1.55, 1.55]:
			_box(rig, "TrailerFender", Vector3(0.83, 0.13, 1.65), Vector3(side * 1.8, 1.92, z), "67746b")
		_box(rig, "ToolLocker", Vector3(0.57, 0.39, 1.16), Vector3(side * 1.19, 0.76, -0.1), "344641")
		_box(rig, "TrailerLamp", Vector3(0.34, 0.18, 0.09), Vector3(side * 1.38, 1.18, -1.89), "b85e47", Vector3.ZERO, true)
	for point in [Vector3(-1.0, 1.38, -0.6), Vector3(1.0, 1.38, -0.6), Vector3(0, 1.38, 0.8)]:
		_cylinder(rig, "TrailerMount", 0.3, 0.13, point, "ac9b71")
	_box(rig, "RearTowReceiver", Vector3(0.34, 0.24, 0.55), Vector3(0, 0.94, -2.1), "a4aaa0")
	var drawbar := Node3D.new()
	drawbar.name = "SteeringDrawbar"
	drawbar.position = Vector3(0, 0.95, 1.55)
	rig.add_child(drawbar)
	for side in [-1, 1]:
		_box(drawbar, "DrawbarRail", Vector3(0.12, 0.17, 1.9), Vector3(side * 0.29, 0, 0.8), "697772", Vector3(0, -side * 0.29, 0))
	_cylinder(drawbar, "HitchJoint", 0.2, 0.23, Vector3(0, 0, 1.7), "c0b79c")
	rig.set_meta("drawbar", drawbar)
	return rig

static func _base(trailer: bool) -> Node3D:
	var rig := Node3D.new()
	var wheels: Array[Node3D] = []
	var springs: Array[Node3D] = []
	var anchors := Suspension.wheel_anchors(trailer)
	for side in [-1, 1]:
		_box(rig, "ChassisRail", Vector3(0.2, 0.27, 3.7 if trailer else 6.6), Vector3(side * (1.2 if trailer else 1.8), 0.94, 0), "2d3b3b")
	for axle in [anchors[0].z, anchors[2].z]:
		_cylinder(rig, "Axle", 0.12, 3.6 if trailer else 4.8, Vector3(0, 0.84, axle), "363c3a", Vector3(0, 0, PI * 0.5))
	for index in 4:
		var anchor: Vector3 = anchors[index]
		var pivot := Node3D.new()
		pivot.name = ("Front" if index < 2 else "Rear") + ("LeftWheel" if index % 2 == 0 else "RightWheel")
		pivot.position = anchor + Vector3.UP * Suspension.RADIUS
		pivot.set_meta("anchor", pivot.position)
		rig.add_child(pivot)
		var spin := Node3D.new()
		spin.name = "WheelRotation"
		pivot.add_child(spin)
		_cylinder(spin, "AllTerrainTire", Suspension.RADIUS, 0.7, Vector3.ZERO, "202925", Vector3(0, 0, PI * 0.5))
		for side in [-1, 1]:
			_cylinder(spin, "WheelRim", 0.48, 0.04, Vector3(side * 0.37, 0, 0), "68746e", Vector3(0, 0, PI * 0.5))
			_cylinder(spin, "Hub", 0.2, 0.08, Vector3(side * 0.4, 0, 0), "b2a17b", Vector3(0, 0, PI * 0.5))
			for bolt in 6:
				var angle := bolt * TAU / 6.0
				_box(spin, "WheelBolt", Vector3(0.07, 0.075, 0.075), Vector3(side * 0.41, sin(angle) * 0.32, cos(angle) * 0.32), "b6b9a7")
		for tread in 16:
			var angle := tread * TAU / 16.0
			_box(spin, "TreadBlock", Vector3(0.75, 0.12, 0.19), Vector3(0, cos(angle) * 0.86, sin(angle) * 0.86), "303931", Vector3(angle, 0, 0))
		var spring := _cylinder(rig, "SuspensionStrut", 0.09, 0.66, anchor + Vector3(-signf(anchor.x) * 0.23, 1.19, 0), "bcac78")
		spring.set_meta("anchor", spring.position)
		springs.append(spring)
		wheels.append(pivot)
	rig.set_meta("wheels", wheels)
	rig.set_meta("springs", springs)
	return rig

static func animate(rig: Node3D, suspension: Dictionary, steer: float, speed: float, wheel_angle: float, trailer: bool = false) -> void:
	var angles := Suspension.steering_angles(steer, speed, trailer)
	var wheels: Array = rig.get_meta("wheels", [])
	var springs: Array = rig.get_meta("springs", [])
	for index in wheels.size():
		var pivot: Node3D = wheels[index]
		pivot.position = pivot.get_meta("anchor") + Vector3.UP * float(suspension.wheel_offsets[index])
		pivot.rotation.y = angles[index] if index < 2 else 0.0
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

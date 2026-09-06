extends RefCounted

# Seat origins are measured from the rendered carrier root.  They deliberately
# leave the pickup centre and wagon equipment mounts free.
const PICKUP := [Vector3(-0.90, 1.53, -3.10), Vector3(0.90, 1.53, -3.10)]
const WAGON := [Vector3(-1.15, 1.55, -1.25), Vector3(1.15, 1.55, -1.25)]
static var _boxes: Dictionary = {}
static var _materials: Dictionary = {}

static func anchor(carrier_id: String, seat: int) -> Vector3:
	var seats: Array = PICKUP if carrier_id == "crawler" else WAGON
	return seats[clampi(seat, 0, seats.size() - 1)]

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "SeatedCrew"
	# Hips and torso stay upright; thighs point forward and shins hang down.
	var bench := Node3D.new()
	bench.name = "PickupBench"
	root.add_child(bench)
	_part(bench, "PickupBenchCushion", Vector3(0, 0.25, 0), Vector3(0.62, 0.14, 0.58), "4a5540")
	for side in [-1.0, 1.0]: _part(bench, "PickupBenchLeg", Vector3(side * 0.22, 0.07, 0), Vector3(0.08, 0.34, 0.10), "30392e")
	_part(root, "Pelvis", Vector3(0, 0.42, 0), Vector3(0.38, 0.20, 0.30), "596744", true)
	_part(root, "Torso", Vector3(0, 0.83, -0.03), Vector3(0.48, 0.64, 0.30), "596744", true)
	_part(root, "VestPlate", Vector3(0, 0.88, 0.14), Vector3(0.42, 0.40, 0.06), "282f26")
	_part(root, "Head", Vector3(0, 1.29, 0.01), Vector3(0.30, 0.32, 0.30), "a29467")
	_part(root, "Helmet", Vector3(0, 1.48, 0.01), Vector3(0.34, 0.12, 0.34), "596744")
	for side in [-1.0, 1.0]:
		_part(root, "Thigh", Vector3(side * 0.16, 0.39, 0.27), Vector3(0.15, 0.17, 0.52), "596744", true)
		_part(root, "Shin", Vector3(side * 0.16, 0.20, 0.49), Vector3(0.15, 0.40, 0.16), "394431")
		_part(root, "Boot", Vector3(side * 0.16, 0.06, 0.57), Vector3(0.18, 0.13, 0.30), "22251f")
		_part(root, "UpperArm", Vector3(side * 0.31, 0.78, 0.03), Vector3(0.14, 0.50, 0.14), "596744", true)
		_part(root, "Forearm", Vector3(side * 0.31, 0.52, 0.26), Vector3(0.14, 0.14, 0.42), "596744", true)
		_part(root, "Hand", Vector3(side * 0.31, 0.51, 0.49), Vector3(0.13, 0.14, 0.14), "a29467")
	return root

static func apply_role(root: Node3D, role: String, faction: String) -> void:
	var colors := {"mechanic": "74805a", "shooter": "596744", "loader": "626950", "looter": "a29467", "fuel": "394431", "anti_tank": "d3954e", "anti_air": "576559"}
	var color := "626950" if faction == "neutral" else str(colors.get(role, "596744"))
	for node: Node in root.get_children():
		if node is MeshInstance3D and bool(node.get_meta("seat_role_uniform", false)):
			node.material_override = _material_for(color)

static func _part(parent: Node3D, label: String, point: Vector3, size: Vector3, color: String = "729b78", role_uniform: bool = false) -> void:
	var key := str(size)
	if not _boxes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_boxes[key] = mesh
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = _boxes[key]
	node.material_override = _material_for(color)
	node.set_meta("seat_role_uniform", role_uniform)
	node.position = point
	parent.add_child(node)

static func _material_for(color: String) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.roughness = 0.95
		material.albedo_color = Color(color)
		_materials[color] = material
	return _materials[color]

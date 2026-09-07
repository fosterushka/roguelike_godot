extends RefCounted

# Seat origins are measured from the rendered carrier root.  They deliberately
# leave the pickup centre and wagon equipment mounts free.
const PICKUP := [Vector3(-0.90, 1.53, -3.10), Vector3(0.90, 1.53, -3.10)]
const WAGON := [Vector3(-1.15, 1.55, -1.25), Vector3(1.15, 1.55, -1.25)]
const People = preload("res://presentation/combat/military_people.gd")
const Appearance = preload("res://presentation/crew/crew_appearance.gd")
static var _materials: Dictionary = {}
static var _templates: Array[Dictionary] = []

static func anchor(carrier_id: String, seat: int) -> Vector3:
	var seats: Array = PICKUP if carrier_id == "crawler" else WAGON
	return seats[clampi(seat, 0, seats.size() - 1)]

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "SeatedCrew"
	# Blender meshes keep the established seat anchors and named anatomy nodes.
	_prepare_templates()
	for template: Dictionary in _templates:
		if str(template.name).begins_with("PickupBench"):
			continue
		var part := MeshInstance3D.new()
		part.name = template.name
		part.mesh = template.mesh
		part.transform = template.transform
		part.material_override = People._material()
		part.set_meta("seat_role_uniform", template.uniform)
		root.add_child(part)
	return root

static func build_pickup_bench() -> Node3D:
	_prepare_templates()
	var bench := Node3D.new()
	bench.name = "PickupBench"
	for template: Dictionary in _templates:
		if not str(template.name).begins_with("PickupBench"):
			continue
		var part := MeshInstance3D.new()
		part.name = template.name
		part.mesh = template.mesh
		part.transform = template.transform
		part.material_override = People._material()
		bench.add_child(part)
	return bench

static func _prepare_templates() -> void:
	if not _templates.is_empty():
		return
	var library := People.LIBRARY.instantiate()
	for part: MeshInstance3D in library.get_node("MODEL_SEATED").get_children():
		var label := str(part.name)
		var uniform := label.begins_with("Torso") or label.begins_with("Pelvis") or label.begins_with("Thigh") or label.begins_with("UpperArm") or label.begins_with("Forearm")
		_templates.append({"name": label, "mesh": part.mesh, "transform": part.transform, "uniform": uniform})
	library.free()

static func apply_role(root: Node3D, role: String, faction: String) -> void:
	Appearance.apply(root, role, true)
	var colors := {"mechanic": "74805a", "shooter": "596744", "loader": "626950", "looter": "a29467", "fuel": "394431", "anti_tank": "d3954e", "anti_air": "576559"}
	var color := "626950" if faction == "neutral" else str(colors.get(role, "596744"))
	for node: Node in root.get_children():
		if node is MeshInstance3D and bool(node.get_meta("seat_role_uniform", false)):
			node.material_override = _material_for(color)

static func _material_for(color: String) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.roughness = 0.95
		material.albedo_color = Color(color)
		_materials[color] = material
	return _materials[color]

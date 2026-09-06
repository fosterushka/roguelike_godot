extends Node3D

const CAPACITY := 256
const LIFETIME := 0.075
var pools: Dictionary = {}
var ages: Dictionary = {}
var cursors := {"player": 0, "enemy": 0}
var preview: Node3D

func _ready() -> void:
	preview = Node3D.new()
	add_child(preview)
	preview.visible = false
	for team: String in ["player", "enemy"]:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.075
		mesh.bottom_radius = 0.075
		mesh.height = 1.0
		mesh.radial_segments = 5
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("e3fbff") if team == "player" else Color("ffb264")
		material.emission_enabled = true
		material.emission = material.albedo_color
		mesh.material = material
		var batch := _batch(mesh, CAPACITY)
		add_child(batch)
		pools[team] = batch.multimesh
		ages[team] = []
		ages[team].resize(CAPACITY)
		ages[team].fill(0.0)
		var warm := _batch(mesh, 1)
		warm.position.x = -0.4 if team == "player" else 0.4
		warm.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3(1, 3, 1)), Vector3.ZERO))
		preview.add_child(warm)
	reset()

func _batch(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var batch := MultiMeshInstance3D.new()
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = count
	return batch

func segment(event: Dictionary) -> void:
	var team := "enemy" if event.get("team", "player") == "enemy" else "player"
	var from: Vector3 = event.get("from", Vector3.ZERO)
	var to: Vector3 = event.get("to", from)
	var offset := to - from
	if offset.length_squared() < 0.000001:
		return
	var index: int = cursors[team]
	cursors[team] = (index + 1) % CAPACITY
	ages[team][index] = LIFETIME
	var orientation := Basis(Quaternion(Vector3.UP, offset.normalized()))
	pools[team].set_instance_transform(index, Transform3D(orientation.scaled(Vector3(1, offset.length(), 1)), (from + to) * 0.5))

func advance(delta: float) -> void:
	if delta <= 0:
		return
	for team: String in pools:
		for index in CAPACITY:
			if ages[team][index] <= 0:
				continue
			ages[team][index] = maxf(0, ages[team][index] - delta)
			if ages[team][index] <= 0:
				pools[team].set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))

func reset() -> void:
	for team: String in pools:
		cursors[team] = 0
		ages[team].fill(0.0)
		for index in CAPACITY:
			pools[team].set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))

func set_warmup(value: bool, point: Vector3) -> void:
	preview.position = point
	preview.visible = value

extends Node3D
const Source = preload("res://presentation/combat/source_model.gd")
const Random = preload("res://modules/world/activities/source_random.gd")
var pieces: Array[MeshInstance3D] = []
var light: OmniLight3D
var life := 0.0
var warmup := false

func _ready() -> void:
	Source._prepare("weather_geometry")
	for index in 31:
		var visual := MeshInstance3D.new()
		visual.mesh = Source._templates.weather_geometry[2 if index >= 26 else 1].mesh
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("78c8ff") if index < 26 and index % 2 == 1 else Color.WHITE
		material.albedo_color.a = 0.34 if index < 26 and index % 2 == 1 else 1.0
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		if index < 26 and index % 2 == 1:
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		visual.material_override = material
		add_child(visual)
		pieces.append(visual)
	light = OmniLight3D.new()
	light.light_color = Color("b8d8ff")
	light.omni_range = 72
	light.omni_attenuation = 2
	light.position.y = 5
	add_child(light)
	visible = false

static func geometry(seed_value: int) -> Array[Dictionary]:
	var random := Random.new()
	random.state = seed_value & 0xffffffff
	var height: float = random.between(34, 46)
	var offset_x: float = random.between(-5.5, 5.5)
	var offset_z: float = random.between(-5.5, 5.5)
	var points: Array[Vector3] = []
	for index in 14:
		var ratio := index / 13.0
		var bend := sin(ratio * PI)
		points.append(Vector3(offset_x * (1 - ratio) + random.between(-2.1, 2.1) * bend, height * (1 - ratio), offset_z * (1 - ratio) + random.between(-2.1, 2.1) * bend))
	var result: Array[Dictionary] = []
	for index in range(1, 14):
		result.append({"start": points[index - 1], "end": points[index], "radius": 0.14 if index > 11 else 0.085})
		result.append({"start": points[index - 1], "end": points[index], "radius": 0.34 if index > 11 else 0.22})
	for index in 5:
		var start: Vector3 = points[random.integer(3, 10)]
		var end := start + Vector3(random.between(-6.5, 6.5), random.between(-7.5, -3.2), random.between(-6.5, 6.5))
		result.append({"start": start, "end": end, "radius": 0.055})
	return result

func strike(point: Vector3, seed_value: int) -> void:
	position = Vector3(point.x, 0.08, point.z)
	var lines := geometry(seed_value)
	for index in pieces.size():
		var segment: Dictionary = lines[index]
		var direction: Vector3 = segment.end - segment.start
		pieces[index].transform = Transform3D(Basis(Quaternion(Vector3.UP, direction.normalized())).scaled_local(Vector3(segment.radius, direction.length(), segment.radius)), (segment.start + segment.end) * 0.5)
	life = 0.55
	visible = true
	_update_light()

func _process(delta: float) -> void:
	advance_visual(delta)

func advance_visual(delta: float) -> void:
	if warmup or life <= 0:
		return
	life = maxf(0, life - delta)
	visible = life > 0
	for index in pieces.size():
		pieces[index].transparency = 1.0 - life / 0.55
	_update_light()

func _update_light() -> void:
	light.light_energy = 70.0 * clampf(life / 0.2, 0, 1) * (0.76 + sin(life * 92) * 0.24)

func reset_run() -> void:
	life = 0
	visible = false
	light.light_energy = 0

func set_warmup_visible(enabled: bool, point: Vector3) -> void:
	warmup = enabled
	if enabled:
		strike(point, 0)
	else:
		reset_run()

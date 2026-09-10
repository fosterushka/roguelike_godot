extends MultiMeshInstance3D
const Random = preload("res://modules/world/activities/source_random.gd")
const CAPACITY := 84
const PALETTES := [["40513a", "657044", "82653d"], ["d3c9a7", "a99f83", "8f8068"], ["55463a", "706c61", "884f32"]]
var random := Random.new()
var records: Array[Dictionary] = []
var cursor := 0
var warmup := false

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = box
	multimesh.instance_count = CAPACITY
	for index in CAPACITY:
		records.append({"life": 0.0})
	reset_run(0)

func reset_run(seed_value: int) -> void:
	random.state = seed_value & 0xffffffff
	cursor = 0
	for index in CAPACITY:
		records[index].life = 0.0
		multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))

func _project(camera: Camera3D, ndc: Vector2, height: float) -> Vector3:
	var screen := (ndc * Vector2(0.5, -0.5) + Vector2.ONE * 0.5) * get_viewport().get_visible_rect().size
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if absf(direction.y) < 0.000001:
		return Vector3(origin.x, height, origin.z)
	return origin + direction * (height - origin.y) / direction.y

func spawn(direction: Vector3, strength: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var point := Vector3.ZERO
	var accepted := false
	for attempt in 4:
		point = _project(camera, Vector2(random.between(-1.08, 1.08), random.between(-1.06, 1.06)), random.between(0.35, 5.2))
		var depth := -(camera.global_transform.affine_inverse() * point).z
		accepted = depth >= camera.near and depth <= camera.far
		if accepted:
			break
	if not accepted:
		point = _project(camera, Vector2.ZERO, 0.35)
	var speed: float = strength * random.between(0.62, 0.96)
	var velocity := Vector3(direction.x * speed + random.between(-1.1, 1.1), random.between(-0.16, 0.28), direction.z * speed + random.between(-1.1, 1.1))
	var rotation := Vector3(random.between(0, TAU), random.between(0, TAU), random.between(0, TAU))
	var spin := Vector3(random.between(-5.5, 5.5), random.between(-8.5, 8.5), random.between(-6.5, 6.5))
	var life: float = random.between(2.4, 4.2)
	var phase: float = random.between(0, TAU)
	var frequency: float = random.between(3.2, 6.8)
	var amplitude: float = random.between(0.12, 0.42)
	var roll: float = random.next()
	var style := 0 if roll < 0.58 else 1 if roll < 0.84 else 2
	var size := Vector3(random.between(0.16, 0.3), random.between(0.018, 0.035), random.between(0.3, 0.56)) if style == 0 else Vector3(random.between(0.3, 0.58), random.between(0.012, 0.025), random.between(0.26, 0.5)) if style == 1 else Vector3(random.between(0.09, 0.18), random.between(0.025, 0.055), random.between(0.34, 0.7))
	var color := Color(PALETTES[style][mini(2, floori(random.next() * 3))]).srgb_to_linear()
	multimesh.set_instance_color(cursor, color)
	records[cursor] = {"color": color, "position": point, "velocity": velocity, "rotation": rotation, "spin": spin, "life": life, "max_life": life, "phase": phase, "frequency": frequency, "amplitude": amplitude, "scale": size}
	cursor = (cursor + 1) % CAPACITY

func _process(delta: float) -> void:
	advance_visual(delta)

func advance_visual(delta: float) -> void:
	if warmup:
		return
	for index in CAPACITY:
		var item: Dictionary = records[index]
		if item.life <= 0:
			continue
		item.life -= delta
		if item.life <= 0:
			multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		item.position += item.velocity * delta
		item.rotation += item.spin * delta
		multimesh.set_instance_transform(index, pose_for(item))

static func pose_for(item: Dictionary) -> Transform3D:
	var age: float = item.max_life - item.life
	var visibility := minf(1, minf(age / 0.12, (item.life / item.max_life) / 0.18))
	var point: Vector3 = item.position + Vector3.UP * sin(item.phase + age * item.frequency) * item.amplitude
	return Transform3D(Basis.from_euler(item.rotation, EULER_ORDER_XYZ).scaled_local(item.scale * visibility), point)

func set_warmup_visible(enabled: bool, point := Vector3.ZERO) -> void:
	warmup = enabled
	if enabled:
		multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, point))
	else:
		multimesh.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))

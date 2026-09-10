extends Node3D
const MathRules = preload("res://presentation/combat/fx/effect_math.gd")
const Rng = preload("res://presentation/combat/fx/visual_random.gd")
const SmokeShader = preload("res://presentation/combat/fx/rocket_smoke.gdshader")
const CAPACITY := 192
const LIFETIME := 1.7
const BASE_SCALE := 0.64
const BASE_OPACITY := 0.92
const CULL_MARGIN := 6.0
const RANDOM_SEED := 0x524f434b
var emitters: Dictionary = {}
var random = Rng.new(RANDOM_SEED)
var elapsed := 0.0
var _batch: MultiMeshInstance3D
var _preview: MultiMeshInstance3D
var _material: ShaderMaterial
var _cursor := 0
var _expires := PackedFloat64Array()
var _last_expiry := 0.0

func _ready() -> void:
	_batch = _create_batch(CAPACITY)
	add_child(_batch)
	_material = _batch.material_override
	_expires.resize(CAPACITY)
	_preview = _create_batch(1)
	_preview.material_override.set_shader_parameter("uTime", LIFETIME * 0.3)
	_preview.multimesh.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ONE * BASE_SCALE), Vector3.ZERO))
	_preview.multimesh.set_instance_custom_data(0, Color(0.0, LIFETIME, 0.5, BASE_OPACITY))
	_preview.multimesh.set_instance_color(0, Color(0.0, 0.0, 0.0, 0.0))
	_preview.multimesh.visible_instance_count = 1
	_preview.visible = false
	add_child(_preview)

func _create_batch(capacity: int) -> MultiMeshInstance3D:
	var batch := MultiMeshInstance3D.new()
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.extra_cull_margin = CULL_MARGIN
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader = SmokeShader
	material.set_shader_parameter("expansion", MathRules.ROCKET_EXPANSION)
	material.set_shader_parameter("fade_in_ratio", MathRules.ROCKET_FADE_IN_RATIO)
	batch.material_override = material
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_custom_data = true
	batch.multimesh.use_colors = true
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = capacity
	batch.multimesh.visible_instance_count = 0
	return batch

func sync_projectiles(projectiles: Array, delta: float) -> void:
	var alive := {}
	for shot: Dictionary in projectiles:
		if shot.kind != "rocket" or shot.get("dead", false):
			continue
		alive[shot.id] = true
		if not emitters.has(shot.id):
			emitters[shot.id] = {"position": shot.get("previous", shot.position), "carry": 0.0}
			_spawn(emitters[shot.id].position)
		var emitter: Dictionary = emitters[shot.id]
		var sample := MathRules.sample_segment(emitter.position, shot.position, emitter.carry, delta)
		emitter.position = shot.position
		emitter.carry = sample.carry
		for particle: Dictionary in sample.samples:
			_spawn(particle.position, particle.age)
	for id in emitters.keys():
		if not alive.has(id):
			emitters.erase(id)

func _spawn(point: Vector3, age: float = 0.0) -> void:
	var life: float = LIFETIME * (0.86 + random.next_float() * 0.28)
	if age >= life:
		return
	var seed_value: float = random.next_float()
	var angle: float = random.next_float() * TAU
	var horizontal: float = 0.1 + random.next_float() * 0.2
	var drift := Vector3(cos(angle) * horizontal, 0.32 + random.next_float() * 0.28, sin(angle) * horizontal)
	var rotation_value: float = random.next_float() * TAU
	var scale_value: float = BASE_SCALE * (0.82 + random.next_float() * 0.36)
	var opacity: float = BASE_OPACITY * (0.86 + random.next_float() * 0.14)
	# Upload each particle once. The shader derives age, motion, scale and opacity.
	var index := _cursor
	_cursor = (_cursor + 1) % CAPACITY
	_expires[index] = elapsed + life - age
	_last_expiry = maxf(_last_expiry, _expires[index])
	_batch.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * scale_value), point))
	_batch.multimesh.set_instance_custom_data(index, Color(elapsed - age, life, seed_value, opacity))
	_batch.multimesh.set_instance_color(index, Color(drift.x, drift.y, drift.z, rotation_value))
	_batch.multimesh.visible_instance_count = maxi(_batch.multimesh.visible_instance_count, index + 1)

func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	elapsed += delta
	_material.set_shader_parameter("uTime", elapsed)
	if elapsed >= _last_expiry:
		_batch.multimesh.visible_instance_count = 0

func active_count() -> int:
	var count := 0
	for expires in _expires:
		count += int(expires > elapsed)
	return count

func reset() -> void:
	emitters.clear()
	random = Rng.new(RANDOM_SEED)
	elapsed = 0.0
	_cursor = 0
	_last_expiry = 0.0
	_expires.fill(0.0)
	_batch.multimesh.visible_instance_count = 0
	_material.set_shader_parameter("uTime", elapsed)

func set_warmup(enabled: bool, point: Vector3) -> void:
	_preview.position = point
	_preview.visible = enabled

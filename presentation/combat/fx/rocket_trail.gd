extends Node3D
const Pool = preload("res://presentation/combat/fx/effect_pool.gd")
const MathRules = preload("res://presentation/combat/fx/effect_math.gd")
const Rng = preload("res://presentation/combat/fx/visual_random.gd")
const SmokeShader = preload("res://presentation/combat/fx/rocket_smoke.gdshader")
var pool: Node3D
var emitters: Dictionary = {}
var random = Rng.new(0x524f434b)
var elapsed := 0.0

func _ready() -> void:
	pool = Pool.new()
	pool.configure(192, 1, SmokeShader)
	add_child(pool)

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
	var life: float = 1.7 * (0.86 + random.next_float() * 0.28)
	if age >= life:
		return
	var seed_value: float = random.next_float()
	var angle: float = random.next_float() * TAU
	var horizontal: float = 0.1 + random.next_float() * 0.2
	var drift := Vector3(cos(angle) * horizontal, 0.32 + random.next_float() * 0.28, sin(angle) * horizontal)
	var rotation_value: float = random.next_float() * TAU
	var scale_value: float = 0.64 * (0.82 + random.next_float() * 0.36)
	var opacity: float = 0.92 * (0.86 + random.next_float() * 0.14)
	var entry: Dictionary = pool.acquire({"position": point + drift * age, "life": life - age, "max_life": life, "age": age, "drift": drift, "seed": seed_value, "base_scale": scale_value, "opacity": opacity, "rotation_value": rotation_value, "fade": false})
	pool.set_part(entry, 0, "quad", Vector3.ONE, Color.WHITE)
	_apply(entry)

func advance(delta: float) -> void:
	elapsed += delta
	for entry: Dictionary in pool.entries:
		if entry.life <= 0.0:
			continue
		entry.life = maxf(0.0, entry.life - delta)
		entry.age += delta
		if entry.life <= 0.0:
			entry.visual.visible = false
			continue
		var phase: float = entry.age * 2.2 + entry.seed * 19.1
		entry.visual.position += (entry.drift + Vector3(sin(phase) * 0.045, 0.0, cos(phase * 0.83) * 0.045)) * delta
		_apply(entry)

func _apply(entry: Dictionary) -> void:
	var state := MathRules.rocket(entry.age, entry.max_life, entry.base_scale, entry.opacity)
	entry.visual.scale = Vector3.ONE * state.scale
	var material: ShaderMaterial = entry.parts[0].material_override
	material.set_shader_parameter("vOpacity", state.opacity)
	material.set_shader_parameter("vAge", entry.age)
	material.set_shader_parameter("rotation_value", entry.rotation_value)
	material.set_shader_parameter("vSeed", entry.seed)
	material.set_shader_parameter("uTime", elapsed)

func reset() -> void:
	pool.reset_pool()
	emitters.clear()
	random = Rng.new(0x524f434b)
	elapsed = 0.0

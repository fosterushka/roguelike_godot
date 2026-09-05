extends Node3D
const Pool = preload("res://presentation/combat/fx/effect_pool.gd")
const DustShader = preload("res://presentation/combat/fx/dust.gdshader")
var pool: Node3D
func _ready() -> void:
	pool = Pool.new()
	pool.configure(112, 1, DustShader)
	add_child(pool)
func spawn(random, position: Vector3, count: int, force: float, color: Color) -> void:
	for _index in count:
		var point := position + Vector3(random.between(-0.7, 0.7), random.between(0.08, 0.32), random.between(-0.7, 0.7))
		var velocity := Vector3(random.between(-1.35, 1.35), random.between(0.55, 1.9), random.between(-1.35, 1.35)) * force
		var size_value: float = random.between(12, 23) * maxf(0.55, force)
		var opacity: float = random.between(0.34, 0.58) + (color.b - 0.35) * 0.08
		var life: float = random.between(0.72, 1.35)
		var angle: float = random.between(0, TAU)
		var spin: float = random.between(-0.6, 0.6)
		var seed_value: float = random.next_float()
		var entry: Dictionary = pool.acquire({"position": point, "velocity": velocity, "base_size": size_value, "opacity": opacity, "life": life, "max_life": life, "angle": angle, "spin_value": spin, "seed": seed_value, "drag": 1.15, "gravity": 0.25, "fade": false})
		pool.set_part(entry, 0, "quad", Vector3.ONE, Color.WHITE)
		_apply(entry)
func advance(delta: float) -> void:
	pool.advance(delta)
	for entry: Dictionary in pool.entries:
		if entry.life > 0.0:
			entry.angle += entry.spin_value * delta
			_apply(entry)
func _apply(entry: Dictionary) -> void:
	var material: ShaderMaterial = entry.parts[0].material_override
	var viewport := get_viewport()
	var logical_width := maxf(1.0, viewport.get_visible_rect().size.x)
	var rendered_width := float(viewport.get_texture().get_width())
	material.set_shader_parameter("pixel_ratio", rendered_width / logical_width if rendered_width > 0.0 else 1.0)
	material.set_shader_parameter("size_pixels", entry.base_size * (1.0 + entry.age * 0.58))
	material.set_shader_parameter("opacity", entry.opacity * minf(1.0, entry.age / 0.14) * minf(1.0, entry.life / entry.max_life * 2.2))
	material.set_shader_parameter("angle", entry.angle)
	material.set_shader_parameter("seed_value", entry.seed)

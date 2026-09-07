extends RefCounted

const DROPLETS := 14
const LIFE := 0.62
const GRAVITY := 10.0
const COLORS := [Color("a91520"), Color("d32c32"), Color("740c18")]

static func spawn(pool: Node3D, random: RefCounted, point: Vector3, size: float = 1.0) -> void:
	for index in DROPLETS:
		var angle: float = random.between(0.0, TAU)
		var speed: float = random.between(1.8, 5.0) * size
		var velocity := Vector3(cos(angle) * speed, random.between(1.5, 4.7) * size, sin(angle) * speed)
		var radius: float = random.between(0.045, 0.11) * size
		var entry: Dictionary = pool.acquire({"position": point + Vector3.UP * 0.65, "velocity": velocity, "life": LIFE, "max_life": LIFE, "gravity": GRAVITY, "drag": 0.6, "shrink": 0.5})
		pool.set_part(entry, 0, "sphere", Vector3(radius, radius * 2.6, radius), COLORS[index % COLORS.size()])
		entry.parts[0].quaternion = Quaternion(Vector3.UP, velocity.normalized())

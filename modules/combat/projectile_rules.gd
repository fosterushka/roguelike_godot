extends RefCounted

static func create(id: int, kind: String, team: String, origin: Vector3, aim: Vector3, damage: float, target: int = -1) -> Dictionary:
	var enemy := team == "enemy"
	var speed := (62.0 if enemy else 84.0)
	var gravity := 0.0
	var min_time := 0.03
	var max_time := 0.8
	var radius := 0.18 if enemy else 0.14
	match kind:
		"rocket":
			speed = 36.0 if enemy else 42.0
			min_time = 0.15
			max_time = 1.8
			radius = 0.32
		"grenade":
			speed = 20.0 if enemy else 24.0
			gravity = 14.0
			min_time = 0.35
			max_time = 2.4
			radius = 0.58 if enemy else 0.52
		"sabot":
			speed = 96.0
			max_time = 0.7
			radius = 0.31 if enemy else 0.25
	var horizontal := Vector2(aim.x - origin.x, aim.z - origin.z).length()
	var travel := clampf(horizontal / speed, min_time, max_time)
	var velocity := (aim - origin) / travel
	velocity.y += 0.5 * gravity * travel
	return {"id": id, "kind": kind, "team": team, "position": origin, "previous": origin,
		"velocity": velocity, "gravity": gravity, "life": travel + 1.35, "radius": radius,
		"damage": damage, "target": target, "dead": false, "x": origin.x, "z": origin.z}

static func hits(from: Vector3, to: Vector3, center: Vector3, radius: float) -> bool:
	var segment := to - from
	var along := clampf((center - from).dot(segment) / maxf(segment.length_squared(), 0.000001), 0.0, 1.0)
	return (from + segment * along).distance_squared_to(center) <= radius * radius

static func blast_radius(kind: String) -> float:
	return 4.2 if kind == "rocket" else 5.2 if kind == "grenade" else 0.0

static func hit_fraction(start: Vector3, end: Vector3, center: Vector3, radius: float) -> float:
	var offset := start - center
	var direction := end - start
	var c := offset.length_squared() - radius * radius
	if c <= 0.0:
		return 0.0
	var a := direction.length_squared()
	if a < 0.000001:
		return -1.0
	var b := 2.0 * offset.dot(direction)
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var fraction := (-b - sqrt(discriminant)) / (2.0 * a)
	return fraction if fraction >= 0.0 and fraction <= 1.0 else -1.0

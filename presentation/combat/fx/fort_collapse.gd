extends RefCounted
const Debris = preload("res://presentation/combat/fx/crash_debris.gd")

static func spawn(effects, event: Dictionary) -> void:
	var pool = effects.transient
	var random = effects.random
	var vehicle: bool = event.get("type") in ["vehicle", "buggy", "priorityVehicle"]
	var boss: bool = event.get("boss", false)
	var point: Vector3 = event.get("position", Vector3.ZERO)
	if event.get("type") in ["keep", "garrison"]:
		effects.hulls.spawn(event, random)
	var count := 4 if vehicle else 32 if boss else 24 if event.get("type") == "garrison" else 16
	for _index in count:
		var roll: float = random.next_float()
		var type := ("panel" if roll < 0.52 else "beam" if roll < 0.8 else "machinery") if vehicle else ("panel" if roll < 0.23 else "beam" if roll < 0.42 else "pipe" if roll < 0.59 else "tank" if roll < 0.74 else "machinery" if roll < 0.9 else "masonry")
		var impulse := 1.0
		var spin_scale := 1.0
		var floor_y := 0.1
		var entry: Dictionary = pool.acquire({"collapse_kind": type, "gravity": 9.8, "drag": 0.045, "bounces": 2 if type == "panel" else 1, "fade_tail": 0.34, "shrink": 0.02})
		match type:
			"panel":
				var width: float = random.between(0.7, 1.45)
				var thickness: float = random.between(0.1, 0.24)
				var depth: float = random.between(0.48, 1.15)
				pool.set_part(entry, 0, "box", Vector3(width, thickness, depth), Debris.RED if random.next_float() < 0.38 else Debris.METAL, Vector3.ZERO, Vector3.ZERO, true)
				if random.next_float() < 0.72:
					pool.set_part(entry, 1, "box", Vector3(0.09, thickness * 1.45, depth * 0.82), Debris.IRON, Vector3(random.between(-width * 0.28, width * 0.28), thickness, 0), Vector3(0, random.between(-0.28, 0.28), 0), true)
				impulse = 1.08
				spin_scale = 1.18
				floor_y = thickness * 0.8
			"beam":
				var length: float = random.between(0.9, 1.8)
				pool.set_part(entry, 0, "box", Vector3(length, 0.17, 0.16), Debris.IRON, Vector3.ZERO, Vector3.ZERO, true)
				pool.set_part(entry, 1, "box", Vector3(length, 0.07, 0.38), Debris.METAL, Vector3(0, -0.12, 0), Vector3.ZERO, true)
				pool.set_part(entry, 2, "box", Vector3(length, 0.07, 0.38), Debris.METAL, Vector3(0, 0.12, 0), Vector3.ZERO, true)
				impulse = 0.77
				spin_scale = 0.68
				floor_y = 0.14
			"pipe":
				var length: float = random.between(0.72, 1.58)
				var radius: float = random.between(0.08, 0.16)
				Debris.cylinder(pool, entry, 0, radius, length, 7, Color("30261f"))
				Debris.cylinder(pool, entry, 1, radius * 1.45, 0.13, 8, Debris.METAL, Vector3(length * 0.32, 0, 0))
				impulse = 0.82
				spin_scale = 0.76
				floor_y = radius
			"tank":
				var radius: float = random.between(0.28, 0.48)
				var length: float = random.between(0.78, 1.42)
				Debris.cylinder(pool, entry, 0, radius, length, 8, Debris.METAL)
				Debris.cylinder(pool, entry, 1, radius * 1.05, 0.08, 8, Debris.IRON, Vector3(-length * 0.3, 0, 0))
				Debris.cylinder(pool, entry, 2, radius * 1.05, 0.08, 8, Debris.IRON, Vector3(length * 0.3, 0, 0))
				impulse = 0.69
				spin_scale = 0.58
				floor_y = radius * 0.72
			"machinery":
				pool.set_part(entry, 0, "box", Vector3(random.between(0.48, 0.88), random.between(0.35, 0.7), random.between(0.42, 0.76)), Debris.IRON, Vector3.ZERO, Vector3.ZERO, true)
				pool.set_part(entry, 1, "collapse_gear", Vector3.ONE, Debris.METAL, Vector3(0.3, 0, 0), Vector3(0, PI / 2, 0), true)
				impulse = 0.72
				spin_scale = 0.72
				floor_y = 0.24
			"masonry":
				pool.set_part(entry, 0, "masonry", Vector3(random.between(0.7, 1.25), random.between(0.6, 1.1), random.between(0.72, 1.22)), Debris.STONE, Vector3.ZERO, Vector3.ZERO, true)
				if random.next_float() < 0.5:
					Debris.cylinder(pool, entry, 1, 0.045, 0.95, 5, Debris.IRON, Vector3(0, 0.1, 0))
				impulse = 0.67
				spin_scale = 0.55
				floor_y = 0.3
		var size: float = (0.62 if vehicle else 1.12 if boss else 0.94) * random.between(0.82, 1.16)
		var spread := 1.05 if vehicle else 2.5
		entry.visual.scale = Vector3.ONE * size
		entry.visual.position = point + Vector3(random.between(-spread, spread), random.between(0.35 if vehicle else 0.8, 1.8 if vehicle else 4.8), random.between(-spread, spread))
		entry.visual.rotation = Vector3(random.between(-1, 1), random.between(0, TAU), random.between(-1, 1))
		entry.velocity = Vector3(random.between(-8, 8), random.between(5, 13), random.between(-8, 8)) * impulse * (0.72 if vehicle else 1.0)
		entry.spin = Vector3(random.between(-9, 9), random.between(-9, 9), random.between(-9, 9)) * spin_scale
		entry.life = random.between(2.2 if vehicle else 3.5, 3.8 if vehicle else 6.0)
		entry.max_life = 3.8 if vehicle else 6.0
		entry.floor_y = floor_y * size
	for _index in (3 if vehicle else 7):
		var size: float = random.between(0.2 if vehicle else 0.35, 0.44 if vehicle else 0.75)
		var spread := 0.78 if vehicle else 1.6
		var seed_value: float = random.next_float()
		var origin := point + Vector3(random.between(-spread, spread), random.between(0.35 if vehicle else 0.8, 1.45 if vehicle else 3.0), random.between(-spread, spread))
		var velocity := Vector3(random.between(-0.7, 0.7), random.between(1.2, 2.7), random.between(-0.7, 0.7))
		effects._spawn_smoke(origin, size * 3.8, Color("3c3b38"), 0.7, 1.06, seed_value, velocity, random.between(2.5, 4.5), 4.5, -0.12, 0.2, 0.0, size * 0.22)
	point.y = 0.7 if vehicle else 1.1
	effects.explosion(point, 1.05 if vehicle else 2.8 if boss else 2.2 if event.get("type") == "garrison" else 1.6, true, maxf(0.7, float(event.get("radius", 0.0)) * 2.0))

extends RefCounted
const IRON := Color("34383a")
const METAL := Color("6b7170")
const WOOD := Color("4b2b1d")
const STONE := Color("6c665d")
const RED := Color("7b4225")

static func spawn(pool, random, position: Vector3, intensity: float, kind: String) -> void:
	var count := mini(12, maxi(4, floori((5.0 + intensity * 2.5) * 0.82)))
	for _index in count:
		var stone: bool = kind == "stone" or (kind == "mixed" and random.next_float() < 0.26)
		var roll: float = random.next_float()
		var type := "chunk" if stone else "splinter" if kind == "wood" and roll < 0.62 else "plate" if kind == "wood" and roll < 0.88 else "bolt" if kind == "wood" else "wheel" if roll < 0.18 else "pipe" if roll < 0.35 else "plate" if roll < 0.54 else "axle" if roll < 0.69 else "gear" if roll < 0.82 else "splinter" if kind == "mixed" and roll > 0.94 else "bolt"
		var impulse := 1.0
		var spin_scale := 1.0
		var floor_y := 0.09
		var bounces := 2 if random.next_float() < 0.55 else 1
		var entry: Dictionary = pool.acquire({"debris_kind": type, "life": 3.4, "max_life": 3.4, "shrink": 0.035, "gravity": 8.8, "drag": 0.1, "fade_tail": 0.32})
		match type:
			"chunk":
				pool.set_part(entry, 0, "chunk", Vector3(random.between(0.75, 1.45), random.between(0.55, 1.15), random.between(0.7, 1.35)), STONE, Vector3.ZERO, Vector3.ZERO, true)
				if random.next_float() < 0.5:
					cylinder(pool, entry, 1, 0.035, 0.62, 5, IRON, Vector3(0.12, 0.06, 0))
				impulse = 0.78
				spin_scale = 0.72
				floor_y = 0.16
				bounces = 1
			"splinter":
				var width: float = random.between(0.13, 0.27)
				var thickness: float = random.between(0.07, 0.14)
				var length: float = random.between(0.58, 1.12)
				pool.set_part(entry, 0, "box", Vector3(width, thickness, length), WOOD, Vector3.ZERO, Vector3.ZERO, true)
				pool.set_part(entry, 1, "cone4", Vector3(width * 0.54, random.between(0.2, 0.38), width * 0.54), WOOD, Vector3(0, 0, length * 0.5 + 0.1), Vector3(PI / 2.0, 0, 0), true)
				if random.next_float() < 0.3:
					cylinder(pool, entry, 2, 0.025, 0.3, 5, IRON, Vector3(width * 0.5, 0.06, 0))
				impulse = 1.18
				spin_scale = 1.25
				floor_y = 0.06
			"pipe":
				var length: float = random.between(0.55, 1.08)
				var radius: float = random.between(0.055, 0.095)
				cylinder(pool, entry, 0, radius, length, 7, METAL)
				cylinder(pool, entry, 1, radius * 1.55, 0.12, 8, IRON, Vector3(length * 0.34, 0, 0))
				impulse = 0.94
				floor_y = radius
			"wheel":
				var radius: float = random.between(0.24, 0.38)
				var width: float = random.between(0.13, 0.21)
				cylinder(pool, entry, 0, radius, width, 9, IRON)
				cylinder(pool, entry, 1, radius * 0.36, width + 0.035, 7, METAL)
				impulse = 0.84
				spin_scale = 1.45
				floor_y = radius * 0.68
				bounces = 3
			"axle":
				var length: float = random.between(0.72, 1.15)
				cylinder(pool, entry, 0, 0.045, length, 6, IRON)
				cylinder(pool, entry, 1, 0.14, 0.12, 7, METAL, Vector3(-length * 0.5, 0, 0))
				cylinder(pool, entry, 2, 0.14, 0.12, 7, METAL, Vector3(length * 0.5, 0, 0))
				impulse = 0.83
				spin_scale = 0.84
				floor_y = 0.12
			"gear":
				pool.set_part(entry, 0, "gear", Vector3.ONE, METAL, Vector3.ZERO, Vector3(PI / 2, 0, 0), true)
				pool.set_part(entry, 1, "cylinder7", Vector3(0.07, 0.14, 0.07), IRON, Vector3.ZERO, Vector3.ZERO, true)
				impulse = 0.88
				spin_scale = 1.35
				floor_y = 0.14
			"bolt":
				cylinder(pool, entry, 0, 0.045, 0.52, 6, IRON)
				cylinder(pool, entry, 1, 0.11, 0.09, 6, METAL, Vector3(0.28, 0, 0))
				impulse = 1.12
				spin_scale = 1.25
				floor_y = 0.06
			"plate":
				var width: float = random.between(0.4, 0.76)
				var thickness: float = random.between(0.045, 0.085)
				var depth: float = random.between(0.32, 0.68)
				var color := WOOD if kind == "wood" else RED if random.next_float() < 0.36 else METAL if random.next_float() < 0.55 else IRON
				pool.set_part(entry, 0, "box", Vector3(width, thickness, depth), color, Vector3.ZERO, Vector3.ZERO, true)
				pool.set_part(entry, 1, "sphere", Vector3.ONE * 0.035, METAL, Vector3(-width * 0.3, thickness * 0.85, 0), Vector3.ZERO, true)
				pool.set_part(entry, 2, "sphere", Vector3.ONE * 0.035, METAL, Vector3(width * 0.3, thickness * 0.85, 0), Vector3.ZERO, true)
				if random.next_float() < 0.38:
					pool.set_part(entry, 3, "box", Vector3(width * 0.58, thickness * 1.2, 0.08), IRON, Vector3(0, thickness, depth * 0.46), Vector3(random.between(0.2, 0.48), 0, 0), true)
				impulse = 1.08
				spin_scale = 1.2
				floor_y = 0.06
		var piece_scale: float = random.between(0.82, 1.22) * (0.85 + intensity * 0.16)
		entry.visual.scale = Vector3.ONE * piece_scale
		entry.visual.position = position + Vector3(random.between(-0.75, 0.75), random.between(0.25, 1.2), random.between(-0.75, 0.75))
		entry.visual.rotation = Vector3(random.between(-1, 1), random.between(0, TAU), random.between(-1, 1))
		entry.velocity = Vector3(random.between(-4.4, 4.4), random.between(2.8, 7.2), random.between(-4.4, 4.4)) * ((0.7 + intensity * 0.2) * impulse)
		entry.spin = Vector3(random.between(-8, 8), random.between(-8, 8), random.between(-8, 8)) * spin_scale
		entry.life = random.between(1.7, 3.4)
		entry.bounces = bounces
		entry.floor_y = floor_y * piece_scale

static func cylinder(pool, entry: Dictionary, index: int, radius: float, height: float, segments: int, color: Color, position: Vector3 = Vector3.ZERO) -> void:
	pool.set_part(entry, index, "cylinder%d" % segments, Vector3(radius, height, radius), color, position, Vector3(0, 0, PI / 2.0), true)

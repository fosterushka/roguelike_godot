extends RefCounted

static func distance_squared(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x - second.x, first.z - second.z).length_squared()

static func clip_line(first: Vector2, last: Vector2, bounds: Rect2) -> PackedVector2Array:
	var delta := last - first
	var near := 0.0
	var far := 1.0
	for axis in 2:
		if absf(delta[axis]) < 0.00001:
			if first[axis] < bounds.position[axis] or first[axis] > bounds.end[axis]:
				return PackedVector2Array()
			continue
		var entry := (bounds.position[axis] - first[axis]) / delta[axis]
		var leave := (bounds.end[axis] - first[axis]) / delta[axis]
		near = maxf(near, minf(entry, leave))
		far = minf(far, maxf(entry, leave))
		if near > far:
			return PackedVector2Array()
	return PackedVector2Array([first + delta * near, first + delta * far])

static func clip_polygon(points: PackedVector2Array, bounds: Rect2) -> PackedVector2Array:
	var result := points
	for axis in 2:
		for side in 2:
			if result.is_empty():
				return result
			var clipped := PackedVector2Array()
			var edge: float = bounds.position[axis] if side == 0 else bounds.end[axis]
			var previous := result[-1]
			var previous_inside: bool = previous[axis] >= edge if side == 0 else previous[axis] <= edge
			for current in result:
				var inside: bool = current[axis] >= edge if side == 0 else current[axis] <= edge
				if inside != previous_inside:
					clipped.append(previous.lerp(current, (edge - previous[axis]) / (current[axis] - previous[axis])))
				if inside:
					clipped.append(current)
				previous = current
				previous_inside = inside
			result = clipped
	return result

static func edge_point(point: Vector2, bounds: Rect2) -> Vector2:
	var direction := point - bounds.get_center()
	var half := bounds.size * 0.5
	var scale := minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
	return bounds.get_center() + direction * minf(1.0, scale)

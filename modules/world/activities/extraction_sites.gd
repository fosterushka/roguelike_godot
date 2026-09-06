extends RefCounted

const Rules = preload("res://modules/world/activities/activity_rules.gd")
const Ground = preload("res://modules/caravan/terrain_surface.gd")
const Grid = preload("res://modules/world/spatial_grid.gd")
const RADIUS := 18.0

static func generate(layout: Dictionary, props: RefCounted, seed_value: int) -> Array[Dictionary]:
	var candidates: Array[Vector3] = []
	for road: Variant in layout.get("roads", []):
		var points: Array = road if road is Array else road.get("points", [])
		var width: float = 8.0 if road is Array else float(road.get("width", 8.0))
		for index in range(1, points.size()):
			var start := Rules.point(points[index - 1])
			var end := Rules.point(points[index])
			var forward := (end - start).normalized()
			var side := Vector3(-forward.z, 0, forward.x)
			for fraction: float in [0.15, 0.35, 0.55, 0.75, 0.95]:
				var access := start.lerp(end, fraction)
				for sign_value: float in [-1.0, 1.0]:
					var point := access + side * sign_value * (width * 0.5 + RADIUS + 3.0)
					if point.length() >= 100.0 and point.length() <= 480.0 and _clear(props, point) and _access_clear(props, access, point):
						candidates.append(point)
	var road_candidate_count := candidates.size()
	# Open central ground provides deterministic fallbacks when a shoulder contains scenery.
	for distance: float in [160.0, 240.0, 320.0, 400.0, 470.0]:
		for sector in 72:
			var angle := float(sector) / 72.0 * TAU
			var point := Vector3(cos(angle), 0, sin(angle)) * distance
			if _clear(props, point):
				candidates.append(point)
	var result: Array[Dictionary] = []
	var rotation := float(seed_value & 0xffff) / 65536.0 * TAU
	for index in 3:
		var angle := rotation + float(index) * TAU / 3.0
		var preferred := Vector3(cos(angle), 0, sin(angle)) * 260.0
		var best := Vector3.ZERO
		var score := INF
		for candidate_index in candidates.size():
			var candidate: Vector3 = candidates[candidate_index]
			var separated := true
			for site: Dictionary in result:
				if candidate.distance_to(site.position) < 120.0:
					separated = false
					break
			var value := candidate.distance_squared_to(preferred) + (1000000.0 if candidate_index >= road_candidate_count else 0.0)
			if separated and value < score:
				best = candidate
				score = value
		if is_finite(score):
			result.append({"id": "extract-%d" % (index + 1), "position": best, "radius": RADIUS})
	return result

static func _clear(props: RefCounted, point: Vector3) -> bool:
	for prop: Dictionary in props.grid.nearby(point, RADIUS + 2.0):
		if (prop.solid or prop.kind in ["tree", "deadTree"]) and not prop.destroyed and Grid.distance_xz(point, prop.position) < float(prop.radius) + RADIUS + 2.0:
			return false
	var height := Ground.height_at(point.x, point.z)
	for index in 8:
		var angle := float(index) / 8.0 * TAU
		if absf(Ground.height_at(point.x + cos(angle) * RADIUS, point.z + sin(angle) * RADIUS) - height) > 4.0:
			return false
	return true

static func _access_clear(props: RefCounted, start: Vector3, end: Vector3) -> bool:
	for prop: Dictionary in props.grid.nearby((start + end) * 0.5, start.distance_to(end) * 0.5 + 2.5):
		if (prop.solid or prop.kind in ["tree", "deadTree"]) and not prop.destroyed and Grid.segment_hit(start, end, prop.position, float(prop.radius) + 2.5) >= 0.0:
			return false
	return true

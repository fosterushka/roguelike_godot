extends RefCounted
# Small local visibility graph. Every edge and movement step uses the same solid-prop query.
var props: RefCounted
var paths: Dictionary = {}

func setup(prop_system: RefCounted) -> void:
	props = prop_system
	paths.clear()

func move(person: Dictionary, destination: Vector3, speed: float, delta: float) -> Vector3:
	var start: Vector3 = person.position
	start.y = 0
	destination.y = 0
	var radius := float(person.get("radius", 0.65))
	var id := str(person.id)
	if props == null:
		return start
	if props.first_segment(start, destination, radius, true).is_empty():
		paths.erase(id)
		return props.resolve_motion(start, start.move_toward(destination, speed * delta), radius)
	var cached: Dictionary = paths.get(id, {})
	if cached.is_empty() or Vector3(cached.target).distance_to(destination) > 1.5 or cached.points.is_empty() or not props.first_segment(start, cached.points[0], radius, true).is_empty():
		cached = {"target": destination, "points": _route(start, destination, radius)}
		paths[id] = cached
	if cached.points.is_empty():
		person.state = "blocked"
		return start
	while cached.points.size() > 1 and start.distance_to(cached.points[0]) < 0.3:
		cached.points.pop_front()
	return props.resolve_motion(start, start.move_toward(cached.points[0], speed * delta), radius)

func _route(start: Vector3, goal: Vector3, radius: float) -> Array[Vector3]:
	var nodes: Array[Vector3] = [start, goal]
	var obstacles: Array = props.grid.nearby((start + goal) * 0.5, start.distance_to(goal) * 0.5 + 12.0)
	obstacles.append_array(props.dynamic_solids)
	for obstacle: Dictionary in obstacles:
		if obstacle.get("destroyed", false) or obstacle.get("airborne", false) or not obstacle.get("solid", false):
			continue
		var clearance := (float(obstacle.radius) + radius + 0.35) / cos(PI / 8)
		for side in 8:
			var point: Vector3 = obstacle.position + Vector3(cos(side * TAU / 8), 0, sin(side * TAU / 8)) * clearance
			point.y = 0
			if nodes.size() < 98 and props.is_clear(point, radius):
				nodes.append(point)
	var costs := {0: 0.0}
	var previous := {}
	var closed := {}
	while closed.size() < nodes.size():
		var best := -1
		var score := INF
		for index: int in costs:
			var estimate: float = costs[index] + nodes[index].distance_to(goal)
			if not closed.has(index) and estimate < score:
				score = estimate
				best = index
		if best < 0:
			break
		if best == 1:
			var route: Array[Vector3] = [goal]
			while previous.get(best, 0) != 0:
				best = previous[best]
				route.push_front(nodes[best])
			return route
		closed[best] = true
		for next in nodes.size():
			if next == best or closed.has(next):
				continue
			var cost: float = costs[best] + nodes[best].distance_to(nodes[next])
			if cost < float(costs.get(next, INF)) and props.first_segment(nodes[best], nodes[next], radius, true).is_empty():
				costs[next] = cost
				previous[next] = best
	return []

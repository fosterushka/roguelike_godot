extends RefCounted

const HEIGHTS := {"building": 3.2, "monument": 12.0, "well": 2.5, "stall": 2.5, "streetlight": 3.8, "signal": 3.6, "windmill": 7.3, "ruin": 3.0, "wreck": 2.2, "tree": 7.0, "deadTree": 6.0, "boulder": 3.0}
const Grid = preload("res://modules/world/spatial_grid.gd")
var grid := Grid.new()
var records: Dictionary = {}
var events: Array[Dictionary] = []
var destroyed_ids: Array[String] = []
var ram_cooldown := 0.0
var dynamic_solids: Array[Dictionary] = []

func setup(layout: Dictionary) -> void:
	grid = Grid.new()
	records.clear()
	destroyed_ids.clear()
	events.clear()
	dynamic_solids.clear()
	ram_cooldown = 0.0
	for source: Dictionary in layout.props:
		var record := source.duplicate()
		record.position = Vector3(source.position.x, 0, source.position.z)
		record.max_hp = float(source.hp)
		record.destroyed = false
		record.solid = bool(source.get("solid", str(source.kind) in ["building", "monument", "well", "windmill", "ruin", "wreck"]))
		record.height = float(source.get("height", HEIGHTS.get(str(source.kind), 1.6)))
		records[str(record.id)] = record
		grid.insert(record)
	for source: Dictionary in layout.rockObstacles:
		if records.has(str(source.id)):
			continue
		var record := {"id": str(source.id), "kind": "rock", "position": Vector3(source.x, 0, source.z), "radius": float(source.radius), "height": 6.0, "hp": INF, "max_hp": INF, "salvage": 0, "destroyed": false, "solid": true}
		records[str(record.id)] = record
		grid.insert(record)

func damage_at(point: Vector3, radius: float, amount: float) -> int:
	var destroyed := 0
	for prop: Dictionary in grid.nearby(point, radius):
		if prop.destroyed or prop.kind == "rock":
			continue
		var distance: float = Grid.distance_xz(prop.position, point)
		if distance > radius + prop.radius:
			continue
		prop.hp -= amount * maxf(0.2, 1.0 - distance / maxf(0.1, radius + prop.radius))
		if prop.hp <= 0.0 and destroy(prop):
			destroyed += 1
	return destroyed

func destroy(prop: Dictionary, force: float = 1.0) -> bool:
	if prop.destroyed or prop.kind == "rock":
		return false
	prop.destroyed = true
	prop.hp = 0.0
	destroyed_ids.append(str(prop.id))
	events.append({"kind": "prop_destroyed", "id": prop.id, "prop_kind": prop.kind, "position": prop.position, "salvage": prop.salvage, "force": force, "large": prop.get("large", prop.kind in ["building", "monument"]), "debris_kind": prop.get("debrisKind", "mixed" if prop.kind in ["monument", "streetlight"] else "wood")})
	return true

func ram(point: Vector3, speed: float, ramming: bool, delta: float, visual_scale: float = 0.88) -> Dictionary:
	ram_cooldown = maxf(0.0, ram_cooldown - delta)
	if absf(speed) < 3.2 or ram_cooldown > 0.0:
		return {"destroyed": 0, "retention": 1.0}
	var radius := 3.4 * visual_scale / 0.88
	var destroyed := 0
	for prop: Dictionary in grid.nearby(point, radius + 2.0):
		if prop.destroyed or prop.kind == "rock" or prop.solid or Grid.distance_xz(prop.position, point) > radius + prop.radius:
			continue
		prop.hp -= absf(speed) * (16.0 if ramming else 7.5)
		if prop.hp <= 0.0 and destroy(prop, absf(speed) / 7.0):
			destroyed += 1
	if destroyed > 0:
		ram_cooldown = 0.12
	return {"destroyed": destroyed, "retention": 1.0 if destroyed == 0 else 0.97 if ramming else maxf(0.84, 0.9 - maxf(0, destroyed - 1) * 0.02)}

func impact(id: String, speed: float, ramming: bool) -> bool:
	var prop: Dictionary = records.get(id, {})
	if prop.is_empty() or prop.destroyed or prop.kind == "rock" or absf(speed) < 3.2:
		return false
	prop.hp -= absf(speed) * (16.0 if ramming else 7.5)
	return prop.hp <= 0.0 and destroy(prop, absf(speed) / 7.0)

func first_segment(start: Vector3, end: Vector3, radius: float = 0.0, solid_only: bool = false) -> Dictionary:
	var result: Dictionary = {}
	var best := 2.0
	var candidates := grid.nearby((start + end) * 0.5, Grid.distance_xz(start, end) * 0.5 + radius)
	if solid_only:
		candidates.append_array(dynamic_solids)
	for prop: Dictionary in candidates:
		if prop.destroyed or (solid_only and not prop.solid):
			continue
		var fraction := Grid.segment_hit(start, end, prop.position, float(prop.radius) + radius)
		if fraction < 0.0 or fraction >= best:
			continue
		var point := start.lerp(end, fraction)
		if point.y > float(prop.height) or point.y < -1.0:
			continue
		best = fraction
		result = {"prop": prop, "fraction": fraction, "position": point}
	return result

func is_clear(point: Vector3, radius: float) -> bool:
	for prop: Dictionary in grid.nearby(point, radius) + dynamic_solids:
		if not prop.destroyed and prop.solid and Grid.distance_xz(point, prop.position) < float(prop.radius) + radius:
			return false
	return true

func resolve_motion(start: Vector3, end: Vector3, radius: float) -> Vector3:
	var position := end
	var hit := first_segment(start, end, radius, true)
	if not hit.is_empty():
		var direction := end - start
		var contact: Vector3 = hit.position
		var normal: Vector3 = contact - hit.prop.position
		normal.y = 0.0
		if normal.length_squared() < 0.001:
			normal = Vector3.RIGHT
		normal = normal.normalized()
		var tangent := direction - normal * minf(0.0, direction.dot(normal))
		position = start + tangent
	for prop: Dictionary in grid.nearby(position, radius) + dynamic_solids:
		if prop.destroyed or not prop.solid:
			continue
		var offset: Vector3 = position - prop.position
		offset.y = 0.0
		var clearance := float(prop.radius) + radius
		if offset.length() < clearance:
			position = prop.position + (offset.normalized() if offset.length_squared() > 0.001 else Vector3.RIGHT) * (clearance + 0.01)
	position.y = end.y
	return position

func reset() -> Array[String]:
	var restored := destroyed_ids.duplicate()
	for prop: Dictionary in records.values():
		prop.hp = prop.max_hp
		prop.destroyed = false
	destroyed_ids.clear()
	events.clear()
	ram_cooldown = 0.0
	return restored

func drain_events() -> Array[Dictionary]:
	var result := events.duplicate()
	events.clear()
	return result

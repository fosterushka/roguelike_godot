extends Control

const Geometry = preload("res://presentation/ui/map_geometry.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const MAX_EDGE_HINTS := 6
const PRIORITY_KINDS := ["jammerTruck", "repairCrawler", "minelayer"]

var state: Dictionary = {}
var world_state: Dictionary = {}
var camera: Camera3D
var occluders: Array[Control] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_state(data: Dictionary, view_camera: Camera3D) -> void:
	state = data
	camera = view_camera
	queue_redraw()

func update_world(data: Dictionary) -> void:
	world_state = data
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(camera):
		return
	var screen := Rect2(Vector2(22, 62), Vector2(maxf(32, size.x - 44), maxf(32, size.y - 90)))
	for enemy: Dictionary in state.get("enemies", []) + state.get("boss_components", []):
		if not _hostile(enemy) or enemy.get("is_component", false) and not enemy.get("exposed", false):
			continue
		var focused: bool = enemy.get("id", -2) == state.get("focus_id", -1)
		var world_point: Vector3 = enemy.position + Vector3.UP * (0.8 if enemy.get("is_component", false) else float(enemy.get("height", 0.0)) + 3.4)
		if not enemy.get("is_component", false):
			world_point.y += Terrain.height_at(world_point.x, world_point.z)
		var point := projected_position(world_point)
		if camera.is_position_behind(world_point) or not screen.has_point(point):
			continue
		var ratio := clampf(float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("max_hp", 1))), 0.0, 1.0)
		if ratio < 1.0 or focused or enemy.get("boss", false):
			draw_rect(Rect2(point - Vector2(20, 0), Vector2(40, 4)), Color("26221d"))
			draw_rect(Rect2(point - Vector2(20, 0), Vector2(40 * ratio, 4)), Color("e7ad53") if focused else Color("df6351"))
		if focused:
			draw_rect(Rect2(point - Vector2(24, 4), Vector2(48, 13)), Color("f8d180"), false)
	for mine: Dictionary in state.get("mines", []):
		var progress := clampf(float(mine.get("hack_progress", 0.0)) / 3.0, 0.0, 1.0)
		var world_point := Vector3(mine.position.x, Terrain.height_at(mine.position.x, mine.position.z) + 1, mine.position.z)
		if progress <= 0.0 or mine.get("dead", false) or camera.is_position_behind(world_point):
			continue
		var point := projected_position(world_point)
		if not screen.has_point(point):
			continue
		draw_rect(Rect2(point - Vector2(18, 0), Vector2(36, 4)), Color("26221d"))
		draw_rect(Rect2(point - Vector2(18, 0), Vector2(36 * progress, 4)), Color("f8d180"))
	for hint: Dictionary in edge_hints():
		_draw_hint(hint)

func _hostile(enemy: Dictionary) -> bool:
	return not enemy.get("dead", false) and enemy.get("allegiance", "enemy") != "friendly" and enemy.has("position")

func _candidate(id: String, position: Vector3, label: String, color: Color, rank: int) -> Dictionary:
	var origin: Vector3 = state.get("player", {}).get("position", Vector3.ZERO)
	return {"id": id, "position": position, "label": Locale.text(label), "color": color, "rank": rank, "distance": sqrt(Geometry.distance_squared(origin, position))}

func _offscreen(position: Vector3) -> bool:
	return camera.is_position_behind(position) or not Rect2(Vector2.ZERO, size).has_point(projected_position(position))

func edge_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if not is_instance_valid(camera) or state.get("player", {}).is_empty():
		return candidates
	var detection_range := preload("res://presentation/ui/enemy_detection.gd").range_for(state, world_state)
	var nearest_threat: Dictionary = {}
	var nearest_priority: Dictionary = {}
	for enemy: Dictionary in state.get("enemies", []) + state.get("boss_components", []):
		if not _hostile(enemy) or enemy.get("is_component", false) and not enemy.get("exposed", false) or not _offscreen(enemy.position):
			continue
		if detection_range <= 0 or Geometry.distance_squared(enemy.position, state.player.get("position", Vector3.ZERO)) > detection_range * detection_range:
			continue
		var focused: bool = enemy.get("id", -2) == state.get("focus_id", -1)
		var boss: bool = enemy.get("boss", false)
		var kind := str(enemy.get("kind", ""))
		var label := "ЦЕЛЬ" if focused else "БОСС" if boss else kind if kind in PRIORITY_KINDS else "ВРАГ"
		var candidate := _candidate("enemy:" + str(enemy.get("id", "")), enemy.position, label, Color("f8d180") if focused or boss else Color("d47cff") if kind == "jammerTruck" else Color("e78568"), 0 if focused else 2 if boss else 3 if kind in PRIORITY_KINDS else 6)
		if focused or boss:
			candidates.append(candidate)
		elif kind in PRIORITY_KINDS:
			if nearest_priority.is_empty() or candidate.distance < nearest_priority.distance:
				nearest_priority = candidate
		elif not enemy.get("is_component", false) and (nearest_threat.is_empty() or candidate.distance < nearest_threat.distance):
			nearest_threat = candidate
	for nearest: Dictionary in [nearest_priority, nearest_threat]:
		if not nearest.is_empty():
			candidates.append(nearest)
	var extraction: Dictionary = world_state.get("extraction", {})
	if extraction.get("visible", false) and _offscreen(extraction.get("position", Vector3.ZERO)):
		candidates.append(_candidate("extraction", extraction.get("position", Vector3.ZERO), "ЭВАКУАЦИЯ", Color("8ee3ad"), 1))
	for activity: Dictionary in world_state.get("activity", {}).get("records", []):
		if activity.get("state", "") not in ["announced", "active"] or not activity.has("position") or not _offscreen(activity.position):
			continue
		candidates.append(_candidate("activity:" + str(activity.get("id", "")), activity.position, str(activity.get("type", "ЦЕЛЬ")), Color("69e0b2"), 4))
	for key in ["heal_carts", "airdrops"]:
		var nearest: Dictionary = {}
		for support: Dictionary in world_state.get("support", {}).get(key, []):
			if support.get("dead", false) or not support.has("position") or not _offscreen(support.position):
				continue
			var candidate := _candidate(key + ":" + str(support.get("id", "")), support.position, "ПОМОЩЬ" if key == "heal_carts" else "ПРИПАСЫ", Color("88f0a1") if key == "heal_carts" else Color("79d8ed"), 5)
			if nearest.is_empty() or candidate.distance < nearest.distance:
				nearest = candidate
		if not nearest.is_empty():
			candidates.append(nearest)
	candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return first.rank < second.rank if first.rank != second.rank else first.distance < second.distance)
	return candidates

func edge_hints() -> Array[Dictionary]:
	var hints: Array[Dictionary] = []
	if not is_visible_in_tree():
		return hints
	var blocked: Array[Rect2] = []
	for control in occluders:
		if is_instance_valid(control) and control.is_visible_in_tree():
			var rectangle := control.get_global_rect()
			rectangle.position -= global_position
			blocked.append(rectangle.grow(6))
	for candidate in edge_candidates():
		if hints.size() >= MAX_EDGE_HINTS:
			break
		var label: String = candidate.label
		var width := clampf(ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 34, 98, 190)
		var footprint := Vector2(width, 36)
		var bounds := Rect2(Vector2(8, 62) + footprint * 0.5, Vector2(maxf(1, size.x - 16 - footprint.x), maxf(1, size.y - 70 - footprint.y)))
		var target := projected_position(candidate.position)
		var direction := (target - size * 0.5).normalized()
		if direction.is_zero_approx():
			direction = Vector2.DOWN
		var point := Geometry.edge_point(bounds.get_center() + direction * maxf(size.x, size.y) * 2, bounds)
		var offset := _perimeter_offset(point, bounds)
		for attempt in 128:
			var displacement := ceilf(attempt * 0.5) * 24 * (1 if attempt % 2 == 1 else -1)
			var center := _perimeter_point(offset + displacement, bounds)
			var rectangle := Rect2(center - footprint * 0.5, footprint)
			var collides := false
			for obstacle in blocked:
				if rectangle.intersects(obstacle):
					collides = true
					break
			if collides:
				continue
			candidate.rect = rectangle
			candidate.direction = direction
			hints.append(candidate)
			blocked.append(rectangle.grow(6))
			break
	return hints

func _perimeter_offset(point: Vector2, bounds: Rect2) -> float:
	if absf(point.y - bounds.position.y) < 0.01:
		return point.x - bounds.position.x
	if absf(point.x - bounds.end.x) < 0.01:
		return bounds.size.x + point.y - bounds.position.y
	if absf(point.y - bounds.end.y) < 0.01:
		return bounds.size.x + bounds.size.y + bounds.end.x - point.x
	return bounds.size.x * 2 + bounds.size.y + bounds.end.y - point.y

func _perimeter_point(offset: float, bounds: Rect2) -> Vector2:
	var remaining := fposmod(offset, 2 * (bounds.size.x + bounds.size.y))
	if remaining <= bounds.size.x:
		return bounds.position + Vector2(remaining, 0)
	remaining -= bounds.size.x
	if remaining <= bounds.size.y:
		return Vector2(bounds.end.x, bounds.position.y + remaining)
	remaining -= bounds.size.y
	if remaining <= bounds.size.x:
		return bounds.end - Vector2(remaining, 0)
	return Vector2(bounds.position.x, bounds.end.y - remaining + bounds.size.x)

func _draw_hint(hint: Dictionary) -> void:
	var rectangle: Rect2 = hint.rect
	var color: Color = hint.color
	var direction: Vector2 = hint.direction
	draw_rect(rectangle, Color(0.04, 0.06, 0.05, 0.93))
	draw_rect(rectangle, Color(color, 0.6), false, 1)
	var center := rectangle.position + Vector2(14, 18)
	var side := Vector2(-direction.y, direction.x) * 4
	draw_colored_polygon(PackedVector2Array([center + direction * 7, center - direction * 5 + side, center - direction * 5 - side]), color)
	var label: String = hint.label
	var font := ThemeDB.fallback_font
	while label.length() > 2 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > rectangle.size.x - 32:
		label = label.left(label.length() - 2) + "…"
	draw_string(font, rectangle.position + Vector2(28, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
	draw_string(font, rectangle.position + Vector2(28, 28), "%d%s" % [roundi(hint.distance), Locale.text("м")], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e3e5d9"))

func projected_position(world_point: Vector3) -> Vector2:
	var point := camera.unproject_position(world_point)
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL and camera.is_position_behind(world_point):
		point = camera.get_viewport().get_visible_rect().get_center() * 2 - point
	return point

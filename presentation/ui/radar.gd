extends Control

const Geometry = preload("res://presentation/ui/map_geometry.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const ZOOM_RANGES: Array[float] = [64.0, 96.0, 128.0, 192.0, 256.0]
const DEFAULT_ZOOM_INDEX := 4
const WORLD_SIZE := 3008.0
const GRID := 216
const RadarRules = preload("res://modules/progression/radar_rules.gd")
const BASE_RANGE := RadarRules.BASE_MAP_RANGE
var zoom_index: int = DEFAULT_ZOOM_INDEX
var state: Dictionary = {}
var world_state: Dictionary = {}
var layout: Dictionary = {}
var view_camera: Camera3D
var cells := PackedByteArray()
var generation := -1
var display_range: float = ZOOM_RANGES[DEFAULT_ZOOM_INDEX]
var effective_range := 0.0
var jammed := false
var _heading := 0.0
var _zoom_in: Button
var _zoom_out: Button
var _map_rect := Rect2(8, 28, 168, 168)

func _ready() -> void:
	custom_minimum_size = Vector2(176, 208)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_zoom_out = Button.new()
	_zoom_out.text = "−"
	_zoom_out.custom_minimum_size = Vector2(24, 22)
	_zoom_out.position = Vector2(120, 2)
	_zoom_out.pressed.connect(func() -> void: step_zoom(1))
	add_child(_zoom_out)
	_zoom_in = Button.new()
	_zoom_in.text = "+"
	_zoom_in.custom_minimum_size = Vector2(24, 22)
	_zoom_in.position = Vector2(148, 2)
	_zoom_in.pressed.connect(func() -> void: step_zoom(-1))
	add_child(_zoom_in)
	for button in [_zoom_in, _zoom_out]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("263229")
		style.border_color = Color("786347")
		style.set_border_width_all(1)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
	cells.resize(GRID * GRID)
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual_models/world_layout.json"))

func update_state(data: Dictionary, camera: Camera3D) -> void:
	state = data
	view_camera = camera
	if int(data.get("generation", 0)) != generation:
		generation = int(data.get("generation", 0))
		cells.fill(0)
		zoom_index = DEFAULT_ZOOM_INDEX
	var player: Dictionary = data.get("player", {})
	var radar_range := float(player.get("radar_range", 0.0))
	visible = not player.is_empty()
	jammed = preload("res://presentation/ui/enemy_detection.gd").is_jammed(data)
	var interference := 0.55 if jammed else 1.0
	var weather: Dictionary = world_state.get("weather", {})
	var fog_strength := float(weather.get("fog_strength", 1.0 if weather.get("type", "") == "foggy" else 0.0))
	interference *= preload("res://modules/world/weather_rules.gd").visibility_multiplier(fog_strength, radar_range > 0.0)
	effective_range = maxf(BASE_RANGE, radar_range) * interference
	display_range = ZOOM_RANGES[zoom_index]
	if is_instance_valid(view_camera):
		var forward := -view_camera.global_basis.z
		if Vector2(forward.x, forward.z).length_squared() > 0.000001:
			_heading = atan2(forward.x, forward.z)
	if data.get("running", false) and data.get("status", "") not in ["dead", "complete", "extracted"]:
		reveal(player.get("position", Vector3.ZERO), maxf(BASE_RANGE, radar_range) * interference)
	_zoom_in.disabled = zoom_index <= 0
	_zoom_out.disabled = zoom_index >= DEFAULT_ZOOM_INDEX
	queue_redraw()

func update_world(data: Dictionary) -> void:
	world_state = data
	if not state.is_empty():
		update_state(state, view_camera)
	else:
		queue_redraw()

func cycle_zoom() -> void:
	if not is_visible_in_tree() or get_tree().paused:
		return
	zoom_index = (zoom_index + 1) % ZOOM_RANGES.size()
	update_state(state, view_camera)

func step_zoom(direction: int) -> void:
	if not is_visible_in_tree() or get_tree().paused:
		return
	zoom_index = clampi(zoom_index + direction, 0, DEFAULT_ZOOM_INDEX)
	update_state(state, view_camera)

func zoom_label() -> String:
	return "%d%s" % [roundi(display_range), Locale.text("м")]

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			step_zoom(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step_zoom(1)
		accept_event()

func reveal(point: Vector3, radius: float) -> void:
	var cell_width := WORLD_SIZE / GRID
	var center := Vector2i(clampi(int((point.x / WORLD_SIZE + 0.5) * GRID), 0, GRID - 1), clampi(int((point.z / WORLD_SIZE + 0.5) * GRID), 0, GRID - 1))
	var reach := ceili(radius / cell_width)
	var padded := pow(radius + sqrt(2.0) * cell_width * 0.5, 2)
	for row in range(maxi(0, center.y - reach), mini(GRID - 1, center.y + reach) + 1):
		for column in range(maxi(0, center.x - reach), mini(GRID - 1, center.x + reach) + 1):
			var location := Vector3((column + 0.5) * cell_width - WORLD_SIZE * 0.5, 0, (row + 0.5) * cell_width - WORLD_SIZE * 0.5)
			if Vector2(location.x - point.x, location.z - point.z).length_squared() <= padded:
				cells[row * GRID + column] = 1

func explored(point: Vector3) -> bool:
	if cells.is_empty() or absf(point.x) > WORLD_SIZE * 0.5 or absf(point.z) > WORLD_SIZE * 0.5:
		return false
	var column := clampi(int((point.x / WORLD_SIZE + 0.5) * GRID), 0, GRID - 1)
	var row := clampi(int((point.z / WORLD_SIZE + 0.5) * GRID), 0, GRID - 1)
	return cells[row * GRID + column] == 1

func _vector(value: Variant) -> Vector3:
	return value if value is Vector3 else Vector3(float(value.get("x", 0)), 0, float(value.get("z", 0)))

func _point(world: Vector3) -> Vector2:
	var origin: Vector3 = state.get("player", {}).get("position", Vector3.ZERO)
	var delta := world - origin
	var right := -delta.x * cos(_heading) + delta.z * sin(_heading)
	var forward := delta.x * sin(_heading) + delta.z * cos(_heading)
	return _map_rect.get_center() + Vector2(right, -forward) * (minf(_map_rect.size.x, _map_rect.size.y) * 0.5 / maxf(1.0, display_range))

func _line(start: Vector3, end: Vector3, color: Color, width: float = 1.0) -> void:
	if not explored(start) or not explored(end) or not explored((start + end) * 0.5):
		return
	var clipped := Geometry.clip_line(_point(start), _point(end), _map_rect.grow(-1))
	if clipped.size() == 2:
		draw_line(clipped[0], clipped[1], color, width)

func detected_hostiles() -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	var player: Dictionary = state.get("player", {})
	var radius := preload("res://presentation/ui/enemy_detection.gd").range_for(state, world_state)
	if radius <= 0.0:
		return contacts
	var origin: Vector3 = player.get("position", Vector3.ZERO)
	for enemy: Dictionary in state.get("enemies", []):
		if not enemy.get("dead", false) and enemy.get("allegiance", "enemy") != "friendly" and enemy.has("position") and Geometry.distance_squared(enemy.position, origin) <= radius * radius:
			contacts.append(enemy)
	return contacts

func _draw() -> void:
	_map_rect = Rect2(8, 28, size.x - 16, minf(size.x - 16, size.y - 66))
	_zoom_out.position.x = size.x - 56
	_zoom_in.position.x = size.x - 28
	draw_rect(Rect2(Vector2.ZERO, size), Color("111713"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("786347"), false)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(10, 18), Locale.text("ПОМЕХИ" if jammed else "РАДАР" if float(state.get("player", {}).get("radar_range", 0)) > 0 else "КАРТА") + (" %d/%d" % [int(state.get("player", {}).get("radar_level", 1)), RadarRules.MAX_LEVEL] if float(state.get("player", {}).get("radar_range", 0)) > 0 else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("edc575"))
	draw_rect(_map_rect, Color("080c09"))
	var cell_width := WORLD_SIZE / GRID
	var location: Vector3 = state.get("player", {}).get("position", Vector3.ZERO)
	var radius_cells := ceili(display_range * sqrt(2.0) / cell_width) + 1
	var center_column := int((location.x / WORLD_SIZE + 0.5) * GRID)
	var center_row := int((location.z / WORLD_SIZE + 0.5) * GRID)
	for strip: Rect2i in explored_strips(Vector2i(center_column, center_row), radius_cells):
		var left := strip.position.x * cell_width - WORLD_SIZE * 0.5
		var right := strip.end.x * cell_width - WORLD_SIZE * 0.5
		var top := strip.position.y * cell_width - WORLD_SIZE * 0.5
		var bottom := top + cell_width
		var corners := PackedVector2Array([_point(Vector3(left, 0, top)), _point(Vector3(right, 0, top)), _point(Vector3(right, 0, bottom)), _point(Vector3(left, 0, bottom))])
		corners = Geometry.clip_polygon(corners, _map_rect)
		if corners.size() >= 3 and not Geometry2D.triangulate_polygon(corners).is_empty():
			draw_colored_polygon(corners, Color("585c50"))
	for road: Array in layout.get("roads", []):
		for index in range(1, road.size()):
			_road_line(_vector(road[index - 1]), _vector(road[index]))
	for key in ["landmarks", "villages"]:
		for landmark: Dictionary in layout.get(key, []):
			if landmark.get("consumed", false) or landmark.get("destroyed", false):
				continue
			var world := _vector(landmark)
			var point := _point(world)
			if explored(world) and _map_rect.grow(-4).has_point(point):
				draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), Color("e5d08a"))
	for activity: Dictionary in world_state.get("activity", {}).get("records", []):
		if not RadarRules.identifies_missions(int(state.get("player", {}).get("radar_level", 0))) or activity.get("state", "") not in ["announced", "active"]:
			continue
		var world := _vector(activity.get("position", Vector3.ZERO))
		var point := _point(world)
		if explored(world) and _map_rect.grow(-4).has_point(point):
			draw_rect(Rect2(point - Vector2(3, 3), Vector2(6, 6)), Color("69e0b2"))
		var route: Array = activity.get("route", activity.get("route_points", []))
		for index in range(1, route.size()):
			_line(_vector(route[index - 1]), _vector(route[index]), Color("69e0b2"), 1.5)
	var origin: Vector3 = state.get("player", {}).get("position", Vector3.ZERO)
	for enemy: Dictionary in detected_hostiles():
		if enemy.get("dead", false) or enemy.get("allegiance", "enemy") == "friendly" or Geometry.distance_squared(enemy.position, origin) > effective_range * effective_range:
			continue
		var point := _point(enemy.position)
		if not _map_rect.grow(-6).has_point(point):
			continue
		var kind := str(enemy.get("kind", ""))
		if kind in ["jammerTruck", "repairCrawler", "minelayer"]:
			draw_string(font, point + Vector2(-4, 4), "J" if kind == "jammerTruck" else "R" if kind == "repairCrawler" else "M", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d47cff") if kind == "jammerTruck" else Color("70efa0") if kind == "repairCrawler" else Color("ffb24d"))
		else:
			var edge := 7.0 if enemy.get("boss", false) else 4.0
			draw_rect(Rect2(point - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), Color("ffce51") if enemy.get("boss", false) else Color("e75b4b"))
	for key in ["heal_carts", "airdrops"]:
		for support: Dictionary in world_state.get("support", {}).get(key, []):
			var point := _point(support.get("position", Vector3.ZERO))
			if support.get("dead", false) or not _map_rect.grow(-4).has_point(point):
				continue
			if key == "heal_carts":
				draw_line(point - Vector2(3, 0), point + Vector2(3, 0), Color("88f0a1"), 2)
				draw_line(point - Vector2(0, 3), point + Vector2(0, 3), Color("88f0a1"), 2)
			else:
				draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), Color("79d8ed"))
	_draw_boundary()
	_draw_extraction()
	var heading := float(state.get("player", {}).get("heading", 0.0))
	var rotation := _heading - heading
	var arrow := PackedVector2Array()
	for point in [Vector2(0, -7), Vector2(4, 5), Vector2(0, 2), Vector2(-4, 5)]:
		arrow.append(point.rotated(rotation) + _map_rect.get_center())
	if float(state.get("player", {}).get("hp", 0)) <= 0:
		var center := _map_rect.get_center()
		draw_line(center - Vector2(4, 4), center + Vector2(4, 4), Color("d58a76"), 2)
		draw_line(center - Vector2(4, -4), center + Vector2(4, -4), Color("d58a76"), 2)
	else:
		draw_colored_polygon(arrow, Color.WHITE)
	var north := Vector2(sin(_heading), -cos(_heading)) * -1
	var north_point := Geometry.edge_point(_map_rect.get_center() + north * 1000, _map_rect.grow(-8))
	draw_string(font, north_point + Vector2(-4, 4), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("edc575"))
	draw_rect(_map_rect, Color("786347"), false)
	var bearing := fposmod(PI - heading, TAU)
	var labels := ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
	draw_string(font, Vector2(8, size.y - 20), "%s %03d° · %d%s" % [labels[roundi(bearing / TAU * 16) % 16], roundi(rad_to_deg(bearing)) % 360, display_range, Locale.text("м")], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("eee9db"))
	draw_string(font, Vector2(8, size.y - 6), "X %04d · Z %04d" % [origin.x, origin.z], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("b8b7aa"))

func _road_line(start: Vector3, end: Vector3) -> void:
	var steps := maxi(1, ceili(start.distance_to(end) / (WORLD_SIZE / GRID * 0.5)))
	for index in steps:
		_line(start.lerp(end, index / float(steps)), start.lerp(end, (index + 1) / float(steps)), Color("b1704a"), 1.5)

func _draw_boundary() -> void:
	var radius := float(world_state.get("boundary", {}).get("radius", 1248.0))
	var origin: Vector3 = state.get("player", {}).get("position", Vector3.ZERO)
	if absf(Vector2(origin.x, origin.z).length() - radius) > display_range * sqrt(2.0):
		return
	for index in 128:
		var first := Vector3(cos(index * TAU / 128.0), 0, sin(index * TAU / 128.0)) * radius
		var last := Vector3(cos((index + 1) * TAU / 128.0), 0, sin((index + 1) * TAU / 128.0)) * radius
		var clipped := Geometry.clip_line(_point(first), _point(last), _map_rect.grow(-1))
		if clipped.size() == 2:
			draw_line(clipped[0], clipped[1], Color("db9367"), 1.5)

func extraction_sites() -> Array:
	if not RadarRules.reveals_extraction(int(state.get("player", {}).get("radar_level", 0))):
		return []
	var extraction: Dictionary = world_state.get("extraction", {})
	var sites: Array = extraction.get("sites", [])
	if sites.is_empty() and extraction.get("visible", false):
		sites = [{"id": "", "position": extraction.get("position", Vector3.ZERO)}]
	return sites

func _draw_extraction() -> void:
	var extraction: Dictionary = world_state.get("extraction", {})
	for site: Dictionary in extraction_sites():
		var target := _point(_vector(site.position))
		var point := Geometry.edge_point(target, _map_rect.grow(-11))
		var active := bool(extraction.get("active", false)) and str(site.get("id", "")) == str(extraction.get("site_id", extraction.get("zone_id", "")))
		var color := Color("ee7257") if active and extraction.get("mode", "") == "leaving" else Color("ffc064") if active else Color("7bdc9a")
		if not _map_rect.grow(-11).has_point(target):
			var direction := (target - _map_rect.get_center()).normalized()
			var side := Vector2(-direction.y, direction.x) * 4
			draw_colored_polygon(PackedVector2Array([point + direction * 4, point - direction * 5 + side, point - direction * 5 - side]), color)
			point -= direction * 10
		else:
			draw_rect(Rect2(point - Vector2(7, 7), Vector2(14, 14)), Color("142723"))
			draw_rect(Rect2(point - Vector2(7, 7), Vector2(14, 14)), color, false, 1.5)
		draw_string(ThemeDB.fallback_font, point + Vector2(-4, 5), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

func explored_strips(center: Vector2i, reach: int) -> Array[Rect2i]:
	var strips: Array[Rect2i] = []
	var first := maxi(0, center.x - reach)
	var last := mini(GRID - 1, center.x + reach)
	for row in range(maxi(0, center.y - reach), mini(GRID - 1, center.y + reach) + 1):
		var column := first
		while column <= last:
			if cells[row * GRID + column] == 0:
				column += 1
				continue
			var start := column
			while column <= last and cells[row * GRID + column] != 0:
				column += 1
			strips.append(Rect2i(start, row, column - start, 1))
	return strips

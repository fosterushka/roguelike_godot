extends RefCounted

# Native Blender anchors are shared with export; all runtime users receive Godot units.
static var DEFINITION: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/leviathan_geometry.json"))
static var _styles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_vehicle_styles.json"))
static var SCALE: float = float(_styles.models.boss.scale)
static var TRIANGLE_BUDGET: int = int(DEFINITION.triangle_budget)

static func anchor(kind: String) -> Vector3:
	var point: Array = DEFINITION.components[kind].anchor
	return Vector3(float(point[0]), float(point[2]), -float(point[1])) * SCALE

static func radius(kind: String) -> float:
	return float(DEFINITION.components[kind].radius)

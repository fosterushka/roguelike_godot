extends RefCounted

## Station behavior belongs to the landmark definition, shared by every layout.
const REFILL_RADIUS := 11.0
const REFILL_PER_SECOND := 24.0
const PUMP_FUEL_DROP := 36
const ROADSIDE_OFFSET := 20.0
const SITE_CLEARANCE := 22.0
const START_FUEL_MAX_DISTANCE := 350.0
const GUARANTEED_PUMPS := 6
const DEFINITIONS := {
	"pumpjack": {"drops": {"fuel": PUMP_FUEL_DROP}},
	"refinery": {"drops": {}},
}

static func is_station(kind: String) -> bool:
	return DEFINITIONS.has(kind)

static func prop_metadata(layout: Dictionary) -> Dictionary:
	var result := {}
	for landmark: Dictionary in layout.get("landmarks", []):
		var kind := str(landmark.get("type", ""))
		if is_station(kind):
			result["prop:" + str(landmark.id)] = {"station_kind": kind, "drops": DEFINITIONS[kind].drops.duplicate(true)}
	return result

## Six service stops along the road through spawn, reserved before other features.
static func roadside_pumps(road: Dictionary) -> Array:
	var result: Array = []
	var points: Array = road.points
	var center := points.size() / 2
	for index in range(1, points.size() - 1):
		if index == center:
			continue
		var point: Dictionary = points[index]
		var next: Dictionary = points[index + 1]
		var direction := Vector2(next.x - point.x, next.z - point.z).normalized()
		var side := -1.0 if index < center else 1.0
		result.append({"id": "fuel-stop-%02d" % result.size(), "type": "pumpjack", "x": point.x - direction.y * ROADSIDE_OFFSET * side, "z": point.z + direction.x * ROADSIDE_OFFSET * side, "rotation": atan2(direction.x, direction.y)})
	return result

extends RefCounted

# Same broad, continuous borders are used by terrain.gdshader.
enum Kind { MEADOW, BADLANDS, TUNDRA }
const BORDER := 260.0
const BLEND_WIDTH := 90.0
const BORDER_WAVE := 95.0
const BORDER_FREQUENCY := 0.004
const DRY_TINT := Color(1.18, 0.8, 0.49)
const COLD_TINT := Color(0.73, 0.87, 1.05)
const VEGETATION_POOLS := ["spruceTrees", "birchTrees", "treeTrunks", "treeCrowns", "treeCrownsAlt", "treeBranches", "scrubInstances", "deadBrushInstances", "grassTufts", "flowerInstances"]

static func coordinate(point: Vector3) -> float:
	return point.x + sin(point.z * BORDER_FREQUENCY) * BORDER_WAVE

static func kind_at(point: Vector3) -> Kind:
	var coordinate_value := coordinate(point)
	return Kind.BADLANDS if coordinate_value > BORDER else Kind.TUNDRA if coordinate_value < -BORDER else Kind.MEADOW

static func tint_at(point: Vector3) -> Color:
	var value := coordinate(point)
	var dry := smoothstep(BORDER - BLEND_WIDTH, BORDER + BLEND_WIDTH, value)
	var cold := 1.0 - smoothstep(-BORDER - BLEND_WIDTH, -BORDER + BLEND_WIDTH, value)
	return Color.WHITE.lerp(DRY_TINT, dry).lerp(COLD_TINT, cold)

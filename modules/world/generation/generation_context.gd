extends RefCounted
const Random = preload("res://modules/world/activities/source_random.gd")
const Layout = preload("res://modules/world/generation/layout_generator.gd")
const DURABILITY := {"tree": [0.9, 28, "wood"], "deadTree": [0.78, 20, "wood"], "boulder": [0.82, 58, "stone"], "scrub": [0.48, 7, "wood"], "fence": [1.05, 14, "wood"], "barrel": [0.52, 12, "metal"], "crate": [0.52, 10, "wood"], "scrap": [0.78, 18, "metal"], "wreck": [1.65, 46, "metal"], "well": [1.45, 72, "mixed"], "stall": [1.75, 34, "mixed"], "windmill": [2.4, 115, "mixed"], "signal": [0.65, 24, "metal"], "ruin": [2.35, 62, "stone"], "streetlight": [0.8, 34, "mixed"], "building": [2.25, 58, "mixed"], "monument": [7, 150, "mixed"]}
const POOLS := {"treeTrunks": [6, 1500], "treeCrowns": [7, 2200], "treeCrownsAlt": [8, 2200], "treeBranches": [9, 2200], "rockInstances": [10, 2600], "stoneInstances": [11, 1600], "scrubInstances": [12, 3600], "deadBrushInstances": [13, 2200], "grassTufts": [14, 7000], "flowerInstances": [15, 1200], "barrelInstances": [16, 900], "crateInstances": [17, 1900], "fencePosts": [18, 2400], "fenceRails": [19, 2800], "ironStructure": [20, 1400], "metalStructure": [21, 1400], "woodStructure": [22, 1400], "redStructure": [23, 700], "tankInstances": [24, 600], "earthStructure": [25, 1800], "ruinStructure": [26, 1100], "scarStructure": [27, 900], "trenches": [28, 256], "bowls": [29, 192], "rims": [30, 192], "decals": [31, 192], "char": [32, 1088], "cliffFaces": [33, 900], "cliffStrata": [34, 900], "spruceTrees": [6, 3300], "birchTrees": [6, 3300], "rockMass0": [33, 500], "rockMass1": [33, 500], "rockMass2": [33, 500], "rockMass3": [33, 500], "rockMass4": [33, 500], "rockMass5": [33, 500]}
var random := Random.new()
var layout: Dictionary
var instances: Dictionary = {}
var props: Array = []
var rock_obstacles: Array = []
var villages: Array = []
var activity_blockers: Array = []
var landmarks: Array = []
var groups: Array = []
var aggregate_destructible := false
var rendered_features: Dictionary = {}
var terrain_details: Dictionary = {}
var biome_centers: Array = []
var roadside_anchors: Array = []
var ambient_animators: Array = []
var ambient_critters: Array = []

func setup(seed_value: int) -> void:
	if has_meta("legacy_tree_views"):
		remove_meta("legacy_tree_views")
	layout = Layout.generate(seed_value)
	random.state = (int(layout.seed) ^ 0x68bc21eb) & 0xffffffff
	instances.clear()
	props.clear()
	rock_obstacles.clear()
	villages.clear()
	activity_blockers.clear()
	landmarks.clear()
	groups.clear()
	for key: String in POOLS:
		instances[key] = []

func append(pool: String, position: Vector3, rotation: Vector3, scale: Vector3) -> Dictionary:
	var values: Array = instances[pool]
	if values.size() >= POOLS[pool][1]:
		return {"pool": pool, "instance": -1}
	var index := values.size()
	var transform := Transform3D(Basis.from_euler(rotation, EULER_ORDER_XYZ).scaled_local(scale), position)
	values.append(transform)
	return {"pool": pool, "instance": index, "transform": transform}

func structure(pool: String, x: float, y: float, z: float, width: float, height: float, depth: float, rotation: float = 0, tilt: float = 0) -> Dictionary:
	return append(pool, Vector3(x, y, z), Vector3(0, rotation, tilt), Vector3(width, height, depth))

func register_prop(kind: String, x: float, z: float, scale: float = 1, visual: Dictionary = {}, overrides: Dictionary = {}) -> Dictionary:
	if aggregate_destructible:
		return {}
	var safe_scale := maxf(0.1, scale)
	var durability: Array = DURABILITY[kind]
	var prop := {"kind": kind, "position": {"x": x, "y": 0.0, "z": z}, "radius": durability[0] * safe_scale, "hp": durability[1] * safe_scale, "salvage": 0, "debrisKind": durability[2], "parts": [], "groups": []}
	prop.merge(visual, true)
	prop.merge(overrides, true)
	if not prop.has("id"):
		prop.id = runtime_prop_id(layout.seed, kind, x, z, prop.radius)
	props.append(prop)
	return prop

func open_dressing_point(x: float, z: float, road_clearance: float = 8, start_clearance: float = 16) -> bool:
	if x * x + z * z < start_clearance * start_clearance:
		return false
	if start_clearance <= 16 and absf(x) < 9 and z > -28 and z < 40:
		return false
	if Layout.distance_to_road({"x": x, "z": z}, layout.roads) <= road_clearance:
		return false
	for obstacle: Dictionary in rock_obstacles:
		if Layout.distance({"x": x, "z": z}, obstacle) <= obstacle.radius + 2:
			return false
	return true

func near_village(x: float, z: float, clearance: float) -> bool:
	for village: Dictionary in villages:
		if Layout.distance({"x": x, "z": z}, village) < clearance:
			return true
	return false

func point_in_disc(minimum: float, maximum: float) -> Dictionary:
	var angle := random.between(0, TAU)
	var radius := sqrt(random.between(minimum * minimum, maximum * maximum))
	return {"x": cos(angle) * radius, "z": sin(angle) * radius}

func find_open_point(minimum: float, maximum: float, road_clearance: float = 10, village_clearance: float = 22, start_clearance: float = 16) -> Dictionary:
	for attempt in 80:
		var point := point_in_disc(minimum, maximum)
		if open_dressing_point(point.x, point.z, road_clearance, start_clearance) and not near_village(point.x, point.z, village_clearance):
			return point
	return {}

static func runtime_prop_id(seed_value: int, kind: String, x: float, z: float, radius: float) -> String:
	var identity := "%d:%s:%s:%s:%s" % [seed_value & 0xffffffff, kind, decimal(x), decimal(z), decimal(radius)]
	return "prop:runtime:" + hashed(identity, 0x811c9dc5) + hashed(identity, 0x9e3779b9)

static func decimal(value: float) -> String:
	var rounded := floorf(value * 1000 + 0.5) / 1000
	if rounded == 0:
		return "0"
	return ("%.3f" % rounded).trim_suffix("0").trim_suffix("0").trim_suffix("0").trim_suffix(".")

static func hashed(value: String, initial: int) -> String:
	var hash_value := initial
	for index in value.length():
		hash_value = ((hash_value ^ value.unicode_at(index)) * 16777619) & 0xffffffff
	var result := ""
	while hash_value > 0:
		result = "0123456789abcdefghijklmnopqrstuvwxyz"[hash_value % 36] + result
		hash_value = hash_value / 36
	return result if not result.is_empty() else "0"

static func rotate_offset(x: float, z: float, offset_x: float, offset_z: float, rotation: float) -> Dictionary:
	return {"x": x + offset_x * cos(rotation) + offset_z * sin(rotation), "z": z - offset_x * sin(rotation) + offset_z * cos(rotation)}

func landmark_box(pool: String, x: float, z: float, offset_x: float, y: float, offset_z: float, width: float, height: float, depth: float, rotation: float = 0, tilt: float = 0) -> Dictionary:
	var point := rotate_offset(x, z, offset_x, offset_z, rotation)
	return structure(pool, point.x, y, point.z, width, height, depth, rotation, tilt)

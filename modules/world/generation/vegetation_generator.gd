extends RefCounted

const Random = preload("res://modules/world/activities/source_random.gd")
const Biomes = preload("res://modules/world/biome_rules.gd")
const DRY_GROVE_DENSITY := 0.38
const TREE_SIZE_SCALE := 1.18
const SPECIES := ["spruceTrees", "birchTrees"]
const CROWNS := [2.6, 2.3]
const TREE_BUDGET := 1800
const GRID_SIZE := 16.0
var _context: RefCounted
var _random := Random.new()
var _occupied: Dictionary = {}
var _count := 0
var _groves := 0

static func populate(context: RefCounted) -> void:
	var generator: RefCounted = load("res://modules/world/generation/vegetation_generator.gd").new()
	generator._generate(context)

func _generate(context: RefCounted) -> void:
	_context = context
	_random.state = (int(context.layout.seed) ^ 0x4f3a918d) & 0xffffffff
	for prop: Dictionary in context.props:
		if prop.kind in ["tree", "deadTree", "building", "monument", "well", "windmill", "ruin", "wreck", "fence"] or prop.get("solid", false):
			_occupy(Vector2(prop.position.x, prop.position.z), maxf(2.5 if prop.kind == "tree" else 1.0, float(prop.radius)))
	for index in 12:
		var angle := index * TAU / 12.0 + _random.between(-0.14, 0.14)
		var center := Vector2(cos(angle), sin(angle)) * _random.between(38, 84)
		_grove(center, 15.0, 24, index % SPECIES.size(), 0.78)
	for index in 64:
		var center := _point(85, 430)
		_grove(center, _random.between(19, 32), _random.integer(27, 42), index % SPECIES.size(), 1.0)
	for index in 64:
		var center := _point(360, 1050)
		_grove(center, _random.between(22, 38), _random.integer(23, 36), (index + 1) % SPECIES.size(), 1.05)
	var totals := {}
	for pool: String in SPECIES:
		totals[pool] = context.instances[pool].size()
	context.set_meta("vegetation_statistics", {"trees": _count, "groves": _groves, "species": totals, "budget": TREE_BUDGET})

func _point(minimum: float, maximum: float) -> Vector2:
	var angle: float = _random.between(0, TAU)
	var radius := sqrt(_random.between(minimum * minimum, maximum * maximum))
	return Vector2(cos(angle), sin(angle)) * radius

func _grove(center: Vector2, radius: float, attempts: int, species: int, size: float) -> void:
	var planted := 0
	for index in attempts:
		if _count >= TREE_BUDGET:
			break
		var angle: float = _random.between(0, TAU)
		var offset := sqrt(_random.next()) * radius
		var point := center + Vector2(cos(angle), sin(angle)) * offset
		var biome := Biomes.kind_at(Vector3(point.x, 0, point.y))
		if biome == Biomes.Kind.BADLANDS and float(index) / attempts > DRY_GROVE_DENSITY:
			continue
		var variation := (species + 1) % SPECIES.size() if _random.next() < 0.23 else species
		if biome == Biomes.Kind.TUNDRA:
			variation = 0
		var scale: float = _random.between(0.76, 1.18) * size * TREE_SIZE_SCALE
		if not _open(point, CROWNS[variation] * scale):
			continue
		var rotation := Vector3(0, _random.between(0, TAU), _random.between(-0.025, 0.025))
		rotation.z = 0.0 # Keep trunks upright while preserving the seeded random sequence.
		var dimensions := Vector3(scale, scale * _random.between(0.88, 1.15), scale)
		var part: Dictionary = _context.append(SPECIES[variation], Vector3(point.x, 0, point.y), rotation, dimensions)
		if part.instance < 0:
			continue
		_context.register_prop("tree", point.x, point.y, scale, {"parts": [part]}, {"vegetation": true, "species": SPECIES[variation], "solid": false, "salvage": 1 if _random.next() < 0.12 else 0})
		_occupy(point, CROWNS[variation] * scale)
		_count += 1
		planted += 1
	if planted >= 3:
		_groves += 1

func _open(point: Vector2, crown: float) -> bool:
	if not _context.open_dressing_point(point.x, point.y, 12.0, 28.0):
		return false
	if _context.near_village(point.x, point.y, 32.0):
		return false
	# Small gaps between nearby crowns preserve side routes through each grove.
	var cell := Vector2i(floori(point.x / GRID_SIZE), floori(point.y / GRID_SIZE))
	for z in range(cell.y - 2, cell.y + 3):
		for x in range(cell.x - 2, cell.x + 3):
			for obstacle: Dictionary in _occupied.get(Vector2i(x, z), []):
				var clearance := crown * 0.65 + float(obstacle.radius) * 0.65 + 2.0
				if point.distance_squared_to(obstacle.point) < clearance * clearance:
					return false
	return true

func _occupy(point: Vector2, radius: float) -> void:
	var cell := Vector2i(floori(point.x / GRID_SIZE), floori(point.y / GRID_SIZE))
	if not _occupied.has(cell):
		_occupied[cell] = []
	_occupied[cell].append({"point": point, "radius": radius})

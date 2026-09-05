extends "res://tests/world_generation_test.gd"
const Context = preload("res://modules/world/generation/generation_context.gd")
const Rocks = preload("res://modules/world/generation/rock_formations.gd")
const Natural = preload("res://modules/world/generation/natural_props.gd")
class OpenContext extends Context:
	func open_dressing_point(_x: float, _z: float, _road: float = 8, _start: float = 16) -> bool:
		return true

func _initialize() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/natural_props.json"))
	for fixture: Dictionary in fixtures:
		var context := OpenContext.new()
		context.setup(int(fixture.seed))
		var natural := Natural.new()
		natural.setup(context)
		natural.tree(123.456, -27.821, 1.2)
		natural.tree(-87.321, 41.205, 0.78, true)
		natural.boulder(72.961, 221.884, 1.3)
		natural.scrub(-60.543, 91.319, 0.8, true)
		natural.dead_tree(45.678, -72.91, 1.05)
		natural.fence(72.882, -141.137, 1.3, 6)
		natural.ground_cover(77, -31, 9, 20, true)
		var rocks := Rocks.new()
		rocks.setup(context)
		rocks.create(fixture.formation)
		compare(context.rock_obstacles, fixture.rockObstacles, "source formation collision")
		compare(context.random.state, fixture.state, "natural exact RNG state")
		var legacy_props: Array = context.props.filter(func(prop: Dictionary) -> bool: return not prop.get("rock_obstacle", false))
		compare(legacy_props.size(), fixture.props.size(), "original prop count")
		for index in mini(legacy_props.size(), fixture.props.size()):
			var actual: Dictionary = legacy_props[index]
			var expected: Dictionary = fixture.props[index]
			for key in ["id", "kind", "radius", "hp", "salvage"]:
				compare(actual[key], expected[key], "prop %d %s" % [index, key])
			compare(actual.position.x, expected.x, "prop x")
			compare(actual.position.z, expected.z, "prop z")
		for pool: String in fixture.instances:
			compare(context.instances[pool].size(), fixture.instances[pool].size(), "instance count " + pool)
			for index in mini(context.instances[pool].size(), fixture.instances[pool].size()):
				var transform: Transform3D = context.instances[pool][index]
				var matrix := [transform.basis.x.x, transform.basis.x.y, transform.basis.x.z, 0, transform.basis.y.x, transform.basis.y.y, transform.basis.y.z, 0, transform.basis.z.x, transform.basis.z.y, transform.basis.z.z, 0, transform.origin.x, transform.origin.y, transform.origin.z, 1]
				compare(matrix, fixture.instances[pool][index], "source matrix " + pool, 0.00015)
	print("Natural props: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree
const Layout = preload("res://modules/world/generation/layout_generator.gd")
const Manifest = preload("res://modules/world/generation/collision_manifest.gd")
const Roads = preload("res://presentation/world/road_view.gd")
const Steering = preload("res://modules/world/navigation/rock_steering.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world_generation.json"))
	for fixture: Dictionary in golden.fixtures:
		var widened: Dictionary = fixture.layout.duplicate(true)
		for road: Dictionary in widened.roads:
			road.width *= Layout.ROAD_WIDTH_SCALE
		compare(Layout.generate(int(fixture.seed)), widened, "layout:" + str(fixture.seed))
		for index in fixture.layout.roads.size():
			var road: Dictionary = fixture.layout.roads[index]
			var actual := Roads.ribbon_data(road.points, road.width)
			var expected: Dictionary = fixture.roads[index]
			for vertex in actual.positions.size():
				compare(actual.positions[vertex].x, expected.positions[vertex * 3], "road:x", 0.0001)
				compare(actual.positions[vertex].z, expected.positions[vertex * 3 + 2], "road:z", 0.0001)
				compare(actual.uvs[vertex].x, expected.uvs[vertex * 2], "road:u", 0.0001)
				compare(actual.uvs[vertex].y, expected.uvs[vertex * 2 + 1], "road:v", 0.0001)
				compare(actual.sides[vertex].x, expected.sides[vertex], "road:side")
			for triangle in actual.indices.size() / 3:
				compare(actual.indices[triangle * 3], expected.indices[triangle * 3], "road:index0")
				compare(actual.indices[triangle * 3 + 2], expected.indices[triangle * 3 + 1], "road:index1 reversed winding")
				compare(actual.indices[triangle * 3 + 1], expected.indices[triangle * 3 + 2], "road:index2 reversed winding")
		compare(Manifest.generate(int(fixture.seed)), fixture.collision, "collision:" + str(fixture.seed))
	var field := Steering.new()
	field.setup(golden.rocks)
	for sample: Dictionary in golden.steering:
		var enemy := {"position": Vector3(sample.position.x, 0, sample.position.z), "radius": sample.radius}
		var result := field.direction(enemy, Vector3(sample.desired.x, 0, sample.desired.z), sample.speed)
		compare(result.x, sample.result.x, "steering:x", 0.000001)
		compare(result.z, sample.result.z, "steering:z", 0.000001)
	print("World generation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func compare(actual: Variant, expected: Variant, label: String, tolerance: float = 0.00000001) -> void:
	if expected is Dictionary:
		if not actual is Dictionary or actual.size() != expected.size():
			fail(label + " dictionary keys")
			return
		for key: String in expected:
			if not actual.has(key):
				fail(label + " missing " + key)
				return
			compare(actual[key], expected[key], label + ":" + key, tolerance)
	elif expected is Array:
		if not actual is Array or actual.size() != expected.size():
			fail(label + " size actual=" + str(actual.size()) + " expected=" + str(expected.size()))
			return
		for index in expected.size():
			compare(actual[index], expected[index], label + ":" + str(index), tolerance)
	elif expected is float or expected is int:
		checks += 1
		if absf(float(actual) - float(expected)) > tolerance:
			failures += 1
			if failures < 12: push_error(label + " actual=" + str(actual) + " expected=" + str(expected))
	else:
		checks += 1
		if actual != expected: fail(label + " actual=" + str(actual) + " expected=" + str(expected))

func fail(message: String) -> void:
	failures += 1
	if failures < 12: push_error(message)

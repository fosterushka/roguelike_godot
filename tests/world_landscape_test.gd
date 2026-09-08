extends SceneTree

const Day = preload("res://modules/world/day_cycle.gd")
const Biomes = preload("res://modules/world/biome_rules.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const Layout = preload("res://modules/world/generation/layout_generator.gd")
const Rocks = preload("res://presentation/world/rock_meshes.gd")
const WeatherView = preload("res://presentation/world/weather_view.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	var noon := (0.25 - Day.START_PHASE) * Day.CYCLE_SECONDS
	var midnight := (0.75 - Day.START_PHASE) * Day.CYCLE_SECONDS
	check(Day.sample(noon).daylight == 1.0 and Day.sample(midnight).daylight == 0.0, "Clock reaches full day and full night within one run")
	check(is_equal_approx(Day.sample(midnight).light, Day.sample(midnight + Day.CYCLE_SECONDS).light), "Day cycle wraps deterministically")
	var previous: Dictionary = Day.sample(0)
	var continuous := true
	for frame in 4800:
		var next := Day.sample(frame * 0.1)
		continuous = continuous and absf(float(next.light) - float(previous.light)) < 0.01
		previous = next
	check(continuous, "Dawn and dusk never switch brightness abruptly")
	check(Biomes.kind_at(Vector3.ZERO) == Biomes.Kind.MEADOW, "Starting region remains meadow")
	check(Biomes.kind_at(Vector3(650, 0, 0)) == Biomes.Kind.BADLANDS and Biomes.kind_at(Vector3(-650, 0, 0)) == Biomes.Kind.TUNDRA, "Exploration reaches arid badlands and cold tundra")
	check(Biomes.tint_at(Vector3(650, 0, 0)) != Biomes.tint_at(Vector3(-650, 0, 0)), "Regional vegetation palettes differ")
	var layout := Layout.generate(72841)
	check(layout.roads.all(func(road: Dictionary) -> bool: return road.width >= 8.784 and road.width <= 12.444), "Roads widen 22 percent across all generated routes")
	Terrain.configure({}, [{"points": [{"x": -50, "z": 0}, {"x": 50, "z": 0}], "width": 12.0}])
	check(absf(Terrain.height_at(0, 0)) < 0.001 and absf(Terrain.height_at(25, 4)) < 0.001, "Wider roads preserve their flat driving surface")
	var minimum := INF
	var maximum := -INF
	for x in range(100, 450, 7):
		for z in range(100, 450, 7):
			minimum = minf(minimum, Terrain.height_at(x, z))
			maximum = maxf(maximum, Terrain.height_at(x, z))
	check(maximum - minimum > 4.0, "Off-road terrain has meaningful physical mounds and hollows")
	for pool: String in ["rockInstances", "stoneInstances"]:
		var mesh := Rocks.mesh_for(pool)
		check(mesh.surface_get_material(0) is ShaderMaterial and mesh.surface_get_material(0).shader == Rocks.ROCK_SHADER, "Small stone uses seam-free object-space surface detail")
		check(mesh == Rocks.mesh_for(pool), "Stone detail preserves shared mesh/material cache")
	var arena := Node3D.new()
	root.add_child(arena)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	arena.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "WastelandSun"
	arena.add_child(sun)
	var vehicle := CharacterBody3D.new()
	arena.add_child(vehicle)
	var view := WeatherView.new()
	arena.add_child(view)
	view.setup(arena, vehicle)
	var state := {"weather": {"type": "rainy", "elapsed": 100.0}, "elapsed": 100.0, "game_time": noon, "tornado": {}, "mud_zones": []}
	view.apply_state(state)
	var day_energy := sun.light_energy
	var day_rain: float = view._rain.rain
	state.game_time = midnight
	view.apply_state(state)
	check(sun.light_energy >= day_energy * 0.4 and sun.light_energy < day_energy * 0.65, "Night retains readable directional light while remaining dimmer than day")
	check(env.environment.ambient_light_energy >= 0.5 and env.environment.ambient_light_energy < Day.DAY_AMBIENT, "Night keeps shadows readable")
	check(sun.light_color.b > sun.light_color.r * 1.5 and env.environment.ambient_light_color.b > env.environment.ambient_light_color.r * 1.5, "Moon and ambient illumination share the blue night tint")
	check(view._rain.rain == day_rain, "Day/night keeps active weather precipitation intact")
	check(env.environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "Clock avoids per-tick sky cubemap regeneration")
	arena.free()
	print("World landscape: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

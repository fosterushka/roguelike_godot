extends SceneTree

const Rain = preload("res://presentation/world/weather_particles.gd")
const OUTPUT := "/private/tmp/iron-rain-coverage-"
const GRID := 3
const PIXEL_STEP := 2
const MIN_SECTOR_PIXELS := 20
var rain: Node3D
var camera: Camera3D
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	root.add_child(environment)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(camera)
	camera.current = true
	rain = Rain.new()
	root.add_child(rain)
	var scenarios := [
		{"id": "normal", "viewport": Vector2i(1280, 720), "zoom": 62.0, "focus": Vector3.ZERO, "mix": Vector4(0, 0, 1, 0)},
		{"id": "ultrawide", "viewport": Vector2i(1920, 720), "zoom": 62.0, "focus": Vector3.ZERO, "mix": Vector4(0, 0, 0, 1)},
		{"id": "zoom-drag", "viewport": Vector2i(1920, 720), "zoom": 120.0, "focus": Vector3(70, 0, -50), "mix": Vector4(0, 0, 1, 0)},
	]
	for scenario: Dictionary in scenarios:
		root.size = scenario.viewport
		camera.size = scenario.zoom
		camera.position = scenario.focus + Vector3(34, 45, 34)
		camera.look_at(scenario.focus)
		rain.clear()
		rain.set_mix(scenario.mix)
		rain.advance(1.25, Vector3.ZERO, Vector3(20, 0, 15), Vector3(0.6, 0, 0.8), 30)
		# Measure actual falling rain separately from world mist, splashes and lens droplets.
		rain.layers[1].visible = false
		rain.layers[2].visible = false
		var frame := await _frame(str(scenario.id))
		var sectors := _sectors(frame)
		print("RAIN_COVERAGE ", scenario.id, " sectors=", sectors)
		for count: int in sectors:
			check(count >= MIN_SECTOR_PIXELS, "%s has visible rain in every screen sector" % scenario.id)
		var frozen := await _frame(str(scenario.id) + "-paused")
		check(frame.get_data() == frozen.get_data(), "Frozen rain time retains identical rendered positions")
	# An opaque surface closer than the whole rain volume must occlude every streak.
	var blocker := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(camera.size * float(root.size.x) / root.size.y, camera.size) * 1.2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.BLACK
	quad.material = material
	blocker.mesh = quad
	camera.add_child(blocker)
	blocker.position.z = -Rain.RAIN_DEPTH_RANGE.x * 0.5
	var covered := await _frame("occluded")
	var visible_pixels := 0
	for count: int in _sectors(covered):
		visible_pixels += count
	check(visible_pixels == 0, "Opaque geometry occludes rain behind it without depth leaks")
	for child in root.get_children():
		child.queue_free()
	await process_frame
	await process_frame
	print("Rain coverage: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _frame(id: String) -> Image:
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	check(result.save_png(OUTPUT + id + ".png") == OK, "Rain capture saved")
	return result

func _sectors(frame: Image) -> PackedInt32Array:
	var sectors := PackedInt32Array()
	sectors.resize(GRID * GRID)
	for y in range(0, frame.get_height(), PIXEL_STEP):
		for x in range(0, frame.get_width(), PIXEL_STEP):
			if frame.get_pixel(x, y).r > 0.025:
				var column := mini(GRID - 1, x * GRID / frame.get_width())
				var row := mini(GRID - 1, y * GRID / frame.get_height())
				sectors[row * GRID + column] += 1
	return sectors

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

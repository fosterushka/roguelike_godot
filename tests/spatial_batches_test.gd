extends SceneTree

const Batches = preload("res://presentation/world/spatial_batches.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	var source := MultiMeshInstance3D.new()
	source.multimesh = MultiMesh.new()
	source.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	source.multimesh.mesh = BoxMesh.new()
	source.multimesh.use_colors = true
	source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(source)
	var poses: Array = []
	var colors: Array = []
	var props: Array = []
	var size := Batches.CHUNK_SIZE
	for x in [-size - 1.0, -size, -1.0, 0.0, size - 1.0, size, size * 16.0]:
		poses.append(Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)))
		colors.append(Color(0.3, 0.5, 0.2))
		props.append({"id": str(x), "parts": [{"mesh": 0, "instance": poses.size() - 1, "matrix": [x]}]})
	var expected := [-2, -1, -1, 0, 0, 1, 16]
	for index in poses.size():
		check(Batches.cell(poses[index].origin).x == expected[index], "negative and positive floor boundaries")
	var mesh: Mesh = source.multimesh.mesh
	var mapping := Batches.split(world, source, poses, colors)
	Batches.remap_props(props, {0: mapping})
	check(world.get_child_count() == 5, "only occupied cells create batches")
	var total := 0
	for batch: MultiMeshInstance3D in world.get_children():
		total += batch.multimesh.instance_count
		check(batch.multimesh.mesh == mesh, "mesh remains shared")
		check(batch.cast_shadow == source.cast_shadow, "shadow policy preserved")
	check(total == poses.size(), "no missing or duplicated instances")
	var slots := {}
	for index in props.size():
		var part: Dictionary = props[index].parts[0]
		var key := Vector2i(part.mesh, part.instance)
		check(not slots.has(key), "destruction mapping is one-to-one")
		slots[key] = true
		check(part.matrix == [poses[index].origin.x], "restore matrix is unchanged")
		if DisplayServer.get_name() != "headless":
			var batch: MultiMeshInstance3D = world.get_child(part.mesh)
			check(batch.multimesh.get_instance_transform(part.instance) == poses[index], "render transform preserved")
			check(batch.multimesh.get_instance_color(part.instance).is_equal_approx(colors[index]), "biome tint preserved")
	world.free()
	print("Spatial batches: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

extends Node

const Main = preload("res://app/main.tscn")
const Weather = preload("res://modules/world/weather_rules.gd")
var game: Node
var captured := 0
var measurements: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	game = Main.instantiate()
	game.profile_path = "/private/tmp/iron-natural-capture-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	for candidate in [72841, 42, 1, 7, 197, 0, 20]:
		if Weather.phase_at(candidate, 0.0).type == "sunny":
			game.run_seed_override = candidate
			break
	get_tree().root.add_child(game)
	await game.game_ready
	await game.restart_run()
	for node: Node in [game, game.session_flow, game.combat, game.world, game.vehicle]:
		node.set_physics_process(false)
	game.sound.set_running(false)
	game.hud.visible = false
	game.camera.set_process(false)
	game.camera._intro = 0.0
	game.camera.h_offset = 0.0
	game.camera.v_offset = 0.0
	var rocks: Array = game.arena.world_layout.rockObstacles.duplicate()
	rocks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a.x, a.z).length_squared() < Vector2(b.x, b.z).length_squared())
	var rock: Dictionary = rocks[0]
	var point := Vector3(rock.x, 3, rock.z)
	_view(point, 27)
	await _measure("first_rock_view")
	await _capture("rock-close")
	_view(point, 65)
	await _capture("rock-landscape")
	_view(Vector3(0, 0, 22), 105)
	await _capture("start-groves")
	var grove_point := Vector3.ZERO
	var best_count := 0
	var trees: Array = game.arena.world_layout.props.filter(func(prop: Dictionary) -> bool: return prop.get("vegetation", false))
	for index in range(0, trees.size(), 15):
		var candidate := Vector3(trees[index].position.x, 0, trees[index].position.z)
		if candidate.length() > 430:
			continue
		var count := 0
		for tree: Dictionary in trees:
			count += int(Vector2(tree.position.x - candidate.x, tree.position.z - candidate.z).length() < 24)
		if count > best_count:
			best_count = count
			grove_point = candidate
	_view(grove_point, 70)
	await _measure("dense_forest")
	await _capture("forest")
	_view(point, 27)
	await _measure("revisited_rock")
	var part: Dictionary = game.arena._prop_records[str(rock.id)].parts[0]
	var batch: MultiMeshInstance3D = game.arena.source_world.get_child(int(part.mesh))
	var original := batch.multimesh.get_instance_transform(int(part.instance))
	assert(absf(original.basis.determinant()) > 0.01, "Live rock mesh is present")
	game.world.damage_props(Vector3(rock.x, 0, rock.z), 0.1, 10000)
	assert(is_zero_approx(batch.multimesh.get_instance_transform(int(part.instance)).basis.determinant()), "Destroyed rock mesh disappears")
	await _capture("rock-destroyed")
	game.world.reset_run()
	assert(batch.multimesh.get_instance_transform(int(part.instance)).is_equal_approx(original), "Rock mesh restores exactly")
	await _capture("rock-restored")
	var legacy: Dictionary = game.arena.world_layout.props.filter(func(prop: Dictionary) -> bool: return prop.kind == "tree" and not prop.get("vegetation", false))[0]
	var tree_part: Dictionary = legacy.parts[0]
	var tree_batch: MultiMeshInstance3D = game.arena.source_world.get_child(int(tree_part.mesh))
	var tree_pose := tree_batch.multimesh.get_instance_transform(int(tree_part.instance))
	assert(str(tree_batch.name) in ["spruceTrees", "birchTrees"], "Legacy tree renders one retained species")
	assert(legacy.parts.size() == 1 and absf(tree_pose.basis.determinant()) > 0.01, "Legacy tree has one live replacement mesh")
	var tree_point := Vector3(legacy.position.x, 0, legacy.position.z)
	_view(tree_point, 24)
	await _capture("legacy-tree")
	game.world.damage_props(tree_point, 0.1, 10000)
	assert(is_zero_approx(tree_batch.multimesh.get_instance_transform(int(tree_part.instance)).basis.determinant()), "Destroyed legacy tree replacement disappears")
	await _capture("legacy-tree-destroyed")
	game.world.reset_run()
	assert(tree_batch.multimesh.get_instance_transform(int(tree_part.instance)).is_equal_approx(tree_pose), "Legacy tree replacement restores exactly")
	var file := FileAccess.open("/private/tmp/iron-natural-render.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(), "seed": game.run_seed, "trees": trees.size(), "measurements": measurements, "notes": "Static actual-world views after covered warmup; gameplay physics frozen. Frame intervals include CPU/GPU sync and display pacing. Imported caches present. These are not a full combat performance benchmark."}, "\t"))
	file.close()
	print("NATURAL_WORLD_CAPTURE_COMPLETE: %d images seed=%d trees=%d dense_grove=%d" % [captured, game.run_seed, trees.size(), best_count])
	game.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	get_tree().quit()

func _view(point: Vector3, span: float) -> void:
	game.camera.size = span
	game.camera.global_position = point + Vector3(32, 39, 32)
	game.camera.look_at(point)

func _capture(id: String) -> void:
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame := get_tree().root.get_texture().get_image()
	print("NATURAL_CAPTURE %s status=%d" % [id, frame.save_png("/private/tmp/iron-natural-%s.png" % id)])
	captured += 1

func _measure(label: String) -> void:
	var values: Array[float] = []
	var previous := Time.get_ticks_usec()
	var calls := 0
	for index in 60:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		values.append((now - previous) / 1000.0)
		previous = now
		calls = maxi(calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		await get_tree().process_frame
	var first := values[0]
	values.sort()
	measurements.append({"view": label, "frames": 60, "first_ms": first, "p50_ms": values[29], "p95_ms": values[56], "max_ms": values[-1], "draw_calls": calls})

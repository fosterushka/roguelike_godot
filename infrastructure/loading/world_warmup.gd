extends RefCounted

const Locale = preload("res://presentation/ui/ui_locale.gd")

var rendered_views := 0
var headless := false

func prepare(game: Node3D, progress: Callable) -> bool:
	if not game.get_tree().paused:
		return false
	rendered_views = 0
	headless = DisplayServer.get_name() == "headless"
	var camera: Camera3D = game.camera
	var was_processing := camera.is_processing()
	camera.set_process(false)
	if headless:
		await game.get_tree().process_frame
		camera.set_process(was_processing)
		return true
	var saved_transform := camera.global_transform
	var saved_size := camera.size
	var saved_far := camera.far
	var positions: Array[Vector3] = [game.vehicle.global_position]
	for village: Dictionary in game.arena.world_layout.get("villages", []):
		positions.append(Vector3(float(village.x), 0, float(village.z)))
	for landmark: Dictionary in game.arena.world_layout.get("landmarks", []):
		positions.append(Vector3(float(landmark.get("x", 0)), 0, float(landmark.get("z", 0))))
	# Upload the actual generated MultiMeshes, including distant scenery.
	camera.far = 8000.0
	camera.size = 4000.0
	camera.global_position = Vector3(2000, 3000, 2000)
	camera.look_at(Vector3.ZERO)
	await _render(game)
	camera.size = saved_size
	camera.far = saved_far
	for index in positions.size():
		camera.global_position = positions[index] + Vector3(34, 45, 34)
		camera.look_at(positions[index])
		await _render(game)
		progress.call(Locale.text("Preparing world views"), 0.96 + 0.035 * (index + 1) / float(positions.size()))
	camera.global_transform = saved_transform
	camera.size = saved_size
	camera.far = saved_far
	await _render(game)
	camera.set_process(was_processing)
	return true

func _render(game: Node) -> void:
	await RenderingServer.frame_post_draw
	await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	rendered_views += 1

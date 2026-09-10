extends SceneTree

const Radar = preload("res://presentation/ui/radar.gd")
const Generator = preload("res://modules/world/generation/world_generator.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
var output := "/tmp/radar-culling-render"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Requires actual rendering")
		quit(1)
		return
	var baseline: Script
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("baseline="):
			baseline = load(argument.trim_prefix("baseline="))
		elif argument.begins_with("output="):
			output = argument.trim_prefix("output=")
	assert(baseline != null, "Supply the original radar script for pixel comparison")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 800)
	var context := Generator.generate(72841, Authored.new())
	var roads: Array = []
	for road: Dictionary in context.layout.roads:
		roads.append(road.points)
	var before: Control = baseline.new()
	var after := Radar.new()
	for radar: Control in [before, after]:
		root.add_child(radar)
		radar.position = Vector2(10, 10)
		radar.size = Vector2(176, 208)
		radar.layout = {"roads": roads, "villages": context.villages, "landmarks": context.landmarks}
		radar.cells.fill(0)
		radar.reveal(Vector3.ZERO, 170.0)
		radar.reveal(Vector3(140, 0, 80), 80.0)
		radar.state = {"player": {"position": Vector3.ZERO, "hp": 100.0}, "enemies": []}
	var failures := 0
	for index in 3:
		for radar: Control in [before, after]:
			radar._heading = index * PI * 0.25
			radar.display_range = [64.0, 192.0, 256.0][index]
			if index == 2:
				radar.cells.fill(1)
		before.show()
		after.hide()
		before.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var original := root.get_texture().get_image()
		original.save_png(output.path_join("before-%d.png" % index))
		before.hide()
		after.show()
		after.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var optimized := root.get_texture().get_image()
		optimized.save_png(output.path_join("after-%d.png" % index))
		if original.get_data() != optimized.get_data():
			failures += 1
			push_error("Radar pixels differ in view %d" % index)
	for group: Node3D in context.groups:
		group.free()
	before.queue_free()
	after.queue_free()
	await process_frame
	print("Radar culling render: %d failures" % failures)
	quit(1 if failures else 0)

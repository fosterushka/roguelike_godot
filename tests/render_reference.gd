extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var center := Vector3(0, 0, 5)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("x="):
			center.x = argument.trim_prefix("x=").to_float()
		elif argument.begins_with("z="):
			center.z = argument.trim_prefix("z=").to_float()
	var arena := preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	for argument in OS.get_cmdline_user_args():
		var pair := argument.split("=", true, 1)
		if pair.size() != 2:
			continue
		for child in arena.get_children():
			if child is WorldEnvironment:
				if pair[0] == "exposure": child.environment.tonemap_exposure = pair[1].to_float()
				if pair[0] == "ambient": child.environment.ambient_light_energy = pair[1].to_float()
				if pair[0] == "fog": child.environment.fog_density = pair[1].to_float()
			elif child is DirectionalLight3D:
				if pair[0] == "sun" and child.name == "WastelandSun": child.light_energy = pair[1].to_float()
				if pair[0] == "rim" and child.name == "WastelandRim": child.light_energy = pair[1].to_float()
	var vehicle := preload("res://presentation/vehicles/vehicle_view.gd").new()
	root.add_child(vehicle)
	vehicle.position.y = 0.04
	vehicle.apply_player_state({"modules": [{"type": "assaultRifle", "mount": {"carrierId": "crawler", "slot": 0}}], "carriers": [], "evolution_tier": 1}, 1)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 62
	root.add_child(camera)
	camera.position = center + Vector3(34, 45, 34)
	camera.look_at(center)
	camera.current = true
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("/private/tmp/iron-caravan-godot-reference.png")
	print("REFERENCE_CAPTURE status=%d camera=%s center=%s" % [result, camera.position, center])
	quit(result)

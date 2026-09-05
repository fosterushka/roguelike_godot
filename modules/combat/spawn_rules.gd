extends RefCounted

static func valid(model, point: Vector3, minimum: float) -> bool:
	if Vector2(point.x, point.z).length() > model.Waves.radius(model.wave) - 40.0 or point.distance_to(model.player.position) < minimum:
		return false
	if model.spawn_validity_query.is_valid() and not model.spawn_validity_query.call(point, 2.5):
		return false
	return not model.spawn_visibility_query.is_valid() or model.spawn_visibility_query.call(point)

static func wave_position(model, kind: String) -> Variant:
	var infantry: bool = model.Enemies.DEFINITIONS[kind].type == "soldier"
	var minimum := 180.0 if kind == "leviathan" else 62.0 if infantry else 85.0
	var maximum := 650.0 if kind == "leviathan" else 92.0 if infantry else 260.0
	for attempt in range(48):
		var angle: float = model.random.randf_range(0.0, TAU)
		var point: Vector3 = model.player.position + Vector3(cos(angle), 0.0, sin(angle)) * model.random.randf_range(minimum, maximum)
		if valid(model, point, minimum):
			return point
	var start_angle: float = model.random.randf_range(0.0, TAU)
	var limit: float = minf((model.Waves.radius(model.wave) - 40.0) * 2.0, maxf(maximum, minimum + 180.0))
	var distance := minimum
	while distance <= limit:
		for sector in range(32):
			var angle := start_angle + sector / 32.0 * TAU
			var point: Vector3 = model.player.position + Vector3(cos(angle), 0.0, sin(angle)) * distance
			if valid(model, point, minimum):
				return point
		distance += 18.0
	for sector in range(128):
		var angle := start_angle + sector / 128.0 * TAU
		var point: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * (model.Waves.radius(model.wave) - 40.0)
		if valid(model, point, minimum):
			return point
	return null

static func capacity(enemies: Array[Dictionary], kind: String, definitions: Dictionary) -> bool:
	var type: String = definitions[kind].type
	var count := 0
	for enemy: Dictionary in enemies:
		if enemy.dead:
			continue
		if type == "priorityVehicle" and enemy.kind == kind:
			return false
		if (type in ["priorityVehicle", "bike", "buggy"] and enemy.type in ["priorityVehicle", "bike", "buggy"]) or (type in ["soldier", "drone"] and enemy.type == type):
			count += 1
	return count < (84 if type == "soldier" else 12 if type == "drone" else 10) if type in ["soldier", "drone", "priorityVehicle", "bike", "buggy"] else true

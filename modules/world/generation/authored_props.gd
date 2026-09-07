extends "res://modules/world/generation/authored_monuments.gd"

const Wildlife = preload("res://modules/world/wildlife_rules.gd")

func utility_pole(x: float, z: float, size: float = 1, angle: float = NAN) -> void:
	if is_nan(angle):
		angle = rng.between(0, TAU)
	var group := _group(x, z, angle, size)
	_quality(group, "utility_pole")
	rng.next() # Preserve the legacy detail-choice draw.
	_finish(group)
	ctx.register_prop("streetlight", x, z, size, {"groups": [group]})

func wreck(x: float, z: float, size: float = 1) -> void:
	var group := _group(x, z, 0, size)
	rng.between(-0.12, 0.12)
	rng.between(-0.5, 0.5)
	_quality(group, "wreck")
	group.rotation.y = rng.between(0, TAU)
	_finish(group)
	ctx.register_prop("wreck", x, z, size, {"groups": [group]}, {"salvage": 2})

func prop_cluster(x: float, z: float, size: float = 1) -> void:
	var index := 0
	while index < rng.integer(2, 5):
		var px: float = x + rng.between(-2.1, 2.1)
		var pz: float = z + rng.between(-2.1, 2.1)
		var angle: float = rng.between(0, TAU)
		var pick: float = rng.next()
		if pick < 0.68:
			var kind := "barrel" if pick < 0.34 else "crate"
			var part: Dictionary = ctx.append(kind + "Instances", Vector3(px, 0.4, pz), Vector3(0, angle, 0), Vector3.ONE * size)
			ctx.register_prop(kind, px, pz, size, {"parts": [part]})
		else:
			var group := _group(px, pz, angle, size)
			_quality(group, "loot_scrap")
			_finish(group)
			ctx.register_prop("scrap", px, pz, size, {"groups": [group]}, {"salvage": 1})
		index += 1

func well(x: float, z: float) -> void:
	var group := _group(x, z)
	_quality(group, "well")
	_finish(group)
	ctx.register_prop("well", x, z, 1, {"groups": [group]}, {"salvage": 2})

func market_stall(x: float, z: float, angle: float = 0) -> void:
	var group := _group(x, z, angle)
	rng.next() # Preserve the old canopy-color draw.
	_quality(group, "market_stall")
	_finish(group)
	ctx.register_prop("stall", x, z, 1, {"groups": [group]}, {"salvage": 1})

func windmill(x: float, z: float, angle: float = 0) -> void:
	var group := _group(x, z, angle)
	_quality(group, "windmill")
	var blades := Node3D.new()
	blades.name = "Blades"
	_quality(blades, "windmill_blades")
	blades.position = Vector3(0, 5, 0.65)
	group.add_child(blades)
	_finish(group)
	ctx.ambient_animators.append({"type": "windmill", "object": blades, "speed": rng.between(0.2, 0.42)})
	ctx.register_prop("windmill", x, z, 1, {"groups": [group]}, {"salvage": 4})

func critter(x: float, z: float) -> void:
	# Use a separate stream: adding a flock must not move the rest of the world.
	for _draw in 4:
		rng.next()
	if ctx.ambient_critters.size() >= Wildlife.MAX_SHEEP:
		return
	var saved_state: int = rng.state
	for index in Wildlife.FLOCK_SIZE:
		if ctx.ambient_critters.size() >= Wildlife.MAX_SHEEP:
			break
		var point := Vector2(x, z) + Vector2(index % 3 - 1, index / 3) * Wildlife.FLOCK_SPACING
		if ctx.open_dressing_point(point.x, point.y, 1.0):
			grazer(point.x, point.y)
	rng.state = saved_state

func grazer(x: float, z: float) -> void:
	if ctx.ambient_critters.size() >= Wildlife.MAX_SHEEP:
		for _draw in Wildlife.GRAZER_RANDOM_DRAWS:
			rng.next()
		return
	var group := _group(x, z)
	_quality(group, "grazer")
	group.rotation.y = rng.between(0, TAU)
	_finish(group)
	_ambient("grazer", group, x, z, 0.2, 0.32)

func _ambient(kind: String, group: Node3D, x: float, z: float, minimum: float, maximum: float) -> void:
	ctx.ambient_critters.append({"id": "%s-%03d" % [kind, ctx.ambient_critters.size()], "kind": kind, "dead": false, "group": group, "origin": Vector3(x, 0, z), "heading": rng.between(0, TAU), "phase": rng.between(0, TAU), "speed": rng.between(minimum, maximum), "turn": rng.between(1.5, 4), "activityState": "roaming", "fleeRemaining": 0, "recoveryRemaining": 2})

func house(x: float, z: float, angle: float = 0) -> Node3D:
	var group := _group(x, z, angle)
	group.set_meta("source_x", x)
	group.set_meta("source_z", z)
	_quality(group, "house")
	_finish(group)
	return group

func village(id: String, x: float, z: float, count: int = 4) -> void:
	_finish(_group(x, z))
	var data := {"id": id, "x": x, "z": z, "houses": [], "signalMast": null, "signalLight": null, "deploymentAnchors": [], "consumed": false, "intact": true, "tribute": 28 + count * 5}
	for index in count:
		var angle: float = float(index) / count * TAU + rng.between(-0.3, 0.3)
		var radius: float = rng.between(4, 8)
		var px := x + cos(angle) * radius
		var pz := z + sin(angle) * radius
		var home := house(px, pz, rng.between(0, TAU))
		var size: float = rng.between(0.75, 1.1)
		home.scale = Vector3.ONE * size
		data.houses.append(home)
		ctx.register_prop("building", px, pz, size, {"groups": [home]}, {"salvage": rng.integer(2, 4), "village_id": id})
		ctx.activity_blockers.append({"id": "%s-house-%02d" % [id, index], "x": px, "z": pz, "radius": 2.25 * size})
	var mast := Primitives.create("cylinder", [0.08, 0.12, 3.2, 8], "metal", Vector3(x, 1.6, z))
	var light := Primitives.create("sphere", [0.2], "enemyRed", Vector3(x, 3.25, z))
	ctx.groups.append(mast)
	ctx.groups.append(light)
	data.signalMast = mast
	data.signalLight = light
	ctx.register_prop("signal", x, z, 1, {"groups": [mast, light]})
	for index in 8:
		var angle := float(index) / 8 * TAU
		data.deploymentAnchors.append({"id": "%s-deployment-%02d" % [id, index], "x": x + cos(angle) * 15, "z": z + sin(angle) * 15})
	ctx.villages.append(data)

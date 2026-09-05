extends "res://modules/world/generation/authored_monuments.gd"

func utility_pole(x: float, z: float, size: float = 1, angle: float = NAN) -> void:
	if is_nan(angle):
		angle = rng.between(0, TAU)
	var group := _group(x, z, angle, size)
	_box(group, [0.24, 3.5, 0.24], "iron", Vector3(0, 1.75, 0))
	_box(group, [1.6, 0.14, 0.14], "metal", Vector3(0, 2.75, 0))
	_shape(group, "cone", [0.28, 0.42, 5], "gold", Vector3(0.55, 2.45, 0))
	_box(group, [1.25, 0.04, 0.04], "woodDark", Vector3(0, 2.72, 0), Vector3(0, 0, 0.12))
	if rng.next() < 0.55:
		_box(group, [0.78, 0.48, 0.08], "enemyRed", Vector3(-0.45, 1.8, 0), Vector3(0, 0, -0.18))
	_finish(group)
	ctx.register_prop("streetlight", x, z, size, {"groups": [group]})

func wreck(x: float, z: float, size: float = 1) -> void:
	var group := _group(x, z, 0, size)
	_box(group, [1.45, 0.6, 2.2], "stoneDark", Vector3(0, 0.32, 0), Vector3(0, 0, rng.between(-0.12, 0.12)))
	_box(group, [0.95, 0.55, 1], "metal", Vector3(0.18, 0.76, -0.2))
	_box(group, [0.7, 0.18, 0.5], "enemyRed", Vector3(-0.4, 0.9, 0.55), Vector3(0, rng.between(-0.5, 0.5), 0))
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
			_box(group, [0.9, 0.22, 1.1], "iron", Vector3(0, 0.15, 0))
			_box(group, [0.55, 0.34, 0.38], "enemyRed", Vector3(0.12, 0.43, -0.08))
			_finish(group)
			ctx.register_prop("scrap", px, pz, size, {"groups": [group]}, {"salvage": 1})
		index += 1

func well(x: float, z: float) -> void:
	var group := _group(x, z)
	_shape(group, "cylinder", [1, 1.2, 2.2, 10], "metal", Vector3(0, 1.1, 0))
	_shape(group, "cylinder", [1.08, 1.08, 0.12, 10], "iron", Vector3(0, 2.18, 0))
	for side in [-1, 1]:
		_box(group, [0.16, 1.6, 0.16], "woodDark", Vector3(side * 0.7, 0.8, 0))
	_shape(group, "cylinder", [0.1, 0.1, 1.7, 6], "iron", Vector3(0.9, 1.4, 0.1), Vector3(0, 0, PI / 2))
	_shape(group, "sphere", [0.12], "gold", Vector3(1.72, 1.4, 0.1))
	_finish(group)
	ctx.register_prop("well", x, z, 1, {"groups": [group]}, {"salvage": 2})

func market_stall(x: float, z: float, angle: float = 0) -> void:
	var group := _group(x, z, angle)
	_box(group, [2.5, 0.24, 1.4], "woodDark", Vector3(0, 0.84, 0))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(group, [0.12, 2.1, 0.12], "iron", Vector3(sx * 1.08, 1.2, sz * 0.54))
	_box(group, [2.9, 0.16, 1.66], "clothRed" if rng.next() < 0.5 else "clothBlue", Vector3(0, 2.15, 0), Vector3(0, 0, 0.03))
	for index in 3:
		_box(group, [0.48, 0.38, 0.48], "wood", Vector3(-0.6 + index * 0.6, 1.18, 0.05))
	_finish(group)
	ctx.register_prop("stall", x, z, 1, {"groups": [group]}, {"salvage": 1})

func windmill(x: float, z: float, angle: float = 0) -> void:
	var group := _group(x, z, angle)
	_box(group, [1.45, 5.9, 1.45], "iron", Vector3(0, 2.95, 0))
	for tilt in [0.45, -0.45]:
		_box(group, [2.2, 0.18, 0.18], "metal", Vector3(0, 3.2, 0), Vector3(0, 0, tilt))
	var blades := Node3D.new()
	blades.name = "Blades"
	for index in 3:
		var blade := Node3D.new()
		blade.rotation_order = EULER_ORDER_XYZ
		blade.rotation.z = index * (TAU / 3)
		_box(blade, [0.16, 2.1, 0.12], "metal", Vector3(0, 1.05, 0))
		_box(blade, [0.34, 1.05, 0.08], "enemyRed", Vector3(0, 1.55, 0))
		blades.add_child(blade)
	blades.position = Vector3(0, 5, 0.65)
	group.add_child(blades)
	_box(group, [1.8, 1.1, 1.3], "stoneDark", Vector3(0, 1.1, 0.05))
	_shape(group, "cylinder", [0.28, 0.28, 1.3, 8], "metal", Vector3(0.85, 1.45, -0.25))
	_finish(group)
	ctx.ambient_animators.append({"type": "windmill", "object": blades, "speed": rng.between(0.2, 0.42)})
	ctx.register_prop("windmill", x, z, 1, {"groups": [group]}, {"salvage": 4})

func critter(_x: float, _z: float) -> void:
	# Retired decorative humans retain their four draws so existing seeds keep prop placement.
	for _draw in 4:
		rng.next()

func grazer(x: float, z: float) -> void:
	var group := _group(x, z)
	_shape(group, "sphere", [0.55], "sheep", Vector3(0, 0.72, 0), Vector3.ZERO, Vector3(1.35, 0.78, 0.72))
	_shape(group, "sphere", [0.28], "stoneDark", Vector3(0, 0.78, 0.67))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(group, [0.09, 0.55, 0.09], "woodDark", Vector3(sx * 0.32, 0.3, sz * 0.3))
	group.rotation.y = rng.between(0, TAU)
	_finish(group)
	_ambient("grazer", group, x, z, 0.2, 0.32)

func _ambient(kind: String, group: Node3D, x: float, z: float, minimum: float, maximum: float) -> void:
	ctx.ambient_critters.append({"id": "%s-%03d" % [kind, ctx.ambient_critters.size()], "group": group, "origin": Vector3(x, 0, z), "heading": rng.between(0, TAU), "phase": rng.between(0, TAU), "speed": rng.between(minimum, maximum), "turn": rng.between(1.5, 4), "activityState": "roaming", "fleeRemaining": 0, "recoveryRemaining": 2})

func house(x: float, z: float, angle: float = 0) -> Node3D:
	var group := _group(x, z, angle)
	group.set_meta("source_x", x)
	group.set_meta("source_z", z)
	_box(group, [3, 1.8, 2.8], "stoneDark", Vector3(0, 0.95, 0))
	_box(group, [1.6, 0.16, 2.2], "metal", Vector3(-1.55, 1.45, 0.12), Vector3(0, 0, -0.28))
	_box(group, [3.35, 0.16, 3.05], "metal", Vector3(0, 1.95, 0), Vector3(0, 0, 0.08))
	_box(group, [1.15, 0.08, 1.4], "enemyRed", Vector3(0.65, 2.1, -0.3), Vector3(0, 0, -0.12))
	_box(group, [1, 0.07, 1.05], "woodDark", Vector3(-0.8, 2.05, 0.4), Vector3(0, 0, 0.16))
	_box(group, [0.75, 1.18, 0.14], "woodDark", Vector3(0, 0.6, 1.45))
	_box(group, [0.52, 0.42, 0.08], "goldBright", Vector3(0.92, 1.18, 1.46))
	_shape(group, "cylinder", [0.42, 0.42, 1.5, 8], "metal", Vector3(-1.15, 0.82, -1.05))
	_shape(group, "cylinder", [0.08, 0.08, 1.8, 6], "iron", Vector3(-0.82, 1.95, -0.62))
	_box(group, [0.55, 0.18, 0.55], "woodDark", Vector3(1.1, 2.15, 0.5))
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

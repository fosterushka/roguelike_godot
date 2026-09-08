extends SceneTree
const Suspension = preload("res://modules/caravan/wheel_suspension.gd")
const TERRAIN_FLOAT_TOLERANCE := 0.0001 # Float32 mesh positions across a 3.4 km map.
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const Motion = preload("res://modules/caravan/vehicle_motion.gd")
const MotionState = preload("res://modules/caravan/vehicle_motion_state.gd")
const VisualMotion = preload("res://presentation/vehicles/vehicle_visual_motion.gd")
const Rig = preload("res://presentation/vehicles/wheeled_rig.gd")
const View = preload("res://presentation/vehicles/vehicle_view.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var state := Suspension.create()
	for frame in 360:
		Suspension.step(state, Vector3.ZERO, 0, 0, 0, 1.0 / 60, 1.0, false, func(_x: float, _z: float) -> float: return 0.0)
	check(absf(state.height) < 0.001 and absf(state.velocity) < 0.001 and state.contacts == 4, "Four springs support stationary chassis without artificial bob")
	for frame in 360:
		Suspension.step(state, Vector3.ZERO, 0, 0, 0, 1.0 / 60, 1.0, false, func(x: float, z: float) -> float: return x * 0.08 + z * 0.12)
	check(state.pitch < -0.1 and state.roll > 0.07 and absf(state.wheel_offsets[1] - state.wheel_offsets[2]) < 0.03, "Chassis follows both axes of the support plane")
	check(state.contacts >= 2 and absf(state.height) < Suspension.TRAVEL, "Tilted chassis remains supported within suspension travel on a two-axis slope")
	state = Suspension.create()
	Suspension.step(state, Vector3.ZERO, 0, 0, 0, 1.0 / 60, 1.0, false, func(_x: float, _z: float) -> float: return 0.0)
	var peak_vertical_speed := 0.0
	for frame in 30:
		Suspension.step(state, Vector3.ZERO, 0, 0, 0, 1.0 / 60, 1.0, false, func(x: float, z: float) -> float: return 0.35 if x > 0 and z > 0 else 0.0)
		peak_vertical_speed = maxf(peak_vertical_speed, absf(state.velocity))
	check(state.wheel_offsets[1] > state.wheel_offsets[0] + 0.05 and state.pitch < -0.01 and state.roll > 0.01, "Single-wheel obstacle compresses suspension and tilts the chassis")
	check(peak_vertical_speed > 0.01, "Ground step excites damped vertical chassis motion during the response")
	for frame in 600:
		Suspension.step(state, Vector3.ZERO, 0, 0, 0, 1.0 / 60, 1.0, false, func(_x: float, _z: float) -> float: return 0.0)
	check(absf(state.height) < 0.001 and absf(state.pitch) < 0.001 and absf(state.roll) < 0.001, "Springs settle after leaving obstacle")
	state.height = 2.0
	state.velocity = 0.0
	Suspension.step(state, Vector3.ZERO, 0, 0, 0, 1.0 / 60, 1.0, false, func(_x: float, _z: float) -> float: return 0.0)
	check(state.velocity < 0 and state.contacts == 0 and state.grip < 1, "Airborne chassis falls and loses wheel grip")
	var frozen := state.duplicate(true)
	Suspension.step(state, Vector3.ONE, 1, 10, 2, 0.0)
	check(state == frozen, "Paused suspension does not integrate")
	var steering := Suspension.steering_angles(1, 6)
	check(steering.x > 0 and steering.y > steering.x, "Inner front wheel uses greater Ackermann steering angle")
	var opposite := Suspension.steering_angles(-1, 6)
	check(is_equal_approx(opposite.x, -steering.y) and is_equal_approx(opposite.y, -steering.x), "Ackermann steering mirrors for opposite turn")
	var motion := MotionState.new()
	var tuning := {"maximum_speed": 9.0, "acceleration": 4.0, "braking": 8.0, "traction": 1.0, "wheeled": true, "wheelbase": 4.7}
	for frame in 120:
		Motion.step(motion, {"throttle": 0.0, "steer": 1.0, "handbrake": false}, tuning, 1.0 / 60)
	check(motion.heading == 0, "Wheel vehicle cannot pivot in place like tracks")
	for frame in 120:
		Motion.step(motion, {"throttle": 1.0, "steer": 1.0, "handbrake": false}, tuning, 1.0 / 60)
	check(motion.yaw_velocity > 0 and motion.x > 0, "Forward motion turns according to front steering")
	for frame in 240:
		Motion.step(motion, {"throttle": -1.0, "steer": 1.0, "handbrake": false}, tuning, 1.0 / 60)
	check(motion.speed < 0 and motion.yaw_velocity < 0, "Reverse steering follows wheel vehicle kinematics")
	_test_moving_bump()
	_test_support_geometry()
	_test_trailer()
	await _test_rig()
	await _test_terrain()
	await _test_dynamic_grounding()
	print("Wheel vehicle: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_support_geometry() -> void:
	var pose_api = preload("res://modules/caravan/vehicle_pose.gd")
	for trailer in [false, true]:
		var rig := Rig.build_trailer() if trailer else Rig.build_player()
		root.add_child(rig)
		for scale_value in [0.88, 1.42]:
			for heading in [0.0, PI * 0.5, -2.3]:
				for gradient in [Vector2(0, 0.2), Vector2(-0.18, 0), Vector2(0.14, -0.16)]:
					var state := Suspension.create()
					var origin := Vector3(7, 0, -3)
					var sampler := func(x: float, z: float) -> float: return x * gradient.x + z * gradient.y
					for tick in 240:
						Suspension.step(state, origin, heading, 0, 0, 1.0 / 60, scale_value, trailer, sampler)
					origin.y = state.height
					rig.transform = pose_api.transform(pose_api.capture(origin, heading, scale_value, 0, 0, 0, state))
					Rig.animate(rig, state, 0.4, 4, 1.2, trailer)
					var valid: bool = state.contacts == 4
					var wheels: Array = rig.get_meta("wheels")
					var springs: Array = rig.get_meta("springs")
					for index in 4:
						var wheel: Node3D = wheels[index]
						var point := wheel.global_position
						valid = valid and absf(point.y - Suspension.RADIUS * scale_value - sampler.call(point.x, point.z)) < 0.0001
						valid = valid and absf(state.wheel_offsets[index]) <= Suspension.TRAVEL
						var spring: Node3D = springs[index]
						var center: Vector3 = spring.get_meta("anchor")
						var upper := center + Vector3.UP * Suspension.STRUT_LENGTH * 0.5
						var lower := center - Vector3.UP * Suspension.STRUT_LENGTH * 0.5 + wheel.position - Vector3(wheel.get_meta("anchor"))
						valid = valid and (spring.transform * (Vector3.UP * Suspension.STRUT_LENGTH * 0.5)).distance_to(upper) < 0.0001
						valid = valid and (spring.transform * (Vector3.DOWN * Suspension.STRUT_LENGTH * 0.5)).distance_to(lower) < 0.0001
					check(valid, "Slope tire contact and both damper endpoints: trailer=%s scale=%s yaw=%s gradient=%s" % [trailer, scale_value, heading, gradient])
		rig.free()

func _test_moving_bump() -> void:
	var sampler := func(x: float, z: float) -> float:
		return 0.4 * exp(-pow((z - 3.0) / 0.8, 2)) if x > 0 else 0.0
	var finals: Array[Dictionary] = []
	for rate in [30, 60, 120]:
		var state := Suspension.create()
		var max_pitch := 0.0
		var max_roll := 0.0
		var valid := true
		for tick in rate * 5:
			var point := Vector3(0, 0, float(tick) / rate * 2.0)
			Suspension.step(state, point, 0, 2, 0, 1.0 / rate, 1, false, sampler)
			max_pitch = maxf(max_pitch, absf(state.pitch))
			max_roll = maxf(max_roll, absf(state.roll))
			for index in 4:
				var anchor: Vector3 = Suspension.ANCHORS[index]
				var ground: float = sampler.call(point.x + anchor.x, point.z + anchor.z)
				var tire_bottom: float = state.height + Suspension.mount_offset(Suspension.body_basis(state), anchor) + state.wheel_offsets[index]
				valid = valid and tire_bottom >= ground - 0.0001 and absf(state.wheel_offsets[index]) <= Suspension.TRAVEL
				if state.wheel_contacts[index]:
					valid = valid and absf(tire_bottom - ground) < 0.0001
		check(valid and max_pitch > 0.01 and max_roll > 0.02, "Moving over a one-sided bump tilts body without tire penetration at %dHz" % rate)
		finals.append(state)
	for state: Dictionary in finals:
		check(absf(state.pitch) < 0.001 and absf(state.roll) < 0.001 and absf(state.height) < 0.01, "Body settles after driving off the bump")

func _test_trailer() -> void:
	var pose := {"x": 0.0, "z": -7.03, "heading": 0.0}
	var leader := {"x": 0.0, "z": 0.0, "heading": 0.0, "scale": 1.0, "rear_hitch": 3.78}
	var highest_steer := 0.0
	var constrained := true
	for frame in 600:
		leader.heading += 0.004
		leader.x += sin(leader.heading) * 0.1
		leader.z += cos(leader.heading) * 0.1
		VisualMotion.trailer(pose, leader, 1.0 / 60, 7.03)
		highest_steer = maxf(highest_steer, absf(pose.steer))
		constrained = constrained and absf(pose.hitch.distance_to(pose.front_axle) - 1.7) < 0.00001
		constrained = constrained and absf(pose.front_axle.distance_to(pose.rear_axle) - 3.1) < 0.00001
	check(constrained, "Trailer drawbar length and wheelbase stay constrained through sustained turn")
	check(highest_steer > 0.1 and pose.heading < leader.heading, "Trailer front wheels steer while rear axle follows towing path")
	var suspension := Suspension.create()
	for frame in 240:
		Suspension.step(suspension, Vector3(pose.x, 0, pose.z), pose.heading, pose.speed, pose.yaw_rate, 1.0 / 60, 1.0, true, func(x: float, z: float) -> float: return x * 0.05 + z * 0.08)
	check(absf(suspension.pitch) + absf(suspension.roll) > 0.05 and suspension.contacts == 4, "Trailer platform follows its own terrain with all wheels supported")

func _test_rig() -> void:
	var player := Rig.build_player()
	var trailer := Rig.build_trailer()
	root.add_child(player)
	root.add_child(trailer)
	check(player.get_meta("wheels").size() == 4 and trailer.get_meta("wheels").size() == 4, "Both rigs use four actual articulated wheels")
	var names := _names(player) + _names(trailer)
	check(not names.contains("Track") and not names.contains("Leg") and player.has_meta("model_path") and trailer.has_meta("model_path"), "Both rigs use authored wheeled assets without tracks or walking legs")
	var trailer_wheels: Array = trailer.get_meta("wheels")
	var tire: MeshInstance3D = trailer_wheels[0].get_child(0).get_child(0)
	check(absf(tire.mesh.get_aabb().size.y * tire.scale.y - Suspension.RADIUS * 2.0) < 0.015, "Authored trailer tire diameter matches suspension contact radius")
	var suspension := Suspension.create()
	suspension.wheel_offsets[0] = 0.2
	Rig.animate(player, suspension, 1.0, 5, 2.0)
	var wheels: Array = player.get_meta("wheels")
	check(wheels[0].rotation.y > 0 and wheels[1].rotation.y > wheels[0].rotation.y and wheels[2].rotation.y == 0, "Visible front wheels steer and rear wheels stay aligned")
	check(absf(wheels[0].position.y - Suspension.RADIUS - 0.2) < 0.00001 and wheels[0].get_child(0).rotation.x == 2.0, "Visible wheel follows contact compression and distance-driven spin")
	var view := View.new()
	root.add_child(view)
	view.set_process(false)
	var weapon := {"type": "assaultRifle", "mount": {"carrierId": "trailer-1", "slot": 1}, "def": {"projectile": true}}
	view.apply_player_state({"position": Vector3.ZERO, "heading": 0.0, "speed": 0.0, "visual_scale": 0.88, "carriers": [{"id": "trailer-1"}], "modules": [weapon]}, 1)
	view._process(1.0 / 60)
	var module: Node3D = view._modules["trailer-1:1:assaultRifle"]
	check(module.get_parent() == view._trailers["trailer-1"] and module.position == View.TRAILER_SLOTS[1], "Armory equipment attaches to selected moving trailer hardpoint")
	check(view.get_weapon_origin(weapon).distance_to(module.global_position + Vector3.UP * 0.6) < 0.001, "Combat muzzle query uses mounted trailer pose")
	view._trailers["trailer-1"].rotation.x = 0.15
	check(module.global_position.distance_to(module.get_parent().to_global(View.TRAILER_SLOTS[1])) < 0.001, "Mounted equipment follows trailer body pitch")
	player.queue_free()
	trailer.queue_free()
	view.queue_free()
	await process_frame

func _test_terrain() -> void:
	Terrain.configure({"props": [{"position": Vector3(33, 0, 48), "radius": 3.0}]})
	check(absf(Terrain.height_at(33, 48)) < 0.00001 and absf(Terrain.height_at(35, 50)) < 0.00001, "Terrain stays flat beneath placed props and their footprint")
	check(absf(Terrain.height_at(200, 250)) > 0.02, "Driveable terrain contains actual geometric height variation")
	var mesh := Terrain.create_mesh()
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var plane := PlaneMesh.new()
	var reference := plane.get_mesh_arrays()
	var reference_indices: PackedInt32Array = reference[Mesh.ARRAY_INDEX]
	var reference_vertices: PackedVector3Array = reference[Mesh.ARRAY_VERTEX]
	var normal := (vertices[indices[1]] - vertices[indices[0]]).cross(vertices[indices[2]] - vertices[indices[0]])
	var expected := (reference_vertices[reference_indices[1]] - reference_vertices[reference_indices[0]]).cross(reference_vertices[reference_indices[2]] - reference_vertices[reference_indices[0]])
	check(signf(normal.y) == signf(expected.y), "Terrain triangle winding matches upward-facing Godot PlaneMesh")
	var accurate := true
	for index in range(0, indices.size(), 15006):
		var first := vertices[indices[index]]
		var second := vertices[indices[index + 1]]
		var third := vertices[indices[index + 2]]
		var point := first * 0.2 + second * 0.3 + third * 0.5
		accurate = accurate and absf(point.y - Terrain.height_at(point.x, point.z)) < TERRAIN_FLOAT_TOLERANCE
	check(accurate, "Wheel sampler matches interior of the actual rendered terrain triangles")
	var world := Node3D.new()
	root.add_child(world)
	var body := StaticBody3D.new()
	body.collision_layer = 16
	var collision := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = Terrain.CELLS + 1
	shape.map_depth = Terrain.CELLS + 1
	shape.map_data = Terrain.heights
	collision.shape = shape
	body.add_child(collision)
	body.scale = Vector3(Terrain.STEP, 1, Terrain.STEP)
	world.add_child(body)
	await physics_frame
	await physics_frame
	var collision_agrees := true
	for point in [Vector2(200, 250), Vector2(-125, 321), Vector2(678, -512), Vector2(33, 48)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 10, point.y), Vector3(point.x, -10, point.y), 16)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		collision_agrees = collision_agrees and not hit.is_empty() and absf(hit.position.y - Terrain.height_at(point.x, point.y)) < 0.005
	check(collision_agrees, "Physics heightfield matches rendered and sampled terrain height")
	world.queue_free()
	await process_frame

func _names(node: Node) -> String:
	var value := str(node.name)
	for child in node.get_children():
		value += " " + _names(child)
	return value

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_dynamic_grounding() -> void:
	var point := Vector3(200, 0, 250)
	for x in range(100, 350, 10):
		if Terrain.height_at(x, 250) > 0.25:
			point.x = x
			break
	var height := Terrain.height_at(point.x, point.z)
	check(height > 0.25, "Dynamic grounding regression runs on raised terrain")
	var model = preload("res://modules/combat/combat_model.gd").new()
	var enemy: Dictionary = model.spawn_enemy("rifleman", point)
	var animated: Dictionary = preload("res://presentation/combat/enemy_animation.gd").advance(enemy, {}, 0.0, 0.0)
	check(absf(animated.position.y - height) < 0.0001 and enemy.position.y == 0, "Enemy feet follow terrain while 2D combat coordinates stay unchanged")
	check(absf(model._target_aim(enemy).y - height - 1.05) < 0.0001 and absf(model._aim_center(enemy).y - height - 1.05) < 0.0001, "Weapon aim and collision center follow raised enemy visual")
	model.player.position = point + Vector3(0, height, 12)
	enemy.cooldown = 0.0
	model.EnemyAI.attack(model, enemy, 0.1, 1.0, 12.0, false)
	check(not model.projectiles.is_empty() and absf(model.projectiles[-1].position.y - height - 1.3) < 0.0001, "Enemy muzzle inherits terrain elevation exactly once")
	var boss: Dictionary = model.spawn_enemy("leviathan", point)
	var component: Dictionary = boss.components[0]
	check(absf(component.position.y - height - model.Leviathan.Geometry.anchor(component.kind).y) < 0.0001 and model._target_aim(component) == component.position, "Boss component target shares boss ground baseline without double offset")
	var mines = preload("res://presentation/combat/mine_views.gd").new()
	root.add_child(mines)
	mines.sync_state([{"position": point + Vector3.UP * 0.4}])
	check(absf(mines.entries[0].visual.position.y - height) < 0.0001, "Mines rest on terrain without inheriting owner chassis height")
	var combat_view = preload("res://presentation/combat/combat_view.gd").new()
	root.add_child(combat_view)
	combat_view._mines = mines
	var source = preload("res://presentation/combat/source_model.gd")
	var source_animation = preload("res://presentation/combat/source_animation.gd")
	for kind in ["pickup_salvage", "pickup_fuel"]:
		var pool: Dictionary = source.create_pool(kind, 2)
		combat_view._pools[kind] = pool
		combat_view._active_counts[kind] = 0
		combat_view.add_child(pool.root)
	combat_view.apply_state({"generation": 1, "elapsed": 0.0, "pickups": [{"id": 1, "kind": "salvage", "position": point, "phase": 0.0}, {"id": 2, "kind": "fuel", "position": point, "phase": 0.0}]})
	var pickup_pose: Transform3D = combat_view.pickup_transform({"position": point, "phase": 0.0}, 0.0)
	check(absf(pickup_pose.origin.y - height - 0.72) < 0.00001, "Production pickup transform places coin above raised terrain")
	var valley := Vector3(-125, 0, 321)
	var valley_pose: Transform3D = combat_view.pickup_transform({"position": valley, "phase": 0.0}, 0.0)
	check(absf(valley_pose.origin.y - Terrain.height_at(valley.x, valley.z) - 0.72) < 0.00001, "Production pickup transform preserves hover height across terrain elevations")
	var pickups_clear := true
	for kind in ["pickup_salvage", "pickup_fuel"]:
		var batch: Dictionary = combat_view._pools[kind].batches[0]
		var transform: Transform3D = batch.mesh.get_instance_transform(0) * source_animation.transform_for(batch, {}).affine_inverse()
		pickups_clear = pickups_clear and absf(transform.origin.y - height - 0.72) < 0.0001
	if DisplayServer.get_name() != "headless":
		check(pickups_clear, "Actual coin and fuel pool transforms hover above raised terrain")
	else:
		check(combat_view._active_counts.pickup_salvage == 1 and combat_view._active_counts.pickup_fuel == 1, "Raised-terrain snapshot keeps both coin and fuel pickup instances active")
	var activities = preload("res://presentation/world/activity_view.gd").new()
	root.add_child(activities)
	activities.set_process(false)
	activities.apply_state({"support": {"heal_carts": [{"position": point, "yaw": 0.0, "phase": 0.0}], "airdrops": [{"position": point, "height": 0.0, "landed": true, "yaw": 0.0}]}})
	var healer_pose: Transform3D = activities.healer_transform({"position": point, "yaw": 0.0, "phase": 0.0}, 0.0)
	check(absf(healer_pose.origin.y - height) < 0.00001, "Production rescue cart transform rests on raised terrain")
	var healer_batch: Dictionary = activities._healers.batches[0]
	var healer_transform: Transform3D = healer_batch.mesh.get_instance_transform(0) * source_animation.transform_for(healer_batch, {}).affine_inverse()
	if DisplayServer.get_name() != "headless":
		check(absf(healer_transform.origin.y - height) < 0.0001, "Rescue cart pool follows terrain")
	check(absf(activities._flare_light.position.y - height - preload("res://presentation/world/airdrop_flare_smoke.gd").FLARE_HEIGHT) < 0.0001, "Landed supply flare follows terrain baseline")
	mines.queue_free()
	combat_view.queue_free()
	activities.queue_free()
	await process_frame

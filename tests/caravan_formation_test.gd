extends SceneTree
const Formation = preload("res://modules/caravan/caravan_formation.gd")
const Factory = preload("res://modules/caravan/wagon_factory.gd")
const Props = preload("res://modules/world/prop_system.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _wagons(count: int = 6) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in count:
		result.append(Factory.create("cargo", "wagon-%d" % (index + 1)))
	return result

func _run() -> void:
	preload("res://modules/caravan/terrain_surface.gd").configure({})
	var formation := Formation.new()
	var wagons := _wagons()
	var player := {"position": Vector3(0, 0, 25), "heading": PI * 0.5, "scale": 0.88, "speed": 7.5, "wind_roll": 0.0}
	formation.step(player, wagons, 0.0)
	check(wagons.size() == 6 and wagons[5].position.distance_to(player.position) > 29.0, "All six factory wagons initialize as a full-length canonical chain")
	var valid_turn := true
	var no_crossing := true
	for frame in 600:
		var angle := float(frame + 1) / 60.0 * 0.3
		player.position = Vector3(sin(angle), 0, cos(angle)) * 25.0
		player.heading = PI * 0.5 + angle
		var events := formation.step(player, wagons, 1.0 / 60.0)
		valid_turn = valid_turn and events.is_empty()
		for index in wagons.size():
			valid_turn = valid_turn and wagons[index].attached and absf(wagons[index].pose.get("hitch_gap", 1.496) - 1.496) < 0.08
			if index > 0:
				no_crossing = no_crossing and wagons[index].position.distance_to(wagons[index - 1].position) > 3.0
	check(valid_turn, "Six wagons complete a continuous tight turn without stretching hitches or detaching")
	check(no_crossing, "Tight turns keep adjacent wagon bodies separated")
	player.speed = -3.0
	var reverse_valid := true
	for frame in 240:
		player.heading += 0.08 / 60.0
		player.position += Formation._forward(player.heading) * player.speed / 60.0
		formation.step(player, wagons, 1.0 / 60.0)
		for index in wagons.size():
			reverse_valid = reverse_valid and wagons[index].attached
			var preceding_heading: float = player.heading if index == 0 else wagons[index - 1].heading
			reverse_valid = reverse_valid and absf(wrapf(wagons[index].heading - preceding_heading, -PI, PI)) <= Formation.MAX_JOINT_ANGLE + 0.03
	check(reverse_valid, "Reverse steering maintains six attached wagons within joint-angle limits")
	player.speed = 0.0
	for frame in 60:
		player.position += Vector3(0.08, 0, 0)
		player.wind_roll = 0.2
		formation.step(player, wagons, 1.0 / 60.0)
	check(wagons.all(func(wagon: Dictionary) -> bool: return wagon.attached), "Realistic sustained tornado shove keeps the caravan coupled")
	check(absf(wagons[0].pose.wind_roll) > absf(wagons[5].pose.wind_roll), "Tornado roll transmits gradually and attenuates down the chain")
	var snapshot: Array = wagons.map(func(wagon: Dictionary) -> Vector3: return wagon.position)
	player.position += Vector3(12, 0, 0)
	var events := formation.step(player, wagons, 1.0 / 60.0)
	check(events.any(func(event: Dictionary) -> bool: return event.kind == "wagon_detached") and wagons.all(func(wagon: Dictionary) -> bool: return not wagon.attached), "Extreme impulse breaks the hitch and detaches the complete tail")
	check(wagons[0].position.distance_to(snapshot[0]) < 0.5, "Broken hitch does not teleport the first wagon to the moving player")
	var detached: Array = wagons.map(func(wagon: Dictionary) -> Vector3: return wagon.position)
	player.position += Vector3(20, 0, 0)
	formation.step(player, wagons, 1.0)
	check(wagons.map(func(wagon: Dictionary) -> Vector3: return wagon.position) == detached, "Detached tail stays exactly where it was left")
	for wagon: Dictionary in wagons:
		wagon.attached = true
	player.position = wagons[0].position + Formation._forward(player.heading) * 7.03 * 0.88 + Vector3(2, 0, 0)
	formation.reset()
	formation.step(player, wagons, 1.0 / 60.0)
	check(wagons[0].position.distance_to(detached[0]) < 0.11 and wagons[0].attached, "Recoupling approaches the hitch gradually without repositioning the tail instantly")
	for frame in 300:
		formation.step(player, wagons, 1.0 / 60.0)
	check(wagons.all(func(wagon: Dictionary) -> bool: return wagon.attached and not wagon.recoupling), "Recovered six-wagon tail settles back onto bounded hitches")
	_test_collision()
	_test_middle_loss()
	_test_frame_rates()
	await _test_view()
	print("CARAVAN_FORMATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_collision() -> void:
	var props := Props.new()
	props.setup({"props": [{"id": "wall", "kind": "building", "position": {"x": 4, "z": 0}, "radius": 2.0, "hp": 1000.0, "solid": true}], "rockObstacles": []})
	var formation := Formation.new()
	var wagons := _wagons(1)
	var player := {"position": Vector3.ZERO, "heading": PI * 0.5, "scale": 0.88, "speed": 8.0}
	formation.step(player, wagons, 0.0, props.resolve_motion)
	var hit := false
	var clear := true
	for frame in 120:
		player.position.x += 8.0 / 60.0
		var events := formation.step(player, wagons, 1.0 / 60.0, props.resolve_motion)
		hit = hit or events.any(func(event: Dictionary) -> bool: return event.kind == "wagon_impact" and event.amount > 0)
		clear = clear and props.is_clear(wagons[0].position, wagons[0].radius - 0.02)
	check(hit, "Swept collision against actual world prop system emits wagon damage")
	check(clear, "Wagon never tunnels into the world's solid obstacle")
	check(not wagons[0].attached and wagons[0].hp == wagons[0].max_hp, "Blocked hitch detaches while roster remains sole authority for HP damage")
	wagons[0].attached = true
	var refused := false
	for frame in 240:
		var events := formation.step(player, wagons, 1.0 / 60.0, props.resolve_motion)
		refused = refused or events.any(func(event: Dictionary) -> bool: return event.get("reason", "") == "recouple_blocked")
	check(refused and not wagons[0].attached, "Blocked recoupling times out instead of leaving a permanently stretched working hitch")

func _test_middle_loss() -> void:
	var formation := Formation.new()
	var wagons := _wagons()
	var player := {"position": Vector3.ZERO, "heading": 0.0, "scale": 0.88, "speed": 6.0}
	formation.step(player, wagons, 0.0)
	wagons[2].dead = true
	for index in range(2, 6):
		wagons[index].attached = false
	var tail: Array = wagons.slice(2).map(func(wagon: Dictionary) -> Vector3: return wagon.position)
	for frame in 120:
		player.position.z += 0.1
		formation.step(player, wagons, 1.0 / 60.0)
	check(wagons[0].position.z > 5.0 and wagons[1].position.z > 0, "Leading live wagons continue driving after a middle wagon is destroyed")
	check(wagons.slice(2).map(func(wagon: Dictionary) -> Vector3: return wagon.position) == tail, "Destroyed middle wagon and detached rear retain their original poses")
	var before: Dictionary = wagons[0].pose.duplicate(true)
	formation.step(player, wagons, 0.0)
	check(before == wagons[0].pose, "Zero simulation delta preserves canonical pose during pause")

func _test_view() -> void:
	var vehicle := preload("res://modules/caravan/vehicle_controller.gd").new()
	root.add_child(vehicle)
	vehicle.set_physics_process(false)
	var view := preload("res://presentation/vehicles/vehicle_view.gd").new()
	vehicle.add_child(view)
	view.set_process(false)
	var formation := Formation.new()
	var wagons := _wagons()
	var player := {"position": Vector3.ZERO, "heading": 0.0, "visual_scale": 0.88, "speed": 0.0, "carriers": wagons, "modules": []}
	formation.step(player, wagons, 0.0)
	view.apply_player_state(player, 1)
	var before: Array = wagons.duplicate(true)
	view._advance_physics(0.3)
	check(wagons == before, "VehicleView never simulates or mutates runtime wagon poses")
	player.position += Vector3(0.1, 0, 0.05)
	formation.step(player, wagons, 1.0 / 60.0)
	view.render_interpolated(1.0)
	var actual: Node3D = view._trailers[wagons[5].id]
	check(actual.global_position.distance_to(wagons[5].position) < 0.001, "Rendering reads the newest canonical tail pose even after its own physics callback ran")
	wagons[3].attached = false
	view.render_interpolated(1.0)
	var detached: Node3D = view._trailers[wagons[3].id]
	check(detached.visible and not detached.get_child(0).get_meta("drawbar").visible, "Detached wagon remains visible without a fake stretched drawbar")
	wagons[2].dead = true
	view.render_interpolated(1.0)
	check(not view._trailers[wagons[2].id].visible, "Destroyed wagon's intact model is hidden")
	wagons[1].attachments.append({"type": "fuel_pump", "slot": 1})
	view.apply_player_state(player, 1)
	var key: String = str(wagons[1].id) + ":1:fuel_pump"
	check(view._attachments.has(key) and view._attachments[key].get_parent() == view._trailers[wagons[1].id] and view._attachments[key].position == view.TRAILER_SLOTS[1], "Installed attachment renders on the exact wagon ID and mount")
	wagons[1].attachments.clear()
	view.apply_player_state(player, 1)
	check(not view._attachments.has(key), "Removing attachment updates its visual without a generation reset")
	vehicle.queue_free()
	await process_frame

func _test_frame_rates() -> void:
	var results: Array = []
	for fps: int in [30, 60, 120]:
		var formation := Formation.new()
		var wagons := _wagons()
		var player := {"position": Vector3.ZERO, "heading": atan2(0.75, 7.0), "scale": 0.88, "speed": 7.0}
		formation.step(player, wagons, 0.0)
		for frame in fps * 4:
			var time := float(frame + 1) / fps
			player.position = Vector3(sin(time * 0.15) * 5.0, 0, time * 7.0)
			player.heading = atan2(cos(time * 0.15) * 0.75, 7.0)
			formation.step(player, wagons, 1.0 / fps)
		results.append(wagons)
	for result: Array in results:
		check(result[5].position.distance_to(results[0][5].position) < 0.03 and result.all(func(wagon: Dictionary) -> bool: return wagon.attached), "Physics substeps keep six-wagon motion consistent at30/60/120FPS")
	var excess := _wagons(7)
	Formation.new().step({"position": Vector3.ZERO, "heading": 0.0}, excess, 0.0)
	check(not excess[6].attached, "Formation cannot attach a seventh wagon even if bad input bypasses purchase validation")

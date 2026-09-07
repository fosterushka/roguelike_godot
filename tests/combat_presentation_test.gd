extends SceneTree
const Source = preload("res://presentation/combat/source_model.gd")
const AnimationRules = preload("res://presentation/combat/source_animation.gd")
const EnemyAnimation = preload("res://presentation/combat/enemy_animation.gd")
const View = preload("res://presentation/vehicles/vehicle_view.gd")
const Dimensions = preload("res://modules/caravan/player_dimensions.gd")
const Model = preload("res://modules/combat/combat_model.gd")
const Controller = preload("res://modules/caravan/vehicle_controller.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.00001, label + ": %s != %s" % [actual, expected])
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	Source.preload_models()
	for sample: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_animation.json")):
		var visual := Source.instantiate(sample.kind)
		var index := 0
		for part: Node3D in visual.get_children():
			var actual := AnimationRules.transform_for(part.get_meta("source_part"), sample.pose)
			var expected := AnimationRules.matrix(sample.matrices[index])
			check(actual.origin.distance_to(expected.origin) < 0.00001 and actual.basis.x.distance_to(expected.basis.x) < 0.00001 and actual.basis.y.distance_to(expected.basis.y) < 0.00001 and actual.basis.z.distance_to(expected.basis.z) < 0.00001, "Actual TypeScript soldier matrix golden %s/%d" % [sample.kind, index])
			index += 1
		visual.free()
	var jammer_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/jammer_animation.json"))
	var jammer_visual := Source.instantiate("weapon_counterDroneJammer")
	var jammer_index := 0
	for part: MeshInstance3D in jammer_visual.get_children():
		var actual := AnimationRules.transform_for(part.get_meta("source_part"), {"elapsed": jammer_fixture.elapsed})
		var expected := AnimationRules.matrix(jammer_fixture.matrices[jammer_index])
		check(actual.origin.distance_to(expected.origin) < 0.00001 and actual.basis.x.distance_to(expected.basis.x) < 0.00001 and actual.basis.z.distance_to(expected.basis.z) < 0.00001, "Source nested jammer head/scan/pulse matrix")
		jammer_index += 1
	jammer_visual.free()
	near(Dimensions.target_scale(1), 0.88, "Source base visual scale")
	near(Dimensions.target_scale(8), 1.405, "Source level 8 visual scale")
	near(Dimensions.target_scale(50), 1.42, "Source scale ceiling")
	near(Dimensions.radius(0.88), 3.5, "Source circular base hull radius")
	var base_pose := EnemyAnimation.advance({"id": 1, "type": "garrison", "position": Vector3.ZERO, "speed": 0.0, "hit_time": 1.0 / 12.0}, {}, 0.0, 0.0)
	check(base_pose.basis.get_scale().is_equal_approx(Vector3.ONE), "Garrison hit feedback keeps its building hull still")
	near(Dimensions.radius(1.42), 5.647727272727, "Source max circular hull radius")
	var model = Model.new()
	model.spawn_queue.clear()
	model.weapons.clear()
	model.running = true
	for level in [1, 8, 50]:
		model.player.visual_scale = Dimensions.target_scale(level)
		var radius := Dimensions.radius(model.player.visual_scale)
		for miss in [false, true]:
			var x := radius + 0.1 + (0.001 if miss else -0.001)
			var shot := {"team": "enemy", "kind": "bullet", "radius": 0.1, "damage": 1.0, "previous": Vector3(x, 2.2, -10), "position": Vector3(x, 2.2, 10)}
			check(model._resolve_projectile_segment(shot) != miss, "Enemy projectile exact grown hull boundary level %d miss %s" % [level, miss])
	model.player.active_protocols = ["targetRelay", "suppressionCycle", "breachCrew", "combinedFeed", "salvageLoop"]
	model.refresh_build_protocols()
	var boss: Dictionary = model.spawn_enemy("leviathan", Vector3(30, 0, 30))
	var exposed: Dictionary = boss.components[0]
	var hidden: Dictionary = boss.components[2]
	model.protocols.mark_focus(model.player, exposed, model.elapsed)
	model.protocols.salvage_charge = 19.0
	model.protocols.primed_until = 3.0
	model.running = false
	model.player.active_protocols = []
	model.refresh_build_protocols()
	near(exposed.relay_until, 0.0, "Removing protocol while paused clears boss relay")
	near(model.protocols.salvage_charge, 0.0, "Removing salvage requirement clears charge")
	near(model.protocols.primed_until, 0.0, "Removing combined requirement clears priming")
	model.player.active_protocols = ["targetRelay", "combinedFeed", "salvageLoop"]
	model.refresh_build_protocols()
	near(exposed.relay_until, 0.0, "Reinstalling requirements does not resurrect mark")
	check(model.damage_enemy_nonlethal(exposed.id, 100000.0), "Lightning can damage exposed component")
	near(exposed.hp, 1.0, "Nonlethal component damage stops at 1HP")
	var hidden_hp: float = hidden.hp
	check(not model.damage_enemy_nonlethal(hidden.id, 100000.0), "Lightning respects hidden component gate")
	near(hidden.hp, hidden_hp, "Hidden component health unchanged")
	model.running = true
	model.player.hp = 10.0
	model.player.armor = 0.4
	model.player.emergency_armor = 0.2
	model.damage_player_nonlethal(10.0)
	near(model.player.hp, 6.0, "Player lightning uses armor and emergency armor")
	model.damage_player_nonlethal(1000.0)
	near(model.player.hp, 1.0, "Player lightning never kills after armor")
	model.events.clear()
	model.player.regen_rate = 0.0
	model._tick_abilities(0.1)
	check(model.events.filter(func(event: Dictionary) -> bool: return event.kind == "low_hp").size() == 1, "Source low HP cue below18percent")
	model.events.clear()
	model._tick_abilities(0.1)
	check(model.events.filter(func(event: Dictionary) -> bool: return event.kind == "low_hp").is_empty(), "Low HP cue rate limited by run time")
	var drone := {"id": 9, "type": "drone", "kind": "shooter", "position": Vector3.ZERO, "height": 4.8}
	var pose := {}
	EnemyAnimation.advance(drone, pose, 0.5, 0.5)
	near(pose.rotor_angle, 14.0, "Source shooter rotor 28 radians per second")
	EnemyAnimation.advance(drone, pose, 0.0, 0.5)
	near(pose.rotor_angle, 14.0, "Repeated paused snapshots freeze rotor")
	var view := View.new()
	root.add_child(view)
	view.set_process(false)
	view.apply_player_state(model.player, 1)
	view._process(1.0 / 60.0)
	check(view.global_position.is_finite(), "Standalone visual parent Window supports body motion")
	view.apply_player_state(model.player, 2)
	near(view._body.wheel_angle, 0.0, "Generation reset clears wheel pose")
	view.queue_free()
	await _test_hulls()
	print("Combat presentation: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
func _test_hulls() -> void:
	preload("res://app/input_actions.gd").register()
	var world := Node3D.new()
	root.add_child(world)
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40, 4, 1)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector3(0, 2, 10)
	world.add_child(wall)
	var vehicle := Controller.new()
	world.add_child(vehicle)
	vehicle.set_physics_process(false)
	await physics_frame
	await physics_frame
	for level in [1, 8, 50]:
		vehicle.position = Vector3.ZERO
		vehicle.player_stats = {"visual_scale": Dimensions.target_scale(level)}
		vehicle.sync_collision_dimensions()
		await physics_frame
		await physics_frame
		var collision: KinematicCollision3D = vehicle.move_and_collide(Vector3(0, 0, 15))
		var radius := Dimensions.radius(Dimensions.target_scale(level))
		check(collision != null and absf(vehicle.position.z - (9.5 - radius)) < 0.02, "Circular collider grows against real wall level %d" % level)
	world.queue_free()
	await process_frame

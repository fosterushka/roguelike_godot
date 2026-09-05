extends SceneTree
const WorldRuntime = preload("res://modules/world/world_runtime.gd")
const Rules = preload("res://modules/world/weather_rules.gd")
const Weather = preload("res://modules/world/weather_state.gd")
const Runtime = preload("res://modules/combat/combat_runtime.gd")
const Vehicle = preload("res://modules/caravan/vehicle_controller.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
	checks += 1

func _run() -> void:
	root.size = Vector2i(1280, 800)
	preload("res://app/input_actions.gd").register()
	var arena := preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	var vehicle := Vehicle.new()
	root.add_child(vehicle)
	vehicle.set_driving_enabled(false)
	var combat := Runtime.new()
	root.add_child(combat)
	combat.setup(vehicle)
	var world := WorldRuntime.new()
	root.add_child(world)
	world.setup(arena, combat, vehicle)
	check(world.props.records.size() == 6525, "6400 source props plus125 rocks")
	var source_prop: Dictionary = arena.world_layout.props[0]
	var prop: Dictionary = world.props.records[source_prop.id]
	var collider: StaticBody3D = arena._prop_colliders[source_prop.id]
	var original_pickups: int = combat.model.pickups.size()
	world.damage_props(prop.position, 0.01, 9999)
	check(prop.destroyed, "prop damage destroys record")
	check(collider.collision_layer == 0, "destroyed prop collider removed")
	for index in source_prop.meshes:
		check(not arena.source_world.get_child(int(index)).visible, "source mesh hidden")
	var after_pickups: int = combat.model.pickups.size()
	check(after_pickups > original_pickups, "source salvage spawns")
	world.damage_props(prop.position, 0.01, 9999)
	check(combat.model.pickups.size() == after_pickups, "salvage exactly once")
	world.reset_run(72841)
	check(not prop.destroyed and prop.hp == prop.max_hp, "reset restores sourcehp")
	check(collider.collision_layer == 1, "reset restores collider")
	var station: Dictionary = {}
	for landmark in arena.world_layout.landmarks:
		if landmark.type in ["pumpjack", "refinery"]:
			station = landmark
			break
	check(not station.is_empty(), "source fuel station available")
	vehicle.global_position = Vector3(station.x + 10.5, 0, station.z)
	vehicle.fuel = 10
	world._refill_station(0.5)
	check(is_equal_approx(vehicle.fuel, 22.0), "station refills24persec inside11radius")
	var station_prop: Dictionary = world.props.records["prop:" + str(station.id)]
	world.props.destroy(station_prop)
	world._flush_prop_events()
	world._refill_station(1.0)
	check(is_equal_approx(vehicle.fuel, 22.0), "destroyed station cannot refuel")
	world.reset_run()
	vehicle.global_position = Vector3(1250, 0, 0)
	world._update_boundary(14.0)
	check(world.outside_remaining == 1.0 and vehicle.health > 0, "boundary15second grace")
	vehicle.global_position = Vector3.ZERO
	world._update_boundary(0.1)
	check(world.outside_remaining == 15.0, "reentry restores fullgrace")
	vehicle.global_position = Vector3(1250, 0, 0)
	world._update_boundary(15.0)
	check(vehicle.health == 0.0, "boundary expiry kills")
	combat.reset_run()
	world.reset_run()
	var rock: Dictionary = world.props.records[arena.world_layout.rockObstacles[0].id]
	var start: Vector3 = rock.position + Vector3(-20, 2, 0)
	var finish: Vector3 = rock.position + Vector3(20, 2, 0)
	var shot := {"previous": start, "position": finish, "radius": 0.05, "kind": "bullet", "damage": 20.0, "team": "player"}
	check(world.handle_projectile(shot), "swept projectile blocks on source rock")
	check(shot.position.distance_to(start) < finish.distance_to(start), "projectile stops at entry")
	check(not world.is_spawn_clear(rock.position, 1.0), "enemy cannot spawn in rock")
	var corrected := world.resolve_enemy_motion({"type": "soldier", "radius": 0.7}, rock.position + Vector3(-7, 0, 0), rock.position)
	check(corrected.distance_to(rock.position) >= rock.radius + 0.7, "enemy slide resolves outside rock")
	var weather_a := Weather.new()
	var weather_b := Weather.new()
	weather_a.reset(72841)
	weather_b.reset(72841)
	weather_a.step(179.0)
	weather_b.step(90.0)
	weather_b.step(89.0)
	check(weather_a.phase == weather_b.phase, "weather phase independent of step partition")
	check(Rules.phase_at(72841, 0).type == "storm" and is_equal_approx(Rules.phase_at(72841, 0).duration, 154.613), "exact source weather phase0 golden")
	check(Rules.phase_at(72841, 360).type == "foggy" and is_equal_approx(Rules.phase_at(72841, 360).ends_at, 437.307), "exact source weather phase2 golden")
	check(is_equal_approx(Rules.lightning_sample(72841, 0, 0).delay, 89.339), "exact source lightning sample golden")
	check(Rules.phase_at(72841, 0).duration >= 120 and Rules.phase_at(72841, 0).duration <= 180, "source weather duration")
	check(is_equal_approx(Rules.range_multiplier("foggy"), 0.68) and is_equal_approx(Rules.range_multiplier("foggy", true), 0.84) and is_equal_approx(Rules.range_multiplier("foggy", false, true), 0.72), "source fog acquisition ratios")
	weather_a.phase.type = "rainy"
	for index in 20:
		weather_a.create_mud(Vector3(index, 0, 0))
	check(weather_a.mud_zones.size() == 10, "bounded10mud zones")
	var effect: Dictionary = weather_a.surface_at(Vector3(19, 0, 0))
	check(effect.movement == 0.62 and effect.turn == 0.55, "source mud movement")
	weather_a.step(15.0)
	check(weather_a.mud_zones.is_empty(), "mud expires after14seconds")
	vehicle.global_position = Vector3.ZERO
	combat.set_running(true)
	vehicle.health = 2.0
	combat.model.player.hp = 2.0
	world._apply_lightning({"screen_x": 0.0, "screen_y": 0.0, "target_roll": 0.01, "target_index": 0.0})
	check(vehicle.health == 1.0, "lightning cannot kill")
	vehicle.health = vehicle.max_health
	combat.model.player.hp = vehicle.health
	combat.model.player.armor = 0.5
	var expected_hp: float = vehicle.health - maxf(14.0, vehicle.max_health * 0.14) * 0.5
	world._apply_lightning({"screen_x": 0.0, "screen_y": 0.0, "target_roll": 0.01, "target_index": 0.0})
	check(absf(vehicle.health - expected_hp) < 0.00001, "Lightning uses combat armor chain before nonlethal floor")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 62
	root.add_child(camera)
	camera.position = Vector3(34, 45, 39)
	camera.look_at(Vector3(0, 0, 5))
	camera.current = true
	var ndc := Vector2(0.4, -0.2)
	var contact: Vector3 = world.project_weather_point(ndc, 0.08)
	var actual_pixel: Vector2 = camera.unproject_position(contact)
	var expected_pixel := Vector2((ndc.x + 1) * 0.5, (1 - ndc.y) * 0.5) * root.get_visible_rect().size
	check(actual_pixel.distance_to(expected_pixel) < 0.01 and absf(contact.y - 0.08) < 0.00001, "Untargeted lightning preserves actual camera projection")
	var before_warmup: float = world.weather.elapsed
	var before_pickups: int = combat.model.pickups.size()
	world.set_warmup_visible(true)
	world.set_warmup_visible(false)
	check(world.weather.elapsed == before_warmup and combat.model.pickups.size() == before_pickups, "weather warmup inert")
	var child_count := world.get_child_count()
	for index in 3:
		world.reset_run()
	check(world.get_child_count() == child_count, "restarts preserve bounded actors")
	print("WORLD_GAMEPLAY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

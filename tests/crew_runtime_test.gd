extends SceneTree
const Runtime = preload("res://modules/crew/crew_runtime.gd")
const Progression = preload("res://modules/progression/progression.gd")
const Expedition = preload("res://modules/meta/expedition.gd")
const Combat = preload("res://modules/combat/combat_runtime.gd")
const Props = preload("res://modules/world/prop_system.gd")
const Tornado = preload("res://modules/world/tornado_rules.gd")
const Loot = preload("res://presentation/world/raid_loot.gd")
const Roles = preload("res://modules/crew/crew_catalog.gd")
const Factory = preload("res://modules/crew/crew_factory.gd")
class TestWorld extends Node:
	var props := Props.new()
	var running := true
	var tornado := Tornado.new()
	var arena := {"world_layout": {"villages": [{"x": 80, "z": 20}, {"x": -90, "z": -20}]}}
var checks := 0
var failures := 0
func _init() -> void:
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	world.props.setup({"props": [{"id": "house", "kind": "building", "position": Vector3(6, 0, 0), "radius": 3.0, "hp": 100, "salvage": 0}], "rockObstacles": []})
	var combat := Combat.new()
	root.add_child(combat)
	var progression := Progression.new("/private/tmp/crew-runtime-%d.json" % Time.get_ticks_usec())
	progression.setup(combat.model)
	var expedition := Expedition.new(progression)
	expedition.begin_run(combat.model.player)
	combat.model.running = true
	var loot := Loot.new()
	root.add_child(loot)
	var vehicle := Node3D.new()
	root.add_child(vehicle)
	var runtime := Runtime.new()
	root.add_child(runtime)
	runtime.setup(expedition, combat, world, vehicle, loot)
	runtime.reset(713)
	check(runtime.recruits.size() == 7 and runtime.targets().size() == 7, "Seven neutral roles are targetable from start")
	var positions: Array = runtime.recruits.map(func(person): return person.position)
	runtime.reset(713)
	check(runtime.recruits.map(func(person): return person.position) == positions, "Recruit placement deterministic by seed")
	check(runtime.recruits.all(func(person): return world.props.is_clear(person.position, 1.2)), "All recruits spawn clear of solid buildings")
	check(runtime.view.views.size() == 31 and runtime.view.views[0].root.visible, "Reusable human views exist before rescue")
	var before_warmup := runtime.recruits.duplicate(true)
	var before_transform: Transform3D = runtime.view.views[0].root.transform
	runtime.set_warmup(true, Vector3(100, 10, 100))
	runtime.set_warmup(false)
	check(runtime.recruits == before_warmup and runtime.view.views[0].root.transform == before_transform and combat.model.projectiles.is_empty(), "Warmup restores visuals and changes no gameplay state")
	check(not runtime.rescue_nearest(), "Remote rescue cannot recruit")
	var recruit: Dictionary = runtime.recruits[0]
	combat.model.player.position = recruit.position
	check(runtime.rescue_nearest() and expedition.caravan.crew.size() == 1, "Nearby stationary rescue boards real recruit")
	check(runtime.targets().size() == 6 and not runtime.rescue_nearest(), "Boarded human excluded from foot targets and cannot be duplicated")
	var neutral: Dictionary = runtime.recruits[0]
	check(runtime.damage_target(neutral.id, 9999) and neutral.dead and not runtime.damage_target(neutral.id, 1), "Neutral can die once from enemy damage")
	check(not combat.model.enemies.has(neutral), "Neutral never enters player auto-target enemy list")
	var walker := Factory.create("looter", "walk-test", Vector3.ZERO)
	var traveled := 0.0
	for index in 180:
		var previous: Vector3 = walker.position
		walker.position = runtime.navigation.move(walker, Vector3(12, 0, 0), 4, 0.05)
		check_solid_step(world, previous, walker.position)
		traveled += previous.distance_to(walker.position)
	check(walker.position.distance_to(Vector3(12, 0, 0)) < 0.6 and traveled > 13, "Collector navigates around building via a longer real path")
	combat.model.player.position = Vector3(20, 0, 0)
	var scavenger := Factory.create_neutral("looter", "rescue-looter", combat.model.player.position)
	expedition.caravan.rescue(scavenger)
	loot.spawn_items("wreck-once", Vector3(29, 0, 0), {"relic": 1})
	loot.spawn_items("wreck-once", Vector3(29, 0, 0), {"relic": 1})
	check(loot.crates.size() == 1 and loot.crates[0].has("id"), "Wagon cargo drops receive stable IDs and duplicate event is ignored")
	runtime.step(0.5)
	check(scavenger.boarded and expedition.cargo_inventory().is_empty(), "Collectors remain aboard until explicit command")
	runtime.toggle_collection()
	for index in 150:
		runtime.step(0.05)
	check(expedition.cargo_inventory().get("relic", 0) == 1 and loot.crates.is_empty(), "Walking collector claims actual physical crate exactly once")
	check(scavenger.boarded and float(scavenger.work_total) == 1, "Collector returns aboard after pickup")
	check(not loot.claim("activity:cargo:wreck-once:relic", expedition), "Stale crate ID cannot duplicate cargo")
	var gunner := Factory.create("shooter", "gunner-test", Vector3(80, 0, 50))
	var target := combat.model.spawn_enemy("rifleman", Vector3(90, 0, 50))
	check(runtime._fire(gunner, target, Roles.ROLES.shooter), "Crew gunner fires a real combat projectile")
	var shot: Dictionary = combat.model.projectiles[-1]
	var expected: Vector3 = (combat.model._target_aim(target) - shot.position).normalized()
	check(Vector3(shot.velocity).normalized().dot(expected) > 0.999, "Crew projectile aims at world enemy position away from origin")
	combat.model.enemies.clear()
	combat.model.player.fuel = 20
	var pickup_id: int = combat.model.spawn_pickup(Vector3(28, 0, 0), 5, "fuel")
	var fuel_pickup: Dictionary = runtime._pickups().filter(func(pickup): return pickup.get("combat_id", -1) == pickup_id)[0]
	check(runtime._collect(scavenger, fuel_pickup) and not runtime._collect(scavenger, fuel_pickup) and combat.model.player.fuel == 20, "Fuel is claimed once but stays carried without immediate rewards")
	check(runtime._deliver(scavenger) and combat.model.player.fuel == 25 and not scavenger.has("carried_parcel"), "Delivering fuel at boarding transfers it exactly once")
	check(runtime._deliver(scavenger) and combat.model.player.fuel == 25, "Repeated delivery cannot duplicate fuel")
	var original_cargo: Dictionary = expedition.backpack.duplicate(true)
	loot.spawn_items("carry-full", scavenger.position + Vector3.RIGHT * 8, {"relic": 1})
	var carry_pickup: Dictionary = runtime._pickups().filter(func(pickup): return pickup.has("crate_id"))[0]
	check(runtime._collect(scavenger, carry_pickup) and scavenger.has("carried_parcel") and expedition.backpack == original_cargo, "Claimed crate stays with collector and is not deposited remotely")
	expedition.backpack = {"scrap": expedition.capacity()}
	check(not runtime._deliver(scavenger) and scavenger.has("carried_parcel"), "Full cargo holds the parcel without deleting it or granting rewards")
	expedition.backpack = original_cargo.duplicate(true)
	check(runtime._deliver(scavenger) and expedition.backpack.get("relic", 0) == 2, "Held parcel delivers once when cargo space becomes available")
	var field_wagon: Dictionary = preload("res://modules/caravan/wagon_factory.gd").create("cargo", "wagon-field")
	field_wagon.position = combat.model.player.position
	expedition.caravan.wagons.append(field_wagon)
	check(expedition.caravan.assign(scavenger.id, field_wagon.id, 0), "Collector can be assigned to a wagon")
	scavenger.boarded = false
	scavenger.position = combat.model.player.position + Vector3.RIGHT * 4
	expedition.caravan.damage_wagon(field_wagon.id, 10000)
	check(not scavenger.dead, "Destroyed wagon does not kill collector who is physically outside")
	var field_position: Vector3 = scavenger.position
	check(expedition.caravan.assign(scavenger.id, "crawler", 1) and scavenger.position == field_position and not scavenger.boarded, "Nearby survivor can change assignment without teleporting aboard")
	for index in 35:
		runtime.step(0.05)
	check(scavenger.boarded and scavenger.position == combat.model.player.position, "Reassigned survivor walks back and boards the pickup")
	loot.spawn_items("carry-death", scavenger.position + Vector3.RIGHT * 8, {"relic": 1})
	carry_pickup = runtime._pickups().filter(func(pickup): return pickup.has("crate_id"))[0]
	runtime._collect(scavenger, carry_pickup)
	expedition.caravan.damage_crew(scavenger.id, 9999)
	check(not runtime._deliver(scavenger) and expedition.backpack.get("relic", 0) == 2, "Death before delivery loses carried parcel and grants no cargo")
	var air_person: Dictionary = runtime.recruits[1]
	world.tornado.position = air_person.position
	world.tornado.intensity = 1
	runtime.step(0.05)
	check(air_person.get("airborne", false), "Tornado captures neutral foot actor")
	world.tornado.intensity = 0
	for index in 180:
		runtime.step(0.05)
	check(not air_person.get("airborne", false) and air_person.hp < air_person.max_hp, "Tornado throws actor and applies landing damage")
	var health: float = air_person.hp
	runtime.step(0.2)
	check(air_person.hp == health, "Landing damage cannot repeat")
	world.running = false
	var before: Vector3 = scavenger.position
	runtime.step(2)
	check(scavenger.position == before and not runtime.rescue_nearest(), "Paused world prevents jobs and rescue")
	world.running = true
	expedition.caravan.locked = true
	check(not runtime.damage_target(runtime.recruits[-1].id, 10) and not runtime.toggle_collection(), "Pending save result blocks crew mutation")
	expedition.caravan.locked = false
	expedition.finish_run(false)
	runtime.queue_free()
	loot.queue_free()
	vehicle.queue_free()
	combat.queue_free()
	world.queue_free()
	await process_frame
	print("Crew runtime tests: %d/%d" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
func check_solid_step(world, start: Vector3, end: Vector3) -> void:
	if not world.props.first_segment(start, end, 0.64, true).is_empty():
		failures += 1
		printerr("FAIL: navigation crossed a solid obstacle")

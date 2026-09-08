extends SceneTree

const Rules = preload("res://modules/world/fuel_station_rules.gd")
const Damage = preload("res://modules/world/damage_context.gd")
const Vehicle = preload("res://modules/caravan/vehicle_controller.gd")
const Combat = preload("res://modules/combat/combat_runtime.gd")
const World = preload("res://modules/world/world_runtime.gd")
const Context = preload("res://modules/world/generation/generation_context.gd")
const Natural = preload("res://modules/world/generation/natural_props.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
const Scatter = preload("res://modules/world/generation/scatter_generator.gd")

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
	_check_generated_layouts()
	preload("res://app/input_actions.gd").register()
	var arena := preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	var vehicle := Vehicle.new()
	root.add_child(vehicle)
	vehicle.set_driving_enabled(false)
	var combat := Combat.new()
	root.add_child(combat)
	combat.setup(vehicle)
	var world := World.new()
	root.add_child(world)
	world.setup(arena, combat, vehicle)
	_check_station(world, combat, vehicle, "cached")
	var context := preload("res://modules/world/generation/world_generator.gd").generate(72841, Authored.new())
	paused = true
	check(arena.rebuild_from_context(context), "Generated oil field replaces frozen world")
	world.rebind_world(int(context.layout.seed))
	paused = false
	_check_station(world, combat, vehicle, "generated")
	var metadata := Rules.prop_metadata(arena.world_layout)
	metadata.values()[0].drops.fuel = 1
	check(Rules.PUMP_FUEL_DROP == int(Rules.DEFINITIONS.pumpjack.drops.fuel), "Instance metadata cannot mutate shared station definitions")
	world.free()
	combat.free()
	vehicle.free()
	arena.free()
	await process_frame
	print("Fuel stations: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

static func pump_context() -> RefCounted:
	var context := Context.new()
	context.setup(72841)
	context.layout.monuments = [{"id": "oil-pump", "type": "pumpjack", "x": 80.0, "z": 0.0, "rotation": 0.0}]
	var natural := Natural.new()
	natural.setup(context)
	var authored := Authored.new()
	authored.setup(context, natural)
	var scatter := Scatter.new()
	scatter.setup(context, natural, authored)
	scatter.monuments()
	return context

func _check_station(world: Node3D, combat: Node3D, vehicle: CharacterBody3D, label: String) -> void:
	var pumps: Array = world.arena.world_layout.landmarks.filter(func(site): return site.type == "pumpjack")
	check(not pumps.is_empty(), label + " world contains oil pump stations")
	if pumps.is_empty():
		return
	var site: Dictionary = pumps[0]
	var prop: Dictionary = world.props.records["prop:" + str(site.id)]
	var point: Vector3 = prop.position
	check(prop.get("station_kind", "") == "pumpjack" and int(prop.get("drops", {}).get("fuel", 0)) == Rules.PUMP_FUEL_DROP, label + " pump receives catalog fuel metadata")
	vehicle.global_position = point + Vector3(Rules.REFILL_RADIUS - 0.5, 0, 0)
	vehicle.fuel = 10.0
	world._refill_station(0.5)
	check(is_equal_approx(vehicle.fuel, 10 + Rules.REFILL_PER_SECOND * 0.5), label + " intact pump preserves passive refill")
	combat.model.pickups.clear()
	combat.model.running = true
	combat.model.status = "running"
	world.damage_props(point, 0.01, 9999, Damage.create("shot"))
	var fuel: Array = combat.model.pickups.filter(func(pickup): return pickup.kind == "fuel")
	check(prop.destroyed and fuel.size() == 1 and int(fuel[0].value) == Rules.PUMP_FUEL_DROP, label + " shooting pump spawns one physical fuel pickup")
	check(world.arena._prop_colliders[str(prop.id)].collision_layer == 0, label + " destroyed pump collider is disabled")
	world.damage_props(point, 0.01, 9999, Damage.create("explosion"))
	world._flush_prop_events()
	check(combat.model.pickups.filter(func(pickup): return pickup.kind == "fuel").size() == 1, label + " repeated damage and flush cannot duplicate fuel")
	var before: float = vehicle.fuel
	world._refill_station(1.0)
	check(is_equal_approx(vehicle.fuel, before), label + " destroyed pump stops passive refill")
	combat.model.player.fuel = combat.model.player.max_fuel
	check(not combat.model.collect_pickup(int(fuel[0].id)) and not fuel[0].dead, label + " full tank leaves dropped fuel pickable")
	combat.model.player.fuel = 0.0
	check(combat.model.collect_pickup(int(fuel[0].id)) and is_equal_approx(combat.model.player.fuel, Rules.PUMP_FUEL_DROP), label + " existing pickup transaction adds station fuel")
	world.reset_run()
	check(not prop.destroyed and prop.hp == prop.max_hp, label + " reset restores the pump")
	combat.model.pickups.clear()
	world.damage_props(point, 0.01, 9999, Damage.create("tornado"))
	check(prop.destroyed and combat.model.pickups.is_empty(), label + " unrewarded destruction emits no fuel or salvage")
	world.reset_run()
	world.damage_props(point, 0.01, 9999, Damage.create("explosion"))
	check(combat.model.pickups.filter(func(pickup): return pickup.kind == "fuel").size() == 1, label + " reset permits one new rewarded drop")

func _check_generated_layouts() -> void:
	for seed_value in [0, 1, 42, 72841, 991827, 4294967295]:
		var context := Context.new()
		context.setup(seed_value)
		var stops: Array = context.layout.monuments.filter(func(site): return str(site.id).begins_with("fuel-stop-"))
		check(stops.size() == Rules.GUARANTEED_PUMPS, "Every seed guarantees six roadside oil pumps")
		var nearest := INF
		for site: Dictionary in stops:
			nearest = minf(nearest, Vector2(site.x, site.z).length())
			check(context.Layout.distance_to_road(site, context.layout.roads) <= Rules.ROADSIDE_OFFSET + 0.01, "Fuel stop is reachable from a clear road")
			check(not context.open_dressing_point(site.x, site.z), "Fuel stop apron is protected from trees and rocks")
			for village: Dictionary in context.layout.villages:
				check(context.Layout.distance(site, village) >= 82, "Village buildings cannot overlap reserved fuel stop")
		check(nearest <= Rules.START_FUEL_MAX_DISTANCE, "First pump is within 350 m of spawn")

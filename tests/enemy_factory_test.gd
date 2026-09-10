extends SceneTree

const Factory = preload("res://modules/combat/enemy_factory.gd")
const Catalog = preload("res://modules/combat/enemy_catalog.gd")
const Model = preload("res://modules/combat/combat_model.gd")
const View = preload("res://presentation/combat/combat_view.gd")
const CatalogScale = preload("res://modules/combat/enemy_catalog.gd")
const WorldScale = preload("res://modules/world/world_scale.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 492
	var view := View.new()
	var assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_manifest.json"))
	for kind: String in Catalog.DEFINITIONS:
		var definition: Dictionary = Catalog.DEFINITIONS[kind]
		check(Factory.validation_errors(definition).is_empty(), "Registered definition validates: " + kind)
		var first := Factory.create(kind, 42, Vector3(10, 2, -20), random)
		check(first.id == 42 and first.kind == kind and first.position == Vector3(10, 2, -20) and first.hp == definition.hp and first.max_hp == definition.hp, "Factory creates independent full state: " + kind)
		check(view._enemy_model(first) == definition.model and definition.model in View.ENEMY_MODELS, "Registered model selects prepared pool: " + kind)
		var path := "res://data/visual_models/%s.json" % definition.model
		check(FileAccess.file_exists(path) and path in assets.data, "Model is present and included in preload: " + kind)
		first.hp = 0
		var second := Factory.create(kind, 43, Vector3.ZERO, random)
		check(second.hp == definition.hp and not second.dead, "An instance cannot mutate catalog or next spawn: " + kind)
	for kind in ["rifleman", "ak", "bazooka", "bomber"]:
		check(is_equal_approx(float(Catalog.DEFINITIONS[kind].radius), CatalogScale.SOLDIER_RADIUS) and is_equal_approx(CatalogScale.SOLDIER_RADIUS, 0.7 * WorldScale.SOLDIER_SCALE), kind + " hit radius follows the visible soldier size")
	var boss := Factory.create("leviathan", 10, Vector3.ZERO, random)
	boss.components[0].hp = 0
	check(Factory.create("leviathan", 20, Vector3.ZERO, random).components[0].hp == 220, "Boss components are deep-copied per instance")
	var untouched_state := random.state
	check(Factory.create("missing", 1, Vector3.ZERO, random).is_empty() and random.state == untouched_state, "Unknown kind refuses creation without consuming gameplay randomness")
	var malformed: Dictionary = Catalog.DEFINITIONS.rifleman.duplicate(true)
	malformed.erase("hp")
	check(Factory.from_definition("bad", malformed, 1, Vector3.ZERO, random).is_empty() and random.state == untouched_state, "Malformed definition refuses before randomness")
	var tower: Dictionary = Catalog.DEFINITIONS.garrison_1.duplicate(true)
	tower.erase("height")
	check(Factory.from_definition("bad_tower", tower, 1, Vector3.ZERO, random).is_empty(), "Garrison without targeting height is refused")
	var bad_drone_height: Dictionary = Catalog.DEFINITIONS.shooter.duplicate(true)
	bad_drone_height.erase("height")
	check(Factory.from_definition("bad_height", bad_drone_height, 1, Vector3.ZERO, random, {"height": 4.8}).is_empty(), "Spawn options cannot rescue malformed definitions")
	var vehicle: Dictionary = Catalog.DEFINITIONS.bike.duplicate(true)
	for multiplier: float in [-1.0, NAN, INF]:
		vehicle.spawn.speed_multiplier = multiplier
		check(Factory.from_definition("bad_vehicle", vehicle, 1, Vector3.ZERO, random).is_empty(), "Invalid randomized speed multiplier is refused")
	var variant: Dictionary = Catalog.DEFINITIONS.rifleman.duplicate(true)
	variant.hp = 33.0
	var custom := Factory.from_definition("scout", variant, 17, Vector3.ZERO, random, {"counts_toward_wave": false, "activity_id": "convoy"})
	check(custom.hp == 33 and custom.kind == "scout" and custom.type == "soldier" and custom.model == "rifleman", "A basic infantry variant reuses an existing AI family and visual")
	check(not custom.counts_toward_wave and custom.activity_id == "convoy", "World encounter spawn options survive factory construction")
	var fixed_speed_bike := Factory.from_definition("convoy_bike", Catalog.DEFINITIONS.bike, 18, Vector3.ZERO, random, {"speed": 7.25})
	check(fixed_speed_bike.speed == 7.25, "Spawn options keep their precedence over randomized speed")
	var bomber_variant: Dictionary = Catalog.DEFINITIONS.bomber.duplicate(true)
	var custom_bomber := Factory.from_definition("convoy_bomber", bomber_variant, 19, Vector3.ZERO, random)
	check(custom_bomber.behavior.detonation.range == 3.4 and not custom_bomber.behavior.retreat, "A differently named bomber keeps its catalog behavior profile")
	var drone_variant := Factory.from_definition("convoy_shooter", Catalog.DEFINITIONS.shooter.duplicate(true), 20, Vector3.ZERO, random)
	check(drone_variant.behavior.flight.strafe == 0.65 and drone_variant.behavior.evasion.cooldown == 0.95, "A differently named drone keeps flight and evasion profiles")
	var repair_variant := Factory.from_definition("convoy_repair", Catalog.DEFINITIONS.repairCrawler.duplicate(true), 21, Vector3.ZERO, random)
	check(repair_variant.behavior.repair.heal_rate == 12.0 and repair_variant.behavior.repair.range == 36.0, "A differently named repair vehicle keeps repair profile")
	var mine_variant := Factory.from_definition("convoy_mines", Catalog.DEFINITIONS.minelayer.duplicate(true), 22, Vector3.ZERO, random)
	check(mine_variant.behavior.mines.interval == 4.0, "A differently named minelayer keeps mine profile")
	var invalid_behavior: Dictionary = Catalog.DEFINITIONS.shooter.duplicate(true)
	invalid_behavior.behavior.evasion.erase("chance")
	check(Factory.from_definition("bad_drone", invalid_behavior, 23, Vector3.ZERO, random).is_empty(), "Incomplete behavior profile is refused before spawn")
	var scalar_behavior: Dictionary = Catalog.DEFINITIONS.shooter.duplicate(true)
	scalar_behavior.behavior = 4
	check(Factory.from_definition("bad_behavior", scalar_behavior, 24, Vector3.ZERO, random).is_empty(), "Scalar behavior is refused before spawn")
	var nonnumeric_behavior: Dictionary = Catalog.DEFINITIONS.minelayer.duplicate(true)
	nonnumeric_behavior.behavior.mines.interval = "four"
	check(Factory.from_definition("bad_interval", nonnumeric_behavior, 25, Vector3.ZERO, random).is_empty(), "Nonnumeric nested behavior is refused before spawn")
	var typo_behavior: Dictionary = Catalog.DEFINITIONS.minelayer.duplicate(true)
	typo_behavior.behavior.mines.intervl = typo_behavior.behavior.mines.interval
	typo_behavior.behavior.mines.erase("interval")
	check(Factory.from_definition("bad_mines", typo_behavior, 26, Vector3.ZERO, random).is_empty(), "Unknown behavior field is refused before spawn")
	check(Factory.validation_errors(Catalog.DEFINITIONS.shooter).is_empty(), "Signed flight throttle is a valid catalog tuning")
	check(Factory.validation_errors(Catalog.DEFINITIONS.kamikaze).is_empty() and Catalog.DEFINITIONS.kamikaze.salvage_drops == 2, "Catalog keeps kamikaze salvage drops")
	var left := RandomNumberGenerator.new()
	var right := RandomNumberGenerator.new()
	left.seed = 3822
	right.seed = 3822
	for kind: String in Catalog.DEFINITIONS:
		var a := Factory.create(kind, 1, Vector3.ZERO, left)
		var b := Factory.create(kind, 1, Vector3.ZERO, right)
		check(a == b and left.state == right.state, "Seeded construction repeats for " + kind)
	var model := Model.new()
	model.spawn_queue.clear()
	check(model.spawn_enemy("missing", Vector3.ZERO).is_empty() and model._next_id == 1, "Invalid kind never allocates a runtime ID")
	for index in 84:
		model.spawn_enemy("rifleman", Vector3(index, 0, 100))
	var next_id: int = model._next_id
	check(model.spawn_enemy("rifleman", Vector3.ZERO).is_empty() and model._next_id == next_id, "Capacity failure never allocates a runtime ID")
	model.reset_run(81)
	var live_boss := model.spawn_enemy("leviathan", Vector3(300, 0, 0))
	var ids: Array[int] = [int(live_boss.id)]
	for component: Dictionary in live_boss.components:
		check(component.id not in ids and component.parent_id == live_boss.id, "Boss setup allocates unique runtime component IDs")
		ids.append(component.id)
	check(not live_boss.targetable and live_boss.components[0].targetable and not live_boss.components[4].targetable, "Factory preserves boss phase gates after runtime setup")
	view.free()
	print("Enemy factory: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

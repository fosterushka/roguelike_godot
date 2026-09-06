extends SceneTree
const Support = preload("res://modules/world/activities/support_system.gd")
const Rewards = preload("res://modules/world/activities/case_rewards.gd")
const Random = preload("res://modules/world/activities/source_random.gd")
class CaseVehicle extends Node3D:
	var fuel := 40.0
	var max_fuel := 100.0
	var health := 20.0
	var max_health := 150.0
class CaseCombat extends RefCounted:
	var model: Dictionary
class CaseWorld extends Node3D:
	const PLAYABLE_RADIUS := 600.0
	var vehicle: Node3D
	var combat: RefCounted
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var world := CaseWorld.new()
	root.add_child(world)
	world.vehicle = CaseVehicle.new()
	world.add_child(world.vehicle)
	world.combat = CaseCombat.new()
	var player := {"coins": 0, "xp": 0, "level": 1, "fuel": 40.0, "hp": 20.0, "unlocked_weapons": ["m4"]}
	var catalog := {"m4": {"name": "M4", "projectile": {}}, "rocket": {"name": "Rocket", "projectile": {}}, "flame": {"name": "Flame", "projectile": {}}, "radar": {"name": "Radar"}}
	world.combat.model = {"player": player, "_catalog": catalog}
	var support := Support.new()
	support.setup(world)
	support.reset(91)
	var drop := support.spawn_airdrop(Vector3.ZERO)
	drop.landed = true
	support._update_airdrops(0)
	var events := support.drain_events().filter(func(event: Dictionary) -> bool: return event.kind == "airdrop_claimed")
	check(events.size() == 1, "One landed crate produces one claim")
	var event: Dictionary = events[0]
	var receipt: Dictionary = event.case
	check(receipt.awarded and receipt.source == "airdrop" and receipt.pool.size() == 2, "Airdrop receipt contains awarded winner and available weapons")
	check(receipt.pool.all(func(entry: Dictionary) -> bool: return entry.kind == "blueprint" and entry.type in ["rocket", "flame"]), "Pool excludes already unlocked and non-weapon catalog entries")
	check(receipt.pool.has(receipt.selected) and player.unlocked_weapons.has(receipt.selected.type), "Winning entry from visible pool is actually unlocked")
	check(receipt.guaranteed == {"salvage": 28, "xp": 24, "fuel": 35.0, "repair": 0.0}, "Guaranteed original crate resources remain explicit and separate")
	check(player.coins == 28 and player.xp == 24 and world.vehicle.fuel == 75, "Guaranteed rewards credited exactly once")
	support._update_airdrops(0)
	check(support.drain_events().is_empty() and player.coins == 28 and player.unlocked_weapons.size() == 2, "Repeated update cannot award or reveal crate again")
	var second := support.spawn_airdrop(Vector3.ZERO)
	second.landed = true
	support._update_airdrops(0)
	events = support.drain_events().filter(func(entry: Dictionary) -> bool: return entry.kind == "airdrop_claimed")
	check(events[0].case.pool.size() == 1 and events[0].case.selected.type != receipt.selected.type, "Next crate excludes previous blueprint immediately")
	check(events[0].case.guaranteed.fuel == 25 and world.vehicle.fuel == 100, "Guaranteed fuel receipt reports actual capped fuel")
	check(events[0].case.id != receipt.id, "Cases have distinct source IDs")
	var third := support.spawn_airdrop(Vector3.ZERO)
	third.landed = true
	support._update_airdrops(0)
	events = support.drain_events().filter(func(entry: Dictionary) -> bool: return entry.kind == "airdrop_claimed")
	check(events[0].blueprint == "" and events[0].case.pool.size() == 2, "Exhausted blueprint pool falls back to useful salvage or experience")
	check(events[0].case.pool.all(func(entry: Dictionary) -> bool: return entry.kind in ["salvage", "xp"]), "Full tank cannot roll a useless fuel reward")
	check(events[0].case.pool.has(events[0].case.selected), "Fallback winner remains present in displayed pool")
	var before_coins: int = player.coins
	var before_xp: int = player.xp
	var cart := support.spawn_healer(Vector3.ZERO)
	support._update_healers(0)
	events = support.drain_events().filter(func(entry: Dictionary) -> bool: return entry.kind == "healer_claimed")
	receipt = events[0].case
	check(cart.claimed and world.vehicle.health == 115 and receipt.guaranteed.repair == 95, "Supply vehicle retains original guaranteed repair")
	check(receipt.source == "resource_car" and receipt.awarded, "Supply vehicle emits same awarded case contract")
	check(player.coins - before_coins == (int(receipt.selected.amount) if receipt.selected.kind == "salvage" else 0) and player.xp - before_xp == (int(receipt.selected.amount) if receipt.selected.kind == "xp" else 0), "Only the displayed random bonus is granted")
	before_coins = player.coins
	before_xp = player.xp
	support._update_healers(0)
	check(support.drain_events().is_empty() and player.coins == before_coins and player.xp == before_xp, "Supply vehicle claim cannot repeat")
	world.vehicle.health = world.vehicle.max_health
	world.vehicle.fuel = 99.5
	cart = support.spawn_healer(Vector3.ZERO)
	support._update_healers(0)
	events = support.drain_events().filter(func(entry: Dictionary) -> bool: return entry.kind == "healer_claimed")
	check(cart.claimed and events.size() == 1 and events[0].case.guaranteed.repair == 0, "Undamaged player can still collect supply case")
	var fuel_entries: Array = events[0].case.pool.filter(func(entry: Dictionary) -> bool: return entry.kind == "fuel")
	check(fuel_entries.size() == 1 and is_equal_approx(float(fuel_entries[0].amount), 0.5), "Pool shows exact available fuel capacity before drawing")
	var ids: Array[String] = []
	for index in 8:
		var seeded := Random.new()
		seeded.seed_run(781)
		world.vehicle.fuel = 90.0
		var selection := Rewards.award(player, catalog, world.vehicle, "resource_car", "seeded", seeded, {})
		ids.append(str(selection.selected.id))
		check(world.vehicle.fuel <= world.vehicle.max_fuel, "Fuel bonus never exceeds tank capacity")
	check(ids.all(func(id: String) -> bool: return id == ids[0]), "Identical source seed gives identical actual winner")
	var expected_random := Random.new()
	expected_random.seed_run(120 ^ 0x6cc819)
	support.reset(120)
	for index in 20:
		support.random.next()
	check(support.case_random.next() == expected_random.next(), "Case draws are isolated from support spawn and navigation random consumption")
	world.queue_free()
	await process_frame
	print("Case reward tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

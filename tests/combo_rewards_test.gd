extends SceneTree
const Model = preload("res://modules/combat/combat_model.gd")
const Fury = preload("res://modules/combat/road_fury_rules.gd")
const Activities = preload("res://modules/world/activities/activity_system.gd")
const Foundries = preload("res://modules/world/activities/foundry_system.gd")
var checks := 0
var failures := 0

class FakeWorld extends Node3D:
	var combat: Dictionary
	var vehicle: Dictionary
	var weather := {"phase": {"type": "clear"}}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var model = Model.new()
	model.running = true
	model.spawn_queue.clear()
	model.weapons.clear()
	model.player.nitro_cooldown = 8.0
	for index in 7:
		model.road_fury.record(0.12)
	model.step(0.05)
	var events: Array = model.drain_events()
	check(events.filter(func(event: Dictionary) -> bool: return event.kind == "overdrive_started").size() == 1, "A full driving combo starts one overdrive")
	check(model.player.road_fury_overdrive == 5.0 and model.player.ram_timer == 5.0, "Overdrive gives five seconds of charged ramming")
	check(model.activate_ability(0) and model.player.nitro_cooldown == 0.0, "Overdrive makes nitro immediately available without cooldown")
	model.player.has_bumper = true
	check(model.activate_ability(1) and model.player.ram_timer == 5.0, "Manual ram does not shorten the earned overdrive")
	model.install_weapon("assaultRifle")
	model.weapons[0].cooldown = 10.0
	model._update_weapons(1.0)
	check(is_equal_approx(model.weapons[0].cooldown, 8.55), "Overdrive accelerates real weapon cooldown by 45 percent")
	model.road_fury.record(1.0)
	check(model.road_fury.momentum == 0.0, "Combo cannot refill while overdrive is active")
	for index in 51:
		model._tick_abilities(0.1)
		model.road_fury.step(model.player, 0.1)
	check(model.player.road_fury_overdrive == 0.0 and model.player.ram_timer == 0.0, "Temporary charged ramming expires")
	model.weapons[0].cooldown = 10.0
	model._update_weapons(1.0)
	check(is_equal_approx(model.weapons[0].cooldown, 9.0), "Fire rate returns to normal after overdrive")
	check(model.activate_ability(0) and model.player.nitro_cooldown == 10.0, "Normal nitro cooldown returns after overdrive")
	model.road_fury.record(1.0)
	check(model.road_fury.momentum == 0.0, "Post-overdrive cooldown prevents immediate repeat farming")
	for index in 80:
		model.road_fury.step(model.player, 0.1)
	model.road_fury.record(1.0)
	check(model.road_fury.step(model.player, 0.01), "Driving can earn a fresh overdrive after cooldown")
	model.reset_run()
	check(model.road_fury.overdrive_remaining == 0.0 and model.road_fury.overdrive_cooldown == 0.0, "New run clears temporary driving rewards")
	var world := FakeWorld.new()
	world.combat = {"model": model}
	world.vehicle = {"health": 30.0, "max_health": 100.0, "fuel": 10.0, "max_fuel": 100.0}
	var activities = Activities.new()
	activities.world = world
	var settlement: Dictionary = activities.announce("settlementDistress", {"position": Vector3(20, 0, 0)})
	check(activities.finish(settlement, "completed") and world.vehicle.health == 65.0 and model.player.hp == 65.0, "Saving a settlement repairs 35 percent of hull and syncs combat health")
	check(not activities.finish(settlement, "completed") and world.vehicle.health == 65.0, "Settlement repair cannot be claimed twice")
	var convoy: Dictionary = activities.announce("raiderSupplyConvoy", {"position": Vector3(30, 0, 0)})
	activities.finish(convoy, "completed")
	check(not str(convoy.reward_info.blueprint).is_empty() and model.player.unlocked_weapons.has(convoy.reward_info.blueprint), "Convoy supplies an actual weapon blueprint")
	var cargo_events: Array = model.drain_events().filter(func(event: Dictionary) -> bool: return event.kind == "activity_completed" and event.get("loot_source") == "convoy")
	check(cargo_events.size() == 1 and cargo_events[0].loot_count == 2 and cargo_events[0].position == Vector3(30, 0, 0), "Convoy creates one positioned reward event with two loot rolls")
	var salvage: Dictionary = activities.announce("scavengerRoute", {"position": Vector3.ZERO})
	activities.finish(salvage, "completed")
	check(world.vehicle.fuel == 35.0 and model.player.fuel == 35.0, "Scavenger route restores real vehicle fuel")
	var failed: Dictionary = activities.announce("settlementDistress", {"position": Vector3.ZERO})
	activities.finish(failed, "failed")
	check(world.vehicle.health == 65.0 and not failed.has("reward_info"), "Failed activities do not repair or award loot")
	var foundries = Foundries.new()
	foundries.world = world
	foundries.activities = activities
	foundries.spawned = true
	var fortress: Dictionary = model.spawn_enemy("garrison_1", Vector3(80, 0, 0), {"counts_toward_wave": false})
	fortress.dead = true
	var collider := StaticBody3D.new()
	foundries.colliders.append(collider)
	foundries.foundries.append({"enemy": fortress, "solid": {"destroyed": false}, "index": 0, "cooldown": 0.0})
	var credits_before: int = activities.credits
	model.drain_events()
	foundries.step(0.1)
	foundries.step(0.1)
	var foundry_events: Array = model.drain_events().filter(func(event: Dictionary) -> bool: return event.kind == "activity_completed" and event.get("loot_source") == "foundry")
	check(foundry_events.size() == 1 and foundry_events[0].position == fortress.position, "Destroyed fortress drops rare cargo exactly once")
	check(activities.credits == credits_before + 1 and model.player.activity_credits == activities.credits, "Destroying a fortress earns one extraction credit")
	collider.free()
	world.free()
	print("COMBO_REWARDS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

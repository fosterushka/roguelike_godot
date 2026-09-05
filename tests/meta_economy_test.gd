extends SceneTree

const Progression = preload("res://modules/progression/progression.gd")
const Expedition = preload("res://modules/meta/expedition.gd")
const Store = preload("res://infrastructure/persistence/profile_store.gd")
const Model = preload("res://modules/combat/combat_model.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func run() -> void:
	var path := "/private/tmp/expedition-test-%d.json" % Time.get_ticks_usec()
	var progression := Progression.new(path)
	var model := Model.new()
	progression.setup(model)
	var raid := Expedition.new(progression)
	check(raid.snapshot().credits == 300 and raid.snapshot().level == 1, "legacy profile receives starter account")
	check(raid.action("accept", "first_delivery") and not raid.action("accept", "first_delivery"), "quest accepted once")
	check(raid.action("accept", "road_keeper") and raid.action("accept", "helping_hand"), "all three quests available")
	check(raid.action("buy", "repair_kit") and raid.snapshot().credits == 240, "buy debits credits")
	check(raid.action("equip", "repair_kit") and raid.snapshot().stash.repair_kit == 2, "equipping transfers inventory")
	check(not raid.action("equip", "scrap"), "only useful gear can be loaded")
	check(raid.begin_run(model.player), "run begins and reserves gear")
	check(not raid.begin_run(model.player), "repeated begin cannot reapply buffs")
	check(not raid.action("sell", "repair_kit") and not raid.action("buy", "circuit"), "stash cannot be accessed in raid")
	var crash_reload := Progression.new(path)
	check(crash_reload.profile.expedition.loadout.is_empty() and crash_reload.profile.expedition.stash.repair_kit == 2, "saved start removes carried gear on crash")
	check(not raid.consume("repair_kit", model.player), "full HP does not waste kit")
	model.player.hp -= 100
	check(raid.consume("repair_kit", model.player) and model.player.hp == model.player.max_hp - 10, "repair restores 90 HP")
	check(raid.collect_loot("scrap", 6), "collect physical quest loot")
	for i: int in 12:
		raid.record_event({"kind": "death", "id": i})
		raid.record_event({"kind": "death", "id": i})
	raid.record_event({"kind": "activity_completed", "id": "rescue-1", "activity_type": "settlementDistress"})
	raid.record_event({"kind": "activity_completed", "id": "rescue-2", "activity_type": "settlementDistress"})
	check(raid.snapshot().backpack == {"scrap": 6}, "death and activities do not teleport loot")
	check(raid.collect_loot("relic", 3) and not raid.collect_loot("scrap"), "weighted backpack capacity enforced")
	check(raid.action("discard", "relic") and raid.collect_loot("scrap", 2), "discard frees real item capacity")
	check(raid.finish_run(true), "extraction commits loot and XP")
	check(not raid.finish_run(true), "duplicate extraction cannot duplicate loot")
	check(raid.snapshot().stash.scrap == 8 and raid.snapshot().stash.relic == 2, "extracted items appear in stash")
	check(raid.snapshot().total_xp == 232, "XP counts unique combat events and loot only once")
	check(raid.action("claim", "first_delivery") and raid.snapshot().stash.scrap == 2, "delivery consumes required loot")
	check(not raid.action("claim", "first_delivery"), "quest reward cannot be claimed twice")
	check(raid.action("claim", "road_keeper") and raid.action("claim", "helping_hand"), "successful raid banks kill and rescue quests")
	check(raid.action("upgrade", "armor"), "account upgrade purchased")
	model.reset_run()
	progression.reset_run()
	var base_hp: float = model.player.max_hp
	raid.begin_run(model.player)
	check(model.player.max_hp == base_hp + 20, "permanent armor applies on new raid")
	raid.collect_loot("convoy")
	check(raid.consume("weapon_parts", model.player) and is_equal_approx(model.player.damage_mult, 1.2), "convoy weapon kit grants actual raid damage")
	raid.collect_loot("convoy")
	check(not raid.consume("weapon_parts", model.player), "weapon kit cannot stack infinitely")
	raid.collect_loot("relic")
	var stash_before: Dictionary = raid.snapshot().stash
	check(raid.finish_run(false) and raid.snapshot().stash == stash_before, "death loses all carried items")
	model.reset_run()
	progression.reset_run()
	raid.begin_run(model.player)
	raid.collect_loot("circuit", 3)
	var xp_before: int = raid.snapshot().total_xp
	raid.abandon_run()
	check(not raid.active and raid.snapshot().stash == stash_before and raid.snapshot().total_xp == xp_before, "restart abandons loot and unbanked XP")
	var reloaded := Progression.new(path)
	check(reloaded.profile.expedition == progression.profile.expedition, "account and stash survive full reload")
	var invalid := Store.normalize({"expedition": {"credits": -5, "xp": "huge", "stash": {"scrap": 1.5, "relic": 999999, "fake": 8}, "loadout": {"scrap": 5, "repair_kit": 90}, "upgrades": {"cargo": 99}, "quests": {"fake": {}, "road_keeper": {"status": "active", "progress": 100}}}})
	check(invalid.expedition.credits == 0 and invalid.expedition.xp == 0 and invalid.expedition.stash == {"relic": 9999}, "malformed saves bounded and unknown items discarded")
	check(invalid.expedition.loadout == {"repair_kit": 24} and invalid.expedition.upgrades.cargo == 3, "saved loadout capacity enforced")
	var failed := Progression.new(path + "/missing/profile.json")
	failed.setup(Model.new())
	var unavailable := Expedition.new(failed)
	check(not unavailable.action("buy", "repair_kit") and unavailable.snapshot().credits == 300, "failed save rolls back economic mutation")
	check(not unavailable.begin_run(failed.model.player) and not unavailable.active, "raid cannot start without durable gear reservation")
	model.reset_run()
	progression.reset_run()
	raid.begin_run(model.player)
	raid.collect_loot("foundry")
	progression.store.path = path + "/missing/profile.json"
	var before_retry: Dictionary = raid.snapshot().stash
	check(not raid.finish_run(true) and raid.snapshot().pending_result and raid.snapshot().stash == before_retry, "failed extraction keeps retryable result without partial deposit")
	check(not raid.consume("relic", model.player) and not raid.action("discard", "relic") and not raid.collect_loot("scrap"), "pending result freezes cargo")
	progression.store.path = path
	check(raid.action("retry_save", "") and raid.snapshot().stash.relic == before_retry.relic + 1 and not raid.snapshot().pending_result, "retry deposits foundry relic exactly once")
	check(not raid.action("retry_save", "") and not raid.finish_run(true), "repeated retry cannot duplicate deposit")
	check(Store.normalize({"settings": {"cameraShake": 5.0}}).settings.cameraShake == 1.5 and Store.normalize({"settings": {"cameraShake": 0.0}}).settings.cameraShake == 0.0, "shake settings safely persist including disabled")
	var delivery_owner := Progression.new(path + ".delivery")
	delivery_owner.setup(Model.new())
	var delivery := Expedition.new(delivery_owner)
	delivery.action("accept", "first_delivery")
	delivery.begin_run(delivery_owner.model.player)
	delivery.collect_loot("scrap", 6)
	delivery.action("discard", "scrap")
	delivery.finish_run(true)
	delivery.action("buy", "scrap")
	check(delivery_owner.profile.expedition.quests.first_delivery.progress == 5 and not delivery.action("claim", "first_delivery"), "discarded loot and trader purchases cannot fake extraction quest progress")
	print("Meta economy tests: ", checks - failures, "/", checks)
	quit(1 if failures else 0)

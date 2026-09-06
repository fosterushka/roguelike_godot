extends SceneTree

const Tracker = preload("res://modules/meta/mission_tracker.gd")
const Progress = preload("res://modules/meta/mission_progress.gd")
const Catalog = preload("res://modules/meta/expedition_catalog.gd")
const Missions = preload("res://modules/meta/mission_catalog.gd")
const Expedition = preload("res://modules/meta/expedition.gd")
const Owner = preload("res://modules/progression/progression.gd")
const Model = preload("res://modules/combat/combat_model.gd")
const Store = preload("res://infrastructure/persistence/profile_store.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_test_metrics()
	_test_event_boundary()
	_test_objectives()
	_test_persistence()
	print("MISSION_TRACKER: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_metrics() -> void:
	var model := Model.new()
	var player: Dictionary = model.player
	var tracker := Tracker.new()
	tracker.reset(player)
	tracker.record({"kind": "death", "id": 1, "type": "soldier", "enemy_kind": "ak"})
	tracker.record({"kind": "death", "id": 1, "type": "soldier", "enemy_kind": "ak"})
	tracker.record({"kind": "death", "id": 2, "type": "garrison", "rewarded": false})
	check(tracker.metrics.kills == 1 and tracker.metrics.kills_soldier == 1 and tracker.metrics.kills_ak == 1 and not tracker.metrics.has("kills_garrison"), "Unique rewarded deaths count enemy categories once")
	tracker.record({"kind": "shot", "id": 10, "team": "enemy", "module_type": "assaultRifle"})
	tracker.record({"kind": "shot", "id": 11, "team": "player", "module_type": "railgun"})
	check(tracker.metrics.shots == 1 and tracker.metrics.shots_railgun == 1 and not tracker.metrics.has("shots_assaultRifle"), "Weapon objectives count player fire only")
	for event: Dictionary in [{"kind": "ram_impact"}, {"kind": "roadkill_impact"}, {"kind": "overdrive_started"}, {"kind": "mine_hacked", "id": 4}, {"kind": "boss_component_destroyed", "id": 7}, {"kind": "airdrop_claimed", "id": 1}, {"kind": "healer_claimed", "id": 1}]:
		tracker.record(event)
	check(tracker.metrics.rams == 1 and tracker.metrics.roadkills == 1 and tracker.metrics.overdrives == 1 and tracker.metrics.mine_hacks == 1 and tracker.metrics.boss_components == 1 and tracker.metrics.airdrops == 1 and tracker.metrics.healers == 1, "Driving, hacking, boss and support events have independent metrics")
	for activity: String in ["raiderSupplyConvoy", "settlementDistress", "foundryDestroyed", "scavengerRoute"]:
		tracker.record({"kind": "activity_completed", "id": activity, "activity_type": activity})
	check(tracker.metrics.activities == 4 and tracker.metrics.convoys == 1 and tracker.metrics.rescues == 1 and tracker.metrics.foundries == 1 and tracker.metrics.scavengers == 1, "Activity categories retain distinct mission progress")
	player.speed = 8.0
	player.handbraking = true
	player.slip_angle = 0.3
	player.road_fury_combo = 7
	tracker.sample(player, 2.0, "storm")
	player.position = Vector3(10000, 0, 10000)
	tracker.sample(player, 0.0, "sunny")
	check(tracker.metrics.distance == 16.0 and tracker.metrics.drift_distance == 16.0 and tracker.metrics.drift_seconds == 2.0 and tracker.metrics.storm_seconds == 2.0 and tracker.metrics.sectors == 2, "Driving uses simulated speed and time; teleports cannot fake distance")
	check(tracker.metrics.speed_max == 8.0 and tracker.metrics.combo_max == 7.0, "Peak speed and combo use player telemetry")
	tracker.record({"kind": "player_hit", "damage": 50.0, "hp": 125.0})
	tracker.sample(player, 0.0, "")
	check(tracker.metrics.damage_taken == 50.0 and tracker.metrics.hits_taken == 1 and tracker.metrics.min_health_pct == 50.0, "Damage captures low-health condition even if repaired before next sample")
	tracker.consumable("repair_kit")
	tracker.consumable("fuel_cell")
	tracker.record({"kind": "ability", "slot": 0})
	check(tracker.metrics.consumables_used == 2 and tracker.metrics.repair_uses == 1 and tracker.metrics.fuel_uses == 1 and tracker.metrics.nitro_uses == 1, "Consumables and nitro have independent counters")
	tracker.loot("scrap", 6)
	tracker.loot("relic", 2)
	tracker.record({"kind": "extraction_started", "site_id": "extract-2"})
	tracker.record({"kind": "extraction_failed"})
	tracker.record({"kind": "extraction_started", "site_id": "extract-3"})
	var cargo := {"scrap": 5, "relic": 1, "fuel_cell": 1}
	tracker.finalize(player, cargo, Catalog.ITEMS, {"extracted": true})
	tracker.finalize(player, cargo, Catalog.ITEMS, {"extracted": true})
	check(tracker.metrics.loot_scrap == 5 and tracker.metrics.loot_relic == 1 and tracker.metrics.loot_fuel_cell == 0 and tracker.metrics.loot_items == 6 and tracker.metrics.loot_types == 2 and tracker.metrics.loot_slots == 7, "Only newly acquired cargo still carried at extraction counts with correct weight and variety")
	check(tracker.metrics.extractions == 1 and tracker.metrics.extract_3 == 1 and tracker.metrics.extraction_attempts == 2 and tracker.metrics.extraction_cancels == 1, "Zone and extraction result finalize exactly once")
	tracker.record({"kind": "ram_impact"})
	check(tracker.metrics.rams == 1, "Finalized metrics are immutable during result save retries")

func _test_event_boundary() -> void:
	var tracker := Tracker.new()
	tracker.reset(Model.new().player)
	for id in Tracker.RECENT_EVENT_LIMIT + 5:
		tracker.record({"kind": "shot", "id": id, "team": "enemy"})
		tracker.record({"kind": "spawn", "id": id})
	check(tracker._seen.is_empty() and tracker.metrics.get("shots", 0) == 0, "Enemy fire and unrelated event streams do not consume mission deduplication memory")
	for id in Tracker.RECENT_EVENT_LIMIT + 7:
		tracker.record({"kind": "shot", "id": id, "team": "player", "module_type": "assaultRifle"})
	tracker.record({"kind": "death", "id": 90001, "type": "soldier"})
	tracker.record({"kind": "activity_completed", "id": "late-convoy", "activity_type": "raiderSupplyConvoy"})
	tracker.record({"kind": "death", "id": 90001, "type": "soldier"})
	tracker.record({"kind": "activity_completed", "id": "late-convoy", "activity_type": "raiderSupplyConvoy"})
	check(tracker.metrics.shots == Tracker.RECENT_EVENT_LIMIT + 7 and tracker.metrics.kills == 1 and tracker.metrics.convoys == 1, "Long raids keep counting new shots, kills and activities while rejecting recent replayed events")
	check(tracker._seen.size() == Tracker.RECENT_EVENT_LIMIT and tracker._recent_ids.size() == Tracker.RECENT_EVENT_LIMIT, "Deduplication storage stays bounded after the capacity boundary")
	tracker.reset(Model.new().player)
	check(tracker._seen.is_empty() and tracker._recent_ids.is_empty(), "A new raid clears the recent-event ring")

func _test_objectives() -> void:
	var definitions := {
		"career": {"id": "career", "name": "career", "scope": "career", "objectives": [{"metric": "kills", "target": 4}, {"metric": "convoys", "target": 2}], "conditions": [], "delivery": {}, "min_level": 1, "credits": 10, "xp": 10},
		"raid": {"id": "raid", "name": "raid", "scope": "raid", "objectives": [{"metric": "kills", "target": 2}, {"metric": "convoys", "target": 1}], "conditions": [{"metric": "damage_taken", "op": "max", "value": 0}, {"metric": "health_pct", "op": "min", "value": 80}], "delivery": {}, "min_level": 1, "credits": 10, "xp": 10}
	}
	var states := {"career": {"status": "active", "progress": 0}, "raid": {"status": "active", "progress": 0}}
	Progress.commit(states, definitions, {"kills": 2, "convoys": 0, "damage_taken": 0, "health_pct": 100})
	Progress.commit(states, definitions, {"kills": 0, "convoys": 1, "damage_taken": 0, "health_pct": 100})
	check(states.career.counts.kills == 2 and states.career.counts.convoys == 1 and states.raid.progress == 0, "Career accumulates objectives separately; raid cannot combine different attempts")
	Progress.commit(states, definitions, {"kills": 2, "convoys": 1, "damage_taken": 1, "health_pct": 100})
	check(states.raid.progress == 0 and Progress.objectives_met(definitions.career, states.career.counts), "Failed same-raid condition blocks completion despite all objectives")
	Progress.commit(states, definitions, {"kills": 2, "convoys": 1, "damage_taken": 0, "health_pct": 90})
	check(Progress.objectives_met(definitions.raid, states.raid.counts), "All raid objectives and min/max conditions complete together")
	var row := Progress.row(definitions.raid, states.raid, {}, 1, false, 2, {})
	check(row.status == "ready" and row.can_claim and row.objectives.size() == 2 and row.progress == 3, "Snapshot exposes complete objective rows and legacy progress")

func _test_persistence() -> void:
	var model := Model.new()
	var path := "/private/tmp/mission-tracker-%d.json" % Time.get_ticks_usec()
	var owner := Owner.new(path)
	owner.setup(model)
	var raid := Expedition.new(owner)
	check(Missions.all().size() >= 100, "Real content contains at least one hundred missions")
	var accepted: Array[String] = []
	for id: String in Missions.all():
		if int(Missions.all()[id].min_level) == 1 and accepted.size() < 5:
			check(raid.action("accept", id), "Available mission accepts before active limit")
			accepted.append(id)
	check(accepted.size() == 5 and raid.active_missions().size() == 5 and raid.snapshot().active_quest_count == 5, "At most five missions are tracked for the run HUD")
	var next_available := ""
	var locked := ""
	for id: String in Missions.all():
		if int(Missions.all()[id].min_level) == 1 and not accepted.has(id): next_available = id
		if int(Missions.all()[id].min_level) > 1: locked = id
	check(not next_available.is_empty() and not raid.action("accept", next_available), "Sixth active mission is rejected")
	check(raid.action("abandon_quest", accepted[4]) and raid.action("accept", next_available), "Abandon releases one active slot")
	check(raid.action("abandon", next_available), "A free active slot is available for the level-gate check")
	check(not locked.is_empty() and not raid.action("accept", locked) and raid.snapshot().active_quest_count == 4, "Level gate rejects a locked mission despite an available slot")
	check(raid.action("accept", next_available), "An unlocked mission still accepts in the same free slot")
	for id: String in owner.profile.expedition.quests.keys():
		raid.action("abandon", id)
	check(raid.action("accept", "first_delivery"), "Legacy mission id remains available")
	model.reset_run()
	raid.begin_run(model.player)
	raid.collect_loot("scrap", 6)
	raid.finish_run(false)
	check(owner.profile.expedition.quests.first_delivery.progress == 0, "Death never banks mission progress")
	model.reset_run()
	raid.begin_run(model.player)
	raid.collect_loot("scrap", 6)
	raid.abandon_run()
	check(owner.profile.expedition.quests.first_delivery.progress == 0, "Abandon never banks mission progress")
	model.reset_run()
	raid.begin_run(model.player)
	raid.collect_loot("scrap", 6)
	owner.store.path = path + "/missing/save.json"
	check(not raid.finish_run(true) and owner.profile.expedition.quests.first_delivery.progress == 0, "Failed extraction save rolls mission progress back")
	owner.store.path = path
	check(raid.action("retry_save", "") and owner.profile.expedition.quests.first_delivery.progress == 6, "Retry commits progress together with extracted loot")
	var credits_before: int = owner.profile.expedition.credits
	owner.store.path = path + "/missing/save.json"
	check(not raid.action("claim", "first_delivery") and owner.profile.expedition.credits == credits_before and owner.profile.expedition.stash.scrap == 6, "Failed delivery claim restores items, credits and ready mission")
	owner.store.path = path
	check(raid.action("claim", "first_delivery") and not raid.action("claim", "first_delivery"), "Successful claim pays only once")
	check(Store.new(path).load_profile().expedition == owner.profile.expedition, "Detailed progress and compact claims survive disk reload")
	var migrated := Catalog.normalize({"quests": {"first_delivery": {"status": "active", "progress": 4}, "road_keeper": {"status": "claimed", "progress": 12}}})
	check(migrated.quests.first_delivery.progress == 4 and migrated.quests.first_delivery.counts.loot_scrap == 4 and migrated.quests.road_keeper.status == "claimed", "Legacy scalar progress migrates without losing active or claimed missions")
	var maximum := Store.defaults()
	for id: String in Missions.all():
		maximum.expedition.quests[id] = {"status": "claimed", "progress": 0}
	check(Store.new(path + ".all").save_profile(maximum), "All mission claims fit the actual bounded profile store")
	var all_reloaded: Dictionary = Store.new(path + ".all").load_profile().expedition.quests
	check(all_reloaded.size() == Missions.all().size() and all_reloaded.values().all(func(state: Dictionary) -> bool: return state.status == "claimed"), "All claimed missions survive actual reload without normalization truncation")

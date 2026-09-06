extends SceneTree
const Tracker = preload("res://modules/meta/mission_tracker.gd")
const Progress = preload("res://modules/meta/mission_progress.gd")
const Missions = preload("res://modules/meta/mission_catalog.gd")
const Items = preload("res://modules/meta/expedition_catalog.gd")
const Crew = preload("res://modules/crew/crew_factory.gd")
const Service = preload("res://modules/crew/crew_service.gd")
const Wagon = preload("res://modules/caravan/wagon_factory.gd")
const Model = preload("res://modules/combat/combat_model.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	_test_catalog()
	_test_repair()
	_test_extraction()
	_test_persistence()
	print("CREW_MISSIONS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_catalog() -> void:
	var ids := ["rescue_new_hand", "working_mechanic", "bring_team_home", "rescue_under_storm", "loaded_caravan_home", "field_repair_convoy"]
	for id: String in ids:
		var mission: Dictionary = Missions.all().get(id, {})
		check(not mission.is_empty() and Missions.validate(mission).is_empty(), "New real gameplay mission has complete valid localized content: " + id)
	check(Missions.all().size() == 126 and Missions.errors().is_empty(), "Six crew missions extend the existing120 without replacing them")

func _test_repair() -> void:
	var player: Dictionary = Model.new().player
	var mechanic := Crew.create("mechanic", "crew-1")
	player.crew = [mechanic]
	player.hp = 100.0
	var tracker := Tracker.new()
	tracker.reset(player)
	var service := Service.new()
	service.step(5.3, player, [], player.crew, [], [])
	var actual := float(player.hp) - 100.0
	var events := service.drain_events()
	check(events.size() >= 4 and events.all(func(event: Dictionary) -> bool: return event.kind == "crew_repaired" and event.has("total")), "Actual mechanic emits cumulative repair updates with a reusable crew ID")
	for event: Dictionary in events:
		tracker.record(event)
		tracker.record(event)
	tracker.sample(player, 0.0, "sunny")
	check(absf(float(tracker.metrics.crew_repair_hp) - actual) < 0.0001, "Every actual HP repaired counts once, including the final unreported fraction")
	service.step(2.0, player, [], player.crew, [], [])
	for event: Dictionary in service.drain_events():
		tracker.record(event)
	tracker.sample(player, 0.0, "sunny")
	check(absf(float(tracker.metrics.crew_repair_hp) - (float(player.hp) - 100.0)) < 0.0001, "Later repairs from the same mechanic are not lost to entity-ID deduplication")
	var total: float = tracker.metrics.crew_repair_hp
	tracker.record(events[0])
	tracker.record({"kind": "crew_repaired", "id": mechanic.id, "total": NAN})
	tracker.record({"kind": "crew_repaired", "id": mechanic.id, "total": -4})
	check(tracker.metrics.crew_repair_hp == total, "Replayed or invalid repair totals never duplicate or reduce mission progress")
	tracker.reset(player)
	tracker.sample(player, 0.0, "sunny")
	check(tracker.metrics.get("crew_repair_hp", 0.0) == 0.0, "Starting a tracker with existing crew work does not count previous raid repairs")

func _test_extraction() -> void:
	var player: Dictionary = Model.new().player
	var wagons := [Wagon.create("cargo", "wagon-1"), Wagon.create("repair", "wagon-2"), Wagon.create("weapon", "wagon-3")]
	wagons[1].attached = false
	wagons[2].dead = true
	wagons[2].hp = 0
	player.carriers = wagons
	var people: Array = []
	for index in 6:
		people.append(Crew.create("mechanic" if index == 0 else "shooter", "crew-%d" % (index + 1)))
	people[1].carrier_id = "wagon-1"
	people[2].carrier_id = "wagon-2"
	people[3].dead = true
	people[3].hp = 0
	people[4].boarded = false
	people[5].rescued = true
	player.crew = people + [people[1]]
	var tracker := Tracker.new()
	tracker.reset(player)
	tracker.record({"kind": "crew_rescued", "id": "crew-6"})
	tracker.record({"kind": "crew_rescued", "id": "crew-6"})
	tracker.record({"kind": "crew_died", "id": "crew-4"})
	tracker.record({"kind": "crew_died", "id": "crew-4"})
	tracker.finalize(player, {}, Items.ITEMS, {"extracted": true})
	check(tracker.metrics.crew_rescued == 1 and tracker.metrics.rescued_crew_extracted == 1, "A newly rescued person counts once and must actually return alive")
	check(tracker.metrics.wagons_extracted == 1 and tracker.metrics.crew_extracted == 3, "Final counts exclude dead/detached wagons, dead/unboarded crew, and duplicate IDs")
	check(tracker.metrics.crew_lost == 3, "Crew on a detached wagon or outside count as left behind; dead crew are not counted twice")
	var frozen := tracker.metrics.duplicate(true)
	tracker.finalize(player, {}, Items.ITEMS, {"extracted": true})
	tracker.record({"kind": "crew_rescued", "id": "late"})
	check(tracker.metrics == frozen, "Result retries and late events cannot increment finalized crew metrics")
	var state := {"bring_team_home": {"status": "active", "progress": 0}}
	Progress.commit(state, Missions.all(), tracker.metrics)
	check(state.bring_team_home.progress == 0, "No-loss team mission rejects an extraction that left crew behind")
	var failure := Tracker.new()
	failure.reset(player)
	failure.finalize(player, {}, Items.ITEMS, {"won": false, "extracted": false})
	check(failure.metrics.get("crew_extracted", 0) == 0 and failure.metrics.get("wagons_extracted", 0) == 0, "A failed raid never reports successfully extracted crew or wagons")
	var victory := Tracker.new()
	victory.reset(player)
	victory.finalize(player, {}, Items.ITEMS, {"won": true})
	check(victory.metrics.crew_extracted == 3 and victory.metrics.wagons_extracted == 1, "Boss victory counts the same surviving manifest that the garage receives")

func _test_persistence() -> void:
	var path := "/private/tmp/crew-missions-%d.json" % Time.get_ticks_usec()
	var model := Model.new()
	var owner := preload("res://modules/progression/progression.gd").new(path)
	owner.setup(model)
	var raid := preload("res://modules/meta/expedition.gd").new(owner)
	check(raid.action("accept", "rescue_new_hand") and raid.action("accept", "working_mechanic"), "New low-level crew missions can be accepted through real expedition actions")
	check(raid.begin_run(model.player), "Failed-raid scenario starts through the existing save transaction")
	model.player.crew = raid.caravan.crew
	var lost := Crew.create_neutral("mechanic", "neutral-lost", Vector3.ZERO)
	check(raid.caravan.rescue(lost), "Actual roster rescues a neutral mechanic into a free seat")
	for event: Dictionary in raid.caravan.drain_events():
		raid.record_event(event)
	raid.finish_run(false)
	check(owner.profile.expedition.quests.rescue_new_hand.progress == 0, "Rescue progress is not banked when the player dies")
	model.reset_run()
	check(raid.begin_run(model.player), "Successful-raid scenario begins independently")
	model.player.crew = raid.caravan.crew
	var rescued := Crew.create_neutral("mechanic", "neutral-returning", Vector3.ZERO)
	check(raid.caravan.rescue(rescued), "Second raid rescues a distinct real mechanic")
	for event: Dictionary in raid.caravan.drain_events():
		raid.record_event(event)
	model.player.hp = 100.0
	var service := Service.new()
	service.step(60.1, model.player, raid.caravan.wagons, raid.caravan.crew, [], [])
	for event: Dictionary in service.drain_events():
		raid.record_event(event)
	raid.sample_run(model.player, 60.1, "sunny")
	owner.store.path = path + "/missing/save.json"
	check(not raid.finish_run(true) and owner.profile.expedition.quests.rescue_new_hand.progress == 0 and owner.profile.expedition.quests.working_mechanic.progress == 0, "Failed result save rolls back both crew objectives")
	owner.store.path = path
	check(raid.action("retry_save", ""), "Retry saves the original successful crew manifest")
	check(owner.profile.expedition.quests.rescue_new_hand.progress == 2 and owner.profile.expedition.quests.working_mechanic.progress == 120, "Real rescue, extraction and mechanic repair complete both missions once")
	var credits: int = owner.profile.expedition.credits
	check(raid.action("claim", "rescue_new_hand") and not raid.action("claim", "rescue_new_hand") and owner.profile.expedition.credits == credits + Missions.all().rescue_new_hand.credits, "New mission reward can be claimed exactly once through the real economy")
	var reloaded: Dictionary = preload("res://infrastructure/persistence/profile_store.gd").new(path).load_profile()
	check(reloaded.expedition.quests.rescue_new_hand.status == "claimed" and reloaded.expedition.quests.working_mechanic.progress == 120 and reloaded.expedition.caravan.crew.has(rescued.id), "Mission state and the same rescued person survive actual disk reload")

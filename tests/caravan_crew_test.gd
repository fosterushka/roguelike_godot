extends SceneTree
const Progression = preload("res://modules/progression/progression.gd")
const Expedition = preload("res://modules/meta/expedition.gd")
const Model = preload("res://modules/combat/combat_model.gd")
const Store = preload("res://infrastructure/persistence/profile_store.gd")
const WagonCatalog = preload("res://modules/caravan/wagon_catalog.gd")
const CrewFactory = preload("res://modules/crew/crew_factory.gd")
const CaravanSave = preload("res://modules/caravan/caravan_save.gd")
const GaragePanel = preload("res://presentation/ui/caravan_panel.gd")
const Service = preload("res://modules/crew/crew_service.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _run() -> void:
	var path := "/private/tmp/caravan-crew-%d.json" % Time.get_ticks_usec()
	var p := Progression.new(path)
	var model := Model.new()
	p.setup(model)
	var expedition := Expedition.new(p)
	var roster = expedition.caravan
	check(roster.snapshot().wagons.is_empty() and roster.snapshot().crew.is_empty(), "Legacy and new profiles receive no free wagons or crew")
	p.profile.expedition.credits = 5000
	var ids: Array[String] = []
	for type: String in WagonCatalog.TYPES:
		check(roster.buy_wagon(type), "Individually buy supported wagon type: " + type)
		ids.append(str(roster.data().selected_wagon_ids[-1]))
	var balance: int = p.profile.expedition.credits
	check(not roster.buy_wagon("cargo") and p.profile.expedition.credits == balance and ids.size() == 6, "Seventh wagon denied without charging credits")
	check(roster.install_attachment(ids[0], 0, "cargo_rack") and not roster.install_attachment(ids[0], 0, "armor_panels"), "Attachment occupies one real mount and prevents overlap")
	check(roster.install_attachment(ids[1], 1, "repair_station"), "Utility station saved on its own wagon")
	var saved: Dictionary = Store.new(path).load_profile()
	check(saved.expedition.caravan.wagons.size() == 6 and saved.expedition.caravan.wagons[ids[0]].attachments.size() == 1, "Bought wagon identities and attachments reach disk")
	check(expedition.begin_run(model.player) and roster.wagons.size() == 6 and model.player.carriers.size() == 6, "Selected wagons enter one active convoy")
	check(Store.new(path).load_profile().expedition.caravan.wagons.is_empty(), "Atomic departure removes deployed wagons from garage on disk")
	check(not expedition.begin_run(model.player) and not roster.buy_wagon("cargo"), "Repeated start and in-raid garage purchase blocked")
	check(expedition.collect_loot("scrap", 20) and expedition.backpack.scrap == 12 and roster.wagons[0].cargo.scrap == 8, "Cargo fills pickup first then the specific cargo wagon")
	var npc := CrewFactory.create_neutral("mechanic", "stranded-one", Vector3.ZERO)
	check(roster.rescue(npc) and not roster.rescue(npc), "Neutral mechanic can be rescued once and boarded without first-raid wage")
	var crew_id: String = npc.id
	check(npc.faction == "ally" and npc.boarded and crew_id.begins_with("crew-"), "Rescue creates a permanent allied identity")
	var far_npc := CrewFactory.create_neutral("shooter", "far", Vector3(90, 0, 0))
	check(not roster.rescue(far_npc), "Remote rescue is rejected")
	model.player.modules.append({"type": "bazooka", "level": 2, "mount": {"carrierId": ids[2], "slot": 0}})
	check(expedition.finish_run(true), "Successful extraction saves cargo and surviving convoy atomically")
	saved = Store.new(path).load_profile()
	check(saved.expedition.caravan.wagons.size() == 6 and saved.expedition.caravan.crew.has(crew_id), "Attached wagons and boarded living recruit return with their IDs")
	check(saved.expedition.stash.scrap == 20 and not saved.expedition.caravan.wagons[ids[0]].has("cargo"), "Extracted cargo enters stash once and is not duplicated inside garage wagon")
	check(saved.expedition.caravan.wagons[ids[2]].modules[0].type == "bazooka" and saved.expedition.caravan.wagons[ids[2]].modules[0].level == 2, "Per-wagon installed weapon and level persist")
	check(not expedition.finish_run(true), "Repeated result cannot duplicate assets or crew")
	model.reset_run()
	p.reset_run()
	var scrap_before: int = p.profile.expedition.stash.scrap
	expedition.begin_run(model.player)
	check(roster.crew.size() == 1 and p.profile.expedition.stash.scrap == scrap_before - 2, "Mechanic salary uses exactly two stash scrap before the next raid")
	model.player.coins = 300
	check(roster.install_attachment(ids[0], 1, "armor_panels") and roster.wagons[0].max_hp == 320, "Active Armory attachment purchase increases the addressed wagon hull")
	var after_install: int = model.player.coins
	check(not roster.install_attachment(ids[0], 1, "turret") and model.player.coins == after_install, "Occupied attachment mount never charges a second purchase")
	check(roster.remove_attachment(ids[0], 1) and roster.wagons[0].max_hp == 240, "Active attachment removal recalculates only its own wagon stats")
	check(roster.attachment_rows(ids[0]).size() == 10, "All ten utility attachment types are exposed as real shop actions")
	var failure: Dictionary = roster.damage_wagon(ids[1], 99999)
	check(failure.destroyed and not roster.wagons[2].attached and roster.wagons[0].attached, "Middle wagon destruction disconnects the tail while preserving the front")
	roster.wagons[2].position = model.player.position
	check(roster.recouple(ids[2]) and roster.wagons[5].attached, "Detached surviving tail can be recovered nearby")
	roster.damage_crew(crew_id, 99999)
	check(roster.find_crew(crew_id).dead and not roster.damage_crew(crew_id, 99999), "Crew death happens once")
	var foot := CrewFactory.create_neutral("looter", "on-foot", Vector3.ZERO)
	roster.rescue(foot)
	foot.boarded = false
	check(expedition.finish_run(true), "Damaged convoy can still extract")
	saved = Store.new(path).load_profile()
	check(saved.expedition.caravan.wagons.size() == 5 and not saved.expedition.caravan.wagons.has(ids[1]), "Destroyed wagon never reappears in garage")
	check(saved.expedition.caravan.crew.is_empty(), "Dead and unboarded crew are permanently lost at extraction")
	model.reset_run()
	p.reset_run()
	expedition.begin_run(model.player)
	var recruit := CrewFactory.create_neutral("loader", "unpaid", Vector3.ZERO)
	roster.rescue(recruit)
	var unpaid_id: String = recruit.id
	expedition.finish_run(true)
	p.profile.expedition.stash.erase("scrap")
	model.reset_run()
	p.reset_run()
	expedition.begin_run(model.player)
	check(roster.crew.is_empty() and roster.data().crew.has(unpaid_id), "Unpaid crew stays at base without taking money from another currency")
	expedition.finish_run(false)
	check(roster.data().wagons.is_empty() and roster.data().crew.has(unpaid_id), "Failed raid loses deployed wagons but preserves unpaid base crew")
	var fresh := Progression.new(path + ".fail")
	fresh.setup(Model.new())
	var failing := Expedition.new(fresh)
	fresh.profile.expedition.credits = 1000
	failing.caravan.buy_wagon("cargo")
	fresh.store.path = path + "/missing/profile.json"
	check(not failing.begin_run(fresh.model.player) and failing.caravan.data().wagons.size() == 1 and not failing.caravan.active, "Save failure rolls back departure and keeps purchased wagon in garage")
	fresh.store.path = path + ".fail"
	failing.begin_run(fresh.model.player)
	failing.collect_loot("scrap", 15)
	fresh.store.path = path + "/missing/profile.json"
	check(not failing.finish_run(true) and failing.caravan.active and failing.caravan.data().wagons.is_empty(), "Failed extraction keeps convoy in memory without partial garage return")
	fresh.store.path = path + ".fail"
	check(failing.action("retry_save", "") and failing.caravan.data().wagons.size() == 1 and fresh.profile.expedition.stash.scrap == 15, "Retry atomically returns one wagon and its cargo exactly once")
	check(not failing.caravan.locked, "Successful retry unlocks roster state")
	_test_jobs()
	_test_normalization()
	var panel := GaragePanel.new()
	root.add_child(panel)
	panel.show_state(failing.caravan.snapshot(), int(fresh.profile.expedition.credits), int(fresh.profile.expedition.stash.get("scrap", 0)))
	check(panel.visible and panel.find_children("*", "Button", true, false).any(func(button: Button) -> bool: return str(button.get_meta("caravan_action", "")).begins_with("configure_wagon:carrier") or str(button.get_meta("caravan_action", "")).begins_with("configure_wagon:wagon")), "Actual convoy panel renders equipment action for owned wagon")
	panel.tab = "shop"
	panel.show_state(failing.caravan.snapshot(), int(fresh.profile.expedition.credits), 0)
	check(panel.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return str(button.get_meta("caravan_action", "")).begins_with("buy_wagon:")).size() == 6, "Explicit trailer shop renders all six separate purchase options")
	panel.tab = "crew"
	panel.show_state(failing.caravan.snapshot(), 0, 0)
	check(panel.content.get_child_count() >= 2, "Crew panel renders recruitment guidance with empty roster")
	panel.queue_free()
	await process_frame
	print("Caravan crew tests: ", checks - failures, "/", checks)
	quit(1 if failures else 0)

func _test_jobs() -> void:
	var service := Service.new()
	var player := {"position": Vector3.ZERO, "speed": 0.0, "crew_collect": true, "hp": 100.0, "max_hp": 200.0, "modules": [{"cooldown": 1.0, "def": {"projectile": "bullet"}, "mount": {"carrierId": "crawler"}}]}
	var mechanic := CrewFactory.create("mechanic", "crew-1")
	var loader := CrewFactory.create("loader", "crew-2")
	service.step(0.1, player, [], [mechanic, loader], [], [])
	check(player.hp > 100 and player.modules[0].cooldown < 1, "Mechanic and loader perform actual repair and reload work")
	var paused_hp: float = player.hp
	service.step(0, player, [], [mechanic], [], [])
	check(player.hp == paused_hp, "Paused crew jobs do not advance")
	var targets: Array = []
	var fire := func(person: Dictionary, target: Dictionary, shot: Dictionary) -> bool:
		targets.append({"role": person.role, "target": target.type, "damage": shot.damage})
		return true
	var enemies := [{"id": 1, "type": "soldier", "position": Vector3(2, 0, 0)}, {"id": 2, "type": "drone", "position": Vector3(3, 0, 0)}, {"id": 3, "type": "buggy", "position": Vector3(4, 0, 0)}]
	var shooters := [CrewFactory.create("shooter", "crew-3"), CrewFactory.create("anti_tank", "crew-4"), CrewFactory.create("anti_air", "crew-5")]
	service.step(0.1, player, [], shooters, enemies, [], {"fire": fire})
	check(targets.size() == 3 and targets[0].target == "soldier" and targets[1].target == "buggy" and targets[2].target == "drone", "Three gunner roles use real fire callback with distinct target filters")
	var pickups := [{"id": "loot-1", "kind": "salvage", "position": Vector3(3, 0, 0)}, {"id": "fuel-1", "kind": "fuel", "position": Vector3(-3, 0, 0)}]
	var collected: Array = []
	var collect := func(person: Dictionary, pickup: Dictionary) -> bool:
		if pickup.get("dead", false):
			return false
		pickup.dead = true
		collected.append(person.role + ":" + pickup.kind)
		return true
	var move := func(person: Dictionary, destination: Vector3, speed: float, delta: float) -> Vector3:
		return person.position.move_toward(destination, speed * delta)
	var workers := [CrewFactory.create("looter", "crew-6"), CrewFactory.create("fuel", "crew-7"), CrewFactory.create("looter", "crew-8")]
	for index in 30:
		service.step(0.1, player, [], workers, [], pickups, {"move": move, "collect": collect})
	check(collected.size() == 2 and collected.has("looter:salvage") and collected.has("fuel:fuel"), "Collectors walk to matching pickups and reserve shared loot against duplicates")
	check(workers[0].boarded and workers[1].boarded, "Workers physically return and board after collecting")
	mechanic.dead = true
	paused_hp = player.hp
	service.step(0.1, player, [], [mechanic], [], [])
	check(player.hp == paused_hp, "Dead crew immediately stops contributing work")

func _test_normalization() -> void:
	var malformed := {"wagons": {"wagon-7": {"type": "cargo", "hp": INF, "attachments": [{"type": "cargo_rack", "slot": 0}, {"type": "armor_panels", "slot": 0}, {"type": "imaginary", "slot": 2}]}, "not-an-id": {"type": "cargo"}}, "crew": {"crew-8": {"role": "mechanic", "carrier_id": "wagon-7", "seat": 0}, "crew-9": {"role": "shooter", "carrier_id": "wagon-7", "seat": 0}, "crew-10": {"role": "imaginary"}}, "selected_wagon_ids": ["wagon-7", "wagon-7", "missing"], "selected_crew_ids": ["crew-8", "crew-9", "crew-10"]}
	var normalized := CaravanSave.normalize(malformed)
	check(normalized.wagons.size() == 1 and normalized.wagons["wagon-7"].attachments.size() == 1 and is_finite(normalized.wagons["wagon-7"].hp), "Save normalization rejects unknown IDs, overlapping attachments and nonfinite hull")
	check(normalized.crew.size() == 2 and normalized.crew["crew-9"].seat == -1 and normalized.next_id >= 10, "Crew migration removes unknown roles, resolves seat conflicts and preserves monotonic IDs")
	check(normalized.selected_wagon_ids.size() == 1 and CaravanSave.normalize(normalized) == normalized, "Caravan migration is idempotent and selection cannot duplicate instances")
	var one_second := {"position": Vector3.ZERO, "speed": 0.0, "hp": 100.0, "max_hp": 200.0}
	var many_steps := one_second.duplicate(true)
	var first := CrewFactory.create("mechanic", "crew-101")
	var second := CrewFactory.create("mechanic", "crew-102")
	var service := Service.new()
	service.step(1.0, one_second, [], [first], [], [])
	for index in 120:
		service.step(1.0 / 120.0, many_steps, [], [second], [], [])
	check(is_equal_approx(one_second.hp, many_steps.hp) and is_equal_approx(one_second.hp, 102.0), "Crew work consumes full elapsed time consistently across one large and 120 small steps")
	var pickup := {"id": "reserved", "kind": "salvage", "position": Vector3.ZERO}
	var looter := CrewFactory.create("looter", "crew-103")
	var counts := [0]
	var collect := func(_person: Dictionary, _pickup: Dictionary) -> bool: counts[0] += 1; return true
	service.step(0.1, one_second, [], [looter], [], [pickup], {"collect": collect})
	check(counts[0] == 0 and looter.boarded, "Collectors never leave or collect without the explicit command")
	check(WagonCatalog.job_factor({"type": "repair"}, "mechanic", "repair") > 1.0 and WagonCatalog.job_factor({"type": "fuel"}, "fuel", "collect_fuel") > 1.0, "Specialized wagon types provide real role-specific base benefits")

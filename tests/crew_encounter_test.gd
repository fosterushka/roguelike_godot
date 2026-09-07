extends SceneTree
const Runtime = preload("res://modules/crew/crew_runtime.gd")
const Factory = preload("res://modules/crew/crew_factory.gd")
const Encounter = preload("res://modules/crew/crew_encounter.gd")
const Policy = preload("res://modules/world/destruction_policy.gd")
const Progression = preload("res://modules/progression/progression.gd")
const Expedition = preload("res://modules/meta/expedition.gd")
const Combat = preload("res://modules/combat/combat_runtime.gd")
const Props = preload("res://modules/world/prop_system.gd")
const Tornado = preload("res://modules/world/tornado_rules.gd")
const Loot = preload("res://presentation/world/raid_loot.gd")
const EncounterPanel = preload("res://presentation/ui/crew_encounter_panel.gd")
const Store = preload("res://infrastructure/persistence/profile_store.gd")
class TestWorld extends Node:
	var props := Props.new()
	var running := true
	var tornado := Tornado.new()
	var arena := {"world_layout": {}}
var checks := 0
var failures := 0
func _init() -> void:
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func _run() -> void:
	var planned := preload("res://modules/crew/crew_assignment.gd").plan(
		[Factory.create("shooter", "crew-1"), Factory.create("mechanic", "crew-2"), Factory.create("civilian", "crew-3")],
		[{"id": "wagon-1", "type": "cargo"}, {"id": "wagon-2", "type": "repair"}])
	check(planned["crew-2"].carrier_id == "wagon-2" and planned["crew-3"].carrier_id == "wagon-1" and planned["crew-1"].carrier_id == "crawler", "Automatic assignments reserve profession matches and cargo seats before fallback")
	var limited := preload("res://modules/crew/crew_assignment.gd").plan(
		[Factory.create("civilian", "crew-1"), Factory.create("mechanic", "crew-2")], [], 2)
	check(not limited.has("crew-1") and limited.has("crew-2"), "Passenger without a cargo wagon does not consume another recruit's wage budget")
	var path := "/private/tmp/crew-encounter-%d.json" % Time.get_ticks_usec()
	var fight := Combat.new()
	root.add_child(fight)
	var world := TestWorld.new()
	root.add_child(world)
	var vehicle := Node3D.new()
	root.add_child(vehicle)
	var loot := Loot.new()
	root.add_child(loot)
	var owner := Progression.new(path)
	owner.setup(fight.model)
	var raid := Expedition.new(owner)
	owner.profile.expedition.credits = 2000
	check(raid.caravan.buy_wagon("repair") and raid.caravan.buy_wagon("cargo"), "Prepare specialist and passenger wagons")
	check(raid.begin_run(fight.model.player), "Begin real expedition")
	fight.model.running = true
	var runtime := Runtime.new()
	root.add_child(runtime)
	runtime.setup(raid, fight, world, vehicle, loot)
	raid.caravan.wagons[0].position = Vector3(35, 0, 0)
	raid.caravan.wagons[1].position = Vector3(42, 0, 0)
	fight.model.player.position = Vector3(0, 20, 0)
	fight.model.player.speed = 6.0
	var mechanic := Factory.create_neutral("mechanic", "test-mechanic", Vector3(37, 0, 8))
	runtime.recruits.append(mechanic)
	var requests: Array = []
	runtime.encounter_requested.connect(func(person: Dictionary): requests.append(person.id))
	runtime.step(0.01)
	check(runtime.pending == mechanic and requests.size() == 1, "Approaching a survivor automatically requests one dialogue")
	runtime.step(0.01)
	check(requests.size() == 1, "Pending dialogue is not repeatedly emitted")
	runtime.cancel_encounter()
	runtime.step(0.01)
	check(runtime.pending.is_empty(), "Talk later suppresses immediate automatic reopening")
	check(runtime.interact() and runtime.pending == mechanic and raid.caravan.crew.is_empty(), "Talk once beside tail wagon despite height and rolling speed, without automatic hire")
	var field_position: Vector3 = mechanic.position
	check(runtime.accept_encounter() and not runtime.accept_encounter(), "Hire is accepted once")
	check(mechanic.carrier_id == raid.caravan.wagons[0].id and not mechanic.boarded and mechanic.position == field_position, "Mechanic reserves repair wagon and stays physically outside")
	var hp: float = raid.caravan.wagons[0].hp
	raid.caravan.wagons[0].hp -= 30
	runtime.step(0.05)
	check(raid.caravan.wagons[0].hp == hp - 30, "Work cannot begin before boarding")
	var saw_climb := false
	for frame in 100:
		runtime.step(0.05)
		saw_climb = saw_climb or mechanic.state == "boarding"
	check(saw_climb and mechanic.boarded and not mechanic.recruit_boarding, "Recruit walks to carrier and completes timed climb")
	check(raid.caravan.wagons[0].hp > hp - 30, "Specialist starts work after boarding")
	var civilian := Factory.create_neutral("civilian", "test-civilian", Vector3(44, 0, 2))
	var identity: int = civilian.identity
	runtime.recruits.append(civilian)
	runtime.interact()
	check(runtime.accept_encounter() and civilian.carrier_id == raid.caravan.wagons[1].id, "Untrained recruit is assigned to ordinary cargo wagon")
	check(not raid.caravan.assign(civilian.id, "crawler", 1), "Untrained passenger cannot be assigned to specialist pickup")
	check(not raid.caravan.train_crew(civilian.id, "mechanic"), "Training cannot run in the field")
	for frame in 100:
		runtime.step(0.05)
	check(civilian.boarded, "Passenger completes actual boarding")
	# Every refusal branch uses real runtime movement or real enemy conversion.
	for expected in ["fleeing", "joining_enemy", "hostile"]:
		var id := ""
		for index in 1000:
			var candidate := "refusal-%d" % index
			if Encounter.refusal(Policy.roll(candidate + ":refusal")) == expected:
				id = candidate
				break
		var npc := Factory.create_neutral("shooter", id, Vector3(43, 0, 4))
		runtime.recruits.append(npc)
		runtime.pending = npc
		var before: Vector3 = npc.position
		check(runtime.decline_encounter() == expected and runtime.pending.is_empty(), "Refusal chooses " + expected)
		check(runtime._nearest_recruit().is_empty(), "Rejected survivor cannot be hired again")
		runtime.step(0.1)
		if expected == "hostile":
			check(runtime.reactions.size() == 1 and runtime.reactions[0].actor == fight.model.enemies[0], "Refusal bubble follows the real hostile actor after conversion")
		if expected == "fleeing":
			check(npc.position != before and fight.model.enemies.is_empty(), "Fleeing survivor moves away without becoming an enemy")
			runtime.recruits.erase(npc)
		else:
			for frame in 90:
				runtime.step(0.1)
			check(not runtime.recruits.has(npc) and fight.model.enemies.size() == 1, "Rejected survivor enters real enemy system once")
			var enemy: Dictionary = fight.model.enemies[0]
			check(not enemy.counts_toward_wave and fight.model.damage_enemy(enemy.id, 1000), "Former survivor can be attacked and does not block wave completion")
			fight.model.enemies.clear()
	owner.profile.expedition.stash.scrap = 40
	check(raid.finish_run(true), "Successful extraction saves boarded survivors")
	var saved_identity: int = raid.caravan.data().crew[civilian.id].identity
	var before_scrap: int = owner.profile.expedition.stash.scrap
	owner.profile.expedition.stash.scrap = 10
	check(not raid.caravan.train_crew(civilian.id, "mechanic") and owner.profile.expedition.stash.scrap == 10, "Insufficient funds cannot train or consume scrap")
	owner.profile.expedition.stash.scrap = before_scrap
	owner.store.path = path + "/invalid/save.json"
	check(not raid.caravan.train_crew(civilian.id, "mechanic") and owner.profile.expedition.stash.scrap == before_scrap and raid.caravan.data().crew[civilian.id].role == "civilian", "Failed save rolls back training and currency")
	owner.store.path = path
	check(raid.caravan.train_crew(civilian.id, "mechanic") and owner.profile.expedition.stash.scrap == before_scrap - 30, "Base training spends exactly 30 scrap")
	check(not raid.caravan.train_crew(civilian.id, "shooter") and owner.profile.expedition.stash.scrap == before_scrap - 30, "Repeated training cannot charge or change profession twice")
	var disk: Dictionary = Store.new(path).load_profile()
	check(disk.expedition.caravan.crew[civilian.id].role == "mechanic" and disk.expedition.caravan.crew[civilian.id].identity == identity and saved_identity == identity, "Profession and personal identity survive disk normalization")
	var panel := EncounterPanel.new()
	root.add_child(panel)
	panel.show_person(Factory.create_neutral("civilian", "new", Vector3.ZERO), raid.caravan)
	check(panel.hire.disabled, "Dialogue cannot hire a civilian without an active cargo seat")
	var bubble := preload("res://presentation/crew/crew_speech.gd").new()
	root.add_child(bubble)
	bubble.show_message("Эй, странник! Подъедь сюда!\nE · Сборщик топлива")
	bubble.show()
	for frame in 3:
		await process_frame
	check(bubble.size.y < 140 and bubble.get_global_rect().encloses(bubble.label.get_global_rect()), "First speech bubble wraps all text inside its background without excessive height")
	bubble.show_message("", true)
	await process_frame
	check(bubble.positive and bubble.size == Vector2(48, 48) and not bubble.label.visible, "Accepted survivor uses a compact smile instead of floating text")
	bubble.queue_free()
	panel.queue_free()
	runtime.queue_free()
	loot.queue_free()
	vehicle.queue_free()
	world.queue_free()
	fight.queue_free()
	await process_frame
	print("Crew encounter tests: %d/%d" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

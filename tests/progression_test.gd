extends SceneTree

const Progression = preload("res://modules/progression/progression.gd")
const Model = preload("res://modules/combat/combat_model.gd")
const Expedition = preload("res://modules/meta/expedition.gd")
const Rules = preload("res://modules/progression/upgrade_rules.gd")
const Store = preload("res://infrastructure/persistence/profile_store.gd")
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
	var path := "/private/tmp/iron-caravan-progression-test-" + str(Time.get_ticks_usec()) + ".json"
	var model := Model.new()
	var progression := Progression.new(path)
	progression.setup(model)
	check(model.player.weight == 12 and model.player.modules.size() == 1, "starter M4 weight is base10 +2")
	check(not progression.buy_upgrade("module:railgun"), "locked blueprint cannot be bought")
	check(not progression.buy_upgrade("module:bazooka"), "insufficient 35 salvage for bazooka cost38")
	model.player.coins = 1000
	check(progression.buy_upgrade("module:bazooka") and model.player.coins == 962, "bazooka original purchase cost38")
	check(not progression.buy_upgrade("module:bazooka"), "duplicate weapon denied")
	check(progression.buy_upgrade("weapon:0") and model.weapons[0].level == 2 and model.player.coins == 922, "weapon MK2 cost40")
	check(model.weapons[0].def.damage == 12 and is_equal_approx(model.weapons[0].def.range, 34.24), "weapon upgrade exact formula")
	check(progression.buy_upgrade("remove:1") and model.player.coins == 933, "MK1 refund11")
	check(not progression.buy_upgrade("remove:0"), "last weapon cannot be removed")
	check(not progression.buy_upgrade("module:armor"), "draft passive not purchasable")
	check(progression.buy_upgrade("module:radar") and model.player.radar_range == 40, "radar cost55 and initial range40")
	check(not progression.buy_upgrade("module:radar"), "radar unique")
	check(not progression.buy_upgrade("trailer"), "trailer blocked at LV1")
	model.running = true
	model.player.xp = 212
	progression.step(0.01)
	check(model.player.level == 3 and model.player.xp == 0 and model.player.xp_next == 247, "multiple XP thresholds70 then142 then247")
	check(model.player.pending_upgrades == 2 and model.player.max_hp == 298, "each level grants core+draft and maxHP24")
	check(progression.buy_upgrade("core:motor") and is_equal_approx(model.player.motor_speed_mult, 1.08), "free core motor exact8percent")
	check(not progression.buy_upgrade("core:motor"), "cannot repeat core before draft")
	var choices: Array = progression.get_shop_state().choices
	check(choices.size() == 3, "draft offers three source-eligible choices")
	check(progression.buy_upgrade(choices[0].id) and model.player.pending_upgrades == 1, "draft consumes one pending level")
	check(progression.buy_upgrade("core:fuel") and model.player.max_fuel == 125, "fuel core adds25")
	choices = progression.get_shop_state().choices
	progression.buy_upgrade(choices[0].id)
	check(model.player.pending_upgrades == 0, "second batch completes")
	check(not progression.buy_upgrade("trailer") and model.player.carriers.is_empty(), "Levels do not create free wagons")
	model.player.level = 4
	check(not progression.buy_upgrade("trailer"), "Raid armory never bypasses the paid garage")
	var expedition := Expedition.new(progression)
	progression.profile.expedition.credits = 1000
	check(expedition.caravan.buy_wagon("cargo") and expedition.begin_run(model.player), "A bought selected wagon deploys from the persistent garage")
	check(progression.buy_upgrade("module:counterDroneJammer") and model.player.modules[-1].mount.carrierId == expedition.caravan.wagons[0].id, "New module uses the actual purchased wagon identity")
	check(Rules.apply_trait("expandedWeaponRack", model.player, model.weapons) and model.player.weapon_capacity == 5, "expanded rack adds fifth")
	check(Rules.apply_trait("expandedWeaponRack", model.player, model.weapons) and model.player.weapon_capacity == 6 and not Rules.apply_trait("expandedWeaponRack", model.player, model.weapons), "rack max6")
	var ids: Array = []
	for definition: Dictionary in progression.catalog.levelUpgrades:
		var id: String = Rules.trait_id(0, definition)
		ids.append(id)
		if id != "expandedWeaponRack":
			check(Rules.apply_trait(id, model.player, model.weapons), "trait implemented: " + id)
	check(ids.size() == 17, "all17 source traits reachable")
	var tuning: Dictionary = Rules.sidegrade_tuning(progression.catalog.modules.grenadeLauncher, progression.catalog.sidegrades["fragmentation-shells"])
	check(is_equal_approx(tuning.range, 36.08) and is_equal_approx(tuning.splashMultiplier, 1.3), "fragmentation source tradeoff")
	var protocol: Dictionary = progression.catalog.protocols.stormConductor
	check(not Rules.protocol_available(protocol, model.player.modules, progression.catalog.moduleBuildProfiles), "protocol rejects missing railgun")
	model.reset_run()
	progression.reset_run()
	check(progression.select_contracts(["break-the-line", "answer-the-call", "mixed-battery", "combined-arms"]) and progression.profile.selectedContractIds.size() == 3, "contract selection capped3")
	progression.begin_run()
	check(not progression.select_sidegrade("railgun", "penetrator-sabots"), "sidegrade change blocked during run")
	check(progression.on_combat_event({"kind": "death", "type": "garrison", "id": 5}), "foundry event accepted")
	check(not progression.on_combat_event({"kind": "death", "type": "garrison", "id": 5}), "foundry duplicate rejected")
	progression.on_combat_event({"kind": "death", "type": "garrison", "id": 6})
	progression.on_combat_event({"kind": "death", "type": "garrison", "id": 7})
	check(progression.profile.unlockedSidegradeIds.has("fragmentation-shells"), "three foundries unlock fragmentation")
	progression.on_combat_event({"kind": "activity_completed", "activity_type": "settlementDistress", "weather": "rainy", "id": "activity1"})
	check(progression.profile.unlockedSidegradeIds.has("concussion-rounds"), "distress unlocks concussion")
	progression.on_combat_event({"kind": "shot", "projectile_kind": "bullet", "team": "player"})
	progression.on_combat_event({"kind": "shot", "projectile_kind": "rocket", "team": "player"})
	check(progression.profile.unlockedSidegradeIds.has("penetrator-sabots"), "two families unlock penetrator")
	check(progression.flush(), "atomic profile saved")
	var reloaded := Progression.new(path)
	check(reloaded.profile.lifetimeStats.foundriesDestroyed == 3 and reloaded.profile.unlockedSidegradeIds.size() == 3, "profile reload preserves totals and rewards")
	progression.on_combat_event({"kind": "result", "won": true, "elapsed": 181})
	check(not progression.on_combat_event({"kind": "result", "won": true, "elapsed": 181}), "duplicate run result rejected")
	var runs: int = progression.profile.lifetimeStats.runs
	model.reset_run()
	progression.reset_run()
	progression.begin_run()
	check(progression.profile.lifetimeStats.runs == runs + 1, "restart rearms profile run")
	progression.on_combat_event({"kind": "result", "won": false, "elapsed": 1})
	model.reset_run()
	progression.reset_run()
	progression.select_contracts(["powder-dry", "combined-arms", "bad-weather-work"])
	progression.begin_run()
	model.player.coins = 500
	progression.buy_upgrade("module:bazooka")
	progression.on_combat_event({"kind": "shot", "projectile_kind": "bullet", "team": "player"})
	progression.on_combat_event({"kind": "activity_completed", "activity_type": "scavengerRoute", "weather": "storm", "id": "storm1"})
	progression.on_combat_event({"kind": "result", "won": true, "elapsed": 180})
	check(progression.profile.completedContractIds.has("powder-dry"), "three minutes without rocket shot completes powder-dry")
	check(progression.profile.completedContractIds.has("combined-arms"), "M4 plus bazooka victory completes combined arms")
	check(progression.profile.completedContractIds.has("bad-weather-work"), "storm activity completes weather contract")
	check(progression.profile.completedContractIds.size() == 6, "all six original contracts implemented")
	check(not progression.on_combat_event({"kind": "death", "type": "garrison", "id": 999, "generation": -4}), "stale generation events rejected")
	progression.flush()
	var future_path := path + ".future"
	var file := FileAccess.open(future_path, FileAccess.WRITE)
	file.store_string('{"version":2,"precious":"keep"}')
	file.close()
	var future := Store.new(future_path)
	future.load_profile()
	check(future.status == "read-only-future" and not future.save_profile(Store.defaults()), "future schema read-only")
	check(FileAccess.get_file_as_string(future_path).contains("precious"), "future profile never overwritten")
	var corrupt_path := path + ".corrupt"
	file = FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_string("bad JSON")
	file.close()
	var corrupt := Store.new(corrupt_path)
	check(corrupt.load_profile().version == 1 and corrupt.status == "recovered", "corrupt profile recovers defaults")
	var unavailable := Store.new(path + "/missing/profile.json")
	check(not unavailable.save_profile(Store.defaults()) and unavailable.status == "unsaved", "unavailable path preserves retry status")
	print("Progression tests: ", checks - failures, "/", checks)
	quit(1 if failures else 0)

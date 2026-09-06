extends SceneTree
const Model = preload("res://modules/combat/combat_model.gd")
const Progression = preload("res://modules/progression/progression.gd")
const Loadout = preload("res://modules/caravan/caravan_loadout.gd")
const Factory = preload("res://modules/caravan/wagon_factory.gd")
const Expedition = preload("res://modules/meta/expedition.gd")
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
	var model := Model.new()
	var progression := Progression.new("/private/tmp/loadout-%d.json" % Time.get_ticks_usec())
	progression.setup(model)
	var player: Dictionary = model.player
	player.coins = 10000
	var wagon := Factory.create("cargo", "wagon-test")
	player.carriers.append(wagon)
	Loadout.refresh(progression)
	var crawler_weapon: Dictionary = model.weapons[0]
	check(progression._equip("bazooka", {"carrierId": wagon.id, "slot": 0}), "Install weapon in selected wagon slot")
	player.weapon_capacity = 2
	player.replacement_cursor = 0
	check(progression._equip("assaultRifle", {"carrierId": wagon.id, "slot": 0}), "Full arsenal replaces selected occupied mount")
	check(model.weapons[0] == crawler_weapon and model.weapons[1].mount.carrierId == wagon.id and model.weapons[1].type == "assaultRifle", "Replacement preserves crawler weapon despite cursor pointing at it")
	var before: Dictionary = player.duplicate(true)
	check(not progression._equip("bazooka", {"carrierId": wagon.id, "slot": 1}) and player == before, "Full arsenal refuses empty explicit mount without moving another weapon or charging")
	player.weapon_capacity = 5
	check(progression._equip("bazooka", {"carrierId": wagon.id, "slot": 0}) and model.weapons.size() == 2, "Occupied selected mount replaces even below capacity")
	var player_max := float(player.max_hp)
	var wagon_max := float(wagon.max_hp)
	check(progression._add_module("armor", {"carrierId": wagon.id, "slot": 1}), "Armor installs on wagon")
	check(wagon.max_hp == wagon_max + 55 and player.max_hp == player_max and is_equal_approx(wagon.armor, 0.05) and player.armor == 0, "Armor benefits only its carrier")
	check(progression._add_module("radar", {"carrierId": wagon.id, "slot": 2}), "Radar occupies wagon slot")
	check(progression.buy_upgrade("radar:2") and player.radar_range == 90, "Active wagon radar upgrades")
	before = player.duplicate(true)
	check(not progression._equip("bazooka", {"carrierId": wagon.id, "slot": 2}) and before == player, "Weapon cannot overwrite selected support")
	wagon.hp = 75.0
	wagon.attached = false
	Loadout.refresh(progression)
	check(wagon.max_hp == wagon_max and wagon.hp == 75 and is_zero_approx(wagon.armor), "Detachment removes armor without healing")
	check(player.radar_range == 0 and player.radar_level == 0 and not progression.buy_upgrade("radar:3"), "Detached radar stops and cannot upgrade")
	check(model.weapons[1].disabled and not progression._equip("assaultRifle", {"carrierId": wagon.id, "slot": 0}), "Detached weapon is disabled and cannot be replaced")
	var detached_weapon: Dictionary = model.weapons[1]
	for index in 20:
		progression._draft.clear()
		progression._ensure_draft()
		check(not progression._draft.any(func(row: Dictionary) -> bool: return row.id == "draft_weapon:1"), "Draft excludes detached weapon")
	wagon.attached = true
	Loadout.refresh(progression)
	check(wagon.max_hp == wagon_max + 55 and wagon.hp == 75 and player.radar_range == 90 and model.weapons[1] == detached_weapon and not model.weapons[1].disabled, "Recoupling restores original gear and radar tier without healing")
	for index in 5:
		Loadout.refresh(progression)
	check(wagon.max_hp == wagon_max + 55 and wagon.hp == 75 and is_equal_approx(wagon.armor, 0.05), "Repeated refresh cannot stack armor")
	var expedition := Expedition.new(progression)
	var roster = expedition.caravan
	roster.wagons.append(wagon)
	roster._player = player
	roster.active = true
	roster.damage_wagon(wagon.id, 20)
	check(wagon.hp == 56, "Wagon armor reduces actual damage by five percent")
	roster._refresh_wagon(wagon)
	check(wagon.max_hp == wagon_max + 55 and wagon.hp == 56, "Attachment rebuild preserves module armor without healing")
	var armor: Dictionary = player.modules.filter(func(module: Dictionary) -> bool: return module.type == "armor")[0]
	check(progression._remove_support(player.modules.find(armor)) and wagon.max_hp == wagon_max and wagon.hp == 56 and player.max_hp == player_max, "Selling armor affects only its carrier")
	check(progression._add_module("workshop", {"carrierId": wagon.id, "slot": 1}), "Workshop installs in released slot")
	model.running = true
	var player_hp := float(player.hp)
	progression.step(4.0)
	check(wagon.hp == 58 and player.hp == player_hp, "Workshop repairs only its wagon")
	wagon.attached = false
	Loadout.refresh(progression)
	progression.step(4.0)
	check(wagon.hp == 58, "Detached workshop gives no repair")
	wagon.attached = true
	Loadout.refresh(progression)
	progression.step(4.0)
	check(wagon.hp == 60, "Recoupled workshop resumes repair")
	check(progression._add_module("bumper"), "Crawler bumper installs")
	var bumper: Dictionary = player.modules.back()
	bumper.disabled = true
	progression._refresh_protocols()
	check(not player.has_bumper, "Disabled bumper loses passive effect")
	bumper.disabled = false
	progression._refresh_protocols()
	check(player.has_bumper, "Enabled bumper restores effect")
	progression._draft = [{"id": "draft_weapon:1"}]
	roster.damage_wagon(wagon.id, 10000)
	Loadout.refresh(progression)
	check(progression._draft.is_empty(), "Destroyed gear invalidates cached indexed draft choices")
	check(model.weapons.size() == 1 and not progression._installed("radar") and not progression._installed("workshop"), "Destroyed gear permanently releases unique module and weapon capacity")
	check(progression._add_module("radar") and player.radar_range == 40, "New radar can replace destroyed unique radar")
	var fresh := Model.new()
	var reloaded := Progression.new("/private/tmp/loadout-hydrate-%d.json" % Time.get_ticks_usec())
	reloaded.setup(fresh)
	var saved := Factory.create("cargo", "saved", {"hp": 60, "modules": [{"type": "armor", "level": 1, "mount": {"slot": 0}}, {"type": "radar", "level": 3, "mount": {"slot": 1}}]})
	fresh.player.carriers.append(saved)
	Loadout.hydrate(reloaded)
	check(saved.hp == 60 and fresh.player.radar_range == 160, "Saved support retains damaged HP and radar tier")
	var normalized: Dictionary = preload("res://modules/caravan/caravan_save.gd").normalize({"wagons": {"wagon-8": {"type": "cargo", "hp": 282.0, "modules": [{"type": "armor", "level": 1, "mount": {"slot": 0}}]}}})
	check(normalized.wagons["wagon-8"].hp == 282, "Save normalization preserves armor HP above base hull maximum")
	var armored := Factory.create("cargo", "wagon-8", normalized.wagons["wagon-8"])
	check(armored.max_hp == 295 and armored.hp == 282, "Factory restores full armored hull range")
	var armor_model := Model.new()
	var armor_progression := Progression.new("/private/tmp/loadout-high-hull-%d.json" % Time.get_ticks_usec())
	armor_progression.setup(armor_model)
	armor_model.player.carriers.append(armored)
	Loadout.hydrate(armor_progression)
	check(armored.max_hp == 295 and armored.hp == 282 and is_equal_approx(armored.armor, 0.05), "Hydration retains exact stored armor HP without doubling or healing")
	progression.flush()
	print("Caravan loadout: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

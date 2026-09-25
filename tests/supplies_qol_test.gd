extends SceneTree
const Progression = preload("res://modules/progression/progression.gd")
const Expedition = preload("res://modules/meta/expedition.gd")
const Model = preload("res://modules/combat/combat_model.gd")
const SuppliesPanel = preload("res://presentation/ui/expedition_panel.gd")
const Store = preload("res://infrastructure/persistence/profile_store.gd")
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
	var path := "/private/tmp/supplies-qol-%d.json" % Time.get_ticks_usec()
	var owner := Progression.new(path)
	owner.setup(Model.new())
	var expedition := Expedition.new(owner)
	owner.profile.expedition.stash = {"repair_kit": 20, "weapon_parts": 8, "fuel_cell": 8}
	check(expedition.transfer_offer("equip", "repair_kit").maximum == expedition.capacity(), "Offer caps packing by actual cargo capacity")
	check(expedition.action("equip", "weapon_parts", 3), "Quantity transfer packs three two-space items")
	check(expedition.snapshot().used == 6 and expedition.snapshot().stash.weapon_parts == 5, "Quantity transfer debits exact stock and weighted capacity")
	var before: Dictionary = owner.profile.expedition.duplicate(true)
	check(not expedition.action("equip", "repair_kit", 7) and owner.profile.expedition == before, "Over-capacity quantity rejects atomically")
	check(not expedition.action("equip", "repair_kit", -1) and not expedition.action("equip", "repair_kit", 0), "Nonpositive transfers rejected")
	check(expedition.action("equip", "repair_kit", 6) and expedition.transfer_offer("equip", "fuel_cell").reason == "full", "Full loadout has a public unavailable reason")
	var panel := SuppliesPanel.new()
	root.add_child(panel)
	panel.show_state(expedition.snapshot())
	var pack := _action(panel, "equip:fuel_cell")
	check(pack != null and pack.disabled, "Full loadout disables Pack before user action")
	expedition.action("unequip", "repair_kit", 2)
	panel.show_state(expedition.snapshot())
	pack = _action(panel, "equip:repair_kit")
	pack.grab_focus()
	panel.show_state(expedition.snapshot())
	await process_frame
	check(root.gui_get_focus_owner() == _action(panel, "equip:repair_kit"), "Refreshing stock restores keyboard focus to same item action")
	var sent := []
	panel.supplies_transfer_requested.connect(func(kind: String, id: String, quantity: int) -> void: sent.append([kind, id, quantity]))
	var quantity := panel.body.get_child(0).get_child(2) as SpinBox
	quantity.value = 2
	_action(panel, "equip:repair_kit").pressed.emit()
	check(sent == [["equip", "repair_kit", 2]], "Quantity UI emits a structured validated-model command")
	var packed: Dictionary = expedition.snapshot().loadout
	check(expedition.begin_run(owner.model.player), "Departure commits prior supply preset")
	var reloaded := Progression.new(path)
	check(reloaded.profile.expedition.last_supplies == packed and reloaded.profile.expedition.loadout.is_empty(), "Preset survives reload without duplicating reserved raid inventory")
	expedition.abandon_run()
	check(expedition.refill_offer().enabled and expedition.action("refill_supplies", ""), "One operation refills previous supplies from owned stock")
	check(expedition.snapshot().loadout == packed and not expedition.action("refill_supplies", ""), "Refill is exact and repeat command cannot duplicate items")
	expedition.action("unequip", "repair_kit", 4)
	owner.profile.expedition.stash.repair_kit = 0
	before = owner.profile.expedition.duplicate(true)
	check(expedition.refill_offer().reason == "missing_stock" and not expedition.action("refill_supplies", "") and owner.profile.expedition == before, "Refill rejects missing stock without partial transfer")
	owner.profile.expedition.stash.repair_kit = 4
	owner.store.path = path + "/invalid/profile.json"
	before = owner.profile.expedition.duplicate(true)
	check(not expedition.action("refill_supplies", "") and owner.profile.expedition == before, "Save failure rolls back entire refill")
	var malformed := Store.normalize({"expedition": {"last_supplies": {"fake": 4, "scrap": 4, "repair_kit": -1, "weapon_parts": 999999}}})
	check(malformed.expedition.last_supplies == {"weapon_parts": 24}, "Preset normalization rejects unknown and nonusable items and bounds counts")
	panel.queue_free()
	await process_frame
	print("Supplies QOL: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _action(node: Node, id: String) -> Button:
	if node is Button and node.get_meta("expedition_action", "") == id:
		return node
	for child in node.get_children():
		var found := _action(child, id)
		if found != null:
			return found
	return null

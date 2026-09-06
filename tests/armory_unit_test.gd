extends SceneTree
const Armory = preload("res://presentation/ui/armory_panel.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Rig = preload("res://presentation/vehicles/wheeled_rig.gd")
const Catalog = preload("res://modules/caravan/wagon_catalog.gd")
const Attachment = preload("res://presentation/vehicles/attachment_view.gd")
var checks := 0
var failures := 0
var sent := ""

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Locale.settings_path = "/private/tmp/iron-unit-language-%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("en")
	var rig := Rig.build_player()
	check(str(rig.get_meta("model_path", "")) == "res://assets/vehicles/military_pickup.glb" and rig.get_meta("model", null) != null, "Armory crawler is built from the authored military pickup asset")
	check(rig.get_meta("wheels", []).size() == 4 and not rig.has_node("Cabin") and not rig.has_node("RearEquipmentDeck"), "Armory crawler keeps animated pickup wheels without procedural placeholder body")
	rig.free()
	for type: String in Catalog.ATTACHMENTS:
		var model := Attachment.build(type)
		check(str(model.get_meta("model_path", "")) == "res://assets/vehicles/military_equipment.glb" and not model.find_children("*", "MeshInstance3D", true, false).is_empty(), "Attachment has an authored equipment mesh batch: " + type)
		model.free()
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_catalogs.json")).modules
	var carriers: Array = []
	for index in 6:
		var type: String = Catalog.TYPES.keys()[index]
		var def: Dictionary = Catalog.TYPES[type]
		carriers.append({"id": "wagon-%d" % (index + 1), "type": type, "slotCount": 3, "mass": def.mass, "hp": def.max_hp - 20, "max_hp": def.max_hp, "cargo": {"scrap": 2}, "cargo_capacity": def.cargo_capacity, "attachments": [{"type": "repair_station", "slot": 2}] if index == 5 else []})
	var player := {"coins": 1000, "weight": 76, "weapon_capacity": 10, "max_hp": 200, "max_fuel": 130, "core_upgrades": {"motor": 2, "armor": 3, "fuel": 1}, "carriers": carriers, "modules": [{"type": "assaultRifle", "level": 1, "def": definitions.assaultRifle, "mount": {"carrierId": "crawler", "slot": 0}}, {"type": "bazooka", "level": 2, "def": definitions.bazooka, "mount": {"carrierId": "wagon-6", "slot": 0}}], "position": Vector3(480, 16, -311), "heading": 2.6, "speed": 19}
	var shop := {"weapons": [{"id": "weapon:0", "enabled": true, "cost": 40, "remove_id": "remove:0", "remove_enabled": true, "refund": 8}, {"id": "weapon:1", "enabled": true, "cost": 50, "remove_id": "remove:1", "remove_enabled": true, "refund": 12}], "modules": [], "protocols": [], "attachments": []}
	for type: String in definitions:
		shop.modules.append({"id": "module:" + type, "enabled": true, "cost": 20})
	for type: String in Catalog.ATTACHMENTS:
		shop.attachments.append({"id": "attachment:%s:wagon-6:1" % type, "type": type, "carrier_id": "wagon-6", "enabled": true, "cost": 20})
	for language: String in ["ru", "en"]:
		Locale.set_language(language)
		var panel := Armory.new()
		root.add_child(panel)
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		panel.action_requested.connect(func(_action: String, id: String) -> void: sent = id)
		panel.display(shop, player)
		check(panel.mount_selector.carrier.item_count == 7 and panel.mount_selector.selected_carrier() == "crawler", "Six purchased IDs plus crawler are individually selectable")
		check(panel.preview.vehicle_view.position == Vector3.ZERO and panel.preview.vehicle_view.get_child_count() == 2, "Crawler preview is local and excludes all wagons and their equipment")
		var camera: Transform3D = panel.preview.camera.transform
		await process_frame
		await process_frame
		check(panel.preview.camera.transform == camera and panel.preview.vehicle_view.position == Vector3.ZERO, "World movement cannot drift inspection model or camera")
		panel.mount_selector.carrier.select(6)
		panel.mount_selector.carrier.item_selected.emit(6)
		check(panel.mount_selector.selected_mount() == {"carrierId": "wagon-6", "slot": 1}, "Exact sixth wagon selected; weapon and attachment slots remain occupied")
		check(panel.mount_selector.slot.is_item_disabled(0) and panel.mount_selector.slot.is_item_disabled(2), "Module and attachment share occupancy")
		check(panel.preview.vehicle_view.get_child_count() == 3 and panel.preview._target.z == 0 and panel.preview._fit_size == 8, "Single selected wagon shows its own equipment at local origin")
		check(_action(panel, "remove:0") == null and _action(panel, "remove:1") != null, "Selected wagon exposes only its own weapon removal")
		_action(panel, "remove:1").pressed.emit()
		check(sent == "remove:1", "Weapon removal preserves the global index belonging to selected wagon")
		check(not panel._installed("assaultRifle") and panel._installed("bazooka"), "Installed filter is scoped to selected wagon")
		panel.select_module("bazooka")
		check(panel.details.text.contains("2") and panel.preview.selected == null, "Installed weapon details use selected unit and do not duplicate preview mesh")
		for dimensions in [Vector2(960, 600), Vector2(1280, 800)]:
			panel.size = dimensions
			await process_frame
			await process_frame
			check(panel.save_status.get_global_rect().end.y <= dimensions.y + 1 and panel.details.get_global_rect().end.y <= dimensions.y - 20, "All statistics and footer stay on screen: " + language + str(dimensions))
			check(panel.preview.size.y <= 230 and panel.preview.get_global_rect().end.x < panel._catalog_scroll.get_global_rect().position.x, "Preview remains compact beside catalog")
		panel.select_module("attachment:armor_panels")
		check(panel.preview.selected.get_meta("attachment_type") == "armor_panels", "Uninstalled attachment previews its actual semantic geometry")
		check(panel._purchase_id("attachment:armor_panels:wagon-6:0") == "attachment:armor_panels:wagon-6:1", "Attachment installation dispatches currently selected exact free mount")
		var removal := _action(panel, "remove_attachment:wagon-6:2")
		check(removal != null, "Installed attachment exposes removal for exact wagon and slot")
		removal.pressed.emit()
		check(sent == "remove_attachment:wagon-6:2", "Attachment removal dispatches its owner and slot")
		panel.hide_panel()
		check(panel.preview.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden inspection stops rendering")
		panel.queue_free()
		await process_frame
	print("Armory units: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _action(node: Node, id: String) -> Button:
	if node is Button and node.get_meta("action_id", "") == id:
		return node
	for child in node.get_children():
		var found := _action(child, id)
		if found != null:
			return found
	return null

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

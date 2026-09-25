extends SceneTree
const Customization = preload("res://modules/caravan/vehicle_customization.gd")
const Progression = preload("res://modules/progression/progression.gd")
const Expedition = preload("res://modules/meta/expedition.gd")
const Model = preload("res://modules/combat/combat_model.gd")
const Save = preload("res://modules/caravan/caravan_save.gd")
const Store = preload("res://infrastructure/persistence/profile_store.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var path := "/tmp/vehicle-customization-%d.json" % Time.get_ticks_usec()
	var progression := Progression.new(path)
	var model := Model.new()
	progression.setup(model)
	var expedition := Expedition.new(progression)
	var roster = expedition.caravan
	check(Save.normalize({}).customization == Customization.defaults(), "Legacy saves get standard tires and no paid utilities")
	check(not roster.select_customization("tires", "road_tires") and not roster.select_customization("fog_lamps", "fog_lamps"), "Unowned equipment cannot be selected")
	check(not roster.select_customization("paint", "invalid"), "Unknown cosmetic selections are rejected")
	progression.profile.expedition.credits = 0
	check(not roster.purchase_customization("fog_lamps") and roster.data().customization.owned.is_empty(), "Unaffordable upgrade never grants ownership")
	progression.profile.expedition.credits = 5000
	check(roster.purchase_customization("fog_lamps") and roster.data().customization.selected.fog_lamps, "Buying fog lamps equips the independent permanent utility")
	var credits := int(progression.profile.expedition.credits)
	check(not roster.purchase_customization("fog_lamps") and progression.profile.expedition.credits == credits, "Owned upgrade cannot be charged twice")
	check(roster.purchase_customization("road_tires") and roster.purchase_customization("mud_tires"), "Both tire options can be purchased once")
	check(roster.select_customization("paint", "oxide") and roster.select_customization("emblem", "stripe"), "Cosmetics select from the shared catalog")
	check(roster.buy_wagon("cargo"), "Favorite convoy fixture owns a real wagon")
	var wagon_id: String = roster.data().selected_wagon_ids[0]
	check(roster.install_attachment(wagon_id, 1, "cargo_rack"), "Favorite convoy fixture keeps an installed attachment")
	var occupied: Array = roster.attachment_rows(wagon_id, 1)
	check(occupied.all(func(row: Dictionary) -> bool: return not row.enabled and row.slot == -1), "Explicit occupied mount never redirects to another mount")
	check(roster.attachment_rows(wagon_id, 2).all(func(row: Dictionary) -> bool: return row.slot == 2), "Explicit free mount is retained in all attachment actions")
	check(roster.save_build(0, "Recovery") and not roster.save_build(Customization.BUILD_LIMIT), "Favorite slots have a bounded persistent owner")
	check(roster.select_wagon(wagon_id, false) and roster.select_customization("tires", "standard") and roster.apply_build(0), "Favorite restores selected convoy and equipment")
	check(roster.data().selected_wagon_ids == [wagon_id] and roster.data().customization.selected.tires == "mud_tires" and roster.data().wagons[wagon_id].attachments.size() == 1, "Applying favorite preserves unique installed gear without cloning")
	var saved: Dictionary = Store.new(path).load_profile().expedition.caravan
	check(saved.customization.selected.paint == "oxide" and saved.customization.selected.fog_lamps and saved.builds["0"].name == "Recovery", "Customization and favorite survive disk reload")
	progression.store.path = path + "/missing/profile.json"
	var before: Dictionary = roster.data().customization.duplicate(true)
	check(not roster.select_customization("paint", "sand") and roster.data().customization == before, "Save failure rolls back cosmetic selection")
	progression.store.path = path
	check(expedition.begin_run(model.player), "Customized vehicle starts a raid")
	check(model.player.customization == before.selected and model.player.customization.fog_lamps, "Runtime receives normalized selected equipment")
	check(not roster.select_customization("paint", "sand") and not roster.apply_build(0) and not roster.purchase_customization("road_tires"), "Garage customization is locked during a raid")
	check(expedition.finish_run(false), "Lost convoy fixture resolves raid")
	check(roster.data().customization == before, "Permanent pickup upgrades survive a lost raid")
	check(not roster.apply_build(0) and roster.data().wagons.is_empty() and not roster.customization_snapshot().builds[0].available, "Favorite with lost wagon cannot recreate it")
	var malformed := Customization.normalize({"owned": ["invalid", "road_tires", "road_tires"], "selected": {"fog_lamps": true, "tires": "mud_tires", "paint": "invalid"}})
	check(malformed.owned == ["road_tires"] and malformed.selected == Customization.defaults().selected, "Malformed saves cannot unlock paid options")
	_test_tires()
	_test_models()
	print("VEHICLE_CUSTOMIZATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_tires() -> void:
	var dry := {"traction": 1.0, "movement": 1.0, "turn": 1.0}
	var mud := {"traction": 0.55, "movement": 0.7, "turn": 0.8}
	var original: Dictionary = mud.duplicate()
	var standard := Customization.tire_effects({"tires": "standard"}, mud, false)
	var offroad := Customization.tire_effects({"tires": "mud_tires"}, mud, false)
	check(offroad.traction > standard.traction and offroad.movement > standard.movement and offroad.turn > standard.turn and offroad.movement < 1.0, "Mud tires reduce real handling penalties without deleting weather")
	check(mud == original, "Tire effects never mutate shared weather state")
	check(Customization.tire_effects({"tires": "mud_tires"}, dry, false).traction == 1.0, "Mud tires do not invent a dry-ground grip bonus")
	var road := Customization.tire_effects({"tires": "road_tires"}, dry, true)
	check(road.road_speed > 1.0 and road.traction > 1.0 and Customization.tire_effects({"tires": "road_tires"}, dry, false).road_speed == 1.0, "Road tire bonus only applies on actual roads")
	var rain := {"traction": 0.7, "movement": 1.0, "turn": 1.0}
	check(Customization.tire_effects({"tires": "mud_tires"}, rain, false).traction == rain.traction, "Mud tires preserve rain-only traction penalties")

func _test_models() -> void:
	var rig_rules = preload("res://presentation/vehicles/wheeled_rig.gd")
	var stock: Node3D = rig_rules.build_player()
	var custom: Node3D = rig_rules.build_player({"paint": "oxide", "emblem": "cross", "tires": "mud_tires", "fog_lamps": true})
	var stock_body := stock.get_meta("model").find_child("PICKUP_BODY", true, false) as MeshInstance3D
	var custom_body := custom.get_meta("model").find_child("PICKUP_BODY", true, false) as MeshInstance3D
	var original: Material = stock_body.get_active_material(0)
	check(stock_body.material_override == null and custom_body.material_override is ShaderMaterial and stock_body.mesh == custom_body.mesh, "Paint uses one instance material while preserving shared mesh and original stock material")
	check(custom_body.material_override.get_shader_parameter("palette") == original.albedo_texture, "Paint preserves the original palette texture")
	var lamps := custom.find_children("FogBeam*", "SpotLight3D", true, false)
	check(lamps.size() == 2 and lamps.all(func(light: SpotLight3D) -> bool: return light.spot_range == Customization.FOG_LAMPS.range and light.spot_angle == Customization.FOG_LAMPS.half_angle_deg), "Physical lamps use catalog beam range and angle")
	check(custom.find_children("MudTread*", "MeshInstance3D", true, false).size() == 48, "Mud tire geometry reuses existing spinning wheel nodes")
	var parts_id := custom.get_node("Customization").get_instance_id()
	rig_rules.customize(custom, {"paint": "oxide", "emblem": "cross", "tires": "mud_tires", "fog_lamps": true})
	check(custom.get_node("Customization").get_instance_id() == parts_id, "Identical selection does not rebuild model parts every frame")
	rig_rules.customize(custom, {})
	check(custom_body.material_override == null and custom_body.get_active_material(0) == original and custom.find_children("FogBeam*", "SpotLight3D", true, false).is_empty() and custom.find_children("MudTread*", "MeshInstance3D", true, false).is_empty(), "Returning to stock removes utility geometry and restores the exact original shared material")
	stock.free()
	custom.free()

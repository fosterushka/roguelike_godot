extends Node3D

const Models = preload("res://presentation/world/world_quality_models.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const LIGHT_RANGE := 22.0
const VIEW_DISTANCE := 260.0
var sites: Dictionary = {}

func apply_state(records: Array) -> void:
	var live := {}
	for record: Dictionary in records:
		var id := str(record.id)
		live[id] = true
		if not sites.has(id):
			sites[id] = _create(record)
		var site: Dictionary = sites[id]
		var village: bool = record.type == "settlementDistress"
		site.label.text = (("ПОСЕЛЕНИЕ СПАСЕНО\nРЕМОНТ ИСПОЛЬЗОВАН" if Locale.language == "ru" else "SETTLEMENT SAFE\nREPAIR SERVICE USED") if record.get("service_used", false) else ("ПОСЕЛЕНИЕ СПАСЕНО\nПУНКТ РЕМОНТА [E]" if Locale.language == "ru" else "SETTLEMENT SAFE\nFIELD REPAIR [E]")) if village else ("КОНВОЙ ОСТАНОВЛЕН" if Locale.language == "ru" else "CONVOY STOPPED")
	for id in sites.keys():
		if not live.has(id):
			sites[id].root.queue_free()
			sites.erase(id)

func _create(record: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "Aftermath_" + str(record.id)
	root.position = record.position
	root.position.y = Terrain.height_at(root.position.x, root.position.z)
	add_child(root)
	var village: bool = record.type == "settlementDistress"
	var prop := Models.create("utility_pole" if village else "wreck")
	prop.position = Vector3(6, 0, 3) if village else Vector3(-3, 0, 2)
	root.add_child(prop)
	if village:
		var shelter := Models.create("market_stall")
		shelter.position = Vector3(4, 0, 0)
		root.add_child(shelter)
	var light := OmniLight3D.new()
	light.position = Vector3(6, 5, 3) if village else Vector3(-3, 2, 2)
	light.light_color = Color("ffdfa0") if village else Color("bb8a57")
	light.light_energy = 2.4 if village else 0.6
	light.omni_range = LIGHT_RANGE
	light.shadow_enabled = false
	root.add_child(light)
	var label := Label3D.new()
	label.position = Vector3(0, 8, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.outline_size = 8
	label.pixel_size = 0.035
	label.modulate = Color("dccba5")
	root.add_child(label)
	return {"root": root, "label": label, "light": light}

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for site: Dictionary in sites.values():
		site.root.visible = camera.global_position.distance_to(site.root.global_position) < VIEW_DISTANCE

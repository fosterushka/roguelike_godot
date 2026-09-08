extends SceneTree
const View = preload("res://presentation/crew/crew_view.gd")
const Factory = preload("res://modules/crew/crew_factory.gd")
const Wagon = preload("res://presentation/vehicles/military_wagon.gd")
const EncounterPanel = preload("res://presentation/ui/crew_encounter_panel.gd")
const CaravanPanel = preload("res://presentation/ui/caravan_panel.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Progression = preload("res://modules/progression/progression.gd")
const Expedition = preload("res://modules/meta/expedition.gd")
const Model = preload("res://modules/combat/combat_model.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	Locale.settings_path = "/private/tmp/crew-capture-language-%d.cfg" % Time.get_ticks_usec()
	Locale.initialize()
	root.size = Vector2i(1280, 800)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#263132")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#d4dde2")
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17
	stage.add_child(camera)
	camera.position = Vector3(10, 12, 15)
	camera.look_at(Vector3(2, 0, 0))
	var wagon := Wagon.build("repair")
	stage.add_child(wagon)
	wagon.position = Vector3(5, 0, 0)
	var view := View.new()
	stage.add_child(view)
	view.set_carrier_visuals({"wagon-1": wagon})
	var npc := Factory.create_neutral("mechanic", "render-survivor", Vector3(-2, 0, 0))
	npc.identity = 0
	Locale.language = "ru"
	view.update_people([npc], 0.4)
	await capture("calling-distant")
	npc.interaction_available = true
	view.update_people([npc], 0)
	await capture("calling-nearby")
	npc.faction = "ally"
	npc.state = "approaching"
	npc.reaction_time = 5.0
	view.update_people([npc], 0.1)
	await capture("accepted")
	npc.state = "offended"
	npc.reaction_text = preload("res://modules/crew/crew_encounter.gd").OFFENDED_LINES[0]
	view.update_people([npc], 0)
	await capture("offended-ru")
	Locale.language = "en"
	view.update_people([npc], 0)
	await capture("offended-en")
	Locale.language = "ru"
	npc.faction = "neutral"
	npc.state = "fleeing"
	npc.reaction_text = ["Тогда поищу других попутчиков.", "Then I'll find another crew."]
	view.update_people([npc], 0.1)
	await capture("refused")
	npc.position += Vector3(3, 0, 2)
	view.update_people([npc], 0.1)
	await capture("refused-follow")
	npc.state = "stranded"
	npc.reaction_time = 0
	view.update_people([npc], 0.1)
	var model := Model.new()
	var progression := Progression.new("/private/tmp/crew-capture-%d.json" % Time.get_ticks_usec())
	progression.setup(model)
	var raid := Expedition.new(progression)
	progression.profile.expedition.credits = 1000
	raid.caravan.buy_wagon("repair")
	var panel := EncounterPanel.new()
	root.add_child(panel)
	raid.begin_run(model.player)
	Locale.language = "ru"
	panel.show_person(npc, raid.caravan)
	await capture("dialogue-ru")
	Locale.language = "en"
	panel.show_person(npc, raid.caravan)
	await capture("dialogue-en")
	panel.hide()
	npc.state = "boarding"
	npc.faction = "ally"
	npc.boarding_start = Vector3(2.3, 0, -1.25)
	npc.position = npc.boarding_start
	npc.carrier_id = "wagon-1"
	npc.seat = 0
	npc.boarding_progress = 0.5
	view.update_people([npc], 0.1)
	await capture("boarding")
	raid.finish_run(false)
	progression.profile.expedition.stash.scrap = 50
	var novice := Factory.create("civilian", "crew-200")
	raid.caravan.data().crew[novice.id] = Factory.save(novice)
	var garage := CaravanPanel.new()
	root.add_child(garage)
	Locale.language = "ru"
	root.size = Vector2i(960, 640)
	garage.tab = "crew"
	garage.show_state(raid.caravan.snapshot(), 1000, 50)
	await capture("training-ru")
	garage.hide()
	var hub := preload("res://presentation/ui/hideout_hub.gd").new()
	root.add_child(hub)
	var armory := preload("res://presentation/ui/armory_panel.gd").new()
	root.add_child(armory)
	var inventory := preload("res://presentation/ui/expedition_panel.gd").new()
	root.add_child(inventory)
	hub.attach(armory, inventory, garage)
	hub.tab_selected.connect(func(tab: String):
		if tab == "garage":
			garage.show_state(raid.caravan.snapshot(), 1000, 50)
		elif tab == "armory":
			armory.show_state(progression.get_shop_state())
		else:
			inventory.show_state(raid.snapshot(), tab))
	hub.update_account(raid.snapshot())
	hub.select_tab("garage")
	await capture("garage-hub-ru")
	hub.select_tab("stash")
	await capture("vault-hub-ru")
	hub.select_tab("loadout")
	await capture("stash-hub-ru")
	hub.detach()
	hub.queue_free()
	armory.queue_free()
	inventory.queue_free()
	garage.queue_free()
	panel.queue_free()
	stage.queue_free()
	await process_frame
	quit()
func capture(label: String) -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/crew-" + label + ".png")
	print("CREW_CAPTURE " + label)

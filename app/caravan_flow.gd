extends RefCounted

const Runtime = preload("res://modules/caravan/caravan_runtime.gd")
const CrewRuntime = preload("res://modules/crew/crew_runtime.gd")
const CaravanPanel = preload("res://presentation/ui/caravan_panel.gd")
const Styles = preload("res://presentation/ui/ui_styles.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var game: Node3D
var encounter_panel: ColorRect
var return_screen := "menu"

func setup(owner: Node3D) -> void:
	game = owner
	game.caravan = Runtime.new()
	game.add_child(game.caravan)
	game.caravan.setup(game.expedition, game.combat, game.vehicle, game.world)
	game.crew_runtime = CrewRuntime.new()
	game.add_child(game.crew_runtime)
	game.crew_runtime.setup(game.expedition, game.combat, game.world, game.vehicle, game.raid_loot)
	game.caravan.crew_runtime = game.crew_runtime
	encounter_panel = preload("res://presentation/ui/crew_encounter_panel.gd").new()
	game.hud.get_node("Screen").add_child(encounter_panel)
	encounter_panel.decided.connect(decide_encounter)
	game.crew_runtime.encounter_requested.connect(func(person: Dictionary): _open_encounter.call_deferred(person))
	game.caravan.caravan_event.connect(_on_event)
	game.caravan_panel = CaravanPanel.new()
	game.hud.get_node("Screen").add_child(game.caravan_panel)
	game.caravan_panel.closed.connect(close)
	game.caravan_panel.action_requested.connect(_action)
	game._crew_button = Styles.button(words("ЭКИПАЖ [J]", "CREW [J]"))
	preload("res://presentation/ui/ui_icons.gd").apply(game._crew_button, "crew")
	game._crew_button.custom_minimum_size = Vector2(0, 26)
	game.hud._coins_label.get_parent().add_child(game._crew_button)
	game.hud._stats_panel.offset_top -= 34
	game.hud._objective_label.offset_top -= 34
	game.hud._objective_label.offset_bottom -= 34
	game._crew_button.pressed.connect(open)
	game._crew_hint = Styles.label("", 12)
	game._crew_hint.position = Vector2(16, 58)
	game._crew_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game._crew_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	game._crew_hint.add_theme_constant_override("shadow_offset_x", 1)
	game._crew_hint.add_theme_constant_override("shadow_offset_y", 1)
	game.hud._gameplay.add_child(game._crew_hint)
	game.hud.markers.occluders.append(game._crew_hint)

static func words(ru: String, en: String) -> String:
	return ru if Locale.language == "ru" else en

func open() -> void:
	if game.screen_state not in ["menu", "running", "pause", "armory", "result", "expedition"]:
		return
	if not game.expedition.active:
		if game.screen_state != "expedition":
			game._open_expedition()
		game.hideout_hub.select_tab("garage")
		return
	return_screen = game.screen_state
	game.hud.hide_menus()
	game._set_screen("garage")
	refresh()

func open_trailers() -> void:
	game.caravan_panel.tab = "wagons"
	game.caravan_panel.purchase_notice = ""
	open()

func close() -> void:
	if not game.expedition.active and game.screen_state == "expedition":
		game._close_expedition()
		return
	if return_screen == "menu":
		game.show_start_menu()
	elif return_screen == "expedition":
		game._set_screen("expedition")
		if game.expedition.active:
			game.expedition_panel.show_state(game.expedition.snapshot(), "backpack")
		else:
			game.hideout_hub.attach(game.hud.armory, game.expedition_panel, game.caravan_panel)
			game.hideout_hub.select_tab(game.hideout_hub.tab)
	elif return_screen == "armory":
		game._set_screen("armory")
		game._show_armory()
	elif return_screen == "pause":
		game._set_screen("pause")
		game.hud.set_paused(true)
	elif return_screen == "result":
		game._set_screen("result")
		game._show_result()
	else:
		game._set_screen("running")

func refresh() -> void:
	var state: Dictionary = game.expedition.snapshot()
	if game.hideout_hub.visible:
		game.hideout_hub.update_account(state)
	var convoy: Dictionary = game.expedition.caravan.snapshot()
	convoy.attachment_rows = {}
	if not convoy.active:
		for wagon: Dictionary in convoy.wagons:
			convoy.attachment_rows[wagon.id] = game.expedition.caravan.attachment_rows(wagon.id)
	game.caravan_panel.show_state(convoy, int(state.credits), int(state.stash.get("scrap", 0)))

func _action(kind: String, id: String, target: String) -> void:
	if game.screen_state != "garage" and not (game.screen_state == "expedition" and game.hideout_hub.tab == "garage"):
		return
	var roster: RefCounted = game.expedition.caravan
	match kind:
		"buy_wagon":
			if roster.buy_wagon(id):
				var ids: Array = roster.data().selected_wagon_ids
				refresh()
				game.caravan_panel.show_equipment(str(ids.back()), true)
				return
		"configure_wagon":
			if roster.active:
				game._set_screen("armory")
				game._show_armory()
				game.hud.armory.select_carrier(id)
			else:
				game.caravan_panel.show_equipment(id)
			return
		"install_attachment":
			if not roster.active:
				buy_equipment(id)
		"remove_attachment":
			if not roster.active and target.is_valid_int():
				roster.remove_attachment(id, int(target))
		"select_wagon": roster.select_wagon(id, target == "1")
		"select_crew": roster.select_crew(id, target == "1")
		"train_crew": roster.train_crew(id, target)
		"assign_crew":
			var parts := target.split(":")
			if parts.size() == 2 and parts[1].is_valid_int():
				roster.assign(id, parts[0], int(parts[1]))
	refresh()

func buy_equipment(id: String) -> bool:
	var parts := id.split(":")
	if parts.size() == 4 and parts[0] == "attachment" and parts[3].is_valid_int():
		return game.expedition.caravan.install_attachment(parts[2], int(parts[3]), parts[1])
	if parts.size() == 3 and parts[0] == "remove_attachment" and parts[2].is_valid_int():
		return game.expedition.caravan.remove_attachment(parts[1], int(parts[2]))
	return game.combat.buy_upgrade(id)

func recouple_nearest() -> bool:
	for wagon: Dictionary in game.expedition.caravan.wagons:
		if game.expedition.caravan.recouple(wagon.id):
			return true
	return false

func update_hint() -> void:
	var hint: String = game.crew_runtime.hint()
	var outside := 0
	for person: Dictionary in game.expedition.caravan.crew:
		outside += int(not person.dead and not person.boarded)
	if hint.is_empty():
		for wagon: Dictionary in game.expedition.caravan.wagons:
			if not wagon.dead and not wagon.attached and wagon.position.distance_to(game.vehicle.global_position) <= 8:
				hint = words("E: вернуть прицеп", "E: recouple wagon")
				break
	var status := words("C: сбор выкл.", "C: collecting off") if not game.combat.model.player.get("crew_collect", false) else words("C: отозвать сборщиков", "C: recall scavengers")
	if outside > 0:
		status += words(" · Снаружи: %d", " · Outside: %d") % outside
	game._crew_hint.text = hint + ("\n" if not hint.is_empty() else "") + status if not game.expedition.caravan.crew.is_empty() or not hint.is_empty() else ""
	game._crew_hint.visible = not game._crew_hint.text.is_empty()
	game._crew_button.text = words("ЭКИПАЖ [J]", "CREW [J]")

func _on_event(event: Dictionary) -> void:
	game.expedition.record_event(event)
	if event.kind == "wagon_destroyed":
		game.raid_loot.spawn_items("wagon-%d-%s" % [game.combat.model.generation, event.id], event.position, event.drops)
		if is_instance_valid(game.combat_view):
			game.combat_view.on_event({"kind": "death", "type": "buggy", "position": event.position, "radius": 2.2, "cause": "wagon_destroyed"})
		game.hud.show_world_banner(words("ПРИЦЕП УНИЧТОЖЕН", "WAGON DESTROYED"), words("Хвост отсоединён. Выжившие прицепы можно вернуть.", "Tail detached. Surviving wagons can be recovered."))
	elif event.kind == "crew_died":
		game.hud.show_world_banner(words("ПОТЕРЯ ЭКИПАЖА", "CREW LOST"), words("Сотрудник погиб.", "A crew member has died."))
	elif event.kind == "wagon_detached":
		game.hud.show_world_banner(words("СЦЕПКА РАЗОМКНУТА", "WAGON DETACHED"), words("Остановитесь рядом с прицепом и нажмите E.", "Stop near the wagon and press E."))

func _open_encounter(person: Dictionary) -> void:
	if game.screen_state != "running" or game.crew_runtime.pending != person or person.get("dead", false):
		game.crew_runtime.cancel_encounter()
		return
	game._set_screen("encounter")
	for action in ["drive_forward", "drive_backward", "drive_left", "drive_right", "handbrake"]:
		Input.action_release(action)
	game.vehicle.motion.speed = 0
	game.vehicle.motion.throttle = 0
	game.vehicle.motion.yaw_velocity = 0
	game.vehicle.velocity = Vector3.ZERO
	game.combat.model.player.speed = 0
	encounter_panel.show_person(person, game.expedition.caravan)

func decide_encounter(action: String) -> void:
	if game.screen_state != "encounter":
		return
	if action == "hire":
		if not game.crew_runtime.accept_encounter():
			encounter_panel.show_error()
			return
	elif action == "decline":
		game.crew_runtime.decline_encounter()
	else:
		game.crew_runtime.cancel_encounter()
	encounter_panel.hide()
	game._set_screen("running")

extends Node3D
const CARGO_POLL_SECONDS := 0.2
const MISSION_POLL_SECONDS := 0.5
const Profiler = preload("res://infrastructure/diagnostics/runtime_profiler.gd")

const Expedition = preload("res://modules/meta/expedition.gd")
const ExpeditionPanel = preload("res://presentation/ui/expedition_panel.gd")

const Locale = preload("res://presentation/ui/ui_locale.gd")

const Actions = preload("res://app/input_actions.gd")
const Assets = preload("res://infrastructure/loading/asset_catalog.gd")
const VehicleController = preload("res://modules/caravan/vehicle_controller.gd")
const CombatRuntime = preload("res://modules/combat/combat_runtime.gd")
const UpgradeProjection = preload("res://presentation/ui/upgrade_projection.gd")
const SoundSystem = preload("res://presentation/audio/sound_system.gd")
const WorldRuntime = preload("res://modules/world/world_runtime.gd")
const Preparation = preload("res://infrastructure/loading/game_preparation.gd")
const Progression = preload("res://modules/progression/progression.gd")
const CombatView = preload("res://presentation/combat/combat_view.gd")

const WorldGenerator = preload("res://modules/world/generation/world_generator.gd")
const AuthoredWorld = preload("res://modules/world/generation/authored_props.gd")

signal game_ready
signal run_ready(seed_value: int)
signal run_prepared(seed_value: int)

var session_flow := preload("res://modules/session/session_flow.gd").new()

var vehicle: CharacterBody3D
var camera: Camera3D
var performance_bar: CanvasLayer
var hud: CanvasLayer
var arena: Node3D
var combat: Node3D
var combat_view: Node3D
var world: Node3D
var sound: Node
var expedition: RefCounted
var expedition_panel: ColorRect
var hideout_hub: ColorRect
var raid_loot: Node3D
var caravan: Node
var crew_runtime: Node3D
var caravan_panel: ColorRect
var _crew_hint: Label
var _crew_button: Button
var caravan_flow := preload("res://app/caravan_flow.gd").new()
var case_flow := preload("res://app/case_opening_flow.gd").new()
var _expedition_return := "menu"
var _expedition_return_page := "main"
var _options_return := "menu"
var _options_return_page := "main"
var _menu_page := "main"
var _cargo_label: Button
var _loot_poll := 0.0
var _mission_poll := 0.0
var _mission_hint: Label
var progression: RefCounted
var progression_feedback := preload("res://presentation/ui/progression_feedback.gd").new()
var run_seed_override := -1
var run_seed := -1
var _seed_source := RandomNumberGenerator.new()
var ready_to_drive := false
var screen_state := "loading"
var selected_ability := 0
var _pointer_start: Dictionary = {}
var _pointer_dragged: Dictionary = {}
var preparation := Preparation.new()
var world_warmup := preload("res://infrastructure/loading/world_warmup.gd").new()
var _result_event: Dictionary = {}
var profile_path := "user://iron_caravan_profile.json"

func _ready() -> void:
	get_tree().auto_accept_quit = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 10
	_seed_source.randomize()
	Actions.register()
	performance_bar = preload("res://presentation/debug/performance_bar.gd").new()
	performance_bar.game = self
	add_child(performance_bar)
	get_tree().paused = true
	hud = Assets.HUD.instantiate()
	add_child(hud)
	hud.menu_action_requested.connect(_menu_action)
	hud.language_requested.connect(_set_language)
	hud.set_loading(true)
	hud.set_loading_progress(Locale.text("Подготовка одиночной игры"), 0.0)
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	if not await preparation.validate_and_load(self, hud.set_loading_progress):
		_loading_failed()
		return
	hud.pause_requested.connect(_toggle_pause)
	hud.ability_selected.connect(_select_ability)
	hud.ability_requested.connect(func() -> void: _touch_command("ability"))
	hud.resume_requested.connect(_resume)
	hud.restart_requested.connect(restart_run)
	hud.armory_requested.connect(_toggle_armory)
	hud.sound_requested.connect(_toggle_sound)
	hud.touch_command_requested.connect(_touch_command)
	hud.set_loading_progress(Locale.text("Построение исходного мира"), 0.62)
	await get_tree().process_frame
	arena = Assets.ARENA.instantiate()
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	vehicle = VehicleController.new()
	vehicle.name = "PlayerVehicle"
	vehicle.process_mode = Node.PROCESS_MODE_PAUSABLE
	vehicle.set_driving_enabled(false)
	vehicle.telemetry_changed.connect(hud.update_telemetry)
	add_child(vehicle)
	var visual: Node3D = Assets.VEHICLE.instantiate()
	visual.name = "VehicleView"
	vehicle.add_child(visual)
	vehicle.telemetry_changed.connect(visual.set_telemetry)
	camera = Assets.CAMERA.new()
	camera.name = "FollowCamera"
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	camera.target = vehicle
	add_child(camera)
	camera.reset_view()
	combat = CombatRuntime.new()
	combat.name = "OfflineCombat"
	add_child(combat)
	combat.setup(vehicle)
	for property: Dictionary in combat.model.get_property_list():
		if property.name == "spawn_visibility_query":
			combat.model.set("spawn_visibility_query", Callable(self, "_spawn_outside_camera"))
		if property.name == "weapon_origin_query":
			combat.model.set("weapon_origin_query", Callable(visual, "get_weapon_origin"))
	combat.state_changed.connect(_on_state)
	combat.combat_event.connect(_on_combat_event)
	progression = Progression.new(profile_path)
	progression.setup(combat.model)
	combat.progression = progression
	expedition = Expedition.new(progression)
	_setup_expedition_ui()
	raid_loot = preload("res://presentation/world/raid_loot.gd").new()
	add_child(raid_loot)
	sound = SoundSystem.new()
	add_child(sound)
	sound.set_enabled(bool(progression.profile.settings.soundEnabled))
	hud.set_sound_enabled(sound.enabled)
	progression_feedback.setup(progression, hud, sound)
	combat.combat_event.connect(sound.on_combat_event)
	world = WorldRuntime.new()
	add_child(world)
	world.setup(arena, combat, vehicle)
	world.state_changed.connect(_on_world_state)
	world.world_event.connect(progression_feedback.on_event)
	world.world_event.connect(sound.on_world_event)
	world.world_event.connect(_on_world_event)
	_setup_caravan()
	hud.set_loading_progress(Locale.text("Подготовка боя и эффектов"), 0.70)
	await get_tree().process_frame
	combat_view = CombatView.new()
	combat_view.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(combat_view)
	combat_view.setup(combat, vehicle)
	add_child(session_flow)
	session_flow.setup(self)
	camera.run_clock = session_flow.clock
	vehicle.clock_delta = session_flow.simulation_delta
	vehicle.get_node("VehicleView").time_delta = _vehicle_visual_delta
	combat.clock_delta = session_flow.simulation_delta
	combat.result_deferred = session_flow.defer_result
	world.clock_delta = session_flow.simulation_delta
	world.raw_weather_driven = true
	if "time_delta" in combat_view._effects:
		combat_view._effects.time_delta = session_flow.effects_delta
	if combat_view.has_signal("screen_impact"):
		combat_view.connect("screen_impact", _on_screen_impact)
	if not await preparation.prepare(self, vehicle.global_position + Vector3.UP, hud.set_loading_progress):
		hud.set_loading(false)
		hud.show_menu(Locale.text("ОШИБКА ЗАГРУЗКИ"), "\n".join(preparation.errors), [])
		return
	hud.set_loading_progress(Locale.text("Прогрев материалов и звука"), 0.96)
	combat_view.set_warmup_visible(true)
	world.set_warmup_visible(true)
	crew_runtime.set_warmup(true, vehicle.global_position + Vector3.UP)
	hud.armory.preview.prepare_models()
	hud.armory.preview.set_active(true)
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await world_warmup.prepare(self, hud.set_loading_progress)
	combat_view.set_warmup_visible(false)
	world.set_warmup_visible(false)
	crew_runtime.set_warmup(false, Vector3.ZERO)
	hud.armory.preview.set_active(false)
	preparation.finish()
	vehicle.reset_vehicle()
	hud.set_loading_progress(Locale.text("Готово"), 1.0)
	ready_to_drive = true
	hud.set_loading(false)
	show_start_menu()
	game_ready.emit()
	print("OFFLINE_READY: loaded world, vehicle, weapons, enemy pools, effects and HUD; waiting for start")

func _input(event: InputEvent) -> void:
	if not ready_to_drive or screen_state in ["countdown", "death"] or (event is InputEventKey and event.echo):
		return
	if screen_state == "encounter":
		if event.is_action_pressed("pause_game"):
			caravan_flow.decide_encounter("later")
			get_viewport().set_input_as_handled()
		return
	if screen_state == "case_opening":
		if event.is_action_pressed("pause_game") or event.is_action_pressed("ui_accept"):
			case_flow.panel.activate()
			get_viewport().set_input_as_handled()
		if event is InputEventKey:
			get_viewport().set_input_as_handled()
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit and focused.is_visible_in_tree() and not event.is_action_pressed("pause_game"):
		return
	if event.is_action_pressed("pause_game"):
		if screen_state == "garage":
			_close_caravan()
		elif screen_state == "expedition":
			_close_expedition()
		elif screen_state == "armory":
			_resume()
		elif screen_state == "options":
			_menu_action("options_back", "")
		else:
			_toggle_pause()
	elif event.is_action_pressed("inventory"):
		if screen_state == "expedition":
			_close_expedition()
		elif screen_state in ["running", "menu", "pause"]:
			_open_expedition()
	elif event.is_action_pressed("armory"):
		_toggle_armory()
	elif event.is_action_pressed("crew_menu"):
		if screen_state == "expedition" and hideout_hub.tab == "garage":
			_close_expedition()
		elif screen_state == "garage":
			_close_caravan()
		else:
			_open_caravan()
	elif screen_state == "running":
		if event.is_action("handbrake"):
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("interact"):
			if crew_runtime.interact() or _recouple_nearest():
				combat.model.player.interaction_claimed = true
			elif world.has_method("interact"):
				world.interact()
		elif event.is_action_pressed("crew_collect"):
			crew_runtime.toggle_collection()
		elif event.is_action_pressed("focus_target"):
			if camera._intro <= 0.0:
				combat.focus_next()
		elif event.is_action_pressed("ability_one"):
			selected_ability = 0
		elif event.is_action_pressed("ability_two"):
			selected_ability = 1
		elif event.is_action_pressed("ability_three"):
			selected_ability = 2
		elif event.is_action_pressed("activate_ability"):
			if not combat.activate_ability(selected_ability):
				hud.set_status(Locale.text("Навык недоступен: проверьте модуль, ресурс и перезарядку"))
		elif event.is_action_pressed("radar_zoom"):
			hud.radar.cycle_zoom()
		else:
			return
	else:
		if event.is_action_pressed("activate_ability") or event.is_action_pressed("handbrake"):
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if screen_state != "running":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer(event.position, event.pressed, -1, 24.0)
	elif event is InputEventScreenTouch:
		_pointer(event.position, event.pressed, event.index, 32.0)
	elif event is InputEventMouseMotion and _pointer_start.has(-1):
		_pointer_dragged[-1] = bool(_pointer_dragged.get(-1, false)) or event.position.distance_to(_pointer_start[-1]) > 8.0
	elif event is InputEventScreenDrag and _pointer_start.has(event.index):
		_pointer_dragged[event.index] = bool(_pointer_dragged.get(event.index, false)) or event.position.distance_to(_pointer_start[event.index]) > 8.0

func _pointer(point: Vector2, pressed: bool, id: int, radius: float) -> void:
	if pressed:
		_pointer_start[id] = point
		_pointer_dragged[id] = false
		return
	if _pointer_start.has(id) and not _pointer_dragged.get(id, false) and point.distance_to(_pointer_start[id]) <= 8.0 and camera._intro <= 0.0:
		_focus_at_screen(point, radius)
	_pointer_start.erase(id)
	_pointer_dragged.erase(id)

func _focus_at_screen(point: Vector2, radius: float) -> void:
	var snapshot: Dictionary = combat.get_state()
	var closest := radius
	var selected := -1
	for target: Dictionary in snapshot.get("enemies", []) + snapshot.get("boss_components", []):
		if target.get("dead", false) or not target.get("targetable", true):
			continue
		var world_point: Vector3 = target.position
		if not target.get("is_component", false):
			world_point.y += preload("res://modules/caravan/terrain_surface.gd").height_at(world_point.x, world_point.z) + float(target.get("height", 2.0))
		var distance := camera.unproject_position(world_point).distance_to(point)
		if distance <= closest:
			closest = distance
			selected = int(target.id)
	combat.focus_target(selected)

func show_start_menu() -> void:
	_menu_page = "main"
	if expedition != null and expedition.snapshot().get("pending_result", false):
		_set_screen("result")
		_show_result()
		return
	if expedition != null and expedition.active:
		expedition.abandon_run()
	_set_screen("menu")
	var sound_on: bool = sound.enabled if is_instance_valid(sound) else true
	hud.show_menu("IRON CARAVAN", ExpeditionPanel.words("Одиночная экспедиция. Подготовьте караван и отправляйтесь в рейд.", "Offline expedition. Prepare the caravan, then deploy."), [
		{"label": ExpeditionPanel.words("ОДИНОЧНАЯ ИГРА", "SINGLEPLAYER"), "action": "singleplayer"},
		{"label": ExpeditionPanel.words("МУЛЬТИПЛЕЕР · СКОРО", "MULTIPLAYER · COMING SOON"), "action": "multiplayer", "disabled": true},
		{"label": ExpeditionPanel.words("НАСТРОЙКИ", "OPTIONS"), "action": "options"},
		{"label": Locale.text("ВЫЙТИ ИЗ ИГРЫ"), "action": "quit"},
	], true)

func _show_singleplayer_menu() -> void:
	_menu_page = "singleplayer"
	_set_screen("menu")
	hud.show_menu(ExpeditionPanel.words("ОДИНОЧНАЯ ИГРА", "SINGLEPLAYER"), ExpeditionPanel.words("Выберите действие перед рейдом.", "Choose an action before deploying."), [
		{"label": ExpeditionPanel.words("РЕЙД", "RAID"), "action": "raid"},
		{"label": ExpeditionPanel.words("ХРАНИЛИЩЕ", "VAULT"), "action": "vault"},
		{"label": ExpeditionPanel.words("НАЗАД", "BACK"), "action": "menu"},
	], true)

func _show_options(return_screen: String) -> void:
	_options_return = return_screen
	_options_return_page = _menu_page
	_set_screen("options")
	var sound_on: bool = sound.enabled if is_instance_valid(sound) else true
	var shake := int(roundf(camera.shake_intensity * 100.0))
	hud.show_menu(ExpeditionPanel.words("НАСТРОЙКИ", "OPTIONS"), ExpeditionPanel.words("Настройки сохраняются в профиле.", "Settings are saved to your profile."), [
		{"label": ExpeditionPanel.words("ЗВУК: ВКЛ", "SOUND: ON") if sound_on else ExpeditionPanel.words("ЗВУК: ВЫКЛ", "SOUND: OFF"), "action": "sound"},
		{"label": ExpeditionPanel.words("ТРЯСКА КАМЕРЫ −  %d%%" % shake, "CAMERA SHAKE −  %d%%" % shake), "action": "shake_down"},
		{"label": ExpeditionPanel.words("ТРЯСКА КАМЕРЫ +  %d%%" % shake, "CAMERA SHAKE +  %d%%" % shake), "action": "shake_up"},
		{"label": "LANGUAGE: ENGLISH" if Locale.language == "en" else "ЯЗЫК: РУССКИЙ", "action": "language"},
		{"label": ExpeditionPanel.words("НАЗАД", "BACK"), "action": "options_back"},
	], true)
	hud.run_menu._language_button.visible = false

func _change_camera_shake(delta: float) -> void:
	camera.shake_intensity = clampf(camera.shake_intensity + delta, 0.0, 1.0)
	expedition_panel.intensity = camera.shake_intensity
	progression.profile.settings["cameraShake"] = camera.shake_intensity
	progression._mark_dirty()
	progression.flush()

func _set_screen(value: String) -> void:
	if is_instance_valid(hideout_hub) and hideout_hub.visible and value != "expedition":
		hideout_hub.detach()
	screen_state = value
	if is_instance_valid(caravan_flow.encounter_panel) and value != "encounter":
		caravan_flow.encounter_panel.hide()
		if is_instance_valid(crew_runtime):
			crew_runtime.cancel_encounter()
	if value in ["loading", "menu", "result", "death"]:
		case_flow.reset()
	if value not in ["running", "countdown"]:
		hud.set_countdown(0, false)
	if is_instance_valid(expedition_panel):
		expedition_panel.visible = value == "expedition"
	if is_instance_valid(caravan_panel):
		caravan_panel.visible = value == "garage"
	hud.set_gameplay_active(value in ["running", "countdown"])
	_pointer_start.clear()
	_pointer_dragged.clear()
	hud.touch_controls.set_enabled(value == "running")
	var running := value == "running"
	get_tree().paused = not running and value != "countdown"
	if value in ["pause", "armory", "choice", "expedition", "garage", "case_opening", "options", "encounter"]:
		session_flow.clock.pause()
	elif value == "running":
		session_flow.clock.resume()
	elif value in ["menu", "loading"]:
		session_flow.cancel()
	elif value == "result":
		session_flow.clock.finish()
	combat.set_running(running)
	if is_instance_valid(world):
		world.set_running(running)
	if is_instance_valid(sound):
		sound.set_running(running)
	vehicle.set_driving_enabled(running)
	if running:
		hud.hide_menus()
		case_flow.try_open.call_deferred()

func _toggle_pause() -> void:
	if screen_state == "running":
		_set_screen("pause")
		hud.set_paused(true)
	elif screen_state == "pause":
		_resume()

func _resume() -> void:
	if screen_state in ["pause", "armory"]:
		_set_screen("running")

func _toggle_armory() -> void:
	if screen_state == "armory":
		_resume()
	elif screen_state == "running":
		_set_screen("armory")
		_show_armory()

func restart_run() -> void:
	if not ready_to_drive:
		return
	if expedition.snapshot().get("pending_result", false):
		_set_screen("result")
		_show_result()
		return
	if expedition.active:
		expedition.abandon_run()
	raid_loot.reset()
	ready_to_drive = false
	_set_screen("loading")
	progression.flush()
	hud.hide_menus()
	hud.set_loading(true)
	hud.set_loading_progress(Locale.text("Создание нового мира"), 0.0)
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var next_seed := run_seed_override & 0xffffffff if run_seed_override >= 0 else _seed_source.randi()
	while run_seed_override < 0 and next_seed == run_seed:
		next_seed = _seed_source.randi()
	var generated: RefCounted = WorldGenerator.generate(next_seed, AuthoredWorld.new())
	hud.set_loading_progress(Locale.text("Мир создан: дороги, поселения и окружение"), 0.45)
	await get_tree().process_frame
	if not arena.rebuild_from_context(generated):
		for group: Node3D in generated.groups:
			group.free()
		preparation.errors = [Locale.text("Перестройка мира требует остановленной симуляции")]
		_loading_failed()
		return
	run_seed = next_seed
	hud.radar.layout = arena.world_layout
	hud.set_loading_progress(Locale.text("Коллизии и события нового мира"), 0.72)
	sound.reset_run()
	combat.reset_run(run_seed)
	combat.set_running(false)
	_setup_progression()
	world.rebind_world(run_seed)
	selected_ability = 0
	camera.reset_view()
	await get_tree().process_frame
	hud.set_loading_progress(Locale.text("Подготовка первого кадра"), 0.92)
	combat_view.set_warmup_visible(true)
	world.set_warmup_visible(true)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	else:
		await get_tree().process_frame
	await world_warmup.prepare(self, hud.set_loading_progress)
	combat_view.set_warmup_visible(false)
	world.set_warmup_visible(false)
	hud.set_loading_progress(Locale.text("Готово"), 1.0)
	hud.set_status("")
	hud.set_loading(false)
	ready_to_drive = true
	if not expedition.begin_run(combat.model.player):
		show_start_menu()
		_open_expedition()
		return
	caravan.reset()
	crew_runtime.reset(run_seed)
	_sync_progression_stats()
	session_flow.begin_run()
	run_prepared.emit(run_seed)
	await run_ready

func _setup_progression() -> void:
	progression.reset_run()
	progression.begin_run()
	_sync_progression_stats()

func _physics_process(delta: float) -> void:
	if progression == null:
		return
	progression.step(session_flow.clock.simulation_delta if screen_state == "running" else delta)
	if screen_state == "armory":
		hud.armory.refresh_save_status(progression.store.status, progression.dirty)
	if screen_state != "running":
		return
	expedition.sample_run(combat.model.player, session_flow.clock.simulation_delta, str(world.weather.phase.type))
	_mission_poll += delta
	if _mission_poll >= MISSION_POLL_SECONDS:
		_mission_poll = 0.0
		_update_mission_hint()
	_loot_poll += delta
	if _loot_poll >= CARGO_POLL_SECONDS:
		_loot_poll = 0.0
		_update_crew_hint()
		if raid_loot.collect_near(vehicle.global_position, expedition):
			hud.set_status(expedition.notice)
		_update_cargo()
	_sync_progression_stats(false)
	if int(combat.model.player.get("pending_upgrades", 0)) > 0:
		_on_state(combat.get_state())
		_set_screen("choice")
		_show_choices()
		sound.play_cue("level", true)

func _sync_progression_stats(refresh_hud: bool = true) -> void:
	vehicle.player_stats = combat.model.player
	vehicle.health = combat.model.player.hp
	vehicle.max_health = combat.model.player.max_hp
	vehicle.fuel = combat.model.player.fuel
	vehicle.max_fuel = combat.model.player.max_fuel
	if refresh_hud:
		_on_state(combat.get_state())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and screen_state == "running":
		for action in ["drive_forward", "drive_backward", "drive_left", "drive_right", "handbrake", "interact"]:
			Input.action_release(action)
		_toggle_pause()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()

func _shop_rows(items: Array, action: String = "buy") -> Array:
	var rows: Array = []
	for item: Dictionary in items:
		var cost := int(item.get("cost", 0))
		var reason := Locale.text(str(item.get("disabled_reason", "")))
		var detail := Locale.text(str(item.get("description", "")))
		if action == "choose":
			var projection := UpgradeProjection.description(str(item.get("id", "")), combat.model.player, combat.model.weapons)
			if not projection.is_empty():
				detail += "\n" + projection
		rows.append({"id": str(item.get("id", "")), "action": action, "label": "%s%s%s" % [Locale.text(str(item.get("label", item.get("title", "")))), Locale.text(" · %d лом") % cost if cost > 0 else "", " · " + reason if not reason.is_empty() else ""], "description": detail, "disabled": not bool(item.get("enabled", true))})
	return rows

func _show_choices() -> void:
	var state: Dictionary = progression.get_shop_state()
	hud.show_menu(Locale.text("НОВЫЙ УРОВЕНЬ"), Locale.text("Выберите улучшение корпуса") if state.get("choice_stage", "") == "core" else Locale.text("Выберите модуль или улучшение"), _shop_rows(state.get("choices", []), "choose"))

func _show_armory() -> void:
	var shop: Dictionary = progression.get_shop_state()
	shop.caravan_active = expedition.caravan.active
	shop.attachments = []
	for wagon: Dictionary in expedition.caravan.wagons:
		shop.attachments.append_array(expedition.caravan.attachment_rows(wagon.id))
	if is_instance_valid(hideout_hub) and hideout_hub.visible:
		hud.armory.display(shop, combat.model.player)
	else:
		hud.show_armory(shop, combat.model.player)

func _menu_action(action: String, id: String) -> void:
	if screen_state in ["countdown", "death"] and action not in ["restart", "menu"]:
		return
	match action:
		"singleplayer": _show_singleplayer_menu()
		"raid": restart_run()
		"vault": _open_expedition()
		"options": _show_options(screen_state)
		"options_back":
			if _options_return == "pause":
				_set_screen("pause")
				hud.set_paused(true)
			elif _options_return_page == "singleplayer":
				_show_singleplayer_menu()
			else:
				show_start_menu()
		"language": _set_language("ru" if Locale.language == "en" else "en")
		"shake_down":
			_change_camera_shake(-0.1)
			_show_options(_options_return)
		"shake_up":
			_change_camera_shake(0.1)
			_show_options(_options_return)
		"retry_save":
			expedition.action("retry_save", "")
			_show_result()
		"hideout": _open_expedition()
		"garage": _open_caravan()
		"trailers": caravan_flow.open_trailers()
		"reload": get_tree().reload_current_scene()
		"sound":
			_toggle_sound()
			if screen_state == "menu":
				show_start_menu()
			elif screen_state == "options":
				_show_options(_options_return)
		"quit": _request_quit()
		"start", "restart": restart_run()
		"resume": _resume()
		"menu": show_start_menu()
		"buy":
			if _buy_equipment(id):
				sound.play_cue("module", true)
				expedition.caravan.capture_modules()
				preload("res://modules/caravan/caravan_loadout.gd").refresh(progression)
				_sync_progression_stats()
			_show_armory()
		"choose":
			if combat.buy_upgrade(id):
				expedition.caravan.capture_modules()
				preload("res://modules/caravan/caravan_loadout.gd").refresh(progression)
				sound.play_cue("evolve", true)
				_sync_progression_stats()
				if int(combat.model.player.pending_upgrades) > 0:
					_show_choices()
				else:
					_set_screen("running")

func _on_state(data: Dictionary) -> void:
	var profile_started := Profiler.begin()
	vehicle.player_stats = combat.model.player
	if is_instance_valid(sound):
		sound.engine(absf(vehicle.motion.speed) / maxf(1.0, VehicleController.Fuel.drive_tuning(vehicle.fuel, combat.model.player).maximum_speed), 1.0 if combat.model.player.nitro_timer > 0 else absf(vehicle.motion.throttle))
		if float(combat.model.player.hp) < float(combat.model.player.max_hp) * 0.3:
			sound.play_cue("lowHp")
	vehicle.get_node("VehicleView").apply_player_state(combat.model.player, int(data.get("generation", 0)))
	hud.update_run(data, camera, selected_ability)
	hud.update_telemetry({"speed": vehicle.motion.speed, "health": vehicle.health, "max_health": vehicle.max_health, "fuel": vehicle.fuel, "max_fuel": vehicle.max_fuel})
	Profiler.finish(&"hud", profile_started)

func _on_combat_event(event: Dictionary) -> void:
	# Tracer segments are presentation-only; no cargo or mission work per segment.
	if event.get("kind", "") == "bullet_segment":
		return
	if expedition != null:
		expedition.record_event(event)
		raid_loot.on_event(event)
		if event.get("kind", "") == "pickup" and event.get("pickup_kind", "") == "salvage" and not event.get("cargo_delivered", false):
			expedition.collect_loot("salvage", 1)
			hud.set_status(expedition.notice)
		if event.get("kind", "") in ["pickup", "result"]:
			_update_cargo()
	if event.get("kind", "") == "overdrive_started":
		hud.show_world_banner(ExpeditionPanel.words("ФОРСАЖ · 5 СЕКУНД", "OVERDRIVE · 5 SECONDS"), ExpeditionPanel.words("Бесплатное нитро, усиленный таран, стрельба +45%", "Free nitro, charged ram, fire rate +45%"))
		camera.add_shake(0.35)
	if event.get("kind", "") == "player_hit" and float(event.get("damage", 0.0)) > 1.0:
		camera.add_hit(clampf(float(event.damage) / 45.0, 0.2, 0.8), event.get("direction", Vector3.ZERO))
	elif event.get("kind", "") == "ability" and int(event.get("slot", -1)) in [0, 1]:
		_on_screen_impact(0.18 if int(event.slot) == 0 else 0.3)
		if int(event.slot) == 0:
			hud.show_world_banner(Locale.text("НИТРО ВКЛЮЧЕНО"), Locale.text("Давление котла сброшено"))
	if progression != null and progression_feedback.progression != null:
		progression_feedback.on_event(event)
	if str(event.get("kind", "")) == "result":
		_set_screen("result")
		_result_event = event.duplicate(true)
		_show_result()

func _toggle_sound() -> void:
	var value: bool = not sound.enabled
	sound.set_enabled(value)
	progression.set_sound_enabled(value)
	hud.set_sound_enabled(value)

func _loading_failed() -> void:
	hud.set_loading(false)
	hud.show_menu(Locale.text("ОШИБКА ЗАГРУЗКИ"), "\n".join(preparation.errors), [{"label": Locale.text("ПОВТОРИТЬ ЗАГРУЗКУ"), "action": "reload"}])

func _touch_command(command: String) -> void:
	if screen_state != "running":
		return
	match command:
		"focus":
			if camera._intro <= 0.0:
				combat.focus_next()
		"ability": combat.activate_ability(selected_ability)
		"select": selected_ability = (selected_ability + 1) % 3
		"interact":
			if not crew_runtime.interact() and not _recouple_nearest():
				world.interact()

func _select_ability(slot: int) -> void:
	if screen_state == "running" and slot in [0, 1, 2]:
		selected_ability = slot
		_on_state(combat.get_state())

func _spawn_outside_camera(point: Vector3) -> bool:
	if camera.is_position_behind(point):
		return true
	return not get_viewport().get_visible_rect().has_point(camera.unproject_position(point))

func _on_world_event(event: Dictionary) -> void:
	if event.get("kind", "") == "extraction_started":
		hud.show_world_banner(ExpeditionPanel.words("ЗАЩИЩАЙТЕ ЗОНУ", "DEFEND THE EXTRACTION ZONE"), ExpeditionPanel.words("Продержитесь 20 секунд внутри разметки", "Stay inside the marked area for 20 seconds"))
	elif event.get("kind", "") == "extraction_failed":
		hud.show_world_banner(ExpeditionPanel.words("ЭВАКУАЦИЯ ПРЕРВАНА", "EXTRACTION CANCELLED"), ExpeditionPanel.words("Вернитесь в зону и нажмите E", "Return to the zone and press E to retry"))
	if expedition != null:
		expedition.record_event(event)
		raid_loot.on_event(event)
	if is_instance_valid(combat_view) and combat_view.has_method("on_world_event"):
		combat_view.on_world_event(event)
	if event.has("case"):
		case_flow.enqueue(event)
	elif event.kind == "airdrop_claimed":
		hud.reward_notice.show_reward(event)
	if event.kind == "village_consumed":
		hud.show_world_banner("OUTPOST SCRAPPED", "Salvage scattered across the road")

func _on_screen_impact(power: float) -> void:
	if screen_state not in ["running", "death"]:
		return
	if power >= 0.45:
		session_flow.clock.request_hit_stop(power)
	camera.add_shake(power)

func _vehicle_visual_delta(raw_delta: float) -> float:
	var clock = session_flow.clock
	return clampf(raw_delta, 0.0, 0.05) * clampf(clock.simulation_delta / maxf(clock.raw_delta, 0.000001), 0.0, 1.0)

func _set_language(value: String) -> void:
	hud.set_language(value)
	_update_mission_hint()
	if expedition != null:
		_update_cargo()
	if not ready_to_drive:
		return
	if screen_state == "result":
		_show_result()
	elif screen_state == "choice":
		_show_choices()
	elif screen_state == "armory":
		_show_armory()
	elif screen_state == "menu":
		if _menu_page == "singleplayer":
			_show_singleplayer_menu()
		else:
			show_start_menu()
	elif screen_state == "options":
		_show_options(_options_return)
	elif screen_state == "expedition":
		if hideout_hub.visible:
			hideout_hub.select_tab(hideout_hub.tab)
		else:
			expedition_panel.show_state(expedition.snapshot())
	elif screen_state == "garage":
		caravan_flow.refresh()
	elif screen_state == "case_opening":
		case_flow.panel.refresh_language()
	_update_crew_hint()
	_on_state(combat.get_state())

func _show_result() -> void:
	if expedition != null and expedition.snapshot().get("pending_result", false):
		hud.show_menu(ExpeditionPanel.words("НЕ УДАЛОСЬ СОХРАНИТЬ", "SAVE FAILED"), ExpeditionPanel.words("Груз сохранён в памяти. Повторите сохранение перед выходом.", "Cargo is held in memory. Retry saving before leaving."), [{"label": ExpeditionPanel.words("ПОВТОРИТЬ СОХРАНЕНИЕ", "RETRY SAVE"), "action": "retry_save"}])
		return
	var event := _result_event
	hud.show_menu(Locale.text("ЭВАКУАЦИЯ ЗАВЕРШЕНА") if event.get("extracted", false) else Locale.text("ПОБЕДА") if event.get("won", false) else Locale.text("ЗАЕЗД ОКОНЧЕН"), (Locale.text("Волна %d · Убито %d · Время %ds") % [event.get("wave", 1), event.get("kills", 0), event.get("elapsed", 0)]) + _expedition_result_text(), [{"label": Locale.text("НОВЫЙ ЗАЕЗД"), "action": "restart"}, {"label": Locale.text("ГЛАВНОЕ МЕНЮ"), "action": "menu"}, {"label": ExpeditionPanel.words("СКЛАД И НАГРАДЫ", "VAULT AND REWARDS"), "action": "hideout"}])

func _setup_expedition_ui() -> void:
	_mission_hint = preload("res://presentation/ui/mission_hint.gd").new()
	hud._gameplay.add_child(_mission_hint)
	hud.markers.occluders.append(_mission_hint)
	expedition_panel = ExpeditionPanel.new()
	hud.get_node("Screen").add_child(expedition_panel)
	expedition_panel.action_requested.connect(_expedition_action)
	expedition_panel.closed.connect(_close_expedition)
	hideout_hub = preload("res://presentation/ui/hideout_hub.gd").new()
	hud.get_node("Screen").add_child(hideout_hub)
	hideout_hub.closed.connect(_close_expedition)
	hideout_hub.garage_requested.connect(_open_caravan)
	hideout_hub.tab_selected.connect(_select_hideout_tab)
	expedition_panel.shake_changed.connect(func(value: float) -> void:
		camera.shake_intensity = value
		progression.profile.settings["cameraShake"] = value
		progression._mark_dirty()
		progression.flush())
	camera.shake_intensity = float(progression.profile.settings.get("cameraShake", 1.0))
	expedition_panel.intensity = camera.shake_intensity
	var cargo := preload("res://presentation/ui/ui_styles.gd").button(ExpeditionPanel.words("ГРУЗ [I]", "CARGO [I]"))
	preload("res://presentation/ui/ui_icons.gd").apply(cargo, "stash")
	cargo.custom_minimum_size = Vector2(0, 28)
	hud._coins_label.get_parent().add_child(cargo)
	hud._stats_panel.offset_top -= 38
	hud._objective_label.offset_top -= 44
	hud._objective_label.offset_bottom -= 38
	cargo.pressed.connect(_open_expedition)
	_cargo_label = cargo

func _open_expedition() -> void:
	if screen_state not in ["menu", "running", "pause", "result"]:
		return
	_expedition_return = screen_state
	_expedition_return_page = _menu_page
	hud.hide_menus()
	_set_screen("expedition")
	if expedition.active:
		expedition_panel.show_state(expedition.snapshot(), "backpack")
	else:
		hideout_hub.attach(hud.armory, expedition_panel, caravan_panel)
		hideout_hub.select_tab("armory")

func _select_hideout_tab(tab: String) -> void:
	hideout_hub.update_account(expedition.snapshot())
	if tab == "armory":
		_show_armory()
	elif tab == "garage":
		caravan_flow.refresh()
	else:
		expedition_panel.show_state(expedition.snapshot(), tab)

func _close_expedition() -> void:
	if _expedition_return == "menu":
		if _expedition_return_page == "singleplayer":
			_show_singleplayer_menu()
		else:
			show_start_menu()
	elif _expedition_return == "pause":
		_set_screen("pause")
		hud.set_paused(true)
	elif _expedition_return == "result":
		_set_screen("result")
		_show_result()
	else:
		_set_screen("running")

func _expedition_action(kind: String, id: String) -> void:
	if screen_state != "expedition":
		return
	if kind == "consume":
		expedition.consume(id, combat.model.player)
		_sync_progression_stats()
	else:
		expedition.action(kind, id)
	expedition_panel.show_state(expedition.snapshot())
	if hideout_hub.visible:
		hideout_hub.update_account(expedition.snapshot())
	_update_mission_hint()
	_update_cargo()

func _update_cargo() -> void:
	if not is_instance_valid(_cargo_label):
		return
	var profile_started := Profiler.begin()
	var used: int = expedition.cargo_used()
	_cargo_label.text = ExpeditionPanel.words("ГРУЗ %d/%d [I]", "CARGO %d/%d [I]") % [used, expedition.capacity()]
	Profiler.finish(&"cargo", profile_started)

func _setup_caravan() -> void:
	caravan_flow.setup(self)
	case_flow.setup(self)

func _open_caravan() -> void:
	caravan_flow.open()

func _close_caravan() -> void:
	caravan_flow.close()

func _buy_equipment(id: String) -> bool:
	return caravan_flow.buy_equipment(id)

func _recouple_nearest() -> bool:
	return caravan_flow.recouple_nearest()

func _update_crew_hint() -> void:
	caravan_flow.update_hint()

func _expedition_result_text() -> String:
	if expedition == null or expedition.last_result.is_empty():
		return ""
	var result: Dictionary = expedition.last_result
	var text := "\n" + ExpeditionPanel.words("Опыт профиля: +%d. %s", "Account XP: +%d. %s") % [result.get("xp", 0), ExpeditionPanel.words("Добыча отправлена на склад.", "Cargo moved to your vault.") if result.get("success", false) else ExpeditionPanel.words("Груз потерян.", "Cargo lost.")]
	var convoy: Dictionary = result.get("caravan", {})
	if not convoy.is_empty():
		text += "\n" + ExpeditionPanel.words("Вернулись: прицепы %d, экипаж %d. Потеряны: прицепы %d, экипаж %d.", "Returned: %d wagons, %d crew. Lost: %d wagons, %d crew.") % [convoy.get("wagons_returned", []).size(), convoy.get("crew_returned", []).size(), convoy.get("wagons_lost", []).size(), convoy.get("crew_lost", []).size()]
	var claimable_count := 0
	for mission: Dictionary in expedition.active_missions():
		claimable_count += int(mission.get("can_claim", false))
	if claimable_count > 0:
		text += "\n" + ExpeditionPanel.words("Заберите награды за задания в убежище: %d.", "Claim mission rewards in the hideout: %d.") % claimable_count
	return text

func _request_quit() -> void:
	if expedition != null and expedition.snapshot().get("pending_result", false):
		if not expedition.action("retry_save", ""):
			_set_screen("result")
			_show_result()
			return
	if progression != null:
		progression.flush()
	get_tree().quit()

func _on_world_state(data: Dictionary) -> void:
	var points: Array = []
	if is_instance_valid(raid_loot):
		for crate: Dictionary in raid_loot.crates:
			points.append({"position": crate.position, "item": crate.item, "count": crate.count})
	data["raid_loot"] = points
	hud.update_world(data)

func _update_mission_hint() -> void:
	if expedition != null and is_instance_valid(_mission_hint):
		_mission_hint.update_missions(expedition.active_missions())

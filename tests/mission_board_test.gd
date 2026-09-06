extends SceneTree

const ExpeditionPanel = preload("res://presentation/ui/expedition_panel.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var checks := 0
var failures := 0
var actions: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	Locale.settings_path = "/private/tmp/iron-mission-board-test-%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("en")
	root.size = Vector2i(960, 600)
	root.content_scale_size = Vector2i(960, 600)
	var panel := ExpeditionPanel.new()
	root.add_child(panel)
	panel.action_requested.connect(func(kind: String, id: String) -> void: actions.append([kind, id]))
	var quests: Array = []
	for index in 120:
		quests.append({"id": "mission-%03d" % index, "name": "Миссия %d" % index, "name_en": "Mission %d" % index, "description": "Найдите груз и эвакуируйтесь.", "description_en": "Find cargo and extract.", "category": "salvage" if index % 2 == 0 else "hunting", "min_level": 1 + int(index / 10), "scope": "raid" if index % 3 == 0 else "career", "status": "available", "can_accept": true, "credits": 100, "xp": 50, "objectives": [{"metric": "kills", "target": 12, "current": 0, "raid_progress": 0}]})
	quests[0].id = "first_delivery"
	quests[110].status = "ready"
	quests[110].can_claim = true
	quests[110].conditions = [{"metric": "damage_taken", "op": "max", "value": 100, "current": 125, "met": false}]
	quests[110].delivery = {"scrap": 6}
	quests[111].status = "active"
	quests[118].status = "locked"
	quests[118].can_accept = false
	quests[119].status = "claimed"
	var state := {"active": false, "quests": quests, "quest_limit": 5}
	panel.show_state(state, "quests")
	for frame in 3:
		await process_frame
	var board = panel.mission_board
	check(board.filtered.size() == 118 and board.visible_ids.size() == 8, "Default filters include active+available only, eight rows at narrow size")
	check(board.visible_ids[0] == "mission-110" and board.visible_ids[1] == "mission-111", "Ready rewards and active tasks sort before available missions")
	check(board.visible_ids.has("first_delivery"), "Starter task remains visible on first page")
	check(board.summary.text.contains("2 / 5"), "Active count stays pinned outside the scrolled mission rows")
	check(board.scroll.get_parent() == board and board.summary.get_parent().get_parent() == board, "Search and count remain outside the scrolling content")
	_press(panel, "accept:first_delivery")
	_press(panel, "claim:mission-110")
	_press(panel, "abandon:mission-111")
	check(actions == [["accept", "first_delivery"], ["claim", "mission-110"], ["abandon", "mission-111"]], "Board forwards real accept, claim and abandon IDs through expedition panel")
	board.next.pressed.emit()
	check(board.page == 1 and board.visible_ids.size() == 8 and not board.visible_ids.has("first_delivery"), "Pagination replaces rows rather than accumulating 120 controls")
	board.search.text = "Миссия 117"
	board.search.text_changed.emit(board.search.text)
	check(board.filtered.size() == 1 and board.visible_ids == ["mission-117"] and board.page == 0, "Bilingual search finds exact mission and resets pagination")
	board.search.text = ""
	board.search.text_changed.emit("")
	board.category_filter.select(1)
	board.category_filter.item_selected.emit(1)
	check(board.filtered.all(func(row: Dictionary) -> bool: return row.category == "salvage"), "Category filter narrows missions")
	board.category_filter.select(0)
	board.category_filter.item_selected.emit(0)
	board.status_select.select(4)
	board.status_select.item_selected.emit(4)
	check(board.visible_ids == ["mission-119"], "Completed filter reveals claimed missions")
	board.status_select.select(3)
	board.status_select.item_selected.emit(3)
	board.search.text_changed.emit("Mission 118")
	check(board.visible_ids == ["mission-118"] and _button(panel, "accept:mission-118").disabled, "All filter exposes locked missions without enabling acceptance")
	board.search.text_changed.emit("Mission 110")
	state.active = true
	panel.show_state(state, "quests")
	check(_button(panel, "claim:mission-110").disabled and _button(panel, "abandon:mission-110").disabled, "Raid blocks claim and abandon actions")
	check(not _has_text(board.rows, "Not met"), "Already banked ready task does not show new raid conditions as failed")
	quests[110].status = "active"
	panel.show_state(state, "quests")
	check(_has_text(board.rows, "Not met") and _has_text(board.rows, "125"), "Active raid condition shows failure and actual current metric")
	check(_has_text(board.rows, "Hand in from vault: Scrap 0 / 6"), "Delivery requirement shows precise stash shortage")
	state.active = false
	Locale.set_language("ru")
	panel.show_state(state, "quests")
	check(board.search.placeholder_text == "Поиск по названию и описанию" and board.summary.text.begins_with("Активные"), "Open board refreshes Russian chrome without losing filters")
	check(board.visible_ids == ["mission-110"] and board.status_select.selected == 3, "Language and action refreshes preserve search and selected filters")
	await process_frame
	check(panel.get_global_rect().encloses(board.search.get_global_rect()) and panel.get_global_rect().encloses(board.status_select.get_global_rect()), "Narrow layout contains search and status control hit areas")
	board.query = ""
	board.search.text = ""
	board.category = "all"
	board.status_filter = "open"
	var owner := preload("res://modules/progression/progression.gd").new("/private/tmp/iron-mission-board-profile-%d.json" % Time.get_ticks_usec())
	var model := preload("res://modules/combat/combat_model.gd").new()
	owner.setup(model)
	var expedition := preload("res://modules/meta/expedition.gd").new(owner)
	owner.profile.expedition.xp = 1000
	check(expedition.action("accept", "freight_trial") and expedition.action("accept", "first_delivery"), "Real catalog tasks can populate board from expedition snapshot")
	expedition.action("equip", "repair_kit")
	expedition.begin_run(model.player)
	model.player.hp -= 90
	expedition.consume("repair_kit", model.player)
	expedition.collect_loot("scrap", 3)
	panel.show_state(expedition.snapshot(), "quests")
	check(_has_text(board.rows, "Не выполнено") and _has_text(board.rows, "Сейчас: 1"), "Actual consumed kit breaches catalog mission condition in snapshot")
	check(_has_text(board.rows, "+3 в рейде"), "Actual collected cargo shows pending mission objective progress")
	expedition.collect_loot("scrap", 3)
	expedition.finish_run(true)
	expedition.action("sell", "scrap")
	panel.show_state(expedition.snapshot(), "quests")
	check(_button(panel, "claim:first_delivery").disabled and _has_text(board.rows, "Металлолом 5 / 6"), "Real completed delivery with sold cargo explains disabled claim using vault shortage")
	panel.queue_free()
	await process_frame
	DirAccess.remove_absolute(Locale.settings_path)
	print("Mission board: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _button(node: Node, id: String) -> Button:
	if node is Button and node.get_meta("expedition_action", "") == id:
		return node
	for child in node.get_children():
		var found := _button(child, id)
		if found != null:
			return found
	return null

func _press(node: Node, id: String) -> void:
	var button := _button(node, id)
	check(button != null and not button.disabled, "Available action: " + id)
	if button != null and not button.disabled:
		button.pressed.emit()

func _has_text(node: Node, value: String) -> bool:
	if node is Label and node.text.contains(value):
		return true
	for child in node.get_children():
		if _has_text(child, value):
			return true
	return false

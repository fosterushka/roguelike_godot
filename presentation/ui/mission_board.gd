extends VBoxContainer

signal action_requested(kind: String, id: String)

const Styles = preload("res://presentation/ui/ui_styles.gd")
const Icons = preload("res://presentation/ui/ui_icons.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Catalog = preload("res://modules/meta/mission_catalog.gd")
const CATEGORIES := {
	"salvage": ["Сбор добычи", "Salvage"], "hunting": ["Охота", "Hunting"],
	"rescue": ["Спасение", "Rescue"], "convoy": ["Конвои", "Convoys"],
	"driving": ["Вождение", "Driving"], "arsenal": ["Арсенал", "Arsenal"],
	"exploration": ["Исследование", "Exploration"], "survival": ["Выживание", "Survival"],
	"extraction": ["Эвакуация", "Extraction"], "elite": ["Элитные", "Elite"]
}
const STATUS_FILTERS := ["open", "active", "available", "all", "completed"]
var state: Dictionary = {}
var query := ""
var category := "all"
var status_filter := "open"
var page := 0
var page_size := 10
var visible_ids: Array[String] = []
var filtered: Array[Dictionary] = []
var search: LineEdit
var category_filter: OptionButton
var status_select: OptionButton
var summary: Label
var page_label: Label
var previous: Button
var next: Button
var scroll: ScrollContainer
var rows: VBoxContainer
var _language := ""

static func words(ru: String, en: String) -> String:
	return ru if Locale.language == "ru" else en

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	var top := HBoxContainer.new()
	add_child(top)
	top.add_child(Icons.view("missions"))
	summary = Styles.label("", 15)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(summary)
	previous = Styles.button("<")
	previous.custom_minimum_size = Vector2(40, 32)
	previous.alignment = HORIZONTAL_ALIGNMENT_CENTER
	previous.pressed.connect(func() -> void: page -= 1; _update_rows())
	top.add_child(previous)
	page_label = Styles.label("", 14)
	page_label.custom_minimum_size.x = 64
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(page_label)
	next = Styles.button(">")
	next.custom_minimum_size = Vector2(40, 32)
	next.alignment = HORIZONTAL_ALIGNMENT_CENTER
	next.pressed.connect(func() -> void: page += 1; _update_rows())
	top.add_child(next)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	add_child(filters)
	search = LineEdit.new()
	search.name = "MissionSearch"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size = Vector2(120, 36)
	search.clear_button_enabled = true
	search.text_changed.connect(func(value: String) -> void: query = value; page = 0; _update_rows())
	filters.add_child(search)
	category_filter = OptionButton.new()
	category_filter.name = "MissionCategory"
	category_filter.custom_minimum_size = Vector2(180, 36)
	category_filter.item_selected.connect(func(index: int) -> void: category = str(category_filter.get_item_metadata(index)); page = 0; _update_rows())
	filters.add_child(category_filter)
	status_select = OptionButton.new()
	status_select.name = "MissionStatus"
	status_select.custom_minimum_size = Vector2(170, 36)
	status_select.item_selected.connect(func(index: int) -> void: status_filter = STATUS_FILTERS[index]; page = 0; _update_rows())
	filters.add_child(status_select)
	for control: Control in [search, category_filter, status_select]:
		control.add_theme_font_size_override("font_size", 14)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("233030")
		style.border_color = Color("64716a")
		style.set_border_width_all(1)
		style.content_margin_left = 10
		style.content_margin_right = 10
		control.add_theme_stylebox_override("normal", style)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	resized.connect(_on_resize)

func show_state(value: Dictionary) -> void:
	state = value
	_localize_filters()
	_update_rows()

func _on_resize() -> void:
	var wanted := 8 if get_viewport_rect().size.x <= 960 else 10
	if wanted != page_size and is_instance_valid(rows):
		page_size = wanted
		page = 0
		_update_rows()

func _localize_filters() -> void:
	if _language == Locale.language:
		return
	_language = Locale.language
	search.placeholder_text = words("Поиск по названию и описанию", "Search title and description")
	category_filter.clear()
	category_filter.add_item(words("Все категории", "All categories"))
	category_filter.set_item_metadata(0, "all")
	for id: String in CATEGORIES:
		category_filter.add_item(words(CATEGORIES[id][0], CATEGORIES[id][1]))
		category_filter.set_item_metadata(category_filter.item_count - 1, id)
		if category == id:
			category_filter.select(category_filter.item_count - 1)
	status_select.clear()
	for text: String in [words("Открытые", "Open"), words("Активные", "Active"), words("Доступные", "Available"), words("Все задания", "All tasks"), words("Завершённые", "Completed")]:
		status_select.add_item(text)
	status_select.select(STATUS_FILTERS.find(status_filter))

func _update_rows() -> void:
	if not is_instance_valid(rows):
		return
	filtered.clear()
	var active_count := 0
	var order := {}
	for quest: Dictionary in state.get("quests", []):
		order[str(quest.id)] = order.size()
		var status := str(quest.get("status", "available"))
		if status in ["active", "ready", "completed"]:
			active_count += 1
		if category != "all" and quest.get("category", "") != category:
			continue
		if status_filter == "open" and status not in ["available", "active", "ready", "completed"]:
			continue
		if status_filter == "active" and status not in ["active", "ready", "completed"]:
			continue
		if status_filter == "available" and status != "available":
			continue
		if status_filter == "completed" and status != "claimed":
			continue
		var text := "%s %s %s %s" % [quest.get("title", quest.get("name", "")), quest.get("name_en", ""), quest.get("description", ""), quest.get("description_en", "")]
		if not query.strip_edges().is_empty() and not text.to_lower().contains(query.strip_edges().to_lower()):
			continue
		filtered.append(quest)
	filtered.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_rank := _status_rank(str(first.get("status", "available")))
		var second_rank := _status_rank(str(second.get("status", "available")))
		if first_rank != second_rank:
			return first_rank < second_rank
		if int(first.get("min_level", 1)) != int(second.get("min_level", 1)):
			return int(first.get("min_level", 1)) < int(second.get("min_level", 1))
		return int(order[str(first.id)]) < int(order[str(second.id)]))
	var pages := maxi(1, ceili(filtered.size() / float(page_size)))
	page = clampi(page, 0, pages - 1)
	page_label.text = "%d / %d" % [page + 1, pages]
	previous.disabled = page == 0
	next.disabled = page == pages - 1
	summary.text = words("Активные: %d / %d  ·  Найдено: %d из %d", "Active: %d / %d  ·  Found: %d of %d") % [active_count, state.get("quest_limit", 5), filtered.size(), state.get("quests", []).size()]
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	visible_ids.clear()
	for index in range(page * page_size, mini(filtered.size(), (page + 1) * page_size)):
		visible_ids.append(str(filtered[index].id))
		_add_mission(filtered[index])
	if filtered.is_empty():
		rows.add_child(Styles.label(words("Заданий по этим условиям нет. Измените поиск или фильтр.", "No matching tasks. Change your search or filters."), 16))
	scroll.scroll_vertical = 0

static func _status_rank(status: String) -> int:
	return {"ready": 0, "completed": 0, "active": 1, "available": 2, "locked": 3, "claimed": 4}.get(status, 5)

func _localized(quest: Dictionary, field: String, fallback := "") -> String:
	if Locale.language == "en" and not str(quest.get(field + "_en", "")).is_empty():
		return str(quest[field + "_en"])
	return Locale.text(str(quest.get(field, fallback)))

func _text(parent: Node, text: String, font_size: int, color := Color("eee9db")) -> Label:
	var label := Styles.label(text, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _add_mission(quest: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.set_meta("mission_id", str(quest.id))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("263333")
	style.border_color = Color("64716a")
	style.border_width_bottom = 1
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	rows.add_child(panel)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	panel.add_child(line)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	line.add_child(content)
	_text(content, _localized(quest, "name", str(quest.get("title", quest.id))), 18)
	var category_name := str(quest.get("category", ""))
	if CATEGORIES.has(category_name):
		category_name = words(CATEGORIES[category_name][0], CATEGORIES[category_name][1])
	_text(content, "%s  ·  %s %d  ·  %s" % [category_name, words("Уровень", "Level"), quest.get("min_level", 1), words("За один успешный рейд", "One successful raid") if quest.get("scope", "career") == "raid" else words("За успешные рейды", "Across successful raids")], 13, Color("bccbb5"))
	_text(content, _localized(quest, "description"), 14)
	var objectives: Array = quest.get("objectives", [])
	if objectives.is_empty():
		_text(content, words("Прогресс: %d / %d", "Progress: %d / %d") % [quest.get("progress", 0), quest.get("target", 1)], 14, Color("edc575"))
	else:
		for objective: Dictionary in objectives:
			var current := float(objective.get("current", objective.get("progress", 0)))
			var pending := float(objective.get("raid_progress", 0))
			var progress := "%s: %s / %s" % [_metric(str(objective.metric)), _number(current), _number(float(objective.target))]
			if pending > 0:
				progress += words("  (+%s в рейде)", "  (+%s in raid)") % _number(pending)
			_text(content, progress, 14, Color("edc575"))
	for condition: Dictionary in quest.get("conditions", []):
		var symbol := "≥" if condition.get("op", "min") == "min" else "≤"
		var detail := "%s %s %s" % [_metric(str(condition.metric)), symbol, _number(float(condition.value))]
		var color := Color("bccbb5")
		if bool(state.get("active", false)) and quest.get("status", "") == "active":
			var met := bool(condition.get("met", false))
			detail += words(" · Сейчас: %s · %s", " · Current: %s · %s") % [_number(float(condition.get("current", 0))), words("Выполнено", "Met") if met else words("Не выполнено", "Not met")]
			color = Color("99d5af") if met else Color("efa384")
		_text(content, detail, 13, color)
	for item: String in quest.get("delivery", {}):
		var needed := int(quest.delivery[item])
		var stored := int(state.get("stash", {}).get(item, 0))
		_text(content, words("Сдать со склада: %s %d / %d", "Hand in from vault: %s %d / %d") % [_item_name(item), stored, needed], 13, Color("99d5af") if stored >= needed else Color("efa384"))
	_text(content, words("Награда: %d кредитов · %d XP", "Reward: %d credits · %d XP") % [quest.get("credits", 0), quest.get("xp", 0)], 14)
	var actions := VBoxContainer.new()
	actions.custom_minimum_size.x = 148
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(actions)
	var status := str(quest.get("status", "available"))
	var raid := bool(state.get("active", false))
	if status in ["ready", "completed"]:
		_action(actions, "claim", str(quest.id), words("ЗАБРАТЬ", "CLAIM"), raid or not bool(quest.get("can_claim", false)))
	elif status == "active":
		_text(actions, words("В РАБОТЕ", "IN PROGRESS"), 13, Color("edc575"))
	elif status == "claimed":
		_text(actions, words("ВЫПОЛНЕНО", "DONE"), 13, Color("99bfa8"))
	else:
		_action(actions, "accept", str(quest.id), words("НУЖЕН УР. %d", "NEEDS LV %d") % quest.get("min_level", 1) if status == "locked" else words("ПРИНЯТЬ", "ACCEPT"), raid or not bool(quest.get("can_accept", status == "available")))
	if status in ["active", "ready", "completed"]:
		_action(actions, "abandon", str(quest.id), words("ОТКАЗАТЬСЯ", "ABANDON"), raid)

func _action(parent: Node, kind: String, id: String, caption: String, disabled: bool) -> void:
	var button := Styles.button(caption)
	Icons.apply(button, "close" if kind == "abandon" else "stash" if kind == "claim" else "missions")
	button.custom_minimum_size = Vector2(148, 38)
	button.disabled = disabled
	button.set_meta("expedition_action", kind + ":" + id)
	button.pressed.connect(func() -> void: action_requested.emit(kind, id))
	parent.add_child(button)

func _metric(id: String) -> String:
	return Catalog.label(id, Locale.language)

static func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value

func _item_name(id: String) -> String:
	var names := {"scrap": ["Металлолом", "Scrap"], "circuit": ["Электроника", "Electronics"], "relic": ["Древний механизм", "Relic"], "repair_kit": ["Ремкомплект", "Repair kit"], "fuel_cell": ["Канистра", "Fuel cell"], "weapon_parts": ["Оружейный комплект", "Weapon kit"]}
	return words(names[id][0], names[id][1]) if names.has(id) else Locale.text(id)

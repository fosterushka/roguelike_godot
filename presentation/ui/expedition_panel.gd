extends ColorRect

signal action_requested(kind: String, id: String)
signal closed
signal shake_changed(value: float)

const Styles = preload("res://presentation/ui/ui_styles.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var tab := "stash"
var state: Dictionary = {}
var body: VBoxContainer
var heading: Label
var tabs: HBoxContainer
var notice: Label
var intensity := 1.0
var close_button: Button

static func words(ru: String, en: String) -> String:
	return ru if Locale.language == "ru" else en

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color("141f22")
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	heading = Styles.label("", 20)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	close_button = Styles.button(words("ЗАКРЫТЬ [ESC]", "CLOSE [ESC]"))
	close_button.pressed.connect(func() -> void: closed.emit())
	top.add_child(close_button)
	tabs = HBoxContainer.new()
	column.add_child(tabs)
	notice = Styles.label("", 14)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(notice)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	visible = false

func show_state(value: Dictionary, initial_tab := "") -> void:
	state = value
	if not initial_tab.is_empty():
		tab = initial_tab
	visible = true
	refresh()

func refresh() -> void:
	close_button.text = words("ЗАКРЫТЬ [ESC]", "CLOSE [ESC]")
	for parent: Node in [tabs, body]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	var raid := bool(state.get("active", false))
	heading.text = "%s  |  LV %d  |  XP %d / %d  |  %s %d" % [words("КАРАВАН / УБЕЖИЩЕ", "CARAVAN / HIDEOUT"), state.get("level", 1), state.get("xp", 0), state.get("xp_next", 100), words("КРЕДИТЫ", "CREDITS"), state.get("credits", 0)]
	var choices := {"backpack": words("ГРУЗ", "CARGO"), "quests": words("ЗАДАНИЯ", "TASKS"), "settings": words("КАМЕРА", "CAMERA")} if raid else {"stash": words("СКЛАД", "VAULT"), "loadout": words("СНАРЯЖЕНИЕ", "LOADOUT"), "trade": words("ТОРГОВЕЦ", "TRADER"), "quests": words("ЗАДАНИЯ", "TASKS"), "upgrades": words("ПРОКАЧКА", "UPGRADES"), "settings": words("КАМЕРА", "CAMERA")}
	if not choices.has(tab):
		tab = "backpack" if raid else "stash"
	for key: String in choices:
		var button := Styles.button(choices[key])
		button.custom_minimum_size.x = 112
		button.disabled = key == tab
		button.pressed.connect(func() -> void: tab = key; refresh())
		tabs.add_child(button)
	notice.text = words("Завершите 2 события, остановитесь у поселения и нажмите E. Удерживайте зону 30 секунд. Гибель и выход теряют груз.", "Complete 2 activities, stop near a settlement and press E. Secure the zone for 30 seconds. Death or abandoning loses cargo.") if raid else words("Переносите вещи со склада в снаряжение перед выездом. Кредиты торговца сохраняются между заездами.", "Move vault items to your loadout before a raid. Trader credits persist between raids.")
	if not str(state.get("notice", "")).is_empty():
		notice.text += "\n" + Locale.text(str(state.notice))
	if state.get("storage_status", "ready") in ["unsaved", "read-only-future", "unavailable"]:
		notice.text += "\n" + words("Не удалось сохранить профиль. Операция отменена.", "Profile could not be saved. Transaction cancelled.")
	match tab:
		"stash", "loadout", "backpack": _inventory(tab)
		"trade": _trade()
		"quests": _quests()
		"upgrades": _upgrades()
		"settings": _settings()

func item_name(id: String) -> String:
	var names := {"scrap": ["Лом", "Scrap"], "circuit": ["Электроника", "Electronics"], "relic": ["Артефакт", "Relic"], "repair_kit": ["Ремкомплект", "Repair kit"], "fuel_cell": ["Топливная ячейка", "Fuel cell"], "weapon_parts": ["Оружейный комплект", "Weapon kit"]}
	return words(names[id][0], names[id][1]) if names.has(id) else id

func _row(title: String, detail: String, actions: Array) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("263333")
	style.border_color = Color("64716a")
	style.border_width_bottom = 1
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	body.add_child(panel)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	panel.add_child(line)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(labels)
	labels.add_child(Styles.label(title, 18))
	var description := Styles.label(detail, 14)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(description)
	for entry: Dictionary in actions:
		var button := Styles.button(str(entry.label))
		button.custom_minimum_size = Vector2(145, 38)
		button.disabled = bool(entry.get("disabled", false))
		button.set_meta("expedition_action", entry.kind + ":" + entry.id)
		button.pressed.connect(func() -> void: action_requested.emit(entry.kind, entry.id))
		line.add_child(button)

func _inventory(container: String) -> void:
	var items: Dictionary = state.get(container, {})
	if container != "stash":
		body.add_child(Styles.label(words("Груз: %d / %d", "Cargo: %d / %d") % [state.get("used", 0) if container == "backpack" else state.get("used", 0), state.get("capacity", 12)], 18))
	if items.is_empty():
		body.add_child(Styles.label(words("Здесь пока пусто.", "Nothing here yet."), 18))
	for id: String in items:
		var definition: Dictionary = state.get("items", {}).get(id, {})
		var usable: bool = id in ["repair_kit", "fuel_cell", "weapon_parts"]
		var actions: Array = []
		if container == "stash" and usable:
			actions.append({"kind": "equip", "id": id, "label": words("ВЗЯТЬ В РЕЙД", "PACK FOR RAID")})
		elif container == "loadout":
			actions.append({"kind": "unequip", "id": id, "label": words("НА СКЛАД", "TO VAULT")})
		elif container == "backpack":
			if usable:
				actions.append({"kind": "consume", "id": id, "label": words("ПРИМЕНИТЬ", "USE")})
			actions.append({"kind": "discard", "id": id, "label": words("ВЫБРОСИТЬ 1", "DISCARD 1")})
		_row("%s × %d" % [item_name(id), items[id]], Locale.text(str(definition.get("description", ""))), actions)

func _trade() -> void:
	for id: String in state.get("items", {}):
		var item: Dictionary = state.items[id]
		var buy := int(item.get("buy", item.get("buy_price", 0)))
		var sell := int(item.get("sell", item.get("sell_price", 0)))
		var actions: Array = []
		if buy > 0:
			actions.append({"kind": "buy", "id": id, "label": words("КУПИТЬ %d", "BUY %d") % buy, "disabled": int(state.credits) < buy})
		actions.append({"kind": "sell", "id": id, "label": words("ПРОДАТЬ %d", "SELL %d") % sell, "disabled": int(state.get("stash", {}).get(id, 0)) == 0})
		_row(item_name(id), (words("На складе: %d", "In vault: %d") % state.get("stash", {}).get(id, 0)) + "\n" + Locale.text(str(item.get("description", ""))), actions)

func _quests() -> void:
	for quest: Dictionary in state.get("quests", []):
		var status := str(quest.get("status", "available"))
		var kind := "claim" if status in ["ready", "completed"] else "accept"
		_row(Locale.text(str(quest.get("title", quest.id))), "%s\n%d / %d  |  %s" % [Locale.text(str(quest.get("description", ""))), int(quest.get("progress", 0)) + int(quest.get("raid_progress", 0)), quest.get("target", 1), words("%d кредитов · %d XP", "%d credits · %d XP") % [quest.get("credits", 0), quest.get("xp", 0)]], [{"kind": kind, "id": str(quest.id), "label": words("ВЫПОЛНЕНО", "DONE") if status == "claimed" else words("В РАБОТЕ", "IN PROGRESS") if status == "active" else words("ЗАБРАТЬ", "CLAIM") if kind == "claim" else words("ПРИНЯТЬ", "ACCEPT"), "disabled": bool(state.get("active", false)) or (not bool(quest.get("can_claim", false)) if kind == "claim" else status != "available")}])

func _upgrades() -> void:
	for upgrade: Dictionary in state.get("upgrades", []):
		_row(Locale.text(str(upgrade.get("title", upgrade.id))), "%s\nLV %d  |  %s" % [Locale.text(str(upgrade.get("description", ""))), upgrade.get("level", 0), words("%d кредитов · уровень профиля %d", "%d credits · account level %d") % [upgrade.get("cost", 0), upgrade.get("required_level", 1)]], [{"kind": "upgrade", "id": str(upgrade.id), "label": words("УЛУЧШИТЬ", "UPGRADE"), "disabled": not bool(upgrade.get("enabled", true))}])

func _settings() -> void:
	body.add_child(Styles.label(words("Сила тряски камеры", "Camera shake intensity"), 20))
	var slider := HSlider.new()
	slider.max_value = 1.5
	slider.step = 0.1
	slider.value = intensity
	slider.custom_minimum_size = Vector2(300, 40)
	body.add_child(slider)
	var amount := Styles.label("%d%%" % roundi(intensity * 100.0), 18)
	body.add_child(amount)
	slider.value_changed.connect(func(value: float) -> void: intensity = value; amount.text = "%d%%" % roundi(value * 100.0); shake_changed.emit(value))

func _units(items: Dictionary) -> int:
	var total := 0
	for count: int in items.values():
		total += count
	return total

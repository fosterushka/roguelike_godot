extends ColorRect

signal action_requested(kind: String, id: String)
signal closed
signal shake_changed(value: float)

const Styles = preload("res://presentation/ui/ui_styles.gd")
const Icons = preload("res://presentation/ui/ui_icons.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const ModelPreview = preload("res://presentation/ui/item_model_preview.gd")
const PreviewPip = preload("res://presentation/ui/item_preview_pip.gd")
var tab := "stash"
var state: Dictionary = {}
var body: VBoxContainer
var heading: Label
var tabs: HBoxContainer
var notice: Label
var intensity := 1.0
var close_button: Button
var _top: HBoxContainer
var _margin: MarginContainer
var _embedded := false
var _scroll: ScrollContainer
var _rendered_tab := ""
var mission_board: VBoxContainer
var item_preview_pip
var _trader_id := "mechanic"

static func words(ru: String, en: String) -> String:
	return ru if Locale.language == "ru" else en

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color("141f22")
	var margin := MarginContainer.new()
	_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	item_preview_pip = PreviewPip.new()
	add_child(item_preview_pip)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var top := HBoxContainer.new()
	_top = top
	column.add_child(top)
	heading = Styles.label("", 20)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	close_button = Styles.button(words("ЗАКРЫТЬ [ESC]", "CLOSE [ESC]"))
	Icons.apply(close_button, "close")
	close_button.pressed.connect(func() -> void: closed.emit())
	top.add_child(close_button)
	tabs = HBoxContainer.new()
	column.add_child(tabs)
	notice = Styles.label("", 14)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(notice)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)
	scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: item_preview_pip.hide_preview())
	mission_board = preload("res://presentation/ui/mission_board.gd").new()
	mission_board.action_requested.connect(func(kind: String, id: String) -> void: action_requested.emit(kind, id))
	column.add_child(mission_board)
	mission_board.visible = false
	visible = false

func set_embedded(value: bool) -> void:
	_embedded = value
	if not is_node_ready():
		return
	_top.visible = not value
	tabs.visible = not value
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 0 if value else 14)

func show_state(value: Dictionary, initial_tab := "") -> void:
	state = value
	if not initial_tab.is_empty():
		tab = initial_tab
	visible = true
	refresh()

func refresh() -> void:
	if item_preview_pip:
		item_preview_pip.hide_preview()
	set_embedded(_embedded)
	if tab != _rendered_tab:
		_scroll.scroll_vertical = 0
		_rendered_tab = tab
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
		button.custom_minimum_size.x = 90
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("expedition_tab", key)
		Icons.apply(button, _tab_icon(key))
		button.disabled = key == tab
		if button.disabled:
			button.add_theme_color_override("font_disabled_color", Color("f0eada"))
		button.pressed.connect(func() -> void: tab = key; refresh())
		tabs.add_child(button)
	notice.text = words("Въезжайте в отмеченную зону эвакуации и нажмите E. Защищайтесь внутри 20 секунд. Гибель и выход теряют груз.", "Drive into a marked extraction zone and press E. Defend inside for 20 seconds. Death or abandoning loses cargo.") if raid else words("Хранилище: всё сохранённое. Запас: вещи для следующего рейда.", "Vault stores your loot. Stash holds supplies packed for the next raid.")
	if tab == "trade":
		notice.text = words("Покупка и продажа по 1 предмету. Покупки поступают в хранилище.", "Buy or sell one item at a time. Purchases go to your vault.")
	elif tab == "loadout":
		notice.text = words("Этот запас отправится с вами в следующий рейд. Пополняйте его из хранилища.", "These supplies travel with you next raid. Pack more from the Vault tab.")
	elif tab == "quests":
		notice.text = words("Эвакуируйтесь или одержите финальную победу, чтобы сохранить прогресс. Одновременно до 5 заданий.", "Extract or win the final battle to save progress. Track up to 5 tasks at once.")
	if not str(state.get("notice", "")).is_empty():
		notice.text += "\n" + Locale.text(str(state.notice))
	if state.get("storage_status", "ready") in ["unsaved", "read-only-future", "unavailable"]:
		notice.text += "\n" + words("Не удалось сохранить профиль. Операция отменена.", "Profile could not be saved. Transaction cancelled.")
	body.get_parent().visible = tab != "quests"
	mission_board.visible = tab == "quests"
	match tab:
		"stash", "loadout", "backpack": _inventory(tab)
		"trade": _trade()
		"quests": _quests()
		"upgrades": _upgrades()
		"settings": _settings()

func item_name(id: String) -> String:
	return preload("res://modules/meta/expedition_catalog.gd").item_name(id, Locale.language)

func _row(title: String, detail: String, actions: Array, icon_key: String = "stash", model_kind := "", model_id := "") -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("263333")
	style.border_color = Color("64716a")
	style.border_width_bottom = 1
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(panel)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)
	if not model_id.is_empty():
		var model_preview := ModelPreview.new()
		model_preview.name = "ModelThumbnail"
		model_preview.custom_minimum_size = Vector2(62, 48)
		model_preview.set_preview(model_kind, model_id)
		line.add_child(model_preview)
		model_preview.mouse_filter = Control.MOUSE_FILTER_STOP
		model_preview.focus_mode = Control.FOCUS_ALL
		model_preview.mouse_entered.connect(func() -> void: item_preview_pip.show_for(model_preview, model_kind, model_id, title))
		model_preview.mouse_exited.connect(item_preview_pip.hide_preview)
		model_preview.focus_entered.connect(func() -> void: item_preview_pip.show_for(model_preview, model_kind, model_id, title))
		model_preview.focus_exited.connect(item_preview_pip.hide_preview)
		panel.mouse_entered.connect(func() -> void: item_preview_pip.show_for(panel, model_kind, model_id, title))
		panel.mouse_exited.connect(item_preview_pip.hide_preview)
	else:
		line.add_child(Icons.view(icon_key, 26))
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(labels)
	var title_label := Styles.label(title, 16)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(title_label)
	var description := Styles.label(detail, 14)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(description)
	for entry: Dictionary in actions:
		var button := Styles.button(str(entry.label))
		button.custom_minimum_size = Vector2(145, 34)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		Icons.apply(button, str(entry.get("icon", "trade" if entry.kind in ["buy", "sell"] else icon_key)), 18)
		button.disabled = bool(entry.get("disabled", false))
		button.set_meta("expedition_action", entry.kind + ":" + entry.id)
		button.pressed.connect(func() -> void: action_requested.emit(entry.kind, entry.id))
		if not model_id.is_empty():
			button.focus_entered.connect(func() -> void: item_preview_pip.show_for(button, model_kind, model_id, title))
			button.focus_exited.connect(item_preview_pip.hide_preview)
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
			actions.append({"kind": "equip", "id": id, "label": words("ВЗЯТЬ", "PACK")})
		elif container == "loadout":
			actions.append({"kind": "unequip", "id": id, "label": words("В ХРАНИЛИЩЕ", "TO VAULT")})
		elif container == "backpack":
			if usable:
				actions.append({"kind": "consume", "id": id, "label": words("ПРИМЕНИТЬ", "USE")})
			actions.append({"kind": "discard", "id": id, "label": words("ВЫБРОСИТЬ 1", "DISCARD 1")})
		_row("%s × %d" % [item_name(id), items[id]], Locale.text(str(definition.get("description", ""))), actions, _item_icon(id), "loot", id)

func _trade() -> void:
	_trade_selector()
	for id: String in state.get("items", {}):
		if _trader_for(id) != _trader_id:
			continue
		var item: Dictionary = state.items[id]
		var buy := int(item.get("buy", item.get("buy_price", 0)))
		var sell := int(item.get("sell", item.get("sell_price", 0)))
		var actions: Array = []
		if buy > 0:
			actions.append({"kind": "buy", "id": id, "label": words("КУПИТЬ %d", "BUY %d") % buy, "disabled": int(state.credits) < buy})
		actions.append({"kind": "sell", "id": id, "label": words("ПРОДАТЬ %d", "SELL %d") % sell, "disabled": int(state.get("stash", {}).get(id, 0)) == 0})
		_row(item_name(id) + " · " + (words("На складе: %d", "In vault: %d") % state.get("stash", {}).get(id, 0)), Locale.text(str(item.get("description", ""))), actions, _item_icon(id), "loot", id)

func _trade_selector() -> void:
	var selector := HBoxContainer.new()
	selector.add_theme_constant_override("separation", 8)
	body.add_child(selector)
	for trader: Dictionary in [
		{"id": "mechanic", "label": words("МЕХАНИК", "MECHANIC"), "detail": words("Ремонт и топливо", "Repair and fuel"), "portrait": "res://assets/ui/traders/mechanic.png"},
		{"id": "quartermaster", "label": words("ИНТЕНДАНТ", "QUARTERMASTER"), "detail": words("Склад и электроника", "Stores and electronics"), "portrait": "res://assets/ui/traders/quartermaster.png"},
		{"id": "scavenger", "label": words("СТАЛКЕР", "SCAVENGER"), "detail": words("Редкая добыча", "Rare salvage"), "portrait": "res://assets/ui/traders/scavenger.png"}
	]:
		var button := Styles.button("")
		button.set_meta("trader_id", str(trader.id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 120)
		button.tooltip_text = str(trader.detail)
		button.disabled = _trader_id == str(trader.id)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		var portrait := TextureRect.new()
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.custom_minimum_size = Vector2(80, 106)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path := str(trader.portrait)
		if ResourceLoader.exists(path):
			portrait.texture = load(path)
		else:
			portrait.modulate = Color("7c887c")
		row.add_child(portrait)
		var words_column := VBoxContainer.new()
		words_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words_column.add_child(Styles.label(str(trader.label), 13))
		words_column.add_child(Styles.label(str(trader.detail), 11))
		if _trader_id == str(trader.id):
			button.custom_minimum_size = Vector2(0, 154)
			portrait.custom_minimum_size = Vector2(112, 140)
			words_column.add_child(Styles.label(words("ВЫБРАН", "SELECTED"), 11))
		row.add_child(words_column)
		button.pressed.connect(func() -> void: _trader_id = str(trader.id); item_preview_pip.hide_preview(); refresh())
		selector.add_child(button)

func _trader_for(id: String) -> String:
	if id in ["repair_kit", "fuel_cell"]:
		return "mechanic"
	if id in ["scrap", "circuit"]:
		return "quartermaster"
	return "scavenger"

func _quests() -> void:
	mission_board.show_state(state)

func _upgrades() -> void:
	for upgrade: Dictionary in state.get("upgrades", []):
		_row(Locale.text(str(upgrade.get("title", upgrade.id))), "%s\nLV %d  |  %s" % [Locale.text(str(upgrade.get("description", ""))), upgrade.get("level", 0), words("%d кредитов · уровень профиля %d", "%d credits · account level %d") % [upgrade.get("cost", 0), upgrade.get("required_level", 1)]], [{"kind": "upgrade", "id": str(upgrade.id), "label": words("УЛУЧШИТЬ", "UPGRADE"), "disabled": not bool(upgrade.get("enabled", true))}], "base")

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

func _tab_icon(key: String) -> String:
	return {"stash": "vault", "loadout": "stash", "backpack": "stash", "quests": "missions", "upgrades": "base", "settings": "settings", "trade": "trade"}.get(key, "stash")

func _item_icon(id: String) -> String:
	return {"scrap": "scrap", "circuit": "settings", "relic": "vault", "repair_kit": "repair", "fuel_cell": "fuel", "weapon_parts": "ammo"}.get(id, "stash")

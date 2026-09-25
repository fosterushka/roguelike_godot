extends ColorRect

const Fieldwork = preload("res://presentation/ui/fieldwork_tokens.gd")

signal tab_selected(tab: String)
signal closed
signal garage_requested
signal deploy_requested
var deploy_button: Button
var footer_hint: Label

const Styles = preload("res://presentation/ui/ui_styles.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Icons = preload("res://presentation/ui/ui_icons.gd")
const TABS = {
	"armory": ["Оружейная", "Armory", "armory"],
	"garage": ["Гараж", "Garage", "base"],
	"loadout": ["Припасы", "Raid supplies", "stash"],
	"stash": ["Запасы", "Supplies", "vault"],
	"trade": ["Торговля", "Trade", "trade"],
	"upgrades": ["База", "Base", "base"],
	"quests": ["Задания", "Tasks", "missions"],
	"settings": ["Настройки", "Settings", "settings"],
}
const SECTIONS = {
	"caravan": ["Караван", "Caravan", "car", "armory"],
	"supplies": ["Запасы", "Supplies", "box", "stash"],
	"trade": ["Торговля", "Trade", "trade", "trade"],
	"quests": ["Задания", "Tasks", "missions", "quests"],
	"upgrades": ["База", "Base", "base", "upgrades"],
	"settings": ["Настройки", "Settings", "settings", "settings"],
}
var _rail_surface: PanelContainer
var _body_margin: MarginContainer
var _header_margin: MarginContainer
var _footer_margin: MarginContainer
var _title_margin: MarginContainer
var _page_title: Label
var _page_subtitle: Label
var _section_caption: Label
var _scrap_label: Label
var _level_label: Label
var _upgrade_scrap := 0
var _rail: VBoxContainer
var _last_caravan := "armory"
var caravan_page := "wagons"
var tab := "armory"
var previous_tab := "armory"
var tabs: HBoxContainer
var content: Control
var heading: Label
var close_button: Button
var garage_button: Button
var resources: Label
var _account: Dictionary = {}
var _armory: Control
var _garage: Control
var _expedition: Control
var _original_parent: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Fieldwork.BG
	var shell := HBoxContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 0)
	add_child(shell)
	_rail_surface = PanelContainer.new()
	var rail_style := StyleBoxFlat.new()
	rail_style.bg_color = Fieldwork.NAV
	rail_style.border_color = Fieldwork.LINE
	rail_style.border_width_right = 1
	rail_style.content_margin_left = 10
	rail_style.content_margin_right = 10
	rail_style.content_margin_top = 10
	rail_style.content_margin_bottom = 20
	_rail_surface.add_theme_stylebox_override("panel", rail_style)
	shell.add_child(_rail_surface)
	_rail = VBoxContainer.new()
	_rail.add_theme_constant_override("separation", 8)
	_rail_surface.add_child(_rail)
	var logo := HBoxContainer.new()
	logo.custom_minimum_size.y = 68
	logo.add_theme_constant_override("separation", 10)
	_rail.add_child(logo)
	var logo_margin := Control.new()
	logo_margin.custom_minimum_size.x = 2
	logo.add_child(logo_margin)
	var emblem := Icons.view("car", 24)
	emblem.modulate = Fieldwork.ACCENT
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.add_child(emblem)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.add_child(brand)
	brand.add_child(Styles.label("IRON", 16))
	var brand_detail := Styles.label("CARAVAN", 10)
	Styles.muted(brand_detail)
	brand.add_child(brand_detail)
	_section_caption = Styles.label("", 11)
	_section_caption.custom_minimum_size.y = 18
	Styles.muted(_section_caption)
	_rail.add_child(_section_caption)
	for key: String in SECTIONS:
		if key == "settings":
			var spacer := Control.new()
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_rail.add_child(spacer)
		var button := Styles.button("")
		button.custom_minimum_size = Vector2(0, 38)
		button.set_meta("section", key)
		Icons.apply(button, SECTIONS[key][2], 20)
		button.pressed.connect(func() -> void: select_tab(_last_caravan if key == "caravan" else SECTIONS[key][3]))
		_rail.add_child(button)
	close_button = Styles.button("")
	close_button.custom_minimum_size = Vector2(0, 38)
	Icons.apply(close_button, "exit", 20)
	Styles.navigation(close_button, false)
	close_button.pressed.connect(func() -> void: closed.emit())
	_rail.add_child(close_button)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	shell.add_child(column)
	_header_margin = MarginContainer.new()
	column.add_child(_header_margin)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_header_margin.add_child(header)
	heading = Styles.label("", 13)
	Styles.muted(heading)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var coin := Icons.view("coin", 20)
	coin.modulate = Fieldwork.ACCENT
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(coin)
	resources = Styles.label("", 14)
	resources.custom_minimum_size.x = 58
	header.add_child(resources)
	var scrap := Icons.view("scrap", 20)
	scrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(scrap)
	_scrap_label = Styles.label("", 14)
	_scrap_label.custom_minimum_size.x = 42
	header.add_child(_scrap_label)
	_level_label = Styles.label("", 12)
	_level_label.custom_minimum_size.x = 104
	Styles.muted(_level_label)
	header.add_child(_level_label)
	column.add_child(HSeparator.new())
	_body_margin = MarginContainer.new()
	_body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body_margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	_body_margin.add_child(body)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	for key: String in TABS:
		var button := Styles.button("")
		button.set_meta("hub_tab", key)
		button.custom_minimum_size = Vector2(116, 32)
		button.pressed.connect(func() -> void:
			if key == "garage": caravan_page = "wagons"
			select_tab(key))
		tabs.add_child(button)
		if key == "garage":
			garage_button = button
			button.set_meta("hub_action", "garage")
	for page: String in ["wagons", "crew"]:
		var button := Styles.button("")
		button.set_meta("caravan_page", page)
		button.custom_minimum_size = Vector2(116, 32)
		button.pressed.connect(func() -> void: caravan_page = page; select_tab("garage"))
		tabs.add_child(button)
		if page == "wagons": tabs.move_child(button, 0)
	_title_margin = MarginContainer.new()
	body.add_child(_title_margin)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 4)
	_title_margin.add_child(titles)
	_page_title = Styles.label("", 28)
	titles.add_child(_page_title)
	_page_subtitle = Styles.label("", 13)
	Styles.muted(_page_subtitle)
	_page_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_page_subtitle)
	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	column.add_child(HSeparator.new())
	_footer_margin = MarginContainer.new()
	_footer_margin.custom_minimum_size.y = 55
	column.add_child(_footer_margin)
	var footer := HBoxContainer.new()
	_footer_margin.add_child(footer)
	footer_hint = Styles.label("", 12)
	Styles.muted(footer_hint)
	footer_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_hint)
	deploy_button = Styles.button("")
	deploy_button.custom_minimum_size = Vector2(167, 36)
	Icons.apply(deploy_button, "arrow", 18)
	deploy_button.pressed.connect(func() -> void: deploy_requested.emit())
	footer.add_child(deploy_button)
	resized.connect(_fit)
	_fit()
	refresh_labels()
	visible = false

func _fit() -> void:
	if not _rail_surface:
		return
	var compact := size.x < Fieldwork.COMPACT_BREAKPOINT
	_rail_surface.custom_minimum_size.x = Fieldwork.COMPACT_RAIL_WIDTH if compact else Fieldwork.RAIL_WIDTH
	var padding := 16 if compact else 24
	for margins: MarginContainer in [_header_margin, _body_margin, _footer_margin]:
		margins.add_theme_constant_override("margin_left", padding)
		margins.add_theme_constant_override("margin_right", padding)
	_header_margin.custom_minimum_size.y = 55 if compact else 63
	_header_margin.add_theme_constant_override("margin_top", 16)
	_header_margin.add_theme_constant_override("margin_bottom", 16)
	_body_margin.add_theme_constant_override("margin_top", 20)
	_body_margin.add_theme_constant_override("margin_bottom", 16)
	_footer_margin.add_theme_constant_override("margin_top", 10)
	_footer_margin.add_theme_constant_override("margin_bottom", 9)
	_page_title.add_theme_font_size_override("font_size", 25 if compact else 28)
	for button: Button in tabs.get_children():
		button.custom_minimum_size.x = 104 if compact else 116

func attach(armory: Control, expedition: Control, garage: Control = null) -> void:
	if _armory != null:
		return
	_original_parent = armory.get_parent()
	_armory = armory
	_expedition = expedition
	_garage = garage
	var panels: Array = [_armory, _expedition]
	if _garage != null:
		panels.append(_garage)
	for panel: Control in panels:
		panel.reparent(content, false)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.set_embedded(true)
	visible = true

func detach() -> void:
	if _armory == null:
		visible = false
		return
	_armory.hide_panel()
	var panels: Array = [_armory, _expedition]
	if _garage != null:
		panels.append(_garage)
	for panel: Control in panels:
		panel.set_embedded(false)
		panel.reparent(_original_parent, false)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.visible = false
	_armory = null
	_expedition = null
	_garage = null
	visible = false

func select_tab(value: String) -> void:
	if not TABS.has(value):
		return
	if tab != "settings":
		previous_tab = tab
	tab = value
	refresh_labels()
	if _armory != null:
		_armory.hide_panel()
		_expedition.visible = false
		if _garage != null:
			_garage.visible = false
	tab_selected.emit(tab)

func refresh_labels() -> void:
	var russian := Locale.language == "ru"
	var section := "caravan" if tab in ["armory", "garage"] else "supplies" if tab in ["stash", "loadout"] else tab
	if section == "caravan":
		_last_caravan = tab
	heading.text = ("Убежище / " if russian else "Hideout / ") + SECTIONS[section][0 if russian else 1]
	close_button.text = "В меню" if russian else "Menu"
	_section_caption.text = "УБЕЖИЩЕ" if russian else "HIDEOUT"
	_page_title.text = TABS[tab][0 if russian else 1]
	if tab == "garage":
		_page_title.text = ("Готовность каравана" if russian else "Caravan readiness") if caravan_page == "wagons" else ("Экипаж" if russian else "Crew") if caravan_page == "crew" else ("Гараж" if russian else "Garage")
	_page_subtitle.text = ("Выберите крепление, затем оружие. Изменения видны до установки." if russian else "Choose a mount, then a weapon. Review changes before installing.") if tab == "armory" else ("Подготовьте караван к следующему выезду." if russian else "Prepare your caravan for the next raid.")
	_page_subtitle.visible = tab != "garage"
	_title_margin.add_theme_constant_override("margin_top", 6 if section == "caravan" else 0)
	footer_hint.text = "Esc · Назад" if russian else "Esc · Back"
	deploy_button.text = "В рейд" if russian else "Deploy"
	Styles.selected(deploy_button, false)
	if tab != "armory":
		Styles.primary(deploy_button)
	update_account(_account)
	for button: Button in tabs.get_children():
		if button.has_meta("caravan_page"):
			var page: String = button.get_meta("caravan_page")
			button.text = ("Обзор" if russian else "Overview") if page == "wagons" else ("Экипаж" if russian else "Crew")
			button.visible = section == "caravan" and page != "wagons"
			Styles.tab(button, tab == "garage" and caravan_page == page)
			continue
		var key: String = button.get_meta("hub_tab")
		button.text = TABS[key][0 if russian else 1]
		button.visible = section == "caravan" and key in ["armory", "garage"]
		Styles.tab(button, key == tab)
	tabs.visible = section == "caravan"
	for node: Node in _rail.get_children():
		if node.has_meta("section"):
			var key: String = node.get_meta("section")
			node.text = SECTIONS[key][0 if russian else 1]
			Styles.navigation(node, key == section)

func update_account(state: Dictionary, upgrade_scrap: int = -1) -> void:
	if upgrade_scrap >= 0:
		_upgrade_scrap = upgrade_scrap
	_account = state
	resources.text = str(state.get("credits", 0))
	_scrap_label.text = str(_upgrade_scrap)
	_level_label.text = ("Уровень %d" if Locale.language == "ru" else "Level %d") % state.get("level", 1)

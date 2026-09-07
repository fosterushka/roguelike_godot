extends ColorRect

signal tab_selected(tab: String)
signal closed
signal garage_requested

const Styles = preload("res://presentation/ui/ui_styles.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Icons = preload("res://presentation/ui/ui_icons.gd")
const TABS = {
	"armory": ["АРСЕНАЛ", "ARMORY", "armory"],
	"garage": ["ГАРАЖ", "GARAGE", "base"],
	"loadout": ["СНАРЯЖЕНИЕ", "STASH", "stash"],
	"stash": ["ХРАНИЛИЩЕ", "VAULT", "vault"],
	"trade": ["ТОРГОВЛЯ", "TRADE", "trade"],
	"upgrades": ["БАЗА", "BASE", "base"],
	"quests": ["ЗАДАНИЯ", "TASKS", "missions"],
	"settings": ["НАСТРОЙКИ", "SETTINGS", "settings"],
}
var tab := "armory"
var tabs: HFlowContainer
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
	color = Color("111b20")
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	heading = Styles.label("", 20)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(Icons.view("trade", 20))
	resources = Styles.label("", 14)
	resources.add_theme_color_override("font_color", Color("f4d89d"))
	header.add_child(resources)
	close_button = Styles.button("")
	Icons.apply(close_button, "close")
	close_button.pressed.connect(func() -> void: closed.emit())
	header.add_child(close_button)
	tabs = HFlowContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	for key: String in TABS:
		var button := Styles.button("")
		button.set_meta("hub_tab", key)
		button.custom_minimum_size = Vector2(82, 32)
		button.add_theme_font_size_override("font_size", 12)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Icons.apply(button, TABS[key][2], 18)
		button.add_theme_constant_override("h_separation", 4)
		button.pressed.connect(func() -> void: select_tab(key))
		tabs.add_child(button)
		if key == "garage":
			garage_button = button
			button.set_meta("hub_action", "garage")
	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	visible = false

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
	heading.text = "УБЕЖИЩЕ" if russian else "HIDEOUT"
	close_button.text = "НАЗАД [ESC]" if russian else "BACK [ESC]"
	garage_button.text = "ГАРАЖ" if russian else "GARAGE"
	update_account(_account)
	for button: Button in tabs.get_children():
		var key: String = button.get_meta("hub_tab")
		button.text = TABS[key][0 if russian else 1]
		button.disabled = false
		var style: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate()
		style.border_width_bottom = 3 if key == tab else 1
		style.border_color = Color("e7b85c") if key == tab else Color("42525a")
		style.bg_color = Color("344038") if key == tab else Color("17252c")
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_color_override("font_color", Color("f4d89d") if key == tab else Color("e2e7e8"))

func update_account(state: Dictionary) -> void:
	_account = state
	resources.text = ("КРЕДИТЫ %d · УР %d" if Locale.language == "ru" else "CREDITS %d · LV %d") % [state.get("credits", 0), state.get("level", 1)]

extends ColorRect

const Locale = preload("res://presentation/ui/ui_locale.gd")

signal action_requested(action: String, id: String)
const Styles = preload("res://presentation/ui/ui_styles.gd")
const Preview = preload("res://presentation/ui/armory_preview.gd")
const MountSelector = preload("res://presentation/ui/mount_selector.gd")
var preview: SubViewportContainer
var query: LineEdit
var filter: OptionButton
var cards: GridContainer
var details: Label
var summary: Label
var save_status: Label
var close_button: Button
var _shop: Dictionary = {}
var _player: Dictionary = {}
var _catalog: Dictionary = {}
var _selected := ""
var _body: HBoxContainer
var _core_summary: Label
var _protocol_summary: Label
var _sidebar: VBoxContainer
var mount_selector: HBoxContainer
var _tile_panels: Dictionary = {}
var _catalog_scroll: ScrollContainer
var reset_view_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.015, 0.02, 0.016, 0.94)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_catalogs.json"))
	_catalog = parsed if parsed is Dictionary else {}
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Styles.label(Locale.text("АРСЕНАЛ"), 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = Styles.button(Locale.text("ПРОДОЛЖИТЬ [ESC]"))
	close_button.pressed.connect(func() -> void: action_requested.emit("resume", ""))
	header.add_child(close_button)
	summary = Styles.label("")
	column.add_child(summary)
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 16)
	column.add_child(_body)
	_sidebar = VBoxContainer.new()
	_sidebar.custom_minimum_size.x = 380
	_sidebar.add_theme_constant_override("separation", 8)
	_body.add_child(_sidebar)
	preview = Preview.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sidebar.add_child(preview)
	var preview_tools := HBoxContainer.new()
	_sidebar.add_child(preview_tools)
	var inspect_hint := Styles.label(Locale.text("Тяните: вращение · Колесо: масштаб"), 11)
	inspect_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_tools.add_child(inspect_hint)
	reset_view_button = Styles.button(Locale.text("Сброс вида"))
	reset_view_button.custom_minimum_size = Vector2(86, 28)
	reset_view_button.add_theme_font_size_override("font_size", 11)
	reset_view_button.pressed.connect(preview.reset_view)
	preview_tools.add_child(reset_view_button)
	mount_selector = MountSelector.new()
	_sidebar.add_child(mount_selector)
	mount_selector.target_changed.connect(_mount_changed)
	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.custom_minimum_size.y = 120
	_sidebar.add_child(sidebar_scroll)
	var sidebar_text := VBoxContainer.new()
	sidebar_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_scroll.add_child(sidebar_text)
	_core_summary = Styles.label("", 12)
	sidebar_text.add_child(_core_summary)
	_protocol_summary = Styles.label("", 12)
	_protocol_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar_text.add_child(_protocol_summary)
	details = Styles.label("", 12)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x = 300
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_text.add_child(details)
	var catalog_column := VBoxContainer.new()
	catalog_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(catalog_column)
	query = LineEdit.new()
	query.placeholder_text = Locale.text("Поиск по названию или описанию")
	query.custom_minimum_size.y = 38
	query.text_changed.connect(func(_text: String) -> void: rebuild_cards())
	catalog_column.add_child(query)
	filter = OptionButton.new()
	for caption in [Locale.text("Все системы"), Locale.text("Оружие"), Locale.text("Поддержка"), Locale.text("Установлено")]:
		filter.add_item(caption)
	filter.item_selected.connect(func(_index: int) -> void: rebuild_cards())
	catalog_column.add_child(filter)
	_catalog_scroll = ScrollContainer.new()
	_catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalog_column.add_child(_catalog_scroll)
	_catalog_scroll.resized.connect(_layout)
	cards = GridContainer.new()
	cards.columns = 2
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	_catalog_scroll.add_child(cards)
	save_status = Styles.label("", 12)
	column.add_child(save_status)
	resized.connect(_layout)
	visible = false

func display(shop: Dictionary, player: Dictionary) -> void:
	var was_visible := visible
	_shop = shop
	_player = player
	_core_summary.text = Locale.text("ДВИГАТЕЛЬ %d/5 · БРОНЯ %d/5 · БАК %d/5\nКОРПУС %d · ТОПЛИВО %d") % [player.core_upgrades.motor, player.core_upgrades.armor, player.core_upgrades.fuel, player.max_hp, player.max_fuel]
	var protocols: Array[String] = []
	for row: Dictionary in shop.protocols:
		var id := str(row.id).get_slice(":", 1)
		if not player.get("protocols", []).has(id):
			continue
		var requirements: Array[String] = []
		for requirement: Dictionary in _catalog.protocols.get(id, {}).get("requirements", []):
			requirements.append(Locale.text(str(requirement.get("label", ""))))
		protocols.append("%s · %s\n%s" % [Locale.text(str(row.label)), Locale.text("АКТИВЕН") if player.active_protocols.has(id) else Locale.text("НЕТ НУЖНЫХ МОДУЛЕЙ"), " + ".join(requirements)])
	_protocol_summary.text = "\n".join(protocols)
	_protocol_summary.visible = not protocols.is_empty()
	summary.text = Locale.text("ЛОМ %d · ВЕС %d · ОРУЖИЕ %d/%d · ПРИЦЕПЫ %d/2") % [player.coins, player.weight, shop.weapons.size(), player.weapon_capacity, player.carriers.size()]
	refresh_save_status(str(shop.get("storage_status", "ready")), bool(shop.get("dirty", false)))
	visible = true
	if not was_visible:
		close_button.grab_focus()
	mount_selector.set_build(player)
	preview.show_build(player)
	preview.set_mount_target(mount_selector.selected_mount())
	preview.set_active(true)
	rebuild_cards()
	if _selected.is_empty():
		select_module("assaultRifle")
	else:
		select_module(_selected)

func hide_panel() -> void:
	visible = false
	preview.set_active(false)

func _layout() -> void:
	if _sidebar:
		_sidebar.custom_minimum_size.x = clampf(size.x * 0.42, 330, 640)
	if cards and _catalog_scroll:
		cards.columns = maxi(2, int((_catalog_scroll.size.x - 12) / 182.0))

func matching_types() -> Array[String]:
	var result: Array[String] = []
	var terms := query.text.to_lower().strip_edges().split(" ", false)
	for type: String in _catalog.modules:
		var definition: Dictionary = _catalog.modules[type]
		var weapon := definition.has("projectile")
		var installed := _installed(type)
		if filter.selected == 1 and not weapon or filter.selected == 2 and weapon or filter.selected == 3 and not installed:
			continue
		var text := (str(definition.name) + " " + str(definition.desc) + " " + Locale.text(str(definition.name)) + " " + Locale.text(str(definition.desc))).to_lower()
		var matches := true
		for term: String in terms:
			matches = matches and text.contains(term)
		if matches:
			result.append(type)
	return result

func _installed(type: String) -> bool:
	return _player.get("modules", []).any(func(module: Dictionary) -> bool: return module.type == type)

func rebuild_cards() -> void:
	if _shop.is_empty():
		return
	_tile_panels.clear()
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	for type: String in matching_types():
		var definition: Dictionary = _catalog.modules[type]
		var card := _card(type, str(definition.name), str(definition.desc))
		var installed := _installed(type)
		var matched_upgrade := false
		if type == "radar" and installed and not _shop.get("radar_upgrade", {}).is_empty():
			var radar_module := _installed_module("radar")
			card.add_child(Styles.label(Locale.text("MK %d · ДАЛЬНОСТЬ %d м") % [radar_module.get("level", 1), radar_module.get("def", {}).get("range", 0)], 11))
			_action(card, _shop.radar_upgrade, Locale.text("МАКС. УРОВЕНЬ") if int(radar_module.get("level", 1)) >= 4 else Locale.text("УЛУЧШИТЬ"))
			matched_upgrade = true
		for weapon: Dictionary in _shop.weapons:
			var index := int(str(weapon.id).get_slice(":", 1))
			var player_weapons: Array = _player.modules.filter(func(module: Dictionary) -> bool: return module.get("def", {}).has("projectile"))
			if index < player_weapons.size() and player_weapons[index].type == type:
				_action(card, weapon, Locale.text("УЛУЧШИТЬ"))
				_action(card, {"id": weapon.remove_id, "enabled": weapon.remove_enabled, "cost": 0, "description": Locale.text("Снять оружие"), "disabled_reason": Locale.text("Последнее оружие") if not weapon.remove_enabled else ""}, Locale.text("СНЯТЬ · +%d ЛОМ") % weapon.refund)
				matched_upgrade = true
		if not matched_upgrade:
			for row: Dictionary in _shop.modules:
				if row.id == "module:" + type:
					_action(card, row, Locale.text("УСТАНОВЛЕНО") if installed else Locale.text("УСТАНОВИТЬ"))
	if filter.selected == 0 and query.text.is_empty():
		var trailer := _card("walkerTrailer", str(_shop.trailer.label), Locale.text("Три крепления модулей · +8 вес · +12% расход"))
		_action(trailer, _shop.trailer, Locale.text("УСТАНОВИТЬ"))

func _card(type: String, title: String, description: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_meta("module_type", type)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("202820")
	style.border_color = Color("e6ac58") if type == _selected else Color("46523f")
	style.set_border_width_all(1)
	for side in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 6)
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(panel)
	_tile_panels[type] = panel
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 164
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var inspect := Styles.button("")
	inspect.name = "Inspect"
	inspect.custom_minimum_size = Vector2(0, 48)
	inspect.tooltip_text = Locale.text(title) + "\n" + Locale.text(description)
	inspect.pressed.connect(func() -> void: select_module(type))
	column.add_child(inspect)
	var heading := Styles.label(title, 13)
	heading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	heading.offset_left = 7
	heading.offset_right = -7
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inspect.add_child(heading)
	return column

func _action(parent: VBoxContainer, row: Dictionary, caption: String) -> void:
	var cost := int(row.get("cost", 0))
	var button := Styles.button(caption + (Locale.text(" · %d ЛОМ") % cost if cost > 0 else ""))
	button.custom_minimum_size = Vector2(0, 27)
	button.add_theme_font_size_override("font_size", 11)
	button.clip_text = true
	button.set_meta("action_id", str(row.id))
	var invalid_mount: bool = str(row.id).begins_with("module:") and str(row.id) != "module:bumper" and not mount_selector.valid_target()
	button.disabled = not row.get("enabled", false) or invalid_mount
	button.tooltip_text = Locale.text("Нет свободных слотов") if invalid_mount else Locale.text(str(row.get("disabled_reason", row.get("description", ""))))
	button.pressed.connect(func() -> void: action_requested.emit("buy", _purchase_id(str(row.id))))
	parent.add_child(button)

func _purchase_id(id: String) -> String:
	var mount: Dictionary = mount_selector.selected_mount()
	if id.begins_with("module:") and id != "module:bumper" and not mount.is_empty():
		return "%s:%s:%d" % [id, mount.carrierId, mount.slot]
	return id

func _mount_changed(mount: Dictionary) -> void:
	preview.set_mount_target(mount)
	rebuild_cards()

func select_module(type: String) -> void:
	_selected = type
	for key: String in _tile_panels:
		var style := _tile_panels[key].get_theme_stylebox("panel") as StyleBoxFlat
		style.border_color = Color("e6ac58") if key == type else Color("46523f")
	preview.show_module(type)
	if type == "walkerTrailer":
		details.text = Locale.text("Колёсный прицеп\nТри крепления модулей\nВес +8\nРасход топлива +12%\nУровень 2 / 4 для второго")
		return
	var definition: Dictionary = _catalog.modules[type]
	var lines: Array[String] = [Locale.text(str(definition.name)), Locale.text(str(definition.desc)), Locale.text("Вес: %d") % definition.weight]
	for module: Dictionary in _player.modules:
		if module.type == type:
			definition = module.def
			lines.append(Locale.text("Установлено: %s · слот %d") % [_carrier_caption(str(module.mount.carrierId)), int(module.mount.slot) + 1])
			lines.append(Locale.text("Уровень MK %d") % module.level)
	for key in ["damage", "range", "cooldown"]:
		if definition.has(key):
			lines.append("%s: %.2f" % [Locale.text("Урон") if key == "damage" else Locale.text("Дальность") if key == "range" else Locale.text("Перезарядка"), float(definition[key])])
	if type == "radar" and not _shop.get("radar_upgrade", {}).is_empty():
		var upgrade: Dictionary = _shop.radar_upgrade
		if not str(upgrade.get("description", "")).is_empty():
			lines.append(Locale.text(str(upgrade.description)))
		if not upgrade.get("enabled", false) and not str(upgrade.get("disabled_reason", "")).is_empty():
			lines.append(Locale.text(str(upgrade.disabled_reason)))
	details.text = "\n".join(lines)

func refresh_save_status(status: String, dirty: bool) -> void:
	var captions := {"ready": Locale.text("сохранён"), "default": Locale.text("новый локальный профиль"), "recovered": Locale.text("восстановлен после повреждения"), "migrated": Locale.text("обновлён"), "read-only-future": Locale.text("новая версия профиля: доступ только для чтения"), "unavailable": Locale.text("файл недоступен"), "unsaved": Locale.text("не удалось сохранить; повторим автоматически")}
	save_status.text = Locale.text("Профиль: ") + (Locale.text("ожидает сохранения") if dirty and status in ["ready", "default"] else str(captions.get(status, status)))

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.keycode != KEY_TAB:
		return
	var controls: Array[Control] = []
	_focus_controls(self, controls)
	if controls.is_empty():
		return
	var current := controls.find(get_viewport().gui_get_focus_owner())
	controls[posmod(current + (-1 if event.shift_pressed else 1), controls.size())].grab_focus()
	get_viewport().set_input_as_handled()

func _focus_controls(parent: Node, result: Array[Control]) -> void:
	for child in parent.get_children():
		if child is Control and child.visible and child.focus_mode == Control.FOCUS_ALL and not (child is BaseButton and child.disabled):
			result.append(child)
		_focus_controls(child, result)

func _carrier_caption(id: String) -> String:
	if id == "crawler":
		return Locale.text("Основная машина")
	for index in _player.get("carriers", []).size():
		if _player.carriers[index].id == id:
			return Locale.text("Прицеп %d") % (index + 1)
	return id

func _installed_module(type: String) -> Dictionary:
	for module: Dictionary in _player.get("modules", []):
		if module.type == type:
			return module
	return {}

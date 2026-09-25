extends ColorRect

const Fieldwork = preload("res://presentation/ui/fieldwork_tokens.gd")

const Icons = preload("res://presentation/ui/ui_icons.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")

signal action_requested(action: String, id: String)
const Styles = preload("res://presentation/ui/ui_styles.gd")
const Preview = preload("res://presentation/ui/armory_preview.gd")
const ModelPreview = preload("res://presentation/ui/item_model_preview.gd")
const PreviewPip = preload("res://presentation/ui/item_preview_pip.gd")
const WagonCatalog = preload("res://modules/caravan/wagon_catalog.gd")
const MountSelector = preload("res://presentation/ui/mount_selector.gd")
var preview: SubViewportContainer
var query: LineEdit
var filter: OptionButton
var cards: GridContainer
var details: RichTextLabel
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
var mount_selector: VBoxContainer
var _tile_panels: Dictionary = {}
var _catalog_scroll: ScrollContainer
var reset_view_button: Button
var _sidebar_text: VBoxContainer
var trailers_button: Button
var _mount_hint: Label
var _catalog_heading: Label
var _embedded := false
var _header: HBoxContainer
var _margin: MarginContainer
var _inspector: VBoxContainer
var _inspector_actions: VBoxContainer
var _module_actions: Dictionary = {}
var _column: VBoxContainer
var _inspector_surface: PanelContainer
var _catalog_column: VBoxContainer
var item_preview_pip

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Fieldwork.BG
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_catalogs.json"))
	_catalog = parsed if parsed is Dictionary else {}
	var margin := MarginContainer.new()
	_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	item_preview_pip = PreviewPip.new()
	add_child(item_preview_pip)
	var column := VBoxContainer.new()
	_column = column
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var header := HBoxContainer.new()
	_header = header
	column.add_child(header)
	var title := Styles.label(Locale.text("АРСЕНАЛ"), 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	trailers_button = Styles.button("ПРИЦЕПЫ / КУПИТЬ" if Locale.language == "ru" else "TRAILERS / BUY")
	trailers_button.set_meta("action_id", "trailers")
	trailers_button.pressed.connect(func() -> void: action_requested.emit("trailers", ""))
	Icons.apply(trailers_button, "base", 20)
	header.add_child(trailers_button)
	close_button = Styles.button(Locale.text("ПРОДОЛЖИТЬ [ESC]"))
	close_button.pressed.connect(func() -> void: action_requested.emit("resume", ""))
	Icons.apply(close_button, "close", 20)
	header.add_child(close_button)
	summary = Styles.label("", 12)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(summary)
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 16)
	column.add_child(_body)
	_sidebar = VBoxContainer.new()
	_sidebar.custom_minimum_size.x = 260
	_sidebar.add_theme_constant_override("separation", 6)
	_body.add_child(_sidebar)
	preview = Preview.new()
	preview.custom_minimum_size.y = 156
	preview.size_flags_vertical = Control.SIZE_FILL
	_sidebar.add_child(preview)
	var preview_tools := HBoxContainer.new()
	_sidebar.add_child(preview_tools)
	var inspect_hint := Styles.label(Locale.text("Тяните: вращение · Колесо: масштаб"), 11)
	inspect_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Styles.muted(inspect_hint)
	inspect_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_tools.add_child(inspect_hint)
	reset_view_button = Styles.button(Locale.text("Сброс вида"))
	reset_view_button.custom_minimum_size = Vector2(86, 28)
	reset_view_button.add_theme_font_size_override("font_size", 12)
	reset_view_button.pressed.connect(preview.reset_view)
	preview_tools.add_child(reset_view_button)
	mount_selector = MountSelector.new()
	_sidebar.add_child(mount_selector)
	_sidebar.move_child(mount_selector, 0)
	mount_selector.target_changed.connect(_mount_changed)
	_sidebar_text = VBoxContainer.new()
	_sidebar_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "InspectionDetails"
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sidebar.add_child(detail_scroll)
	detail_scroll.add_child(_sidebar_text)
	_core_summary = Styles.label("", 12)
	_sidebar_text.add_child(_core_summary)
	_mount_hint = Styles.label("", 11)
	_mount_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_protocol_summary = Styles.label("", 12)
	_protocol_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sidebar_text.add_child(_protocol_summary)
	details = RichTextLabel.new()
	details.bbcode_enabled = true
	details.fit_content = true
	details.scroll_active = false
	details.add_theme_font_size_override("normal_font_size", 13)
	details.add_theme_font_override("bold_font", Styles.font(true))
	details.add_theme_color_override("default_color", Fieldwork.MUTED)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x = 0
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sidebar_text.add_child(details)
	var catalog_column := VBoxContainer.new()
	_catalog_column = catalog_column
	catalog_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(catalog_column)
	_catalog_heading = Styles.label("", 15)
	_catalog_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	catalog_column.add_child(_catalog_heading)
	catalog_column.add_child(_mount_hint)
	var search_row := HBoxContainer.new()
	catalog_column.add_child(search_row)
	query = LineEdit.new()
	query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	query.placeholder_text = "Поиск оружия" if Locale.language == "ru" else "Search weapons"
	query.right_icon = Icons.texture("search")
	query.custom_minimum_size.y = 34
	query.text_changed.connect(func(_text: String) -> void: rebuild_cards())
	search_row.add_child(query)
	filter = OptionButton.new()
	for caption in [Locale.text("Все системы"), Locale.text("Оружие"), Locale.text("Поддержка"), Locale.text("Установлено")]:
		filter.add_item(caption)
	filter.item_selected.connect(func(_index: int) -> void: rebuild_cards())
	filter.custom_minimum_size = Vector2(116, 36)
	filter.add_theme_font_size_override("font_size", 12)
	search_row.add_child(filter)
	_catalog_scroll = ScrollContainer.new()
	_catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalog_column.add_child(_catalog_scroll)
	_catalog_scroll.resized.connect(_layout)
	cards = GridContainer.new()
	cards.columns = 1
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 7)
	_catalog_scroll.add_child(cards)
	_catalog_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: item_preview_pip.hide_preview())
	_inspector_surface = PanelContainer.new()
	_inspector_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_surface.add_theme_stylebox_override("panel", Styles.panel_style())
	_body.add_child(_inspector_surface)
	_inspector = VBoxContainer.new()
	_inspector.add_theme_constant_override("separation", 12)
	_inspector_surface.add_child(_inspector)
	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inspector.add_child(inspector_scroll)
	details.reparent(inspector_scroll)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_font_size_override("font_size", 14)
	details.size_flags_vertical = Control.SIZE_FILL
	_inspector_actions = VBoxContainer.new()
	_inspector_actions.add_theme_constant_override("separation", 8)
	_inspector.add_child(_inspector_actions)
	save_status = Styles.label("", 12)
	column.add_child(save_status)
	resized.connect(_layout)
	visible = false

func display(shop: Dictionary, player: Dictionary) -> void:
	query.placeholder_text = "Поиск оружия" if Locale.language == "ru" else "Search weapons"
	var was_visible := visible
	_shop = shop
	_player = player

	var protocols: Array[String] = []
	for row: Dictionary in shop.protocols:
		var id := str(row.id).get_slice(":", 1)
		if not player.get("protocols", []).has(id):
			continue
		var requirements: Array[String] = []
		for requirement: Dictionary in _catalog.protocols.get(id, {}).get("requirements", []):
			requirements.append(Locale.text(str(requirement.get("label", ""))))
		protocols.append("%s · %s\n%s" % [Locale.text(str(row.label)), Locale.text("АКТИВЕН") if player.active_protocols.has(id) else Locale.text("НЕТ НУЖНЫХ МОДУЛЕЙ"), " + ".join(requirements)])
	_protocol_summary.text = ("Протоколы: %d" if Locale.language == "ru" else "Protocols: %d") % protocols.size()
	_protocol_summary.tooltip_text = "\n".join(protocols)
	_protocol_summary.visible = not protocols.is_empty()
	summary.text = ("ЛОМ %d · ОБЩИЙ ВЕС %d · ОРУЖИЕ %d/%d · ПРИЦЕПЫ %d/6" if Locale.language == "ru" else "SCRAP %d · TOTAL WEIGHT %d · WEAPONS %d/%d · TRAILERS %d/6") % [player.coins, player.weight, player.modules.filter(func(module: Dictionary) -> bool: return module.get("def", {}).has("projectile")).size(), player.weapon_capacity, player.carriers.size()]
	refresh_save_status(str(shop.get("storage_status", "ready")), bool(shop.get("dirty", false)))
	trailers_button.tooltip_text = "Покупка и сцепка прицепов доступны на базе после эвакуации." if Locale.language == "ru" else "Buy and attach trailers at base after extraction."
	visible = true
	if not was_visible:
		if _embedded:
			close_button.release_focus()
		else:
			close_button.grab_focus()
	mount_selector.set_build(player)
	_refresh_unit_stats()
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
	if item_preview_pip:
		item_preview_pip.hide_preview()

func _layout() -> void:
	if not _inspector:
		return
	var compact := size.x < Fieldwork.ARMORY_COMPACT_WIDTH
	mount_selector.set_compact(compact)
	_sidebar.visible = not compact
	_sidebar.custom_minimum_size.x = 292
	_catalog_column.custom_minimum_size.x = (size.x - 16) * 0.45 if compact else 300
	_catalog_column.size_flags_horizontal = Control.SIZE_FILL
	_inspector_surface.custom_minimum_size.x = 0
	preview.custom_minimum_size.y = 156 if compact else 218
	if compact and mount_selector.get_parent() != _column:
		mount_selector.reparent(_column)
		_column.move_child(mount_selector, 2)
	elif not compact and mount_selector.get_parent() != _sidebar:
		mount_selector.reparent(_sidebar)
		_sidebar.move_child(mount_selector, 0)

	cards.columns = 1

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
	return not _installed_module(type).is_empty()

func rebuild_cards() -> void:
	if _shop.is_empty():
		return
	if item_preview_pip:
		item_preview_pip.hide_preview()
	_tile_panels.clear()
	_module_actions.clear()
	for child in _inspector_actions.get_children():
		_inspector_actions.remove_child(child)
		child.queue_free()
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
			_action(card, _shop.radar_upgrade, Locale.text("МАКС. УРОВЕНЬ") if int(radar_module.get("level", 1)) >= preload("res://modules/progression/radar_rules.gd").MAX_LEVEL else Locale.text("УЛУЧШИТЬ"))
			matched_upgrade = true
		for row: Dictionary in _shop.weapons:
			var index := int(str(row.id).get_slice(":", 1))
			var support := str(row.id).begins_with("support:")
			var collection: Array = _player.modules if support else _player.modules.filter(func(module: Dictionary) -> bool: return module.get("def", {}).has("projectile"))
			if index >= collection.size() or collection[index].type != type or not _on_selected_unit(collection[index]):
				continue
			if not support:
				_action(card, row, Locale.text("УЛУЧШИТЬ") + " · " + (Locale.text("Слот %d") % (int(collection[index].mount.slot) + 1)))
			_action(card, {"id": row.remove_id, "enabled": row.remove_enabled, "cost": 0, "description": Locale.text("Снять оружие"), "disabled_reason": Locale.text("Последнее оружие") if not row.remove_enabled and not support else ""}, Locale.text("СНЯТЬ · +%d ЛОМ") % row.refund)
			matched_upgrade = true
		if not matched_upgrade or (definition.has("projectile") and filter.selected != 3):
			for row: Dictionary in _shop.modules:
				if row.id == "module:" + type:
					_action(card, row, ("ДОБАВИТЬ" if Locale.language == "ru" else "ADD") if installed and definition.has("projectile") else Locale.text("УСТАНОВЛЕНО") if installed else Locale.text("УСТАНОВИТЬ"))
	_rebuild_attachments()
	if cards.get_child_count() == 0:
		var empty := Styles.label("Нет результатов. Измените поиск или фильтр." if Locale.language == "ru" else "No results. Change the search or filter.", 14)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cards.add_child(empty)
	_show_actions()

func _card(type: String, title: String, description: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_meta("module_type", type)
	var style := StyleBoxFlat.new()
	style.bg_color = Fieldwork.RAISED if type == _selected else Fieldwork.PANEL
	style.set_corner_radius_all(4)
	style.border_color = Fieldwork.ACCENT if type == _selected else Fieldwork.LINE
	style.set_border_width_all(1)
	for side in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 1)
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(panel)
	_tile_panels[type] = panel
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 180
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var inspect := Styles.button("")
	inspect.name = "Inspect"
	inspect.custom_minimum_size = Vector2(0, 56)

	inspect.pressed.connect(func() -> void: select_module(type))
	column.add_child(inspect)
	Styles.ghost(inspect)
	var row_style := inspect.get_theme_stylebox("normal") as StyleBoxFlat
	row_style.bg_color = Color.TRANSPARENT
	var icon := Icons.view("gun" if _catalog.modules.get(type, {}).has("projectile") else "settings", 20)
	icon.position = Vector2(14, 18)
	inspect.add_child(icon)
	var heading := Styles.label(title, 14)
	heading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	heading.offset_left = 50
	heading.offset_right = -12
	heading.offset_top = 5
	heading.offset_bottom = -26
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inspect.add_child(heading)
	var caption := Styles.label(Locale.text(description).get_slice(".", 0), 12)
	Styles.muted(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.offset_left = 50
	caption.offset_right = -12
	caption.offset_top = 29
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inspect.add_child(caption)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.visible = false
	_inspector_actions.add_child(actions)
	_module_actions[type] = actions
	column.set_meta("actions", actions)
	return column

func _action(parent: VBoxContainer, row: Dictionary, caption: String) -> void:
	var cost := int(row.get("cost", 0))
	var button := Styles.button(caption + (Locale.text(" · %d ЛОМ") % cost if cost > 0 else ""))
	button.custom_minimum_size = Vector2(0, 30)
	button.add_theme_font_size_override("font_size", 12)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.set_meta("action_id", str(row.id))
	var invalid_mount: bool = (str(row.id).begins_with("module:") or str(row.id).begins_with("attachment:")) and str(row.id) != "module:bumper" and (not mount_selector.valid_target())
	if str(row.id) == "module:bumper" and mount_selector.selected_carrier() != "crawler":
		invalid_mount = true
	button.disabled = not row.get("enabled", false) or invalid_mount
	button.tooltip_text = button.text + "\n" + (Locale.text("Нет свободных слотов") if invalid_mount else Locale.text(str(row.get("disabled_reason", row.get("description", "")))))
	button.pressed.connect(func() -> void: action_requested.emit("buy", _purchase_id(str(row.id))))
	var target: VBoxContainer = parent.get_meta("actions", parent)
	target.add_child(button)
	if button.disabled:
		var reason := Locale.text("Нет свободных слотов") if invalid_mount else Locale.text(str(row.get("disabled_reason", "")))
		if cost > int(_player.get("coins", 0)):
			reason = ("Не хватает %d лома" if Locale.language == "ru" else "Need %d more scrap") % (cost - int(_player.get("coins", 0)))
		if not reason.is_empty():
			var explanation := Styles.label(reason, 14)
			explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			explanation.add_theme_color_override("font_color", Fieldwork.ACCENT)
			target.add_child(explanation)

func _show_actions() -> void:
	for type: String in _module_actions:
		_module_actions[type].visible = type == _selected

func _purchase_id(id: String) -> String:
	var mount: Dictionary = mount_selector.selected_mount()
	if id.begins_with("attachment:") and not mount.is_empty():
		return "attachment:%s:%s:%d" % [id.get_slice(":", 1), mount.carrierId, mount.slot]
	if id.begins_with("module:") and id != "module:bumper" and not mount.is_empty():
		return "%s:%s:%d" % [id, mount.carrierId, mount.slot]
	return id

func _mount_changed(mount: Dictionary) -> void:
	preview.set_mount_target(mount)
	_refresh_unit_stats()
	rebuild_cards()
	for module: Dictionary in _player.get("modules", []):
		if module.get("mount", {}) == mount:
			select_module(str(module.type))
			return
	for installed: Dictionary in _carrier_data().get("attachments", []):
		if int(installed.slot) == int(mount.get("slot", -1)):
			_selected = "attachment:" + str(installed.type)
			_show_attachment(str(installed.type))
			_show_actions()
			return
	if not _selected.is_empty():
		select_module(_selected)

func select_module(type: String) -> void:
	_selected = type
	_show_actions()

	for key: String in _tile_panels:
		var style := _tile_panels[key].get_theme_stylebox("panel") as StyleBoxFlat
		style.border_color = Fieldwork.ACCENT if key == type else Fieldwork.LINE
		style.bg_color = Fieldwork.RAISED if key == type else Fieldwork.PANEL
	preview.show_attachment(type.trim_prefix("attachment:")) if type.begins_with("attachment:") else preview.show_module(type)
	if type == "walkerTrailer":
		details.text = ("Колёсный прицеп\nОтдельная техника с тремя креплениями.\nПокупка добавляет новый прицеп в список.\nВсего до 6 прицепов." if Locale.language == "ru" else "Wheeled trailer\nSeparate unit with three module mounts.\nPurchase adds a new trailer to the selector.\nUp to 6 trailers.")
		return
	if type.begins_with("attachment:"):
		_show_attachment(type.trim_prefix("attachment:"))
		return
	var definition: Dictionary = _catalog.modules[type]
	var lines: Array[String] = [Locale.text(str(definition.name)), Locale.text(str(definition.desc)), Locale.text("Вес: %d") % definition.weight]
	for module: Dictionary in _player.modules:
		if module.type == type and _on_selected_unit(module):
			definition = module.def
			lines.append(Locale.text("Установлено: %s · слот %d") % [_carrier_caption(str(module.mount.carrierId)), int(module.mount.slot) + 1])
			lines.append(Locale.text("Уровень MK %d") % module.level)
			break
	for key in ["damage", "range", "cooldown"]:
		if definition.has(key):
			lines.append("%s: %.2f" % [Locale.text("Урон") if key == "damage" else Locale.text("Дальность") if key == "range" else Locale.text("Перезарядка"), float(definition[key])])
	if type == "radar" and not _shop.get("radar_upgrade", {}).is_empty():
		var upgrade: Dictionary = _shop.radar_upgrade
		if not str(upgrade.get("description", "")).is_empty():
			lines.append(Locale.text(str(upgrade.description)))
		if not upgrade.get("enabled", false) and not str(upgrade.get("disabled_reason", "")).is_empty():
			lines.append(Locale.text(str(upgrade.disabled_reason)))
	details.text = "[font_size=22][b][color=#EEEBDD]" + lines[0] + "[/color][/b][/font_size]\n\n" + "\n\n".join(lines.slice(1))

func refresh_save_status(status: String, dirty: bool) -> void:
	var captions := {"ready": Locale.text("сохранён"), "default": Locale.text("новый локальный профиль"), "recovered": Locale.text("восстановлен после повреждения"), "migrated": Locale.text("обновлён"), "read-only-future": Locale.text("новая версия профиля: доступ только для чтения"), "unavailable": Locale.text("файл недоступен"), "unsaved": Locale.text("не удалось сохранить; повторим автоматически")}
	save_status.text = Locale.text("Профиль: ") + (Locale.text("ожидает сохранения") if dirty and status in ["ready", "default"] else str(captions.get(status, status)))

func _input(event: InputEvent) -> void:
	if _embedded or not visible or not event is InputEventKey or not event.pressed or event.keycode != KEY_TAB:
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
		return "Пикап" if Locale.language == "ru" else "Pickup"
	for index in _player.get("carriers", []).size():
		if _player.carriers[index].id == id:
			var definition: Dictionary = WagonCatalog.TYPES.get(str(_player.carriers[index].get("type", "")), {})
			return "%d. %s" % [index + 1, definition.get("name" if Locale.language == "ru" else "name_en", Locale.text("Прицеп %d") % (index + 1))]
	return id

func _installed_module(type: String) -> Dictionary:
	for module: Dictionary in _player.get("modules", []):
		if module.type == type and _on_selected_unit(module):
			return module
	return {}

func _on_selected_unit(module: Dictionary) -> bool:
	return str(module.get("mount", {}).get("carrierId", "crawler")) == mount_selector.selected_carrier()

func _refresh_unit_stats() -> void:
	var id: String = mount_selector.selected_carrier()
	var modules: Array = _player.get("modules", []).filter(_on_selected_unit)
	var carrier := _carrier_data()
	var attachments: Array = carrier.get("attachments", [])
	var weight := 12.0 if id == "crawler" else float(carrier.get("mass", carrier.get("weight", 8)))
	var slots := 12 if id == "crawler" else int(carrier.get("slotCount", 3))
	for module: Dictionary in modules:
		weight += float(module.get("def", {}).get("weight", 0))
	var weapons := modules.filter(func(module: Dictionary) -> bool: return module.get("def", {}).has("projectile")).size()
	var heading := _carrier_caption(id)
	_catalog_heading.text = ("ОБОРУДОВАТЬ: " if Locale.language == "ru" else "EQUIP: ") + heading
	_mount_hint.text = ("Выберите технику и свободное крепление слева." if Locale.language == "ru" else "Select a vehicle and free mount on the left.")
	var usage := ("Вес %.0f · Крепления %d/%d · Оружие %d" if Locale.language == "ru" else "Weight %.0f · Mounts %d/%d · Weapons %d") % [weight, modules.size() + attachments.size(), slots, weapons]
	var stats := ""
	if id == "crawler":
		var upgrades: Dictionary = _player.get("core_upgrades", {})
		stats = ("Корпус %d · Топливо %d · Двиг/Брон/Бак %d/%d/%d" if Locale.language == "ru" else "Hull %d · Fuel %d · ENG/ARM/TANK %d/%d/%d") % [_player.get("max_hp", 0), _player.get("max_fuel", 0), upgrades.get("motor", 0), upgrades.get("armor", 0), upgrades.get("fuel", 0)]
	else:
		stats = ("Корпус %d/%d · Груз %d/%d" if Locale.language == "ru" else "Hull %d/%d · Cargo %d/%d") % [carrier.get("hp", 0), carrier.get("max_hp", 0), WagonCatalog.cargo_used(carrier.get("cargo", {})), carrier.get("cargo_capacity", 0)]
	_core_summary.text = heading + "\n" + usage + "\n" + stats
	_core_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _carrier_data() -> Dictionary:
	for carrier: Dictionary in _player.get("carriers", []):
		if str(carrier.id) == mount_selector.selected_carrier():
			return carrier
	return {}

func _rebuild_attachments() -> void:
	var rows: Array = _shop.get("attachments", [])
	for row: Dictionary in rows:
		if str(row.get("carrier_id", "")) != mount_selector.selected_carrier():
			continue
		var type := str(row.type)
		var definition: Dictionary = WagonCatalog.ATTACHMENTS.get(type, {})
		var title := str(definition.get("name" if Locale.language == "ru" else "name_en", type))
		var installed: bool = _carrier_data().get("attachments", []).any(func(item: Dictionary) -> bool: return item.type == type)
		if filter.selected == 1 or (filter.selected == 3 and not installed):
			continue
		if not query.text.is_empty() and not (title + " " + str(definition.get("name", "")) + " " + str(definition.get("name_en", ""))).to_lower().contains(query.text.to_lower()):
			continue
		var card := _card("attachment:" + type, title, str(row.get("description", "")))
		if not installed:
			_action(card, row, Locale.text("УСТАНОВИТЬ"))
		for installation: Dictionary in _carrier_data().get("attachments", []):
			if installation.type == type:
				_action(card, {"id": "remove_attachment:%s:%d" % [mount_selector.selected_carrier(), installation.slot], "enabled": true}, ("СНЯТЬ" if Locale.language == "ru" else "REMOVE"))

func _show_attachment(type: String) -> void:
	var definition: Dictionary = WagonCatalog.ATTACHMENTS.get(type, {})
	var lines: Array[String] = [str(definition.get("name" if Locale.language == "ru" else "name_en", type))]
	lines.append(("Вес: %.1f" if Locale.language == "ru" else "Weight: %.1f") % float(definition.get("mass", 0)))
	if definition.has("factor"):
		var roles := {"shooter": ["стрелок", "gunner"], "mechanic": ["механик", "mechanic"], "loader": ["заряжающий", "loader"], "looter": ["сборщик", "scavenger"], "fuel": ["топливщик", "fuel operator"], "anti_tank": ["ПТ-стрелок", "anti-tank gunner"], "anti_air": ["зенитчик", "anti-air gunner"]}
		var role: Array = roles.get(str(definition.get("role", "")), ["экипаж", "crew"])
		lines.append(("Эффективность ×%.2f · %s" if Locale.language == "ru" else "Efficiency ×%.2f · %s") % [definition.factor, role[0 if Locale.language == "ru" else 1]])
	for item in [["cargo", "Груз +%d", "Cargo +%d"], ["armor_hp", "Корпус +%d", "Hull +%d"], ["hitch_strength", "Прочность сцепки ×%.1f", "Hitch strength ×%.1f"]]:
		if definition.has(item[0]):
			lines.append(item[1 if Locale.language == "ru" else 2] % definition[item[0]])
	for installed: Dictionary in _carrier_data().get("attachments", []):
		if installed.type == type:
			lines.append(Locale.text("Установлено: %s · слот %d") % [_carrier_caption(mount_selector.selected_carrier()), int(installed.slot) + 1])
	details.text = "[font_size=22][b][color=#EEEBDD]" + lines[0] + "[/color][/b][/font_size]\n\n" + "\n\n".join(lines.slice(1))

func select_carrier(id: String) -> void:
	mount_selector.select_carrier(id)

func set_embedded(value: bool) -> void:
	_embedded = value
	if _header:
		_header.visible = not value
		summary.visible = not value
		_catalog_heading.visible = not value
		_mount_hint.visible = not value
	if _margin:
		for side in ["left", "right", "top", "bottom"]:
			_margin.add_theme_constant_override("margin_" + side, 0 if value else 12)
	_layout()

extends ColorRect

signal action_requested(kind: String, id: String, target: String)
signal closed
const Styles = preload("res://presentation/ui/ui_styles.gd")
const Icons = preload("res://presentation/ui/ui_icons.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Catalog = preload("res://modules/caravan/wagon_catalog.gd")
const Factory = preload("res://modules/caravan/wagon_factory.gd")
const ModelPreview = preload("res://presentation/ui/item_model_preview.gd")
const PreviewPip = preload("res://presentation/ui/item_preview_pip.gd")
var state: Dictionary = {}
var credits := 0
var scrap := 0
var embedded := false
var top: HBoxContainer
var heading: Label
var content: VBoxContainer
var tab := "wagons"
var tabs: HBoxContainer
var close_button: Button
var equipment_wagon_id := ""
var purchase_notice := ""
var _scroll: ScrollContainer
var _rendered_tab := ""
var item_preview_pip

static func words(ru: String, en: String) -> String:
	return ru if Locale.language == "ru" else en

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color("141f22")
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 14)
	add_child(margins)
	item_preview_pip = PreviewPip.new()
	add_child(item_preview_pip)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margins.add_child(column)
	top = HBoxContainer.new()
	column.add_child(top)
	heading = Styles.label("", 19)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(heading)
	close_button = Styles.button(words("ЗАКРЫТЬ [ESC]", "CLOSE [ESC]"))
	Icons.apply(close_button, "close")
	close_button.pressed.connect(func() -> void: closed.emit())
	top.add_child(close_button)
	tabs = HBoxContainer.new()
	column.add_child(tabs)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: item_preview_pip.hide_preview())
	visible = false

func show_state(value: Dictionary, credit_balance: int = 0, stash_scrap: int = 0) -> void:
	state = value
	credits = credit_balance
	scrap = stash_scrap
	visible = true
	_refresh()

func _refresh() -> void:
	if item_preview_pip:
		item_preview_pip.hide_preview()
	if tab != _rendered_tab:
		_scroll.scroll_vertical = 0
		_rendered_tab = tab
	for parent: Node in [content, tabs]:
		for child: Node in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	close_button.text = words("ЗАКРЫТЬ [ESC]", "CLOSE [ESC]")
	heading.text = words("БАЗА  |  Кредиты %d  |  Лом %d", "BASE  |  Credits %d  |  Vault scrap %d") % [credits, scrap]
	var tab_ids: Array[String] = ["wagons", "shop", "crew"]
	if not equipment_wagon_id.is_empty() and not state.get("active", false):
		tab_ids.insert(2, "equipment")
	for id: String in tab_ids:
		var captions := {"wagons": words("МОЙ СОСТАВ", "MY CONVOY"), "shop": words("ТОРГОВЛЯ", "TRADE"), "crew": words("ЭКИПАЖ", "CREW"), "equipment": words("ОБОРУДОВАНИЕ", "EQUIPMENT")}
		var button := Styles.button(captions[id])
		Icons.apply(button, {"wagons": "base", "shop": "trade", "crew": "crew", "equipment": "armory"}[id])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("caravan_tab", id)
		button.disabled = tab == id
		if button.disabled:
			var selected_style := StyleBoxFlat.new()
			selected_style.bg_color = Color("263333")
			selected_style.border_color = Color("e6ac58")
			selected_style.border_width_bottom = 2
			selected_style.content_margin_left = 12
			button.add_theme_stylebox_override("disabled", selected_style)
			button.add_theme_color_override("font_disabled_color", Color("f0eada"))
		button.pressed.connect(func() -> void: tab = id; _refresh())
		tabs.add_child(button)
	var instruction := words("Купите прицеп → он прицепится к пикапу → выберите ОБОРУДОВАНИЕ.", "Buy a trailer → it attaches to your pickup → choose EQUIP.")
	if tab == "crew":
		instruction = words("Места назначаются по профессии автоматически. Зарплата берётся со склада.", "Seats are assigned by profession. Wages use vault scrap.")
	elif state.get("active", false):
		instruction = words("Вы в рейде. Купить и прицепить новые прицепы можно после эвакуации, в гараже на базе.", "You are in a raid. Extract first to buy and attach trailers in the base garage.")
	var info := Styles.label(instruction, 14)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	if not purchase_notice.is_empty():
		var confirmation := Styles.label(purchase_notice, 16)
		confirmation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(confirmation)
	if not str(state.get("notice", "")).is_empty():
		var notice := Styles.label(_notice(str(state.notice)), 14)
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(notice)
	if tab == "wagons":
		_wagons()
	elif tab == "shop":
		_shop()
	elif tab == "equipment":
		_equipment()
	else:
		_crew()

func _row(title: String, description: String, parent: Node = null, model_kind := "", model_id := "") -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("263333")
	style.border_color = Color("68716a")
	style.border_width_bottom = 1
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	if not model_id.is_empty():
		panel.set_meta("preview_kind", model_kind)
		panel.set_meta("preview_id", model_id)
	(parent if parent != null else content).add_child(panel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	if not model_id.is_empty():
		var model_preview := ModelPreview.new()
		model_preview.name = "ModelThumbnail"
		model_preview.custom_minimum_size = Vector2(72, 54)
		model_preview.set_preview(model_kind, model_id)
		title_row.add_child(model_preview)
		model_preview.mouse_filter = Control.MOUSE_FILTER_STOP
		model_preview.focus_mode = Control.FOCUS_ALL
		model_preview.mouse_entered.connect(func() -> void: item_preview_pip.show_for(model_preview, model_kind, model_id, title))
		model_preview.mouse_exited.connect(item_preview_pip.hide_preview)
		model_preview.focus_entered.connect(func() -> void: item_preview_pip.show_for(model_preview, model_kind, model_id, title))
		model_preview.focus_exited.connect(item_preview_pip.hide_preview)
		panel.mouse_entered.connect(func() -> void: item_preview_pip.show_for(panel, model_kind, model_id, title))
		panel.mouse_exited.connect(item_preview_pip.hide_preview)
	else:
		title_row.add_child(Icons.view("crew" if tab == "crew" else "armory" if tab == "equipment" else "base", 22))
	var name_label := Styles.label(title, 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_row.add_child(name_label)
	var info := Styles.label(description, 14)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(info)
	return column

func _action(parent: Node, label: String, kind: String, id: String, target: String = "", disabled: bool = false) -> void:
	var button := Styles.button(label)
	Icons.apply(button, {"buy_wagon": "trade", "configure_wagon": "armory", "select_wagon": "base", "select_crew": "crew", "install_attachment": "trade", "remove_attachment": "armory"}.get(kind, "base"), 18)
	button.disabled = disabled
	button.custom_minimum_size.y = 34
	button.set_meta("caravan_action", kind + ":" + id + (":" + target if not target.is_empty() else ""))
	button.pressed.connect(func() -> void: action_requested.emit(kind, id, target))
	if parent.get_parent() != null and parent.get_parent().has_meta("preview_kind"):
		var panel: Control = parent.get_parent()
		button.focus_entered.connect(func() -> void: item_preview_pip.show_for(button, str(panel.get_meta("preview_kind")), str(panel.get_meta("preview_id")), ""))
		button.focus_exited.connect(item_preview_pip.hide_preview)
	parent.add_child(button)

func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2 if get_viewport_rect().size.x >= 900 else 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	return grid

func _wagon_title(wagon: Dictionary, index: int) -> String:
	var definition: Dictionary = state.get("types", {}).get(str(wagon.get("type", "")), {})
	return "%d. %s" % [index + 1, definition.get("name" if Locale.language == "ru" else "name_en", words("Прицеп", "Trailer"))]

func _wagons() -> void:
	var owned: Array = state.get("wagons", [])
	var active: bool = state.get("active", false)
	var selected: Array = state.get("selected_wagon_ids", [])
	var attached_count := owned.filter(func(wagon: Dictionary) -> bool: return wagon.get("attached", true) and not wagon.get("dead", false)).size() if active else selected.size()
	content.add_child(Styles.label(words("ПИКАП + %d / 6 ПРИЦЕПОВ", "PICKUP + %d / 6 ATTACHED TRAILERS") % attached_count, 18))
	var pickup := _row(words("Пикап", "Pickup"), words("Ваша основная машина. Начинаете без прицепов.", "Your main vehicle. You start without trailers."), null, "vehicle", "crawler")
	if active:
		_action(pickup, words("ОБОРУДОВАНИЕ ПИКАПА", "EQUIP PICKUP"), "configure_wagon", "crawler")
	else:
		pickup.add_child(Styles.label(words("Оружие пикапа: Арсенал [B] в рейде.", "Pickup weapons: Armory [B] during a raid."), 14))
	if owned.is_empty():
		var empty := _row(words("Прицепов пока нет", "No trailers yet"), words("Купите первый прицеп за кредиты на базе. Он сразу добавится в конец состава.", "Buy your first trailer with base credits. It joins the back of your convoy automatically."))
		var buy := Styles.button(words("ВЫБРАТЬ ПЕРВЫЙ ПРИЦЕП", "CHOOSE YOUR FIRST TRAILER"))
		Icons.apply(buy, "trade")
		buy.set_meta("caravan_tab", "shop")
		buy.pressed.connect(func() -> void: tab = "shop"; _refresh())
		empty.add_child(buy)
		return
	var grid := _grid()
	for index in owned.size():
		var saved: Dictionary = owned[index]
		var wagon: Dictionary = saved if active else Factory.create(saved.type, saved.id, saved)
		var attached: bool = wagon.get("attached", true) and not wagon.get("dead", false) if active else selected.has(wagon.id)
		var status := words("ПРИЦЕПЛЕН", "ATTACHED") if attached else words("В ГАРАЖЕ", "IN GARAGE")
		if active and not attached:
			status = words("УНИЧТОЖЕН", "DESTROYED") if wagon.get("dead", false) else words("ОТЦЕПЛЕН", "DETACHED")
		var column := _row(_wagon_title(wagon, index) + " · " + status, words("Корпус %.0f/%.0f · Груз %d · Места %d\nОборудование %d/%d", "Hull %.0f/%.0f · Cargo %d · Seats %d\nEquipment %d/%d") % [wagon.hp, wagon.max_hp, wagon.cargo_capacity, wagon.crew_slots, wagon.get("modules", []).size() + wagon.get("attachments", []).size(), wagon.slotCount], grid, "vehicle", str(wagon.type))
		_action(column, words("ОБОРУДОВАНИЕ", "EQUIP TRAILER"), "configure_wagon", wagon.id, "", active and not attached)
		if not active:
			_action(column, words("ОСТАВИТЬ НА БАЗЕ", "LEAVE AT BASE") if attached else words("ПРИЦЕПИТЬ", "ATTACH"), "select_wagon", wagon.id, "0" if attached else "1")

func _shop() -> void:
	var owned: Array = state.get("wagons", [])
	var active: bool = state.get("active", false)
	content.add_child(Styles.label(words("МАГАЗИН ПРИЦЕПОВ · Куплено %d / 6", "TRAILER SHOP · Owned %d / 6") % owned.size(), 18))
	var grid := _grid()
	for type: String in state.get("types", {}):
		var definition: Dictionary = state.types[type]
		var title: String = definition.name if Locale.language == "ru" else definition.name_en
		var benefits := {"cargo": words("Больше места для добычи.", "More room for loot."), "repair": words("Механик ремонтирует на 15% быстрее.", "Mechanic repairs 15% faster."), "weapon": words("Урон экипажа выше на 10%.", "Crew weapon damage is 10% higher."), "fuel": words("Сборщик топлива движется на 20% быстрее.", "Fuel scavenger moves 20% faster."), "anti_tank": words("Урон бойца ПТ выше на 15%.", "Anti-tank crew damage is 15% higher."), "anti_air": words("Урон бойца ПВО выше на 15%.", "Anti-air crew damage is 15% higher.")}
		var column := _row(title, str(benefits.get(type, "")) + "\n" + words("3 крепления для оборудования · 2 места экипажа", "3 equipment mounts · 2 crew seats"), grid, "vehicle", type)
		var caption := words("КУПИТЬ И ПРИЦЕПИТЬ · %d КР.", "BUY & ATTACH · %d CR") % definition.cost
		if active:
			caption = words("ПОКУПКА НА БАЗЕ · %d КР.", "BUY AT BASE · %d CR") % definition.cost
		elif owned.size() >= int(state.get("max_wagons", 6)):
			caption = words("УЖЕ КУПЛЕНО 6 ПРИЦЕПОВ", "ALL 6 TRAILERS OWNED")
		elif credits < int(definition.cost):
			caption = words("НЕ ХВАТАЕТ %d КР.", "NEED %d MORE CR") % (int(definition.cost) - credits)
		_action(column, caption, "buy_wagon", type, "", active or owned.size() >= int(state.get("max_wagons", 6)) or credits < int(definition.cost))
	var note := Styles.label(words("Покупка добавляет пустой прицеп в конец состава. Оружие и оборудование устанавливаются отдельно кнопкой ОБОРУДОВАНИЕ.", "Purchase attaches an empty trailer to your convoy. Choose EQUIP TRAILER afterwards to install weapons and equipment."), 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)

func show_equipment(id: String, bought: bool = false) -> void:
	equipment_wagon_id = id
	tab = "equipment"
	purchase_notice = words("КУПЛЕНО И ПРИЦЕПЛЕНО. Прицеп готов к следующему рейду.", "BOUGHT & ATTACHED. Your trailer is ready for the next raid.") if bought else ""
	_refresh()

func _equipment() -> void:
	var saved: Dictionary = {}
	var index := 0
	for wagon: Dictionary in state.get("wagons", []):
		if wagon.id == equipment_wagon_id:
			saved = wagon
			break
		index += 1
	if saved.is_empty():
		tab = "wagons"
		_wagons()
		return
	var attached: bool = state.get("selected_wagon_ids", []).has(equipment_wagon_id)
	var heading_row := HBoxContainer.new()
	content.add_child(heading_row)
	var title := Styles.label(_wagon_title(saved, index) + " · " + (words("ПРИЦЕПЛЕН", "ATTACHED") if attached else words("В ГАРАЖЕ", "IN GARAGE")), 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading_row.add_child(title)
	var ready_button := Styles.button(words("К СОСТАВУ", "BACK TO CONVOY"))
	Icons.apply(ready_button, "base")
	ready_button.pressed.connect(func() -> void: tab = "wagons"; purchase_notice = ""; _refresh())
	heading_row.add_child(ready_button)
	var occupied := {}
	for entry: Dictionary in saved.get("attachments", []):
		occupied[int(entry.slot)] = {"name": Catalog.ATTACHMENTS[entry.type]["name" if Locale.language == "ru" else "name_en"], "attachment": true, "refund": int(Catalog.ATTACHMENTS[entry.type].cost) / 2}
	for module: Dictionary in saved.get("modules", []):
		occupied[int(module.get("mount", {}).get("slot", -1))] = {"name": Locale.text(str(module.get("def", {}).get("name", module.get("type", ""))))}
	var mount_grid := GridContainer.new()
	mount_grid.columns = 3
	mount_grid.add_theme_constant_override("h_separation", 10)
	content.add_child(mount_grid)
	var next_free := -1
	for slot in 3:
		var mount := _row(words("Крепление %d", "Mount %d") % (slot + 1), str(occupied[slot].name) if occupied.has(slot) else words("Свободно", "Empty"), mount_grid)
		if not occupied.has(slot) and next_free < 0:
			next_free = slot
		if occupied.has(slot) and occupied[slot].get("attachment", false):
			_action(mount, words("СНЯТЬ · +%d КР.", "REMOVE · +%d CR") % occupied[slot].refund, "remove_attachment", equipment_wagon_id, str(slot))
	var target := words("Выберите оборудование ниже. Покупка установит его на крепление %d.", "Choose equipment below. Purchase installs it on mount %d.") % (next_free + 1) if next_free >= 0 else words("Все крепления заняты. Снимите оборудование, чтобы установить другое.", "All mounts are occupied. Remove equipment to install another item.")
	var hint := Styles.label(target + "\n" + words("Станции усиливают соответствующего члена экипажа. Оружие ставится в Арсенале во время рейда.", "Stations improve their matching crew member. Fit weapons in the Armory during a raid."), 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	var grid := _grid()
	for row: Dictionary in state.get("attachment_rows", {}).get(equipment_wagon_id, []):
		var definition: Dictionary = Catalog.ATTACHMENTS[row.type]
		var description := _attachment_description(str(row.type))
		var column := _row(definition["name" if Locale.language == "ru" else "name_en"], description, grid, "attachment", str(row.type))
		var installed: bool = saved.get("attachments", []).any(func(entry: Dictionary) -> bool: return entry.type == row.type)
		var caption := words("УСТАНОВИТЬ · %d КР.", "INSTALL · %d CR") % row.cost
		if installed:
			caption = words("УСТАНОВЛЕНО", "INSTALLED")
		elif next_free < 0:
			caption = words("НЕТ СВОБОДНОГО КРЕПЛЕНИЯ", "NO EMPTY MOUNT")
		elif credits < int(row.cost):
			caption = words("НЕ ХВАТАЕТ %d КР.", "NEED %d MORE CR") % (int(row.cost) - credits)
		_action(column, caption, "install_attachment", str(row.id), "", not row.get("enabled", false))

func _attachment_description(type: String) -> String:
	var descriptions := {
		"turret": ["Стрелок: урон ×1.3", "Gunner: damage ×1.3"],
		"repair_station": ["Механик: ремонт ×1.5", "Mechanic: repair ×1.5"],
		"ammo_feed": ["Заряжающий: эффективность ×1.5", "Loader: efficiency ×1.5"],
		"cargo_rack": ["Вместимость добычи +4", "Loot capacity +4"],
		"salvage_arm": ["Сборщик: эффективность ×1.35", "Scavenger: efficiency ×1.35"],
		"fuel_pump": ["Топливщик: эффективность ×1.35", "Fuel operator: efficiency ×1.35"],
		"anti_tank_station": ["ПТ-стрелок: урон ×1.4", "Anti-tank gunner: damage ×1.4"],
		"anti_air_station": ["Зенитчик: урон ×1.4", "Anti-air gunner: damage ×1.4"],
		"armor_panels": ["Прочность корпуса +80", "Hull strength +80"],
		"reinforced_hitch": ["Прочность сцепки ×1.5", "Hitch strength ×1.5"]}
	var pair: Array = descriptions.get(type, ["", ""])
	return words(pair[0], pair[1])

func _crew() -> void:
	var people: Array = state.get("crew", [])
	var active: bool = state.get("active", false)
	if people.is_empty():
		content.add_child(Styles.label(words("Найдите нейтрального выжившего в рейде, спасите его и вывезите живым.", "Find a neutral survivor in a raid, rescue them and extract with them alive."), 16))
	var grid := _grid()
	for person: Dictionary in people:
		var definition: Dictionary = state.get("roles", {}).get(person.role, {})
		var title := str(definition.get("name" if Locale.language == "ru" else "name_en", person.role))
		var selected: bool = state.get("selected_crew_ids", []).has(person.id)
		var personal_name: String = preload("res://modules/crew/crew_encounter.gd").NAMES[clampi(int(person.get("identity", 0)), 0, 7)][0 if Locale.language == "ru" else 1]
		var column := _row(personal_name + " · " + title, words("Здоровье %.0f  |  Зарплата %d лома за рейд", "Health %.0f  |  Wage %d scrap per raid") % [person.hp, definition.get("wage", 0)], grid)
		if active:
			column.add_child(Styles.label(_crew_state(str(person.get("state", ""))), 14))
		else:
			_action(column, words("ОСТАВИТЬ В УБЕЖИЩЕ", "LEAVE AT BASE") if selected else words("НАЗНАЧИТЬ В РЕЙД", "DEPLOY CREW"), "select_crew", person.id, "0" if selected else "1")
		if not active and person.role == "civilian":
			var training := OptionButton.new()
			training.custom_minimum_size.y = 36
			var professions: Array[String] = []
			for role: String in state.get("roles", {}):
				if role == "civilian":
					continue
				professions.append(role)
				var entry: Dictionary = state.roles[role]
				training.add_item(str(entry.name if Locale.language == "ru" else entry.name_en))
			var training_row := HBoxContainer.new()
			column.add_child(training_row)
			training.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			training_row.add_child(training)
			var learn := Styles.button(words("ОБУЧИТЬ · 30 ЛОМА", "TRAIN · 30 SCRAP"))
			learn.disabled = scrap < preload("res://modules/crew/crew_catalog.gd").TRAINING_COST or state.get("locked", false)
			learn.pressed.connect(func(): action_requested.emit("train_crew", person.id, professions[training.selected]))
			training_row.add_child(learn)
		if not active and selected and scrap < int(definition.get("wage", 0)):
			column.add_child(Styles.label(words("Не хватает лома: останется в убежище.", "Insufficient scrap: will remain at base."), 14))
		var assigned := str(person.get("carrier_id", ""))
		var destination := words("Место подберётся автоматически", "Seat assigned automatically")
		if assigned == "crawler":
			destination = words("Пикап", "Pickup")
		else:
			for wagon: Dictionary in state.get("wagons", []):
				if wagon.id == assigned:
					var wagon_type: Dictionary = state.get("types", {}).get(wagon.type, {})
					destination = str(wagon_type.get("name" if Locale.language == "ru" else "name_en", assigned))
		column.add_child(Styles.label(destination, 13))

func set_embedded(value: bool) -> void:
	embedded = value
	if is_instance_valid(top):
		top.visible = not value

func _crew_state(value: String) -> String:
	var labels := {"boarded": ["На борту", "On board"], "repairing": ["Ремонтирует", "Repairing"], "shooting": ["Стреляет", "Firing"], "reloading": ["Заряжает", "Reloading"], "collecting": ["Идёт за добычей", "Collecting loot"], "returning": ["Возвращается", "Returning"], "waiting_carrier": ["Нужно новое место", "Needs a new assignment"], "cargo_full": ["Ждёт разгрузки у борта", "Waiting to unload"], "dead": ["Погиб", "Dead"], "airborne": ["Поднят торнадо", "Airborne"], "blocked": ["Путь перекрыт", "Route blocked"], "waiting_weapon": ["Ожидает оружие", "Waiting for weapon"], "stranded": ["Ждёт спасения", "Awaiting rescue"], "approaching": ["Идёт к вагону", "Walking to wagon"], "boarding": ["Залезает на борт", "Climbing aboard"]}
	var pair: Array = labels.get(value, ["Ожидает", "Waiting"])
	return words(pair[0], pair[1])

func _notice(value: String) -> String:
	if Locale.language == "ru":
		return value
	if value == "Не удалось сохранить состав. Действие отменено.":
		return "Could not save the convoy. Action cancelled."
	if "сотрудников остались в убежище без оплаты." in value:
		return "%d unpaid crew stayed at base." % value.to_int()
	return value

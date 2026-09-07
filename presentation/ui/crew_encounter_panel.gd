extends ColorRect

signal decided(action: String)
const Styles = preload("res://presentation/ui/ui_styles.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Encounter = preload("res://modules/crew/crew_encounter.gd")
const Catalog = preload("res://modules/crew/crew_catalog.gd")
var title: Label
var story: Label
var detail: Label
var decline: Button
var later: Button
var hire: Button
var panel: PanelContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.02, 0.03, 0.04, 0.78)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#202c2e")
	box.border_color = Color("#8e9b83")
	box.set_border_width_all(1)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 20
	box.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	title = Styles.label("", 23)
	column.add_child(title)
	story = Styles.label("", 18)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(story)
	detail = Styles.label("", 15)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	hire = Styles.button("")
	hire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hire.pressed.connect(func(): decided.emit("hire"))
	actions.add_child(hire)
	decline = Styles.button(words("ОТКАЗАТЬСЯ", "DECLINE"))
	decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decline.pressed.connect(func(): decided.emit("decline"))
	actions.add_child(decline)
	later = Styles.button(words("ПОГОВОРИМ ПОЗЖЕ [ESC]", "TALK LATER [ESC]"))
	later.pressed.connect(func(): decided.emit("later"))
	column.add_child(later)
	resized.connect(_resize)
	_resize()
	hide()

func _resize() -> void:
	if is_instance_valid(panel):
		panel.custom_minimum_size.x = clampf(size.x - 32, 280, 560)

static func words(ru: String, en: String) -> String:
	return ru if Locale.language == "ru" else en

func show_person(person: Dictionary, roster: RefCounted) -> void:
	Locale.initialize()
	decline.text = words("ОТКАЗАТЬСЯ", "DECLINE")
	later.text = words("ПОГОВОРИМ ПОЗЖЕ [ESC]", "TALK LATER [ESC]")
	var lang := 0 if Locale.language == "ru" else 1
	var identity := clampi(int(person.get("identity", 0)), 0, Encounter.NAMES.size() - 1)
	var role: Dictionary = Catalog.ROLES[person.role]
	title.text = str(Encounter.NAMES[identity][lang]) + " · " + str(role.name if lang == 0 else role.name_en)
	story.text = words("Меня зовут %s. ", "My name is %s. ") % Encounter.NAMES[identity][lang] + Encounter.STORIES[identity % Encounter.STORIES.size()][lang]
	story.text += "\n\n" + (words("Профессии у меня пока нет, но я хочу учиться. Возьми меня с собой.", "I have no trade yet, but I am willing to learn. Take me with you.") if person.role == "civilian" else words("Я %s. Буду работать в твоём караване. Возьмёшь меня?", "I am a %s. I can work in your convoy. Will you take me?") % str(role.name if lang == 0 else role.name_en).to_lower())
	var seat := Encounter.seat(roster, str(person.role))
	hire.text = words("НАНЯТЬ", "RECRUIT")
	hire.disabled = seat.is_empty()
	if seat.is_empty():
		detail.text = words("Нужно свободное место в грузовом вагоне.", "A free seat in a cargo wagon is required.") if person.role == "civilian" else words("В составе нет свободных мест.", "There are no free seats in the convoy.")
	else:
		var destination := words("Пикап", "Pickup")
		if seat.carrier_id != "crawler":
			var wagon: Dictionary = roster.find_wagon(seat.carrier_id)
			destination = str(wagon.get("name" if lang == 0 else "name_en", seat.carrier_id))
		detail.text = words("Место: %s · Зарплата: %d лома за следующий рейд.", "Seat: %s · Wage: %d scrap next raid.") % [destination, role.wage]
		if person.role == "civilian":
			detail.text += "\n" + words("После эвакуации: обучение на базе за %d лома.", "After extraction: training at base for %d scrap.") % Catalog.TRAINING_COST
	show()

func show_error() -> void:
	detail.text = words("Нанять не удалось: проверь места и состояние выжившего.", "Could not recruit: check seating and the survivor's condition.")

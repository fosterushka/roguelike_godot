extends CanvasLayer

signal selected(index: int)
signal overview_requested
const PANEL_WIDTH := 292.0
var search: LineEdit
var categories: OptionButton
var listing: ItemList
var details: Label
var status: Label
var entries: Array[Dictionary] = []

func _ready() -> void:
	var panel := ColorRect.new()
	panel.color = Color("171e25")
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_right = PANEL_WIDTH
	add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	var title := Label.new()
	title.text = "MODEL GALLERY"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	status = Label.new()
	status.text = "Building models..."
	column.add_child(status)
	search = LineEdit.new()
	search.placeholder_text = "Поиск / search model ID"
	column.add_child(search)
	search.text_changed.connect(func(_text: String): _filter())
	categories = OptionButton.new()
	categories.fit_to_longest_item = false
	column.add_child(categories)
	categories.item_selected.connect(func(_index: int): _filter())
	var overview := Button.new()
	overview.text = "Вся карта [Home]"
	column.add_child(overview)
	overview.pressed.connect(func(): overview_requested.emit())
	listing = ItemList.new()
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(func(index: int): selected.emit(int(listing.get_item_metadata(index))))
	column.add_child(listing)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.y = 92
	column.add_child(details)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "WASD / стрелки: движение\nПКМ: обзор · СКМ: сдвиг\nКолесо: масштаб · F: к модели\nPage Up / Down: предыдущая / следующая"
	help.add_theme_font_size_override("font_size", 12)
	column.add_child(help)

func populate(rows: Array[Dictionary]) -> void:
	entries = rows
	categories.add_item("Все категории")
	var seen := {}
	for entry: Dictionary in rows:
		if not seen.has(entry.section):
			seen[entry.section] = true
			categories.add_item(entry.section)
	_filter()

func _filter() -> void:
	listing.clear()
	var query := search.text.to_lower()
	var category := categories.get_item_text(categories.selected) if categories.selected > 0 else ""
	for index in entries.size():
		var entry: Dictionary = entries[index]
		if not category.is_empty() and entry.section != category:
			continue
		if not query.is_empty() and not (entry.id + " " + entry.note).to_lower().contains(query):
			continue
		var row := listing.add_item(entry.title)
		listing.set_item_metadata(row, index)
		listing.set_item_tooltip(row, entry.id + "\n" + entry.note)
	status.text = "%d / %d models" % [listing.item_count, entries.size()]

func show_entry(index: int, dimensions: Vector3, scale_value: float) -> void:
	var entry: Dictionary = entries[index]
	details.text = "%s\n%s\n%.2f × %.2f × %.2f m · scale %.2f\n%s" % [entry.title, entry.section, dimensions.x, dimensions.y, dimensions.z, scale_value, entry.note]
	for row in listing.item_count:
		if int(listing.get_item_metadata(row)) == index:
			listing.select(row)
			listing.ensure_current_is_visible()
			break

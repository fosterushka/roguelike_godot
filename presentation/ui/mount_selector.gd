extends HBoxContainer

signal target_changed(mount: Dictionary)
const WagonCatalog = preload("res://modules/caravan/wagon_catalog.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
var carrier: OptionButton
var slot: OptionButton
var _player: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var caption := Label.new()
	caption.text = "НА" if Locale.language == "ru" else "ON"
	caption.add_theme_font_size_override("font_size", 11)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	carrier = OptionButton.new()
	carrier.fit_to_longest_item = false
	carrier.clip_text = true
	carrier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carrier.custom_minimum_size.y = 30
	carrier.add_theme_font_size_override("font_size", 11)
	carrier.item_selected.connect(_carrier_changed)
	add_child(carrier)
	slot = OptionButton.new()
	slot.custom_minimum_size = Vector2(130, 30)
	slot.add_theme_font_size_override("font_size", 11)
	slot.item_selected.connect(func(_index: int) -> void: target_changed.emit(selected_mount()))
	add_child(slot)

func set_build(player: Dictionary) -> void:
	(get_child(0) as Label).text = "НА" if Locale.language == "ru" else "ON"
	var previous := selected_mount()
	_player = player
	carrier.clear()
	carrier.add_item("Пикап" if Locale.language == "ru" else "Pickup")
	carrier.set_item_metadata(0, "crawler")
	for index in player.get("carriers", []).size():
		var definition: Dictionary = WagonCatalog.TYPES.get(str(player.carriers[index].get("type", "")), {})
		carrier.add_item("%d. %s" % [index + 1, definition.get("name" if Locale.language == "ru" else "name_en", Locale.text("Прицеп %d") % (index + 1))])
		carrier.set_item_metadata(index + 1, str(player.carriers[index].id))
	for index in carrier.item_count:
		if carrier.get_item_metadata(index) == previous.get("carrierId", "crawler"):
			carrier.select(index)
	if carrier.selected < 0:
		carrier.select(0)
	_rebuild_slots(int(previous.get("slot", -1)))

func selected_mount() -> Dictionary:
	if carrier == null or carrier.item_count == 0 or carrier.selected < 0:
		return {}
	return {"carrierId": str(carrier.get_item_metadata(carrier.selected)), "slot": slot.get_item_id(slot.selected) if slot.selected >= 0 else -1}

func valid_target() -> bool:
	for entry: Dictionary in _player.get("carriers", []):
		if str(entry.id) == selected_carrier() and (entry.get("dead", false) or not entry.get("attached", true)):
			return false
	return slot.selected >= 0 and not slot.is_item_disabled(slot.selected)

func _carrier_changed(_index: int) -> void:
	_rebuild_slots()
	target_changed.emit(selected_mount())

func _rebuild_slots(preferred: int = -1) -> void:
	slot.clear()
	slot.visible = carrier.selected >= 0
	if not slot.visible:
		return
	var id := str(carrier.get_item_metadata(carrier.selected))
	var count := 12 if id == "crawler" else 0
	for entry: Dictionary in _player.get("carriers", []):
		if str(entry.id) == id:
			count = int(entry.get("slotCount", 3))
	var first_free := -1
	for index in count:
		var occupied: bool = _player.get("modules", []).any(func(module: Dictionary) -> bool: return module.get("mount", {}).get("carrierId", "") == id and int(module.get("mount", {}).get("slot", -1)) == index)
		for entry: Dictionary in _player.get("carriers", []):
			if str(entry.id) == id:
				occupied = occupied or entry.get("attachments", []).any(func(item: Dictionary) -> bool: return int(item.slot) == index)
		slot.add_item(("Занято %d" if occupied else "Крепление %d") % (index + 1) if Locale.language == "ru" else ("Occupied %d" if occupied else "Mount %d") % (index + 1), index)
		slot.set_item_disabled(index, occupied)
		if not occupied and first_free < 0:
			first_free = index
	if preferred >= 0 and preferred < count and not slot.is_item_disabled(preferred):
		slot.select(preferred)
	elif first_free >= 0:
		slot.select(first_free)
	else:
		slot.select(-1)
		slot.text = Locale.text("Нет свободных слотов")

func selected_carrier() -> String:
	return str(selected_mount().get("carrierId", "crawler"))

func select_carrier(id: String) -> void:
	for index in carrier.item_count:
		if str(carrier.get_item_metadata(index)) == id:
			carrier.select(index)
			_carrier_changed(index)
			return

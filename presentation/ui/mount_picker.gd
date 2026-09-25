extends HFlowContainer

signal selected(slot: int)
const Styles = preload("res://presentation/ui/ui_styles.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")

func display(count: int, occupied: Dictionary, selection: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 4)
	for index in count:
		var button := Styles.button(str(index + 1) + (" *" if occupied.has(index) else ""))
		button.custom_minimum_size = Vector2(40, 36)
		button.tooltip_text = ("Крепление %d: " if Locale.language == "ru" else "Mount %d: ") % (index + 1) + str(occupied.get(index, "Свободно" if Locale.language == "ru" else "Empty"))
		button.set_meta("mount_slot", index)
		Styles.tab(button, index == selection)
		button.pressed.connect(func() -> void: selected.emit(index))
		add_child(button)

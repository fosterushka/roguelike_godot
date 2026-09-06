extends Label

const Locale = preload("res://presentation/ui/ui_locale.gd")

func _ready() -> void:
	position = Vector2(12, 64)
	size = Vector2(250, 160)
	get_viewport().size_changed.connect(_layout)
	_layout()
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 12)
	add_theme_color_override("font_color", Color("fff0c9"))
	add_theme_color_override("font_shadow_color", Color("142126"))
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)
	visible = false

func _layout() -> void:
	size.x = clampf((get_viewport_rect().size.x - 560.0) * 0.5 - 24.0, 120.0, 250.0)

func update_missions(rows: Array) -> void:
	visible = not rows.is_empty()
	if rows.is_empty():
		return
	var ru := Locale.language == "ru"
	var lines: Array[String] = ["ЗАДАНИЯ [I] · СОХРАНЯЮТСЯ ПРИ ЭВАКУАЦИИ" if ru else "MISSIONS [I] · EXTRACT TO SAVE PROGRESS"]
	for row: Dictionary in rows.slice(0, 3):
		var title := str(row.get("name", row.get("title", row.id))) if ru else str(row.get("name_en", row.get("title", row.id)))
		var progress: Array[String] = []
		for objective: Dictionary in row.get("objectives", []):
			var current := float(objective.get("progress", objective.get("current", 0))) + float(objective.get("raid_progress", 0))
			progress.append("%d/%d" % [mini(floori(current), int(objective.target)), int(objective.target)])
		lines.append(title + "  " + " · ".join(progress))
	if rows.size() > 3:
		lines.append(("Ещё %d в журнале [I]" if ru else "%d more in journal [I]") % (rows.size() - 3))
	text = "\n".join(lines)

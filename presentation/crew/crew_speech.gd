extends PanelContainer
# One screen-space bubble owns both background and wrapped text.
signal interaction_requested
var label: Label
var prompt: Button
var negative := false
var positive := false
var message := ""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1c292b")
	style.border_color = Color("#718580")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	label = Label.new()
	label.custom_minimum_size.x = 206
	label.size.x = 206
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("#f1e8cf"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	add_child(column)
	column.add_child(label)
	prompt = Button.new()
	prompt.text = "E"
	prompt.custom_minimum_size = Vector2(32, 28)
	prompt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	prompt.focus_mode = Control.FOCUS_NONE
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color.TRANSPARENT
	key_style.border_color = Color("#f1e8cf")
	key_style.set_border_width_all(2)
	prompt.add_theme_stylebox_override("normal", key_style)
	prompt.add_theme_stylebox_override("hover", key_style)
	prompt.add_theme_stylebox_override("pressed", key_style)
	var dim_style := key_style.duplicate() as StyleBoxFlat
	dim_style.border_color = Color("#455452")
	prompt.add_theme_stylebox_override("disabled", dim_style)
	prompt.add_theme_color_override("font_disabled_color", Color("#63716d"))
	prompt.pressed.connect(func(): interaction_requested.emit())
	column.add_child(prompt)
	prompt.hide()
	hide()

func show_message(text: String, smile: bool = false, sad: bool = false) -> void:
	message = text
	positive = smile
	negative = sad
	label.custom_minimum_size.y = 48 if sad else 0
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if sad else VERTICAL_ALIGNMENT_CENTER
	label.visible = not smile
	label.text = "\n\n" + text if sad else text
	custom_minimum_size = Vector2(48, 48) if smile else Vector2(230, 0)
	size = Vector2(48, 48) if smile else Vector2(230, 0)
	reset_size()
	queue_redraw()

func show_interaction(displayed: bool, available: bool) -> void:
	prompt.visible = displayed
	prompt.disabled = not available

func _draw() -> void:
	var center := Vector2(size.x * .5, 24)
	if positive or negative:
		draw_circle(center, 16, Color("#d1ad78") if negative else Color("#77c875"))
		draw_circle(center + Vector2(-5, -4), 2, Color("#18372b"))
		draw_circle(center + Vector2(5, -4), 2, Color("#18372b"))
		if negative:
			draw_arc(center + Vector2(0, 12), 8, PI + 0.35, TAU - 0.35, 20, Color("#18372b"), 2, true)
		else:
			draw_arc(center + Vector2(0, -1), 9, 0.25, PI - 0.25, 20, Color("#18372b"), 2, true)
	draw_colored_polygon(PackedVector2Array([Vector2(size.x/2-5, size.y), Vector2(size.x/2+5, size.y), Vector2(size.x/2, size.y+6)]), Color("#1c292b"))

func follow(camera: Camera3D, point: Vector3) -> void:
	visible = camera != null and not camera.is_position_behind(point)
	if not visible:
		return
	size.y = get_combined_minimum_size().y
	var screen := camera.unproject_position(point)
	var bounds := get_viewport_rect().size
	visible = Rect2(Vector2.ZERO, bounds).has_point(screen)
	position = Vector2(clampf(screen.x - size.x/2, 8, maxf(8, bounds.x-size.x-8)), maxf(8, screen.y-size.y-10))

extends PanelContainer
# One screen-space bubble owns both background and wrapped text.
var label: Label
var positive := false

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
	add_child(label)
	hide()

func show_message(text: String, smile: bool = false) -> void:
	positive = smile
	label.visible = not smile
	label.text = text
	custom_minimum_size = Vector2(48, 48) if smile else Vector2(230, 0)
	size = Vector2(48, 48) if smile else Vector2(230, 0)
	reset_size()
	queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x * .5, 24)
	if positive:
		draw_circle(center, 16, Color("#77c875"))
		draw_circle(center + Vector2(-5, -4), 2, Color("#18372b"))
		draw_circle(center + Vector2(5, -4), 2, Color("#18372b"))
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

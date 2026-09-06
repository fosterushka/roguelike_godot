extends "res://presentation/ui/item_model_preview.gd"

## One non-interactive overlay per panel. It follows the hovered/focused source
## and dismisses itself when that source scrolls out of the visible viewport.
var _source: Control
var _title: Label

func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(310, 186)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 20
	visible = false
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101713", 0.0)
	style.border_color = Color("e6ac58")
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)
	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.position = Vector2(10, 8)
	_title.add_theme_font_size_override("font_size", 13)
	_title.add_theme_color_override("font_color", Color("f4dfac"))
	add_child(_title)

func show_for(source: Control, kind: String, id: String, title: String) -> void:
	if source == null or not is_instance_valid(source):
		hide_preview()
		return
	_source = source
	_title.text = title
	set_preview(kind, id)
	visible = true
	_request_frame()
	_reposition()
	set_process(true)

func hide_preview() -> void:
	_source = null
	visible = false
	set_process(false)
	set_rendering(false)

func _process(_delta: float) -> void:
	if _source == null or not is_instance_valid(_source) or not _source.is_visible_in_tree():
		hide_preview()
		return
	if not _source_is_visible():
		hide_preview()
		return
	_reposition()

func _source_is_visible() -> bool:
	var visible_rect := get_viewport().get_visible_rect()
	var node: Node = _source
	while node != null:
		if node is Control:
			var control := node as Control
			if not control.visible:
				return false
			if control.clip_contents:
				visible_rect = visible_rect.intersection(control.get_global_rect())
				if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
					return false
		node = node.get_parent()
	return _source.get_global_rect().intersects(visible_rect)

func _reposition() -> void:
	if _source == null or not is_instance_valid(_source):
		return
	var screen := get_viewport().get_visible_rect()
	var source_rect := _source.get_global_rect()
	var candidate := source_rect.position + Vector2(source_rect.size.x + 10, 0)
	if candidate.x + size.x > screen.end.x - 8:
		candidate.x = source_rect.position.x - size.x - 10
	candidate.x = clampf(candidate.x, screen.position.x + 8, screen.end.x - size.x - 8)
	candidate.y = clampf(candidate.y, screen.position.y + 8, screen.end.y - size.y - 8)
	global_position = candidate

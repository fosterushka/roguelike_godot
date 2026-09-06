extends Node

const Preview = preload("res://presentation/ui/item_model_preview.gd")
const Pip = preload("res://presentation/ui/item_preview_pip.gd")
var thumbnail: ItemModelPreview
var pip
var source: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	get_window().size = Vector2i(640, 360)
	get_tree().root.content_scale_size = Vector2i(640, 360)
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("141f22")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	var caption := Label.new()
	caption.position = Vector2(20, 18)
	caption.add_theme_font_size_override("font_size", 18)
	caption.text = "MODEL PREVIEW FIT · thumbnail 58×52 · PIP 310×186"
	canvas.add_child(caption)
	source = Button.new()
	source.position = Vector2(20, 90)
	source.size = Vector2(176, 64)
	source.text = "HOVER TARGET"
	canvas.add_child(source)
	thumbnail = Preview.new()
	thumbnail.name = "ActualThumbnail58x52"
	thumbnail.position = Vector2(212, 96)
	thumbnail.size = Vector2(58, 52)
	canvas.add_child(thumbnail)
	pip = Pip.new()
	pip.name = "ActualPip310x186"
	pip.position = Vector2(304, 88)
	canvas.add_child(pip)
	await _capture_model("assaultRifle", "module", "M4", "m4")
	await _capture_model("bumper", "module", "WIDE BUMPER", "bumper")
	await _capture_model("crawler", "vehicle", "PICKUP", "pickup")
	canvas.queue_free()
	await get_tree().process_frame
	print("ITEM_PREVIEW_CAPTURE_DONE")
	get_tree().quit()

func _capture_model(id: String, kind: String, title: String, output: String) -> void:
	thumbnail.set_preview(kind, id)
	pip.show_for(source, kind, id, title)
	for frame in 6:
		await get_tree().process_frame
	assert(thumbnail.viewport.size == Vector2i(58, 52), "Thumbnail must use its final layout aspect")
	assert(pip.viewport.size == Vector2i(310, 186), "PIP must use its final layout aspect")
	assert(is_instance_valid(thumbnail._model) and thumbnail._model.get_child_count() > 0, "Capture requires a real model")
	await RenderingServer.frame_post_draw
	var path := "/private/tmp/item-preview-%s.png" % output
	var status := get_viewport().get_texture().get_image().save_png(path)
	print("ITEM_PREVIEW_CAPTURE %s status=%d camera=%.3f" % [path, status, pip.camera.size])

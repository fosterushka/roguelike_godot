extends SceneTree

const Preview = preload("res://presentation/ui/item_model_preview.gd")
const Pip = preload("res://presentation/ui/item_preview_pip.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var trigger := Button.new()
	trigger.position = Vector2(8, 8)
	trigger.size = Vector2(74, 42)
	host.add_child(trigger)
	var thumbnail := Preview.new()
	thumbnail.position = Vector2(100, 8)
	thumbnail.size = Vector2(96, 56)
	host.add_child(thumbnail)
	thumbnail.set_preview("module", "bazooka")
	await process_frame
	_check(is_instance_valid(thumbnail._model) and thumbnail._model.get_meta("equipment_type") == "bazooka", "Module thumbnail uses the runtime equipment model")
	thumbnail.set_preview("vehicle", "cargo")
	await process_frame
	_check(is_instance_valid(thumbnail._model) and thumbnail._model.get_child_count() > 0, "Vehicle thumbnail builds the runtime wagon model")
	thumbnail.set_preview("loot", "relic")
	await process_frame
	_check(is_instance_valid(thumbnail._model) and thumbnail._model.name == "LootModel_relic" and thumbnail._model.get_child_count() == 2, "Rare loot thumbnail has its own physical silhouette")
	thumbnail.set_preview("module", "bumper")
	thumbnail.size = Vector2(160, 52)
	await process_frame
	await process_frame
	var wide_camera_size := thumbnail.camera.size
	thumbnail.size = Vector2(52, 120)
	await process_frame
	await process_frame
	_check(thumbnail.viewport.size == Vector2i(52, 120) and thumbnail.camera.size > wide_camera_size, "Viewport and camera refit after a narrow thumbnail layout so wide models are not cropped")
	var pip := Pip.new()
	host.add_child(pip)
	pip.show_for(trigger, "loot", "relic", "Relic")
	await process_frame
	_check(pip.visible and pip.mouse_filter == Control.MOUSE_FILTER_IGNORE and pip.focus_mode == Control.FOCUS_NONE, "Hover PIP is visible but cannot block pointer or keyboard input")
	var screen := root.get_viewport().get_visible_rect()
	_check(pip.get_global_rect().position.x >= screen.position.x and pip.get_global_rect().end.x <= screen.end.x, "PIP is clamped inside the viewport")
	trigger.visible = false
	await process_frame
	_check(not pip.visible and pip.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "PIP hides and stops rendering when its source is hidden")
	host.queue_free()
	await process_frame
	paused = false
	print("Item previews: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

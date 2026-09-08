extends CanvasLayer

# Final screen pass: shares the world's authoritative boundary state, with no radius copy.
const DESATURATION = preload("res://presentation/ui/screen_desaturation.gdshader")
const FINAL_SCREEN_LAYER := 20
var outside := false
var gameplay_active := false
var overlay: ColorRect

func _ready() -> void:
	name = "BoundaryDesaturation"
	layer = FINAL_SCREEN_LAYER
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	overlay = ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = DESATURATION
	overlay.material = shader_material
	add_child(overlay)
	_refresh()

func update_world(state: Dictionary) -> void:
	outside = bool(state.get("boundary", {}).get("outside", false))
	_refresh()

func set_gameplay_active(active: bool) -> void:
	gameplay_active = active
	_refresh()

func reset() -> void:
	outside = false
	_refresh()

func _refresh() -> void:
	visible = gameplay_active and outside

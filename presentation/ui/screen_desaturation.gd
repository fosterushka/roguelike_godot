extends CanvasLayer

# Final screen pass: shares the world's authoritative boundary state, with no radius copy.
const DESATURATION = preload("res://presentation/ui/screen_desaturation.gdshader")
const FINAL_SCREEN_LAYER := 20
const Locale = preload("res://presentation/ui/ui_locale.gd")
const FADE_IN_SECONDS := 0.8
const FADE_OUT_SECONDS := 1.2
const PULSE_SECONDS := 1.6
const WARNING_FONT_SIZE := 28
var strength := 0.0
var elapsed := 0.0
var warning: Label
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
	warning = Label.new()
	warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning.add_theme_font_size_override("font_size", WARNING_FONT_SIZE)
	warning.add_theme_color_override("font_color", Color("fff0cf"))
	warning.add_theme_color_override("font_outline_color", Color("201b16"))
	warning.add_theme_constant_override("outline_size", 4)
	add_child(warning)
	_refresh()

func update_world(state: Dictionary) -> void:
	outside = bool(state.get("boundary", {}).get("outside", false))
	_refresh()

func set_gameplay_active(active: bool) -> void:
	gameplay_active = active
	_refresh()

func reset() -> void:
	outside = false
	strength = 0.0
	elapsed = 0.0
	_refresh()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not gameplay_active:
		return
	var safe_delta := maxf(delta, 0.0)
	strength = move_toward(strength, 1.0 if outside else 0.0, safe_delta / (FADE_IN_SECONDS if outside else FADE_OUT_SECONDS))
	elapsed += safe_delta
	_refresh()

func _refresh() -> void:
	visible = gameplay_active and (outside or strength > 0.0)
	overlay.material.set_shader_parameter("strength", smoothstep(0.0, 1.0, strength))
	warning.text = Locale.text("ВЕРНИТЕСЬ В ЗОНУ")
	warning.modulate.a = smoothstep(0.0, 1.0, strength) * (0.75 + 0.25 * cos(elapsed * TAU / PULSE_SECONDS))

extends Control

const Locale = preload("res://presentation/ui/ui_locale.gd")
const Styles = preload("res://presentation/ui/ui_styles.gd")
const FADE_SECONDS := 0.3
var glyph: Label
var subtitle: Label
var _step := -1
var _pulse_age := 0.0
var _fade_remaining := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://presentation/ui/countdown_blur.gdshader")
	veil.material = material
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)
	glyph = Styles.label("3", 96)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.add_theme_color_override("font_color", Color("fef3c7"))
	var heavy_font := SystemFont.new()
	heavy_font.font_names = PackedStringArray(["Arial Black", "Arial", "Noto Sans"])
	heavy_font.font_weight = 900
	glyph.add_theme_font_override("font", heavy_font)
	column.add_child(glyph)
	subtitle = Styles.label("", 12)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	var caption_font := FontVariation.new()
	caption_font.base_font = heavy_font
	caption_font.spacing_glyph = 4
	subtitle.add_theme_font_override("font", caption_font)
	column.add_child(subtitle)
	visible = false

func set_step(step: int, show: bool) -> void:
	if not show:
		visible = false
		_fade_remaining = 0.0
		return
	if not visible or _step != step:
		_pulse_age = 0.0
	_step = step
	_fade_remaining = 0.0
	modulate.a = 1.0
	visible = true
	glyph.text = str(step) if step > 0 else Locale.text("RIDE!")
	subtitle.text = Locale.text("Prepare the crawler" if step > 0 else "Break the siege").to_upper()

func finish() -> void:
	if visible:
		_fade_remaining = FADE_SECONDS

func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_age += delta
	glyph.modulate.a = 0.75 + cos(_pulse_age * PI) * 0.25
	if _fade_remaining > 0.0:
		_fade_remaining = maxf(0.0, _fade_remaining - delta)
		modulate.a = _fade_remaining / FADE_SECONDS
		if _fade_remaining <= 0.0:
			visible = false

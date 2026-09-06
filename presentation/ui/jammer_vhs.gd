extends ColorRect

const VHS = preload("res://presentation/ui/jammer_vhs.gdshader")
var intensity := 0.0

func _ready() -> void:
	name = "JammerVHS"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	material = ShaderMaterial.new()
	material.shader = VHS
	visible = false

func update_state(state: Dictionary) -> void:
	var player: Dictionary = state.get("player", {})
	var strength := clampf(float(player.get("jammer_strength", 0.0)), 0, 1)
	var jammed := bool(player.get("jammed", false))
	# Even the outer edge of the active radius needs a readable signal warning.
	intensity = maxf(strength, 0.32 if jammed else 0.0)
	if float(player.get("hp", 0)) <= 0:
		intensity = 0.0
	visible = intensity > 0.001
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("pulse", clampf(float(player.get("jammer_pulse", 0.0)), 0, 1))

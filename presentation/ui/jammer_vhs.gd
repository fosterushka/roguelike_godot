extends ColorRect

const VHS = preload("res://presentation/ui/jammer_vhs.gdshader")
const Weather = preload("res://modules/world/weather_rules.gd")
var intensity := 0.0
var wetness := 0.0
var rain_target := 0.0

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
	_refresh_visibility()
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("pulse", clampf(float(player.get("jammer_pulse", 0.0)), 0, 1))

func update_weather(state: Dictionary) -> void:
	var weather: Dictionary = state.get("weather", {})
	var phase: Dictionary = weather.get("phase_data", {"type": weather.get("type", "sunny")})
	var mix := Weather.mix_for_phase(phase, float(weather.get("elapsed", state.get("elapsed", 0))))
	var wind: Dictionary = state.get("wind", {})
	var strength := clampf(float(wind.get("strength", 0)) / 42.0, 0, 1)
	var direction: Vector3 = wind.get("direction", Vector3.RIGHT)
	rain_target = clampf((mix.z * 0.7 + mix.w) * (1 + strength * 0.2), 0, 1)
	material.set_shader_parameter("rain_wind", direction.x * strength)
	_refresh_visibility()

func _process(delta: float) -> void:
	if is_visible_in_tree():
		advance(delta)

func advance(delta: float) -> void:
	wetness = move_toward(wetness, rain_target, maxf(0, delta) / (1.8 if rain_target > wetness else 6.0))
	material.set_shader_parameter("rain", wetness)
	_refresh_visibility()

func reset_weather() -> void:
	wetness = 0
	rain_target = 0
	material.set_shader_parameter("rain", 0.0)
	_refresh_visibility()

func _refresh_visibility() -> void:
	visible = intensity > 0.001 or wetness > 0.001 or rain_target > 0.001

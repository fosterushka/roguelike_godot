extends Node3D

const SHADERS := [preload("res://presentation/world/weather_rain.gdshader"), preload("res://presentation/world/weather_splash.gdshader"), preload("res://presentation/world/weather_mist.gdshader")]
const CAPACITIES := [1100, 220, 20]
const RADII := [46.0, 38.0, 48.0]
const RAIN_LAYER := 0
const RAIN_DEPTH_RANGE := Vector2(6.0, 110.0)
const RAIN_SCREEN_MARGIN := 1.08
const RAIN_WIDTH_PIXELS := Vector2(0.7, 1.2)
var layers: Array[MultiMeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var elapsed := 0.0
var rain := 0.0
var storm := 0.0
var fog := 0.0
var lightning_life := 0.0
var drift := Vector2.ZERO
var targets := Vector3.ZERO
var warmup := false

func _ready() -> void:
	for index in 3:
		var visual := MultiMeshInstance3D.new()
		visual.multimesh = MultiMesh.new()
		visual.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		visual.multimesh.use_custom_data = true
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		visual.multimesh.mesh = quad
		visual.multimesh.instance_count = CAPACITIES[index]
		for particle in CAPACITIES[index]:
			visual.multimesh.set_instance_transform(particle, Transform3D.IDENTITY)
			visual.multimesh.set_instance_custom_data(particle, particle_data(particle, RADII[index]))
		visual.custom_aabb = AABB(Vector3(-2000, -10, -2000), Vector3(4000, 100, 4000))
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = SHADERS[index]
		if index == RAIN_LAYER:
			material.set_shader_parameter("uSeedRadius", RADII[RAIN_LAYER])
			material.set_shader_parameter("uDepthRange", RAIN_DEPTH_RANGE)
			material.set_shader_parameter("uScreenMargin", RAIN_SCREEN_MARGIN)
			material.set_shader_parameter("uStreakWidthPixels", RAIN_WIDTH_PIXELS)
		material.render_priority = [4, 2, 3][index]
		visual.material_override = material
		materials.append(material)
		layers.append(visual)
		add_child(visual)
	clear()

static func particle_data(index: int, radius: float) -> Color:
	return Color((seeded_unit(index, 1) * 2 - 1) * radius, (seeded_unit(index, 2) * 2 - 1) * radius, seeded_unit(index, 3), seeded_unit(index, 4))

static func seeded_unit(index: int, salt: int) -> float:
	return fposmod(sin((index + 1) * 12.9898 + salt * 78.233) * 43758.5453, 1.0)

func set_weather(type: String) -> void:
	targets = Vector3(0.72 if type == "rainy" else (1.0 if type == "storm" else 0.0), 1.0 if type == "storm" else 0.0, 1.0 if type == "foggy" else 0.0)

# The world view supplies the shared fade; legacy set_weather retains source behavior.
func set_mix(mix: Vector4) -> void:
	targets = Vector3(mix.z * 0.72 + mix.w, mix.w, mix.y)
	rain = targets.x
	storm = targets.y
	fog = targets.z

func flash_lightning() -> void:
	lightning_life = 0.28

func advance(delta: float, anchor: Vector3, velocity: Vector3, direction: Vector3, strength: float) -> void:
	if warmup:
		return
	if rain <= 0.003 and fog <= 0.003 and targets == Vector3.ZERO and lightning_life <= 0:
		for layer in layers:
			layer.visible = false
		return
	var safe_delta := maxf(0, delta)
	elapsed += safe_delta
	var blend := 1 - pow(0.01, safe_delta)
	rain = lerpf(rain, targets.x, blend)
	storm = lerpf(storm, targets.y, blend)
	fog = lerpf(fog, targets.z, blend)
	var wind := Vector2(direction.x, direction.z) * maxf(0, strength) * 0.18
	drift.x = fmod(drift.x + (wind.x + 1.3 * storm) * safe_delta, 4416)
	drift.y = fmod(drift.y + (wind.y + 0.5 * storm) * safe_delta, 4416)
	lightning_life = maxf(0, lightning_life - safe_delta)
	_apply(anchor, velocity, wind)

func _apply(anchor: Vector3, velocity: Vector3, wind: Vector2) -> void:
	for material in materials:
		material.set_shader_parameter("uTime", elapsed)
		material.set_shader_parameter("uAnchor", Vector2(anchor.x, anchor.z))
		material.set_shader_parameter("uPlayerVelocity", Vector2(velocity.x, velocity.z))
		material.set_shader_parameter("uWind", wind)
		material.set_shader_parameter("uDrift", drift)
		material.set_shader_parameter("uRain", rain)
		material.set_shader_parameter("uStorm", storm)
		material.set_shader_parameter("uFog", fog)
		material.set_shader_parameter("uLightning", lightning_life / 0.28)
	layers[0].visible = rain > 0.003 or warmup
	layers[1].visible = layers[0].visible
	layers[2].visible = layers[0].visible or fog > 0.003 or warmup

func clear() -> void:
	rain = 0
	storm = 0
	fog = 0
	lightning_life = 0
	elapsed = 0
	drift = Vector2.ZERO
	targets = Vector3.ZERO
	for layer in layers:
		layer.visible = false

func set_warmup_visible(enabled: bool, anchor: Vector3) -> void:
	warmup = enabled
	if enabled:
		rain = 1
		storm = 1
		fog = 1
		_apply(anchor, Vector3.ZERO, Vector2.ZERO)
	else:
		clear()

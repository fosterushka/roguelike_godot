extends Node3D

const DayCycle = preload("res://modules/world/day_cycle.gd")
const Rules = preload("res://modules/world/weather_rules.gd")
const Ground = preload("res://presentation/world/ground_surface_view.gd")
const MUD_TEXTURES := [preload("res://assets/textures/weather/mud-patch-a.png"), preload("res://assets/textures/weather/mud-rut-b.png"), preload("res://assets/textures/weather/mud-splash-c.png")]
const PRESETS := {
	"clear": {"fog": "bccbb2", "background": "b4c8bd", "density": 0.0036, "sun": 3.25, "rim": 0.58, "exposure": 1.04},
	"sunny": {"fog": "bccbb2", "background": "b4c8bd", "density": 0.0036, "sun": 3.25, "rim": 0.58, "exposure": 1.04},
	"foggy": {"fog": "a3b8b5", "background": "9dafb2", "density": 0.0135, "sun": 2.15, "rim": 0.38, "exposure": 0.96},
	"rainy": {"fog": "899eab", "background": "899cab", "density": 0.0054, "sun": 1.95, "rim": 0.34, "exposure": 0.96},
	"storm": {"fog": "798b9d", "background": "7b8a9e", "density": 0.0059, "sun": 1.7, "rim": 0.3, "exposure": 0.88}}
var externally_driven := false
var _visual_elapsed := 0.0
var _weather_type := ""
var _rim: DirectionalLight3D
var _wind_debris: MultiMeshInstance3D
var _vehicle: Node3D
var _environment: Environment
var _sun: DirectionalLight3D
var _mud: Array[MeshInstance3D] = []
var _rain: Node3D
var _tornado_view: Node3D
var _bolt: Node3D
var _seed := 72841
var _state: Dictionary = {}
var _flash := 0.0
var _warmup := false

func setup(arena: Node3D, vehicle: Node3D) -> void:
	_vehicle = vehicle
	_wind_debris = preload("res://presentation/world/wind_debris.gd").new()
	add_child(_wind_debris)
	for child in arena.get_children():
		if child is WorldEnvironment:
			_environment = child.environment
		elif child is DirectionalLight3D and child.name == "WastelandSun":
			_sun = child
		elif child is DirectionalLight3D and child.name == "WastelandRim":
			_rim = child
	for index in 10:
		var visual := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE
		visual.rotation_order = EULER_ORDER_XYZ
		visual.rotation.x = -PI / 2.0
		visual.scale = Vector3(10, 10, 1)
		visual.mesh = mesh
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.albedo_texture = MUD_TEXTURES[index % 3]
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.42
		Ground.prepare_material(material, -124 + index)
		visual.material_override = material
		visual.visible = false
		add_child(visual)
		_mud.append(visual)
	_rain = preload("res://presentation/world/weather_particles.gd").new()
	add_child(_rain)
	_tornado_view = preload("res://presentation/world/tornado_view.gd").new()
	add_child(_tornado_view)
	_bolt = preload("res://presentation/world/lightning_view.gd").new()
	add_child(_bolt)

func apply_state(state: Dictionary) -> void:
	_state = state
	preload("res://presentation/world/track_surface.gd").mud_zones = state.get("mud_zones", [])
	if not _warmup:
		_tornado_view.apply_state(state.tornado)
	_visual_elapsed = float(state.weather.get("elapsed", state.get("elapsed", 0)))
	_weather_type = str(state.weather.type)
	if not _warmup:
		_apply_weather_mix()
	for index in _mud.size():
		_mud[index].visible = index < state.mud_zones.size()
		if _mud[index].visible:
			var zone: Dictionary = state.mud_zones[index]
			var visual := _mud[index]
			if int(visual.get_meta("zone_id", -1)) != int(zone.id):
				visual.set_meta("zone_id", int(zone.id))
				visual.position = Ground.point_at(zone.position, Ground.MUD_OFFSET)
				visual.rotation = Vector3(-PI / 2.0, 0, float(zone.id) * 2.399963)
				visual.material_override.albedo_texture = MUD_TEXTURES[(int(zone.id) - 1) % MUD_TEXTURES.size()]
				Ground.conform_quad(visual, Ground.MUD_OFFSET)
			visual.transparency = 1.0 - clampf((float(zone.expires_at) - float(state.elapsed)) / 3.0, 0.0, 1.0)

func _apply_weather_mix() -> void:
	var phase: Dictionary = _state.weather.get("phase_data", {"type": _weather_type})
	var mix := Rules.mix_for_phase(phase, _visual_elapsed)
	_rain.set_mix(mix)
	if _environment == null or _sun == null:
		return
	var fog_color := Color(0, 0, 0, 0)
	var background := Color(0, 0, 0, 0)
	var density := 0.0
	var sun := 0.0
	var rim := 0.0
	var exposure := 0.0
	for index in Rules.TYPES.size():
		var preset: Dictionary = PRESETS[Rules.TYPES[index]]
		var weight := mix[index]
		fog_color += Color(str(preset.fog)).srgb_to_linear() * weight
		background += Color(str(preset.background)).srgb_to_linear() * weight
		density += float(preset.density) * weight
		sun += float(preset.sun) * weight
		rim += float(preset.rim) * weight
		exposure += float(preset.exposure) * weight
	# FogExp2 -> exponential native fog, calibrated at the 65-unit camera distance.
	_environment.fog_density = density * density * 65.0
	var day := DayCycle.sample(float(_state.get("game_time", 0.0)))
	_environment.ambient_light_energy = day.ambient
	_environment.fog_light_color = DayCycle.NIGHT_FOG.lerp(fog_color.linear_to_srgb(), day.daylight)
	_environment.background_color = DayCycle.NIGHT_SKY.lerp(background.linear_to_srgb(), day.daylight)
	# Color ambient avoids regenerating a sky cubemap on every clock update.
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = DayCycle.MOON_COLOR.lerp(Color("c6d7df"), day.daylight)
	_environment.tonemap_exposure = exposure
	_sun.light_energy = sun / PI * float(day.light)
	_sun.light_color = DayCycle.MOON_COLOR.lerp(DayCycle.SUN_COLOR, day.daylight)
	_sun.rotation = Basis.looking_at(day.direction, Vector3.UP).get_euler()
	if _rim != null:
		_rim.light_energy = rim / PI * lerpf(0.45, 1.0, day.daylight)

func _process(delta: float) -> void:
	if not externally_driven:
		advance_visual(delta)

func advance_visual(delta: float) -> void:
	if _warmup or _state.is_empty() or not is_instance_valid(_vehicle):
		return
	if not externally_driven:
		_visual_elapsed += maxf(0, delta)
		_apply_weather_mix()
	var wind: Dictionary = _state.get("wind", {})
	_rain.advance(delta, _vehicle.global_position, _vehicle.velocity, wind.get("direction", Vector3.RIGHT), float(wind.get("strength", 0)))


func on_event(event: Dictionary) -> void:
	if str(event.get("kind", "")) == "wind_particle":
		_wind_debris.spawn(event.direction, event.strength)
	if str(event.get("kind", "")) == "lightning":
		_rain.flash_lightning()
		_bolt.strike(event.position, int(event.get("cosmetic_seed", 0)))

func reset_run(seed_value: int = -1) -> void:
	preload("res://presentation/world/track_surface.gd").mud_zones = []
	if seed_value >= 0:
		_seed = seed_value
	_wind_debris.reset_run(_seed)
	_bolt.reset_run()
	_tornado_view.clear()
	_flash = 0.0
	_rain.clear()
	_weather_type = ""
	_visual_elapsed = 0.0
	for visual in _mud:
		visual.visible = false
		visual.set_meta("zone_id", -1)

func set_warmup_visible(enabled: bool) -> void:
	_warmup = enabled
	_wind_debris.set_warmup_visible(enabled, _vehicle.global_position + Vector3.UP)
	_bolt.set_warmup_visible(enabled, _vehicle.global_position)
	_rain.set_warmup_visible(enabled, _vehicle.global_position)
	_tornado_view.set_warmup_visible(enabled, _vehicle.global_position)
	if enabled:
		for visual in _mud:
			visual.position = Ground.point_at(_vehicle.global_position, Ground.MUD_OFFSET)
			visual.set_meta("zone_id", -1)
			Ground.conform_quad(visual, Ground.MUD_OFFSET)
			visual.visible = true
	else:
		reset_run()
		if not _state.is_empty():
			apply_state(_state)

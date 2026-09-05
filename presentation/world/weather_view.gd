extends Node3D

const Ground = preload("res://presentation/world/ground_surface_view.gd")
const MUD_TEXTURES := [preload("res://assets/textures/weather/mud-patch-a.png"), preload("res://assets/textures/weather/mud-rut-b.png"), preload("res://assets/textures/weather/mud-splash-c.png")]
const PRESETS := {
	"clear": {"fog": "9da58f", "background": "94a08d", "density": 0.0036, "sun": 3.25, "rim": 0.58, "exposure": 1.04},
	"sunny": {"fog": "9da58f", "background": "94a08d", "density": 0.0036, "sun": 3.25, "rim": 0.58, "exposure": 1.04},
	"foggy": {"fog": "8f9792", "background": "8d9590", "density": 0.0069, "sun": 2.15, "rim": 0.38, "exposure": 0.96},
	"rainy": {"fog": "7d8787", "background": "7c8685", "density": 0.0054, "sun": 1.95, "rim": 0.34, "exposure": 0.96},
	"storm": {"fog": "6f7777", "background": "727a79", "density": 0.0059, "sun": 1.7, "rim": 0.3, "exposure": 0.88}}
var externally_driven := false
var _transition: Dictionary = {}
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
	var type := str(state.weather.type)
	_rain.set_weather(type)
	if type != _weather_type:
		_begin_transition(type)
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

func _begin_transition(type: String) -> void:
	_weather_type = type
	if _environment == null or _sun == null:
		return
	_transition = {"elapsed": 0.0, "from_fog": _environment.fog_light_color,
		"from_background": _environment.background_color, "from_density": sqrt(_environment.fog_density / 65.0),
		"from_sun": _sun.light_energy * PI, "from_rim": _rim.light_energy * PI if _rim != null else 0.52,
		"from_exposure": _environment.tonemap_exposure}

func _process(delta: float) -> void:
	if not externally_driven:
		advance_visual(delta)

func advance_visual(delta: float) -> void:
	if _warmup or _state.is_empty() or not is_instance_valid(_vehicle):
		return
	if not _transition.is_empty():
		var preset: Dictionary = PRESETS.get(_weather_type, PRESETS.clear)
		_transition.elapsed = minf(12, float(_transition.elapsed) + delta)
		var linear := float(_transition.elapsed) / 12.0
		var blend := linear * linear * (3 - 2 * linear)
		# FogExp2 -> exponential native fog calibrated at the source camera's 65-unit distance.
		var density := lerpf(float(_transition.from_density), float(preset.density), blend)
		_environment.fog_density = density * density * 65.0
		_environment.fog_light_color = Color(_transition.from_fog).srgb_to_linear().lerp(Color(str(preset.fog)).srgb_to_linear(), blend).linear_to_srgb()
		_environment.background_color = Color(_transition.from_background).srgb_to_linear().lerp(Color(str(preset.background)).srgb_to_linear(), blend).linear_to_srgb()
		_environment.tonemap_exposure = lerpf(float(_transition.from_exposure), float(preset.exposure), blend)
		_sun.light_energy = lerpf(float(_transition.from_sun), float(preset.sun), blend) / PI
		if _rim != null:
			_rim.light_energy = lerpf(float(_transition.from_rim), float(preset.rim), blend) / PI
		if linear >= 1:
			_transition.clear()
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
	_transition.clear()
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

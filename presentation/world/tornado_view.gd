extends Node3D
const Source = preload("res://presentation/combat/source_model.gd")
const CAPACITY := 260
var _materials: Array[ShaderMaterial] = []
var _overlay: ColorRect
var _layer: CanvasLayer
var elapsed := 0.0
var warmup := false
var state: Dictionary = {}

func _ready() -> void:
	Source._prepare("weather_geometry")
	var funnel := ShaderMaterial.new()
	funnel.shader = preload("res://presentation/world/tornado_funnel.gdshader")
	_materials.append(funnel)
	for index in 2:
		var visual := MeshInstance3D.new()
		visual.mesh = Source._templates.weather_geometry[0].mesh
		visual.material_override = funnel
		visual.position.y = 12
		if index == 1:
			visual.scale = Vector3(0.76, 1, 0.76)
			visual.rotation.y = 2.1
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.extra_cull_margin = 24
		add_child(visual)
	var skirt := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 25
	skirt.mesh = plane
	skirt.position.y = 0.1
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var skirt_material := ShaderMaterial.new()
	skirt_material.shader = preload("res://presentation/world/tornado_skirt.gdshader")
	skirt.material_override = skirt_material
	_materials.append(skirt_material)
	add_child(skirt)
	var particles := MultiMeshInstance3D.new()
	particles.multimesh = MultiMesh.new()
	particles.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	particles.multimesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	particles.multimesh.mesh = quad
	particles.multimesh.instance_count = CAPACITY
	for index in CAPACITY:
		particles.multimesh.set_instance_transform(index, Transform3D.IDENTITY)
		particles.multimesh.set_instance_custom_data(index, Color(seeded_unit(index, 1) * TAU, seeded_unit(index, 2), seeded_unit(index, 3), 0))
	particles.custom_aabb = AABB(Vector3(-24, -1, -24), Vector3(48, 50, 48))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var particle_material := ShaderMaterial.new()
	particle_material.shader = preload("res://presentation/world/tornado_particles.gdshader")
	particles.material_override = particle_material
	_materials.append(particle_material)
	add_child(particles)
	_layer = CanvasLayer.new()
	_layer.layer = 0
	add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay_material := ShaderMaterial.new()
	overlay_material.shader = preload("res://presentation/world/tornado_overlay.gdshader")
	_overlay.material = overlay_material
	_layer.add_child(_overlay)
	clear()

static func seeded_unit(index: int, salt: int) -> float:
	return fposmod(sin((index + 1) * 12.9898 + salt * 78.233) * 43758.5453, 1.0)

func apply_state(tornado: Dictionary) -> void:
	state = tornado
	elapsed = maxf(0, float(tornado.get("age", 0)))
	if not warmup:
		position = tornado.get("position", Vector3.ZERO)
		_update()

func _process(delta: float) -> void:
	advance_visual(delta)

func advance_visual(delta: float) -> void:
	if warmup or state.is_empty():
		return
	elapsed += delta
	_update()

func _update() -> void:
	var intensity := clampf(float(state.get("intensity", 0)), 0, 1)
	visible = intensity > 0.003
	for material in _materials:
		material.set_shader_parameter("uTime", elapsed)
		material.set_shader_parameter("uIntensity", intensity)
	var opacity := clampf(float(state.get("camera_dust", 0)), 0, 1)
	_overlay.visible = opacity > 0.003
	_overlay.material.set_shader_parameter("uTime", elapsed)
	_overlay.material.set_shader_parameter("uOpacity", opacity)

func clear() -> void:
	state = {}
	elapsed = 0
	visible = false
	_overlay.visible = false

func set_warmup_visible(enabled: bool, point: Vector3) -> void:
	warmup = enabled
	if enabled:
		state = {"position": point, "intensity": 1.0, "camera_dust": 0.1}
		position = point
		_update()
	else:
		clear()

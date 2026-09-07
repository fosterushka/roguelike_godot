extends Node3D
const Smoke = preload("res://presentation/combat/fx/smoke.gdshader")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const CAPACITY := 12
const RED := Color("df291d")
const FLARE_HEIGHT := 2.9
const GREEN := Color("60de8b")
var plumes: Array[MeshInstance3D] = []
var _warmup := false

func _ready() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	for index in CAPACITY:
		var plume := MeshInstance3D.new()
		plume.mesh = mesh
		var material := ShaderMaterial.new()
		material.shader = Smoke
		material.render_priority = 0
		material.set_shader_parameter("uDensity", 0.92)
		plume.material_override = material
		plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(plume)
		plumes.append(plume)
	visible = false

func apply_drop(drop: Dictionary, time: float) -> void:
	if _warmup:
		return
	if drop.is_empty():
		visible = false
		return
	visible = true
	var point: Vector3 = drop.position
	point.y = Terrain.height_at(point.x, point.z) + float(drop.get("height", 0)) + FLARE_HEIGHT
	point += Basis(Vector3.UP, float(drop.get("yaw", 0))) * Vector3(0.62, 0, 0.58)
	var color := RED
	for index in CAPACITY:
		var age := fposmod(time * 0.32 + index / float(CAPACITY), 1.0)
		var radius := 0.3 + age * 0.65
		var angle := index * 2.399963 + time * 0.25
		var plume := plumes[index]
		plume.position = point + Vector3(sin(angle) * radius + age * 0.8, age * 6.5, cos(angle) * radius * 0.45)
		plume.scale = Vector3(0.55 + age * 2.4, 0.8 + age * 3.1, 1)
		var material: ShaderMaterial = plume.material_override
		material.set_shader_parameter("uColor", Vector3(color.r, color.g, color.b))
		material.set_shader_parameter("uOpacity", sin(age * PI) * 0.78)
		material.set_shader_parameter("uSeed", index * 0.371)
		material.set_shader_parameter("uTime", time + index * 1.73)

func set_warmup(enabled: bool, point: Vector3 = Vector3.ZERO) -> void:
	_warmup = false
	if enabled:
		apply_drop({"position": point, "height": 0, "landed": true}, 1.0)
		plumes[0].material_override.set_shader_parameter("uColor", Vector3(RED.r, RED.g, RED.b))
	else:
		visible = false
	_warmup = enabled

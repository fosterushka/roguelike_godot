extends Node3D
const Burn = preload("res://presentation/combat/fx/burning_hull.gdshader")
const WheeledRig = preload("res://presentation/vehicles/wheeled_rig.gd")
var parts: Array[MeshInstance3D] = []
var life := 0.0
var _base_height := 0.0
var fall_direction := 1.0
var _count := 0
var _preview: Node3D
func _ready() -> void:
	rotation_order = EULER_ORDER_XYZ
	for index in 512:
		var part := MeshInstance3D.new()
		var material := ShaderMaterial.new()
		material.shader = Burn
		part.material_override = material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.visible = false
		add_child(part)
		parts.append(part)
	_preview = WheeledRig.build_player()
	_prepare_preview(_preview)
	_preview.visible = false
	add_child(_preview)
func spawn(source: Node3D, position_value: Vector3, heading: float, random) -> void:
	if not is_instance_valid(source):
		return
	_count = 0
	_copy(source, source.global_transform.affine_inverse(), source)
	for index in range(_count, parts.size()):
		parts[index].visible = false
	_base_height = position_value.y
	global_position = position_value
	global_rotation = Vector3(0, heading, 0)
	scale = source.global_basis.get_scale()
	life = 8.0
	fall_direction = -1.0 if random.next_float() < 0.5 else 1.0
	visible = true
	advance(0.0)
func _copy(node: Node3D, inverse: Transform3D, source: Node3D) -> void:
	if node != source and node.top_level:
		return
	if node is MeshInstance3D and node.visible and _count < parts.size():
		var material: Material = node.get_active_material(0)
		var color := Color("55504a")
		if material is StandardMaterial3D:
			color = material.albedo_color
			if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and color.a < 0.5:
				return
		var part := parts[_count]
		part.mesh = node.mesh
		part.transform = inverse * node.global_transform
		part.visible = true
		part.material_override.set_shader_parameter("base_color", Vector3(color.r, color.g, color.b))
		var texture: Texture2D = material.albedo_texture if material is StandardMaterial3D else null
		part.material_override.set_shader_parameter("has_base_texture", texture != null)
		part.material_override.set_shader_parameter("base_texture", texture)
		_count += 1
	for child in node.get_children():
		if child is Node3D:
			_copy(child, inverse, source)
func advance(delta: float) -> void:
	if life <= 0.0:
		return
	life = maxf(0.0, life - delta)
	var elapsed := 8.0 - life
	var fall := clampf(elapsed / 1.25, 0.0, 1.0)
	var eased := fall * fall * (3.0 - 2.0 * fall)
	rotation.x = eased * 0.12
	rotation.z = fall_direction * eased * 0.24
	position.y = _base_height - eased * 0.16
	for index in _count:
		var material: ShaderMaterial = parts[index].material_override
		material.set_shader_parameter("elapsed", elapsed)
		material.set_shader_parameter("burn", clampf(elapsed / 2.1, 0.0, 1.0))
		material.set_shader_parameter("opacity", clampf(life / 1.5, 0.0, 1.0))
		parts[index].visible = life > 0.0
func reset() -> void:
	life = 0.0
	for part: MeshInstance3D in parts:
		part.visible = false
func set_warmup(enabled: bool) -> void:
	_preview.visible = enabled

func _prepare_preview(node: Node3D) -> void:
	if node is MeshInstance3D:
		node.material_override = parts[0].material_override
	for child: Node in node.get_children():
		if child is Node3D:
			_prepare_preview(child)

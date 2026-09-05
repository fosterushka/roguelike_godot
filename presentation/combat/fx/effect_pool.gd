extends Node3D

const Source = preload("res://presentation/combat/source_model.gd")
var entries: Array[Dictionary] = []
var cursor := 0
var meshes: Dictionary = {}
var shader: Shader
var capacity := 185
var part_count := 4
var fireballs := false
static var _sequence := 0

func configure(maximum: int, parts: int = 4, custom_shader: Shader = null, fire: bool = false) -> void:
	capacity = maximum
	part_count = parts
	shader = custom_shader
	fireballs = fire

func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	meshes.box = box
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	meshes.quad = quad
	for kind in ["sphere", "chunk", "gear", "collapse_gear", "masonry", "shockwave", "cylinder4", "cylinder5", "cylinder6", "cylinder7", "cylinder8", "cylinder9", "cone4", "cone5", "cone6", "cone7", "cone8", "cone9"]:
		var model := Source.instantiate("fx_" + kind)
		meshes[kind] = model.get_child(0).mesh
		model.free()
	for index in capacity:
		var group := Node3D.new()
		group.rotation_order = EULER_ORDER_XYZ
		add_child(group)
		var parts: Array[MeshInstance3D] = []
		for part_index in part_count:
			var visual := MeshInstance3D.new()
			visual.rotation_order = EULER_ORDER_XYZ
			visual.mesh = meshes.quad if shader != null or fireballs else meshes.sphere
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material: Material
			if fireballs:
				var custom := ShaderMaterial.new()
				custom.shader = preload("res://presentation/combat/fx/fireball.gdshader") if part_index == 0 else preload("res://presentation/combat/fx/fireball_core.gdshader")
				custom.render_priority = 0
				custom.set_shader_parameter("fireball_texture", preload("res://assets/textures/fx/explosion-fireball.png"))
				custom.set_shader_parameter("tint", Color.WHITE if part_index == 0 else Color("ffd18a"))
				custom.set_shader_parameter("alpha_threshold", 0.018 if part_index == 0 else 0.026)
				material = custom
			elif shader != null:
				var custom := ShaderMaterial.new()
				custom.shader = shader
				material = custom
			else:
				var standard := StandardMaterial3D.new()
				standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				standard.cull_mode = BaseMaterial3D.CULL_DISABLED
				standard.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				standard.no_depth_test = false
				standard.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if fireballs else BaseMaterial3D.BILLBOARD_DISABLED
				material = standard
			visual.material_override = material
			visual.visible = false
			group.add_child(visual)
			parts.append(visual)
		var light: OmniLight3D = null
		if fireballs:
			light = OmniLight3D.new()
			light.light_color = Color("ff8a32")
			light.shadow_enabled = false
			group.add_child(light)
		group.visible = false
		entries.append({"visual": group, "parts": parts, "life": 0.0, "light": light})

func acquire(data: Dictionary) -> Dictionary:
	var entry := entries[cursor]
	cursor = (cursor + 1) % capacity
	var visual: Node3D = entry.visual
	var parts: Array = entry.parts
	var light: OmniLight3D = entry.light
	entry.clear()
	entry.merge({"visual": visual, "parts": parts, "light": light, "life": 1.0, "max_life": 1.0, "velocity": Vector3.ZERO, "spin": Vector3.ZERO, "gravity": 0.0, "drag": 0.0, "grow": 0.0, "shrink": 0.0, "fade": true, "fade_tail": 1.0, "bounces": 0, "floor_y": 0.08, "opacity": 1.0, "age": 0.0})
	entry.merge(data, true)
	_sequence += 1
	entry.sequence = _sequence
	visual.transform = Transform3D.IDENTITY
	visual.position = data.get("position", Vector3.ZERO)
	visual.rotation = data.get("rotation", Vector3.ZERO)
	visual.scale = data.get("scale", Vector3.ONE)
	visual.visible = true
	for part: MeshInstance3D in parts:
		part.visible = false
		part.transform = Transform3D.IDENTITY
		part.transparency = 0.0
	return entry

func set_part(entry: Dictionary, index: int, kind: String, size: Vector3, color: Color, position: Vector3 = Vector3.ZERO, rotation: Vector3 = Vector3.ZERO, lit: bool = false, additive: bool = false) -> void:
	var part: MeshInstance3D = entry.parts[index]
	part.mesh = meshes[kind]
	part.position = position
	part.rotation = rotation
	part.scale = size
	part.visible = true
	if part.material_override is StandardMaterial3D:
		var material: StandardMaterial3D = part.material_override
		material.albedo_color = color
		material.albedo_texture = null
		material.render_priority = 0
		material.no_depth_test = false
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX

func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	for entry: Dictionary in entries:
		if entry.life <= 0.0:
			continue
		entry.life = maxf(0.0, entry.life - delta)
		entry.age += delta
		if entry.life <= 0.0:
			entry.visual.visible = false
			continue
		entry.velocity *= maxf(0.0, 1.0 - entry.drag * delta)
		entry.velocity.y -= delta * entry.gravity
		entry.visual.position += entry.velocity * delta
		entry.visual.rotation += entry.spin * delta
		if entry.bounces > 0 and entry.visual.position.y < entry.floor_y and entry.velocity.y < 0.0:
			entry.visual.position.y = entry.floor_y
			entry.velocity *= Vector3(0.64, -0.34, 0.64)
			entry.bounces -= 1
		entry.visual.scale += Vector3.ONE * entry.grow * delta
		entry.visual.scale *= maxf(0.01, 1.0 - delta * entry.shrink)
		if entry.fade:
			var ratio := clampf(entry.life / maxf(0.001, entry.max_life * entry.fade_tail), 0.0, 1.0)
			for part: MeshInstance3D in entry.parts:
				part.transparency = 1.0 - ratio

func active_count() -> int:
	var count := 0
	for entry: Dictionary in entries:
		count += int(entry.life > 0.0)
	return count

func reset_pool() -> void:
	cursor = 0
	_sequence = 0
	for entry: Dictionary in entries:
		entry.life = 0.0
		entry.visual.visible = false

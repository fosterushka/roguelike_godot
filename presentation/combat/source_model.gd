extends RefCounted

const MilitaryEnemies = preload("res://presentation/combat/military_enemies.gd")
const MilitaryPeople = preload("res://presentation/combat/military_people.gd")
const MilitaryFieldProps = preload("res://presentation/combat/military_field_props.gd")
const PaintedMaterials = preload("res://presentation/style/painted_materials.gd")
const SourceAnimation = preload("res://presentation/combat/source_animation.gd")
const WorldScale = preload("res://modules/world/world_scale.gd")
const EnemyCatalog = preload("res://modules/combat/enemy_catalog.gd")

static var _templates: Dictionary = {}
static var _materials: Dictionary = {}
static var _drone_models: Array[String] = EnemyCatalog.model_ids("drone")


static func preload_models() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual_models/catalog.json"))
	for entry in catalog.models:
		var name := str(entry.name)
		if MilitaryEnemies.has_model(name) or MilitaryPeople.has_model(name) or MilitaryFieldProps.has_model(name) or FileAccess.file_exists("res://data/visual_models/%s.json" % name):
			_prepare(name)


static func instantiate(model_name: String) -> Node3D:
	_prepare(model_name)
	var root := Node3D.new()
	root.name = model_name
	root.scale = Vector3.ONE * model_scale(model_name)
	for part in _templates.get(model_name, []):
		var visual: GeometryInstance3D
		if part.instances != null:
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = part.mesh
			multimesh.instance_count = part.instances.size()
			for index in part.instances.size():
				multimesh.set_instance_transform(index, _transform(part.instances[index]))
			var batch := MultiMeshInstance3D.new()
			batch.multimesh = multimesh
			visual = batch
		else:
			var single := MeshInstance3D.new()
			single.mesh = part.mesh
			visual = single
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if part.cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.name = part.name
		visual.transform = SourceAnimation.transform_for(part, {})
		visual.set_meta("animation", part.animation)
		visual.set_meta("base_transform", part.transform)
		visual.set_meta("source_part", part)
		root.add_child(visual)
	return root

static func model_scale(model_name: String) -> float:
	if model_name in _drone_models:
		return WorldScale.DRONE_SCALE
	return WorldScale.SOLDIER_SCALE if MilitaryPeople.has_model(model_name) else 1.0


static func _prepare(model_name: String) -> void:
	if _templates.has(model_name):
		return
	if model_name.begins_with("projectile_"):
		var library = preload("res://presentation/world/world_quality_models.gd")
		if library.has_model(model_name):
			_templates[model_name] = [{"name": model_name, "mesh": library.mesh_for(model_name), "transform": Transform3D.IDENTITY, "animation": "", "rig": {}, "bindings": [], "instances": null, "cast_shadow": false}]
			return
	if MilitaryEnemies.has_model(model_name):
		_templates[model_name] = MilitaryEnemies.templates(model_name)
		return
	if MilitaryPeople.has_model(model_name):
		_templates[model_name] = MilitaryPeople.templates(model_name)
		return
	if MilitaryFieldProps.has_model(model_name):
		var parts: Array = MilitaryFieldProps.templates(model_name).duplicate()
		# Keep only the existing support signal effects, not the legacy solid model.
		if model_name in ["airdrop", "heal_cart"]:
			_prepare_legacy(model_name)
			for old: Dictionary in _templates[model_name]:
				if old.bindings.any(func(binding: Dictionary) -> bool: return binding.role in ["airdrop_aura", "airdrop_flareRoot", "airdrop_flareCore", "airdrop_flareGlow", "airdrop_signalBeam", "heal_cart_aura"]):
					parts.append(old)
		_templates[model_name] = parts
		return
	_prepare_legacy(model_name)


static func _prepare_legacy(model_name: String) -> void:
	if _templates.has(model_name):
		return
	var file := "res://data/visual_models/%s.json" % model_name
	if not FileAccess.file_exists(file):
		push_warning("Missing source visual: " + model_name)
		_templates[model_name] = []
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	var parts: Array = []
	for part in data.meshes:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _vectors3(part.attributes.position)
		if part.attributes.has("normal"):
			arrays[Mesh.ARRAY_NORMAL] = _vectors3(part.attributes.normal)
		if part.attributes.has("uv"):
			var uv := PackedVector2Array()
			var raw: Array = part.attributes.uv
			for index in range(0, raw.size(), 2):
				uv.append(Vector2(float(raw[index]), float(raw[index + 1])))
			arrays[Mesh.ARRAY_TEX_UV] = uv
		if part.attributes.has("color"):
			var colors := PackedColorArray()
			var raw: Array = part.attributes.color
			for index in range(0, raw.size(), 3):
				colors.append(Color(float(raw[index]), float(raw[index + 1]), float(raw[index + 2])))
			arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(part.indices)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material_data: Dictionary = part.material.duplicate()
		material_data.painted_outline = not model_name.begins_with("world_") and not model_name.begins_with("fx_") and not model_name.begins_with("projectile_")
		material_data.receive_shadow = bool(part.get("receive_shadow", true))
		mesh.surface_set_material(0, _material(material_data))
		var m: Array = part.matrix
		var transform := Transform3D(Basis(Vector3(m[0], m[1], m[2]), Vector3(m[4], m[5], m[6]), Vector3(m[8], m[9], m[10])), Vector3(m[12], m[13], m[14]))
		parts.append({"bindings": SourceAnimation.prepare(part.get("bindings", [])), "rig": part.get("rig") if part.get("rig") is Dictionary else {}, "name": str(part.name), "mesh": mesh, "transform": transform, "animation": str(part.get("animate", "")), "instances": part.get("instances"), "cast_shadow": bool(part.get("cast_shadow", true))})
	_templates[model_name] = parts


static func _transform(m: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(m[0], m[1], m[2]), Vector3(m[4], m[5], m[6]), Vector3(m[8], m[9], m[10])), Vector3(m[12], m[13], m[14]))


static func _vectors3(raw: Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for index in range(0, raw.size(), 3):
		result.append(Vector3(float(raw[index]), float(raw[index + 1]), float(raw[index + 2])))
	return result


static func _material(data: Dictionary) -> StandardMaterial3D:
	var key := JSON.stringify(data)
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(str(data.color))
	material.roughness = float(data.roughness)
	material.metallic = float(data.metallic)
	if bool(data.get("lambert", false)):
		material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.vertex_color_use_as_albedo = bool(data.vertex_colors)
	material.vertex_color_is_srgb = false
	material.disable_receive_shadows = not bool(data.get("receive_shadow", true))
	if bool(data.get("double_sided", false)):
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not str(data.get("texture", "")).is_empty():
		material.albedo_texture = load("res://assets/textures/" + str(data.texture))
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.035
	if bool(data.get("transparent", false)) and str(data.get("texture", "")).is_empty():
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = float(data.get("opacity", 1.0))
	if bool(data.unshaded):
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if bool(data.backside):
		material.cull_mode = BaseMaterial3D.CULL_FRONT
	if bool(data.get("additive", false)):
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if str(data.get("emission", "000000")) != "000000":
		material.emission_enabled = true
		material.emission = Color(str(data.emission))
		material.emission_energy_multiplier = float(data.get("emission_energy", 1.0))
	if data.name in ["goldBright", "cyan", "fire", "foundryGlow"]:
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 0.8
	PaintedMaterials.apply(material, data)
	_materials[key] = material
	return material


static func create_pool(model_name: String, capacity: int) -> Dictionary:
	_prepare(model_name)
	var root := Node3D.new()
	root.name = model_name + "Pool"
	var batches: Array = []
	var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for part in _templates.get(model_name, []):
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = part.mesh
		multimesh.instance_count = capacity
		multimesh.visible_instance_count = 0
		for index in capacity:
			multimesh.set_instance_transform(index, hidden)
		var visual := MultiMeshInstance3D.new()
		visual.multimesh = multimesh
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if part.cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(visual)
		batches.append({"mesh": multimesh, "base": part.transform, "animation": part.animation, "bindings": part.bindings, "rig": part.rig})
	return {"root": root, "batches": batches, "capacity": capacity}


static func set_pool_instance(pool: Dictionary, index: int, transform: Transform3D, pose: Dictionary = {}) -> void:
	for batch in pool.batches:
		batch.mesh.set_instance_transform(index, transform * SourceAnimation.transform_for(batch, pose))
		if index >= batch.mesh.visible_instance_count:
			batch.mesh.visible_instance_count = index + 1


static func set_pool_visible_count(pool: Dictionary, count: int) -> void:
	for batch in pool.batches:
		batch.mesh.visible_instance_count = clampi(count, 0, int(pool.capacity))


static func hide_pool_instance(pool: Dictionary, index: int) -> void:
	var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for batch in pool.batches:
		batch.mesh.set_instance_transform(index, hidden)
		if index == batch.mesh.visible_instance_count - 1:
			batch.mesh.visible_instance_count = index

static func animate_instance(root: Node3D, pose: Dictionary) -> void:
	for child: Node in root.get_children():
		if child is GeometryInstance3D and child.has_meta("source_part"):
			child.transform = SourceAnimation.transform_for(child.get_meta("source_part"), pose)

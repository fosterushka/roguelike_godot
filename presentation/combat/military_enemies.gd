extends RefCounted

# Authored low-poly military enemies. The scene is loaded once; pools reuse its meshes.
const SCENE := preload("res://assets/actors/military_enemies.glb")
const PaintedMaterials = preload("res://presentation/style/painted_materials.gd")
const PALETTE_TEXTURE := preload("res://assets/actors/military_enemies_palette.png")
const MODELS := ["bike", "buggy", "drone", "kamikaze", "raider", "jammerTruck", "repairCrawler", "minelayer", "boss", "wreck_bike", "wreck_buggy", "wreck_jammerTruck", "wreck_repairCrawler", "wreck_minelayer"]
## Detailed bodywork retains a single static body draw and existing pivots.
const TRIANGLE_BUDGET := 6000
const BossGeometry = preload("res://modules/combat/leviathan_geometry.gd")
static var BOSS_TRIANGLE_BUDGET: int = BossGeometry.TRIANGLE_BUDGET
static var _cache: Dictionary = {}
static var _body_material: StandardMaterial3D
static var _styles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_vehicle_styles.json"))
static var _preset_materials: Dictionary = {}
const VARIANT_DIRECTORY := "res://assets/actors/enemies_revised/"
const PAINT_CELLS := {"paint": Vector2i(0, 3), "light": Vector2i(1, 3), "shadow": Vector2i(2, 3)}


static func has_model(model_name: String) -> bool:
	return model_name in MODELS


static func templates(model_name: String, variant: String = "", preset: String = "") -> Array:
	var revised: bool = _styles.models.has(model_name)
	if revised:
		if not _styles.variants.has(variant):
			variant = str(_styles.models[model_name].variant)
		if not _styles.presets.has(preset):
			preset = str(_styles.models[model_name].preset)
	var key := model_name + ":" + variant + ":" + preset
	if _cache.has(key):
		return _cache[key]
	var asset_name := model_name + "_" + variant if revised else model_name
	var scene: PackedScene = load(VARIANT_DIRECTORY + asset_name + ".glb") if revised else SCENE
	var root: Node = scene.instantiate()
	var model := root.get_node_or_null(NodePath(asset_name)) as Node3D
	var result: Array = []
	if model != null:
		for child: Node in model.get_children():
			if child is MeshInstance3D and child.mesh != null:
				var mesh := child.mesh.duplicate(true) as Mesh
				for surface in mesh.get_surface_count():
					mesh.surface_set_material(surface, material_for_preset(preset) if revised else _palette_material())
				var transform: Transform3D = child.transform
				result.append({
					"name": child.name,
					"mesh": mesh,
					"transform": transform,
					"animation": "",
					"rig": {},
					"bindings": _bindings(str(child.name), transform),
					"instances": null,
					"cast_shadow": true,
				})
	root.free()
	_cache[key] = result
	return result


## Cached palettes are immutable. Callers can choose a preset without changing peers.
static func material_for_preset(preset: String) -> StandardMaterial3D:
	if not _styles.presets.has(preset):
		preset = "olive"
	if _preset_materials.has(preset):
		return _preset_materials[preset]
	var image := PALETTE_TEXTURE.get_image()
	if image.is_compressed():
		image.decompress()
	for role: String in PAINT_CELLS:
		var cell: Vector2i = PAINT_CELLS[role]
		# Palette hex colors and PNG pixels are both sRGB.
		image.set_pixelv(cell, Color(str(_styles.presets[preset][role])))
	var material := _palette_material().duplicate() as StandardMaterial3D
	material.albedo_texture = ImageTexture.create_from_image(image)
	_preset_materials[preset] = material
	return material


## Per-instance material override; never edits shared Mesh/Material resources.
static func apply_preset(root: Node3D, preset: String) -> void:
	for child: Node in root.get_children():
		if child is GeometryInstance3D:
			child.material_override = material_for_preset(preset)


static func _palette_material() -> StandardMaterial3D:
	if _body_material != null:
		return _body_material
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_texture = PALETTE_TEXTURE
	_body_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_body_material.roughness = 0.88
	_body_material.metallic = 0.12
	PaintedMaterials.apply(_body_material, {"name": "", "painted_outline": true})
	return _body_material


static func _bindings(part_name: String, base: Transform3D) -> Array:
	var role := ""
	var kind := ""
	if part_name.begins_with("Wheel_"):
		role = "wheel"
	elif part_name.begins_with("Rotor_"):
		role = "rotor"
	elif part_name.begins_with("JammerHead"):
		role = "jammer_head"
	elif part_name.begins_with("JammerScan"):
		role = "jammer_scan"
	elif part_name.begins_with("WeaponPitch"):
		role = "weapon_pitch"
	elif part_name.begins_with("Component_"):
		role = "boss_component"
		kind = part_name.trim_prefix("Component_").replace("LeftDrive", "leftDrive").replace("RightDrive", "rightDrive").replace("MissilePod", "missilePod").replace("GunPod", "gunPod").replace("Core", "core")
	if role.is_empty():
		return []
	# Preserve scene-imported pivots: animation runs around the authored part origin.
	var binding := {"role": role, "kind": kind, "position": Vector3.ZERO, "rotation": Vector3.ZERO, "scale": Vector3.ONE, "rest_inverse": base.affine_inverse(), "parent_transform": base, "initial_visible": true}
	return [binding]

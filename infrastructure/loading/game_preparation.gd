extends RefCounted

const Locale = preload("res://presentation/ui/ui_locale.gd")

const Equipment = preload("res://presentation/vehicles/equipment_model.gd")
const SourceModel = preload("res://presentation/combat/source_model.gd")
const WagonCatalog = preload("res://modules/caravan/wagon_catalog.gd")
const AttachmentView = preload("res://presentation/vehicles/attachment_view.gd")
const WheeledRig = preload("res://presentation/vehicles/wheeled_rig.gd")
const NaturalMeshes = preload("res://presentation/world/natural_meshes.gd")
var procedural_models: Array[String] = []
var retained_resources: Array[Resource] = []
var warmup_root: Node3D
var errors: Array[String] = []
var manifest: Dictionary = {}
var completed := 0
var total := 1
var manifest_path := "res://data/asset_manifest.json"

func validate_and_load(parent: Node, progress: Callable) -> bool:
	errors.clear()
	var parser := JSON.new()
	var code := parser.parse(FileAccess.get_file_as_string(manifest_path))
	if code != OK or not parser.data is Dictionary:
		errors.append("asset_manifest.json: " + parser.get_error_message())
		return false
	manifest = parser.data
	var paths: Array = manifest.get("resources", []) + manifest.get("data", [])
	total = maxi(1, paths.size())
	completed = 0
	for path: String in paths:
		if path.ends_with(".json"):
			if not FileAccess.file_exists(path):
				errors.append(Locale.text("Отсутствует: ") + path)
			else:
				var data := JSON.new()
				if data.parse(FileAccess.get_file_as_string(path)) != OK:
					errors.append("%s:%d %s" % [path, data.get_error_line(), data.get_error_message()])
		else:
			if not ResourceLoader.exists(path):
				errors.append(Locale.text("Отсутствует: ") + path)
			else:
				var resource := load(path)
				if resource == null:
					errors.append(Locale.text("Не удалось загрузить: ") + path)
				else:
					retained_resources.append(resource)
		completed += 1
		progress.call(Locale.text("Ресурсы: ") + path.get_file(), 0.1 + 0.5 * completed / float(total))
		if completed % 4 == 0:
			await parent.get_tree().process_frame
	return errors.is_empty()

func prepare(parent: Node3D, point: Vector3, progress: Callable) -> bool:
	warmup_root = Node3D.new()
	warmup_root.name = "CoveredAssetWarmup"
	warmup_root.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(warmup_root)
	var screen_layer := CanvasLayer.new()
	screen_layer.layer = 0
	warmup_root.add_child(screen_layer)
	var interference := preload("res://presentation/ui/jammer_vhs.gd").new()
	screen_layer.add_child(interference)
	interference.update_state({"player": {"hp": 100, "jammed": true, "jammer_strength": 1.0}})
	interference.update_weather({"weather": {"type": "storm"}})
	interference.advance(2.0)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual_models/catalog.json"))
	var index := 0
	for entry: Dictionary in catalog.models:
		index += 1
		if str(entry.name).begins_with("world_") and str(entry.name) != "world_primitives":
			continue
		var model_name := str(entry.name)
		var visual := Equipment.build(model_name.trim_prefix("weapon_")) if model_name.begins_with("weapon_") else SourceModel.instantiate(model_name)
		visual.position = point
		warmup_root.add_child(visual)
		progress.call(Locale.text("Подготовка модели: ") + str(entry.name), 0.75 + 0.2 * index / float(catalog.models.size()))
		if index % 4 == 0:
			await parent.get_tree().process_frame
	procedural_models.clear()
	var procedural: Array[Node3D] = [WheeledRig.build_player()]
	for type: String in WagonCatalog.TYPES:
		var rig := WheeledRig.build_trailer(type)
		rig.name = "SteeringWheelTrailer_" + type
		procedural.append(rig)
	for type: String in WagonCatalog.ATTACHMENTS:
		procedural.append(AttachmentView.build(type))
	for visual: Node3D in procedural:
		visual.position = point
		warmup_root.add_child(visual)
		procedural_models.append(str(visual.name))
		await parent.get_tree().process_frame
	var primitives := SourceModel.instantiate("world_primitives")
	primitives.position = point
	warmup_root.add_child(primitives)
	for pool: String in NaturalMeshes.all():
		var batch := MultiMeshInstance3D.new()
		batch.name = pool
		batch.position = point
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = NaturalMeshes.mesh_for(pool)
		batch.multimesh.instance_count = 1
		batch.multimesh.set_instance_transform(0, Transform3D.IDENTITY)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if pool.begins_with("rockMass") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		warmup_root.add_child(batch)
	return true

func finish() -> void:
	if is_instance_valid(warmup_root):
		warmup_root.queue_free()

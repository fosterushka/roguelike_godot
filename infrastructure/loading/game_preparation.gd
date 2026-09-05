extends RefCounted

const Locale = preload("res://presentation/ui/ui_locale.gd")

const SourceModel = preload("res://presentation/combat/source_model.gd")
const WheeledRig = preload("res://presentation/vehicles/wheeled_rig.gd")
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
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual_models/catalog.json"))
	var index := 0
	for entry: Dictionary in catalog.models:
		index += 1
		if str(entry.name).begins_with("world_") and str(entry.name) != "world_primitives":
			continue
		var visual := SourceModel.instantiate(str(entry.name))
		visual.position = point
		warmup_root.add_child(visual)
		progress.call(Locale.text("Подготовка модели: ") + str(entry.name), 0.75 + 0.2 * index / float(catalog.models.size()))
		if index % 4 == 0:
			await parent.get_tree().process_frame
	procedural_models.clear()
	for visual: Node3D in [WheeledRig.build_player(), WheeledRig.build_trailer()]:
		visual.position = point
		warmup_root.add_child(visual)
		procedural_models.append(str(visual.name))
		await parent.get_tree().process_frame
	var primitives := SourceModel.instantiate("world_primitives")
	primitives.position = point
	warmup_root.add_child(primitives)
	return true

func finish() -> void:
	if is_instance_valid(warmup_root):
		warmup_root.queue_free()

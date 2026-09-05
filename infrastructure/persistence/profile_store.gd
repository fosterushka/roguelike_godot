extends RefCounted

const MAX_BYTES := 32768
var path := "user://iron-caravan-profile.json"
var status := "ready"
var read_only := false

func _init(save_path: String = "user://iron-caravan-profile.json") -> void:
	path = save_path

static func defaults() -> Dictionary:
	return {"version": 1, "unlockedSidegradeIds": [], "selectedContractIds": [], "completedContractIds": [], "contractProgress": {}, "recentEventIds": [], "lifetimeStats": {"runs": 0, "victories": 0, "foundriesDestroyed": 0, "activitiesCompleted": 0}, "settings": {"soundEnabled": true}}

static func ids(value: Variant, maximum: int) -> Array:
	var result: Array = []
	var pattern := RegEx.new()
	pattern.compile("^[a-z0-9][a-z0-9._:-]{0,79}$")
	if value is Array:
		for entry: Variant in value:
			if entry is String and pattern.search(entry) and not result.has(entry):
				result.append(entry)
				if result.size() >= maximum:
					break
	return result

static func bounded(value: Variant) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or floor(float(value)) != float(value):
		return 0
	return clampi(int(value), 0, 1000000000)

static func normalize(value: Dictionary) -> Dictionary:
	var profile := defaults()
	for key: String in ["unlockedSidegradeIds", "selectedContractIds", "completedContractIds", "recentEventIds"]:
		profile[key] = ids(value.get(key, []), {"unlockedSidegradeIds": 32, "selectedContractIds": 3, "completedContractIds": 64, "recentEventIds": 128}[key])
	if value.get("contractProgress") is Dictionary:
		for key: Variant in value.contractProgress:
			if not ids([key], 1).is_empty() and profile.contractProgress.size() < 64:
				profile.contractProgress[key] = bounded(value.contractProgress[key])
	if value.get("lifetimeStats") is Dictionary:
		for key: String in profile.lifetimeStats:
			profile.lifetimeStats[key] = bounded(value.lifetimeStats.get(key, 0))
	if value.get("settings") is Dictionary:
		profile.settings.soundEnabled = value.settings.get("soundEnabled", true) != false
	return profile

func load_profile() -> Dictionary:
	if not FileAccess.file_exists(path):
		status = "default"
		return defaults()
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		status = "unavailable"
		return defaults()
	if file.get_length() > MAX_BYTES:
		status = "recovered"
		return defaults()
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	var value: Variant = parser.data if parse_error == OK else null
	file.close()
	if value is Dictionary and (value.get("version", 0) is float or value.get("version", 0) is int) and float(value.get("version", 0)) > 1:
		read_only = true
		status = "read-only-future"
		return defaults()
	if not value is Dictionary:
		status = "recovered"
		return defaults()
	if value.get("version", -1) == 0:
		value = {"version": 1, "unlockedSidegradeIds": value.get("sidegrades", []), "selectedContractIds": value.get("selectedContracts", []), "completedContractIds": value.get("completedContracts", []), "contractProgress": value.get("progress", {}), "lifetimeStats": value.get("stats", {}), "settings": value.get("settings", {})}
		status = "migrated"
	elif value.get("version", -1) != 1 or not value.get("lifetimeStats") is Dictionary or not value.get("settings") is Dictionary:
		status = "recovered"
		return defaults()
	else:
		status = "ready"
	return normalize(value)

func save_profile(profile: Dictionary) -> bool:
	if read_only:
		return false
	var encoded := JSON.stringify(normalize(profile))
	if encoded.to_utf8_buffer().size() > MAX_BYTES:
		status = "unsaved"
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if not file:
		status = "unsaved"
		return false
	file.store_string(encoded)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		status = "unsaved"
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) != OK:
		status = "unsaved"
		return false
	status = "ready"
	return true

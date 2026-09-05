extends RefCounted

const DISPLAY_NAMES := {
	"raiderSupplyConvoy": "Raider convoy", "settlementDistress": "Settlement distress",
	"foundryDispatch": "Foundry reinforcement", "scavengerRoute": "Scavenger route",
	"announced": "Announced", "active": "In progress", "completed": "Completed", "failed": "Failed", "expired": "Expired",
	"rifleman": "Rifleman", "ak": "AK gunner", "bazooka": "Bazooka soldier", "bomber": "Bomber",
	"shooter": "Shooter drone", "kamikaze": "Kamikaze drone", "jammerTruck": "Jammer truck",
	"repairCrawler": "Repair crawler", "minelayer": "Minelayer", "leviathan": "Leviathan",
}

static var language := "en"
static var settings_path := "user://iron_caravan_language.cfg"
static var _initialized := false
static var _english: Dictionary = {}
static var _russian: Dictionary = {}

static func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/ui.json"))
	_english = parsed if parsed is Dictionary else {}
	for source: String in _english:
		_russian[str(_english[source])] = source
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		language = "ru" if config.get_value("interface", "language", "en") == "ru" else "en"
	TranslationServer.set_locale(language)

static func set_language(value: String) -> Error:
	initialize()
	language = "ru" if value == "ru" else "en"
	TranslationServer.set_locale(language)
	var config := ConfigFile.new()
	config.set_value("interface", "language", language)
	return config.save(settings_path)

static func text(source: String) -> String:
	initialize()
	source = str(DISPLAY_NAMES.get(source, source))
	var dictionary := _english if language == "en" else _russian
	if dictionary.has(source):
		return str(dictionary[source])
	if language == "ru":
		if source.begins_with("Need ") and source.ends_with(" salvage"):
			return "Нужно " + source.trim_prefix("Need ").trim_suffix(" salvage") + " лома"
		if source.begins_with("Requires level "):
			return "Нужен уровень " + source.trim_prefix("Requires level ")
		for separator in [" MK ", " LV "]:
			if source.contains(separator):
				return text(source.get_slice(separator, 0)) + separator + source.get_slice(separator, 1)
	return source

static func refresh_controls(node: Node) -> void:
	if node is Label or node is Button:
		node.text = text(node.text)
	if node is LineEdit:
		node.placeholder_text = text(node.placeholder_text)
	if node is OptionButton:
		for index in node.item_count:
			node.set_item_text(index, text(node.get_item_text(index)))
	for child in node.get_children():
		refresh_controls(child)

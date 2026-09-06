extends RefCounted

const PATH := "res://data/missions.json"
const CATEGORIES := ["salvage", "hunting", "rescue", "convoy", "driving", "arsenal", "exploration", "survival", "extraction", "elite"]
const ITEMS := {"scrap": 1, "circuit": 1, "relic": 2, "repair_kit": 1, "fuel_cell": 1, "weapon_parts": 2}
const METRICS := {
	"crew_rescued": {"ru": "Люди спасены в рейде", "en": "People rescued in raid"},
	"crew_repair_hp": {"ru": "Прочность восстановлена экипажем", "en": "Hull repaired by crew"},
	"crew_extracted": {"ru": "Живые сотрудники вывезены", "en": "Living crew extracted"},
	"rescued_crew_extracted": {"ru": "Новые спасённые вывезены живыми", "en": "New survivors extracted alive"},
	"wagons_extracted": {"ru": "Целые прицепы вывезены", "en": "Surviving wagons extracted"},
	"crew_lost": {"ru": "Сотрудники погибли или остались в рейде", "en": "Crew killed or left behind"},
	"kills": {
		"ru": "Враги уничтожены",
		"en": "Enemies defeated"
	},
	"kills_soldier": {
		"ru": "Пехота уничтожена",
		"en": "Infantry defeated"
	},
	"kills_bike": {
		"ru": "Мотоциклы уничтожены",
		"en": "Bikes destroyed"
	},
	"kills_buggy": {
		"ru": "Багги уничтожены",
		"en": "Buggies destroyed"
	},
	"kills_drone": {
		"ru": "Дроны уничтожены",
		"en": "Drones destroyed"
	},
	"kills_keep": {
		"ru": "Боевые тягачи уничтожены",
		"en": "Combat crawlers destroyed"
	},
	"kills_garrison": {
		"ru": "Гарнизоны уничтожены",
		"en": "Garrisons destroyed"
	},
	"kills_priority": {
		"ru": "Машины поддержки уничтожены",
		"en": "Support vehicles destroyed"
	},
	"kills_boss": {
		"ru": "Боссы уничтожены",
		"en": "Bosses defeated"
	},
	"kills_ak": {
		"ru": "Стрелки АК уничтожены",
		"en": "AK gunners defeated"
	},
	"kills_bazooka": {
		"ru": "Гранатомётчики уничтожены",
		"en": "Rocket soldiers defeated"
	},
	"kills_bomber": {
		"ru": "Подрывники уничтожены",
		"en": "Bombers defeated"
	},
	"kills_shooter": {
		"ru": "Стрелковые дроны уничтожены",
		"en": "Shooter drones destroyed"
	},
	"kills_kamikaze": {
		"ru": "Дроны-камикадзе уничтожены",
		"en": "Kamikaze drones destroyed"
	},
	"kills_jammerTruck": {
		"ru": "Постановщики помех уничтожены",
		"en": "Jammer trucks destroyed"
	},
	"kills_repairCrawler": {
		"ru": "Ремонтные машины уничтожены",
		"en": "Repair crawlers destroyed"
	},
	"kills_minelayer": {
		"ru": "Минные заградители уничтожены",
		"en": "Minelayers destroyed"
	},
	"activities": {
		"ru": "События завершены",
		"en": "Activities completed"
	},
	"convoys": {
		"ru": "Конвои перехвачены",
		"en": "Convoys intercepted"
	},
	"rescues": {
		"ru": "Поселения спасены",
		"en": "Settlements rescued"
	},
	"foundries": {
		"ru": "Литейные уничтожены",
		"en": "Foundries destroyed"
	},
	"scavengers": {
		"ru": "Маршруты сборщиков завершены",
		"en": "Scavenger routes completed"
	},
	"loot_scrap": {
		"ru": "Новый лом вывезен",
		"en": "New scrap extracted"
	},
	"loot_circuit": {
		"ru": "Новая электроника вывезена",
		"en": "New electronics extracted"
	},
	"loot_relic": {
		"ru": "Новые механизмы вывезены",
		"en": "New relics extracted"
	},
	"loot_repair_kit": {
		"ru": "Новые ремкомплекты вывезены",
		"en": "New repair kits extracted"
	},
	"loot_fuel_cell": {
		"ru": "Новые канистры вывезены",
		"en": "New fuel cans extracted"
	},
	"loot_weapon_parts": {
		"ru": "Новые оружейные комплекты вывезены",
		"en": "New weapon kits extracted"
	},
	"loot_items": {
		"ru": "Новые предметы вывезены",
		"en": "New items extracted"
	},
	"loot_types": {
		"ru": "Типы новой добычи вывезены",
		"en": "Distinct new loot types extracted"
	},
	"loot_slots": {
		"ru": "Ячейки новой добычи вывезены",
		"en": "New loot slots extracted"
	},
	"distance": {
		"ru": "Путь, м",
		"en": "Distance, m"
	},
	"drift_distance": {
		"ru": "Путь в дрифте, м",
		"en": "Drift distance, m"
	},
	"drift_seconds": {
		"ru": "Время в дрифте, с",
		"en": "Drift time, s"
	},
	"moving_seconds": {
		"ru": "Время в движении, с",
		"en": "Moving time, s"
	},
	"seconds": {
		"ru": "Время рейда, с",
		"en": "Raid time, s"
	},
	"speed_max": {
		"ru": "Пиковая скорость, м/с",
		"en": "Peak speed, m/s"
	},
	"combo_max": {
		"ru": "Пиковая серия комбо",
		"en": "Peak combo streak"
	},
	"sectors": {
		"ru": "Разные секторы посещены",
		"en": "Distinct sectors visited"
	},
	"sunny_seconds": {
		"ru": "Время при ясной погоде, с",
		"en": "Sunny weather time, s"
	},
	"foggy_seconds": {
		"ru": "Время в тумане, с",
		"en": "Fog time, s"
	},
	"rainy_seconds": {
		"ru": "Время под дождём, с",
		"en": "Rain time, s"
	},
	"storm_seconds": {
		"ru": "Время в грозе, с",
		"en": "Storm time, s"
	},
	"overdrives": {
		"ru": "Форсажи активированы",
		"en": "Overdrives activated"
	},
	"rams": {
		"ru": "Удары тараном",
		"en": "Ram hits"
	},
	"roadkills": {
		"ru": "Враги сбиты машиной",
		"en": "Road kills"
	},
	"nitro_uses": {
		"ru": "Нитро использовано",
		"en": "Nitro uses"
	},
	"repair_uses": {
		"ru": "Ремонтов использовано",
		"en": "Repairs used"
	},
	"fuel_uses": {
		"ru": "Канистры использованы",
		"en": "Fuel cans used"
	},
	"weapon_uses": {
		"ru": "Оружейные комплекты использованы",
		"en": "Weapon kits used"
	},
	"consumables_used": {
		"ru": "Расходники использованы",
		"en": "Consumables used"
	},
	"shots": {
		"ru": "Выстрелы",
		"en": "Shots fired"
	},
	"shots_assaultRifle": {
		"ru": "Выстрелы из M4",
		"en": "M4 shots"
	},
	"shots_akTurret": {
		"ru": "Выстрелы из турели АК",
		"en": "AK turret shots"
	},
	"shots_bazooka": {
		"ru": "Выстрелы из базуки",
		"en": "Bazooka shots"
	},
	"shots_grenadeLauncher": {
		"ru": "Выстрелы из гранатомёта",
		"en": "Grenade launcher shots"
	},
	"shots_minigun": {
		"ru": "Выстрелы из минигана",
		"en": "Minigun shots"
	},
	"shots_railgun": {
		"ru": "Выстрелы из рельсотрона",
		"en": "Railgun shots"
	},
	"shots_missileRack": {
		"ru": "Ракеты из ракетного блока",
		"en": "Missile rack shots"
	},
	"damage_taken": {
		"ru": "Полученный урон",
		"en": "Damage taken"
	},
	"hits_taken": {
		"ru": "Полученные попадания",
		"en": "Hits taken"
	},
	"health_pct": {
		"ru": "Прочность при выходе, %",
		"en": "Hull at extraction, %"
	},
	"fuel_pct": {
		"ru": "Топливо при выходе, %",
		"en": "Fuel at extraction, %"
	},
	"min_health_pct": {
		"ru": "Минимальная прочность за рейд, %",
		"en": "Lowest raid hull, %"
	},
	"extractions": {
		"ru": "Эвакуации завершены",
		"en": "Extractions completed"
	},
	"wins": {
		"ru": "Победы над Левиафаном",
		"en": "Leviathan victories"
	},
	"extract_1": {
		"ru": "Выходы через E1",
		"en": "Extractions through E1"
	},
	"extract_2": {
		"ru": "Выходы через E2",
		"en": "Extractions through E2"
	},
	"extract_3": {
		"ru": "Выходы через E3",
		"en": "Extractions through E3"
	},
	"extraction_attempts": {
		"ru": "Вызовы эвакуации",
		"en": "Extraction requests"
	},
	"extraction_cancels": {
		"ru": "Эвакуации отменены выходом из зоны",
		"en": "Extractions cancelled by leaving"
	},
	"airdrops": {
		"ru": "Воздушные грузы подобраны",
		"en": "Airdrops claimed"
	},
	"healers": {
		"ru": "Помощь ремонтных караванов получена",
		"en": "Repair caravan assistance received"
	},
	"mine_hacks": {
		"ru": "Мины взломаны",
		"en": "Mines hacked"
	},
	"boss_components": {
		"ru": "Узлы босса уничтожены",
		"en": "Boss components destroyed"
	}
}

static var _cache: Dictionary = {}
static var _loaded := false
static var _errors: Array[String] = []

static func label(metric: String, language: String = "ru") -> String:
	return str(METRICS.get(metric, {}).get("ru" if language == "ru" else "en", metric))

static func all() -> Dictionary:
	if not _loaded:
		_load()
	return _cache

static func errors() -> Array[String]:
	all()
	return _errors.duplicate()

static func _number(value: Variant, minimum: float = 0.0, maximum: float = 1000000.0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func validate(row: Dictionary) -> String:
	for field: String in ["id", "name", "name_en", "description", "description_en"]:
		if not row.get(field) is String or str(row[field]).strip_edges().is_empty():
			return "Missing text: " + field
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]{2,63}$")
	if not pattern.search(row.id):
		return "Invalid mission id"
	if row.get("category", "") not in CATEGORIES or row.get("scope", "") not in ["career", "raid"]:
		return "Unknown category or scope"
	if not _number(row.get("min_level"), 1, 8) or floor(float(row.min_level)) != float(row.min_level):
		return "Invalid level"
	for field: String in ["credits", "xp"]:
		if not _number(row.get(field), 1, 5000) or floor(float(row[field])) != float(row[field]):
			return "Invalid reward: " + field
	if not row.get("objectives") is Array or row.objectives.is_empty() or row.objectives.size() > 5:
		return "Expected one to five objectives"
	var seen := {}
	for objective: Variant in row.objectives:
		if not objective is Dictionary or not METRICS.has(objective.get("metric", "")) or not _number(objective.get("target"), 0.01):
			return "Invalid objective"
		if seen.has(objective.metric):
			return "Duplicate objective metric"
		seen[objective.metric] = true
	if not row.get("conditions") is Array or row.conditions.size() > 4:
		return "Invalid conditions"
	for condition: Variant in row.conditions:
		if not condition is Dictionary or not METRICS.has(condition.get("metric", "")) or condition.get("op", "") not in ["min", "max"] or not _number(condition.get("value")):
			return "Invalid condition"
	if not row.get("delivery") is Dictionary:
		return "Invalid delivery"
	var slots := 0
	for item: Variant in row.delivery:
		if not ITEMS.has(item) or not _number(row.delivery[item], 1, 24) or floor(float(row.delivery[item])) != float(row.delivery[item]):
			return "Invalid delivery item"
		slots += int(ITEMS[item]) * int(row.delivery[item])
	if slots > 24:
		return "Delivery exceeds maximum raid capacity"
	return ""

static func _load() -> void:
	_loaded = true
	var file := FileAccess.open(PATH, FileAccess.READ)
	if not file:
		_errors.append("Mission catalog is missing")
		push_error(_errors[-1])
		return
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not parser.data is Dictionary or parser.data.get("version", 0) != 1 or not parser.data.get("missions") is Array:
		_errors.append("Mission catalog has an invalid schema")
		push_error(_errors[-1])
		return
	var names := {}
	for value: Variant in parser.data.missions:
		if not value is Dictionary:
			_errors.append("Mission entry must be an object")
			continue
		var reason := validate(value)
		var id := str(value.get("id", "unknown"))
		if not reason.is_empty():
			_errors.append(id + ": " + reason)
		elif _cache.has(id) or names.has(value.name) or names.has(value.name_en):
			_errors.append(id + ": Duplicate mission id or title")
		else:
			_cache[id] = value
			names[value.name] = true
			names[value.name_en] = true
	if not _errors.is_empty():
		_cache.clear()
		push_error("Mission catalog rejected: " + "; ".join(_errors))

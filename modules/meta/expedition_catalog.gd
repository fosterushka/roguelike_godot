extends RefCounted

const CaravanSave = preload("res://modules/caravan/caravan_save.gd")
const Missions = preload("res://modules/meta/mission_catalog.gd")
const MissionProgress = preload("res://modules/meta/mission_progress.gd")

const ITEMS := {
	"scrap": {"name": "Металлолом", "description": "Материал для продажи и первого задания.", "buy": 16, "sell": 8, "size": 1, "usable": false, "rarity": "common"},
	"circuit": {"name": "Электроника", "description": "Ценная добыча для торговца.", "buy": 80, "sell": 40, "size": 1, "usable": false, "rarity": "uncommon"},
	"relic": {"name": "Древний механизм", "description": "Редкая добыча из укреплений. Занимает две ячейки.", "buy": 250, "sell": 125, "size": 2, "usable": false, "rarity": "rare"},
	"repair_kit": {"name": "Ремкомплект", "description": "В рейде восстанавливает 90 прочности.", "buy": 60, "sell": 25, "size": 1, "usable": true, "rarity": "common"},
	"fuel_cell": {"name": "Канистра", "description": "В рейде восстанавливает 45 топлива.", "buy": 50, "sell": 20, "size": 1, "usable": true, "rarity": "common"},
	"weapon_parts": {"name": "Оружейный комплект", "description": "В рейде усиливает урон на 20% до конца рейда. Один раз за рейд.", "buy": 180, "sell": 75, "size": 2, "usable": true, "rarity": "uncommon"},
}
const UPGRADES := {
	"cargo": {"name": "Грузовой отсек", "description": "+4 ячейки рюкзака за уровень.", "base_cost": 180, "max_level": 3},
	"armor": {"name": "Усиление корпуса", "description": "+20 прочности в начале каждого рейда за уровень.", "base_cost": 200, "max_level": 3},
	"engine": {"name": "Настройка двигателя", "description": "+3% скорости в каждом рейде за уровень.", "base_cost": 220, "max_level": 3},
}

const LOOT_SOURCE_ITEMS := {
	"convoy": "weapon_parts", "raiderSupplyConvoy": "weapon_parts", "scavengerRoute": "weapon_parts",
	"fort": "relic", "foundry": "relic", "garrison": "relic", "stronghold": "relic", "boss": "relic",
	"settlement": "repair_kit", "settlementDistress": "repair_kit",
}
const ELECTRONICS_INTERVAL := 5
const ENGLISH_ITEM_NAMES := {
	"scrap": "Scrap", "circuit": "Electronics", "relic": "Relic",
	"repair_kit": "Repair kit", "fuel_cell": "Fuel cell", "weapon_parts": "Weapon kit",
}

static func loot_item(source: String, index: int = 0) -> String:
	if ITEMS.has(source):
		return source
	return str(LOOT_SOURCE_ITEMS.get(source, "circuit" if index % ELECTRONICS_INTERVAL == ELECTRONICS_INTERVAL - 1 else "scrap"))

static func item_name(id: String, language: String = "en") -> String:
	if not ITEMS.has(id):
		return id
	return str(ITEMS[id].name) if language == "ru" else str(ENGLISH_ITEM_NAMES.get(id, id))

static func quests() -> Dictionary:
	return Missions.all()

static func defaults() -> Dictionary:
	return {"credits": 1000 if OS.is_debug_build() else 300, "xp": 0, "stash": {"repair_kit": 2, "fuel_cell": 1}, "loadout": {}, "upgrades": {"cargo": 0, "armor": 0, "engine": 0}, "quests": {}, "caravan": CaravanSave.defaults()}

static func integer(value: Variant, maximum: int = 1000000000) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or floor(float(value)) != float(value):
		return 0
	return clampi(int(value), 0, maximum)

static func inventory(value: Variant, limit: int = 9999, usable_only: bool = false) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for id: String in ITEMS:
			var amount := integer(value.get(id, 0), limit)
			if amount > 0 and (not usable_only or ITEMS[id].usable):
				result[id] = amount
	return result

static func normalize(value: Variant) -> Dictionary:
	var result := defaults()
	if not value is Dictionary:
		return result
	result.credits = integer(value.get("credits", result.credits))
	result.xp = integer(value.get("xp", 0))
	result.stash = inventory(value.get("stash", {}))
	var upgrades: Variant = value.get("upgrades", {})
	for id: String in UPGRADES:
		result.upgrades[id] = integer(upgrades.get(id, 0), UPGRADES[id].max_level) if upgrades is Dictionary else 0
	var loadout := inventory(value.get("loadout", {}), 24, true)
	var space: int = 12 + 4 * result.upgrades.cargo
	for id: String in loadout:
		var amount := mini(loadout[id], int(space / int(ITEMS[id].size)))
		if amount > 0:
			result.loadout[id] = amount
			space -= amount * int(ITEMS[id].size)
	result.quests = MissionProgress.normalize(value.get("quests", {}), quests())
	result.caravan = CaravanSave.normalize(value.get("caravan"))
	return result

static func account(xp: int) -> Dictionary:
	var level := 1
	var remaining := xp
	var threshold := 120
	while remaining >= threshold and level < 100:
		remaining -= threshold
		level += 1
		threshold = 120 + 60 * (level - 1)
	return {"level": level, "xp": remaining, "xp_next": threshold}

static func used(inventory_value: Dictionary) -> int:
	var result := 0
	for id: String in inventory_value:
		result += int(inventory_value[id]) * int(ITEMS.get(id, {}).get("size", 1))
	return result

extends RefCounted

const Locale = preload("res://presentation/ui/ui_locale.gd")

const Rules = preload("res://modules/progression/upgrade_rules.gd")
const Fuel = preload("res://modules/caravan/vehicle_fuel.gd")
const LABELS := {"max_hp": "Корпус", "armor": "Броня", "max_fuel": "Бак", "fuel_burn_mult": "Расход", "maximum_speed": "Скорость", "acceleration": "Разгон", "pickup_radius": "Сбор", "damage_mult": "Урон", "range_mult": "Дальность", "nitro_recovery": "Восстановление нитро", "repair_power": "Ремонт", "weapon_capacity": "Оружейные слоты", "coins": "Лом", "regen_rate": "Регенерация", "ram_cd_mult": "Перезарядка тарана"}

static func description(id: String, player: Dictionary, weapons: Array) -> String:
	var next := player.duplicate(true)
	var next_weapons := weapons.duplicate(true)
	var kind := id.get_slice(":", 0)
	var value := id.get_slice(":", 1)
	match kind:
		"core": Rules.apply_core(value, next)
		"trait": Rules.apply_trait(value, next, next_weapons)
		"draft_weapon", "weapon":
			var index := int(value)
			if index >= 0 and index < next_weapons.size():
				Rules.upgrade_weapon(next_weapons[index])
	var before := player.duplicate()
	before.merge(Fuel.drive_tuning(float(player.get("fuel", 100.0)), player), true)
	next.merge(Fuel.drive_tuning(float(next.get("fuel", 100.0)), next), true)
	var lines: Array[String] = []
	for key: String in LABELS:
		if before.has(key) and next.has(key) and before[key] != next[key]:
			lines.append("%s: %.2f → %.2f" % [Locale.text(LABELS[key]), before[key], next[key]])
	for index in range(weapons.size()):
		var old: Dictionary = weapons[index].def
		var changed: Dictionary = next_weapons[index].def
		for key in ["damage", "range", "cooldown"]:
			if old.get(key, 0) != changed.get(key, 0):
				lines.append("%s %s: %.2f → %.2f" % [Locale.text(str(old.name)), Locale.text("Урон") if key == "damage" else Locale.text("Дальность") if key == "range" else Locale.text("Перезарядка"), old[key], changed[key]])
	return "\n".join(lines)

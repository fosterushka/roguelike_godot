extends RefCounted

const TRAINING_COST := 30
const ROLES := {
	"mechanic": {"name": "Механик", "name_en": "Mechanic", "job": "repair", "hp": 85.0, "wage": 2, "speed": 3.6, "power": 2.0},
	"shooter": {"name": "Стрелок", "name_en": "Gunner", "job": "shoot", "hp": 100.0, "wage": 2, "speed": 3.8, "damage": 9.0, "range": 32.0, "cooldown": 0.8, "projectile": "bullet", "targets": []},
	"loader": {"name": "Заряжающий", "name_en": "Loader", "job": "reload", "hp": 90.0, "wage": 1, "speed": 3.6, "power": 0.22},
	"looter": {"name": "Сборщик лута", "name_en": "Scavenger", "job": "collect", "hp": 75.0, "wage": 2, "speed": 4.2, "range": 18.0},
	"fuel": {"name": "Сборщик топлива", "name_en": "Fuel scavenger", "job": "collect_fuel", "hp": 80.0, "wage": 2, "speed": 4.0, "range": 18.0},
	"anti_tank": {"name": "Боец ПТ", "name_en": "Anti-tank gunner", "job": "shoot", "hp": 95.0, "wage": 3, "speed": 3.4, "damage": 27.0, "range": 42.0, "cooldown": 2.8, "projectile": "rocket", "targets": ["bike", "buggy", "keep", "garrison", "priorityVehicle"]},
	"anti_air": {"name": "Боец ПВО", "name_en": "Anti-air gunner", "job": "shoot", "hp": 90.0, "wage": 3, "speed": 3.8, "damage": 7.0, "range": 40.0, "cooldown": 0.5, "projectile": "bullet", "targets": ["drone"]},
	"civilian": {"name": "Без профессии", "name_en": "Untrained", "job": "passenger", "hp": 80.0, "wage": 1, "speed": 4.0},
}

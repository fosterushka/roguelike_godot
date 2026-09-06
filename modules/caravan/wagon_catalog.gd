extends RefCounted

const MAX_WAGONS := 6
const MAX_CREW := 24
const PICKUP_CREW_SLOTS := 2
const ITEM_SIZES := {"scrap": 1, "circuit": 1, "relic": 2, "repair_kit": 1, "fuel_cell": 1, "weapon_parts": 2}
const TYPES := {
	"cargo": {"name": "Грузовой прицеп", "name_en": "Cargo wagon", "max_hp": 240.0, "mass": 7.0, "cargo_capacity": 8, "crew_slots": 2, "cost": 180},
	"repair": {"name": "Ремонтный прицеп", "name_en": "Repair wagon", "max_hp": 280.0, "mass": 9.0, "cargo_capacity": 4, "crew_slots": 2, "cost": 240},
	"weapon": {"name": "Оружейный прицеп", "name_en": "Weapon wagon", "max_hp": 260.0, "mass": 9.0, "cargo_capacity": 4, "crew_slots": 2, "cost": 260},
	"fuel": {"name": "Топливный прицеп", "name_en": "Fuel wagon", "max_hp": 230.0, "mass": 8.0, "cargo_capacity": 6, "crew_slots": 2, "cost": 220},
	"anti_tank": {"name": "Противотанковый прицеп", "name_en": "Anti-tank wagon", "max_hp": 310.0, "mass": 11.0, "cargo_capacity": 3, "crew_slots": 2, "cost": 360},
	"anti_air": {"name": "Зенитный прицеп", "name_en": "Anti-air wagon", "max_hp": 250.0, "mass": 8.0, "cargo_capacity": 3, "crew_slots": 2, "cost": 340},
}
const ATTACHMENTS := {
	"turret": {"name": "Турель", "name_en": "Turret", "kind": "universal", "mass": 2.0, "cost": 100, "job": "shoot", "factor": 1.3, "role": "shooter"},
	"repair_station": {"name": "Ремонтная станция", "name_en": "Repair station", "kind": "universal", "mass": 2.5, "cost": 120, "job": "repair", "factor": 1.5, "role": "mechanic"},
	"ammo_feed": {"name": "Подача боеприпасов", "name_en": "Ammo feed", "kind": "universal", "mass": 1.5, "cost": 110, "job": "reload", "factor": 1.5, "role": "loader"},
	"cargo_rack": {"name": "Грузовой отсек", "name_en": "Cargo rack", "kind": "universal", "mass": 1.5, "cost": 90, "cargo": 4},
	"salvage_arm": {"name": "Сборочный захват", "name_en": "Salvage arm", "kind": "universal", "mass": 2.0, "cost": 100, "job": "collect", "factor": 1.35, "role": "looter"},
	"fuel_pump": {"name": "Топливный насос", "name_en": "Fuel pump", "kind": "universal", "mass": 2.0, "cost": 100, "job": "collect_fuel", "factor": 1.35, "role": "fuel"},
	"anti_tank_station": {"name": "ПТ-станция", "name_en": "Anti-tank station", "kind": "universal", "mass": 3.5, "cost": 160, "job": "shoot", "factor": 1.4, "role": "anti_tank"},
	"anti_air_station": {"name": "ПВО", "name_en": "Air defense", "kind": "universal", "mass": 2.5, "cost": 150, "job": "shoot", "factor": 1.4, "role": "anti_air"},
	"armor_panels": {"name": "Бронепанели", "name_en": "Armor panels", "kind": "universal", "mass": 3.0, "cost": 120, "armor_hp": 80.0},
	"reinforced_hitch": {"name": "Усиленная сцепка", "name_en": "Reinforced hitch", "kind": "universal", "mass": 1.0, "cost": 80, "hitch_strength": 1.5},
}

static func mounts() -> Array:
	return [{"id": 0, "kind": "universal", "max_mass": 5.0}, {"id": 1, "kind": "universal", "max_mass": 5.0}, {"id": 2, "kind": "universal", "max_mass": 5.0}]

static func cargo_used(cargo: Dictionary) -> int:
	var result := 0
	for id: String in cargo:
		result += int(cargo[id]) * int(ITEM_SIZES.get(id, 1))
	return result

static func job_factor(wagon: Dictionary, role: String, job: String) -> float:
	var base := 1.0
	var type := str(wagon.get("type", ""))
	if type == "repair" and role == "mechanic" and job == "repair":
		base = 1.15
	elif type == "weapon" and job == "shoot":
		base = 1.1
	elif type == "fuel" and role == "fuel" and job == "collect_fuel":
		base = 1.2
	elif type == role and role in ["anti_tank", "anti_air"] and job == "shoot":
		base = 1.15
	var factor := 1.0
	for installation: Dictionary in wagon.get("attachments", []):
		var definition: Dictionary = ATTACHMENTS.get(installation.get("type", ""), {})
		if definition.get("job", "") == job and definition.get("role", "") == role:
			factor = maxf(factor, float(definition.get("factor", 1.0)))
	return base * factor

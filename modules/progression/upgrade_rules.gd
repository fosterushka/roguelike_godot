extends RefCounted

static func trait_id(index: int, definition: Dictionary) -> String:
	return str(definition.get("id", definition.title.to_snake_case()))

static func trait_available(id: String, player: Dictionary) -> bool:
	return id != "expandedWeaponRack" or (player.base_weapon_capacity < 6 and player.level >= (2 if player.base_weapon_capacity == 4 else 4))

static func apply_trait(id: String, p: Dictionary, weapons: Array) -> bool:
	if not trait_available(id, p):
		return false
	match id:
		"high_flow_turbo":
			p.speed_mult *= 1.14
			p.mobility_upgrades += 1
		"racing_transmission":
			p.speed_mult *= 1.1
			p.mobility_upgrades += 1
		"nitro_calibration":
			p.speed_mult *= 1.08
			p.nitro_recovery *= 1.18
			p.mobility_upgrades += 1
		"reinforced_core":
			p.max_hp += 70
			p.hp = minf(p.max_hp, p.hp + 70)
		"salvage_chains": p.pickup_radius *= 1.42
		"combat_engineer": p.repair_power += 18
		"layered_plating": p.armor = minf(0.58, p.armor + 0.08)
		"salvage_rush":
			p.coins += 55
			p.coin_mult *= 1.1
		"plow_momentum":
			p.ram_cd_mult *= 0.72
			p.momentum_decay_mult *= 0.72
		"fire_control_officer":
			p.damage_mult *= 1.12
			for weapon: Dictionary in weapons:
				weapon.def.range *= 1.12
		"overdrive_feed": p.overdrive_feed = true
		"targeting_computer": p.range_mult *= 1.18
		"emergency_nanoweld": p.regen_rate += 1.25
		"twin_feed_mechanism": p.double_shot_chance = minf(0.48, p.double_shot_chance + 0.16)
		"pressure_recovery": p.nitro_recovery *= 1.24
		"fire_suppression": p.emergency_armor = minf(0.28, p.emergency_armor + 0.1)
		"expandedWeaponRack":
			var next := mini(6, int(p.base_weapon_capacity) + 1)
			p.weapon_capacity += next - p.base_weapon_capacity
			p.base_weapon_capacity = next
		_: return false
	return true

static func apply_core(id: String, p: Dictionary) -> bool:
	if not p.core_upgrades.has(id) or p.core_upgrades[id] >= 5:
		return false
	p.core_upgrades[id] += 1
	match id:
		"motor":
			p.motor_speed_mult *= 1.08
			p.motor_acceleration_mult *= 1.1
		"armor":
			p.max_hp += 45
			p.hp = minf(p.max_hp, p.hp + 45)
			p.armor = minf(0.6, p.armor + 0.04)
			p.weight += 1
		"fuel":
			p.max_fuel += 25
			p.fuel = minf(p.max_fuel, p.fuel + 25)
			p.fuel_burn_mult = maxf(0.55, p.fuel_burn_mult * 0.92)
	return true

static func upgrade_weapon(weapon: Dictionary) -> bool:
	if weapon.level >= weapon.def.get("maxLevel", 5):
		return false
	weapon.level += 1
	weapon.def.damage = floor(float(weapon.def.damage) * 1.24 + 1.5)
	weapon.def.range *= 1.07
	weapon.def.cooldown = maxf(0.22, weapon.def.cooldown * 0.9)
	return true

static func protocol_available(protocol: Dictionary, modules: Array, profiles: Dictionary) -> bool:
	var types: Array = []
	var families: Array = []
	var tags: Array = []
	for module: Dictionary in modules:
		types.append(module.type)
		families.append_array(profiles.get(module.type, {}).get("families", []))
		tags.append_array(profiles.get(module.type, {}).get("tags", []))
	for requirement: Dictionary in protocol.requirements:
		for key: String in ["types", "families", "tags"]:
			if requirement[key].is_empty():
				continue
			var values: Array = {"types": types, "families": families, "tags": tags}[key]
			var found := false
			for entry: String in requirement[key]:
				found = found or values.has(entry)
			if not found:
				return false
	return true

static func sidegrade_tuning(definition: Dictionary, variant: Dictionary) -> Dictionary:
	var tuning: Dictionary = variant.get("pve", {})
	return {"range": definition.range * tuning.get("rangeMultiplier", 1), "cooldown": definition.cooldown, "damage": definition.damage * tuning.get("damageMultiplier", 1), "splashMultiplier": tuning.get("splashMultiplier", 1), "pierce": tuning.get("pierce", 0), "slowMultiplier": tuning.get("slowMultiplier", 1), "slowSeconds": tuning.get("slowSeconds", 0)}

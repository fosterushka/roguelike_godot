extends RefCounted

static func hydrate(progression: RefCounted) -> void:
	var player: Dictionary = progression.model.player
	for wagon: Dictionary in player.get("carriers", []):
		var health := float(wagon.hp)
		wagon.max_hp -= float(wagon.get("unhydrated_armor_hp", 0))
		wagon.erase("unhydrated_armor_hp")
		for saved: Dictionary in wagon.get("modules", []).duplicate(true):
			var type := str(saved.get("type", ""))
			var mount := {"carrierId": wagon.id, "slot": int(saved.get("mount", {}).get("slot", -1))}
			if not progression._add_module(type, mount):
				continue
			var module: Dictionary = player.modules.back()
			if module.def.has("projectile"):
				for tier in range(1, int(saved.get("level", 1))):
					progression.Rules.upgrade_weapon(module)
			elif type == "radar":
				module.level = clampi(int(saved.get("level", 1)), 1, progression.RadarRules.MAX_LEVEL)
				module.def.range = progression.RadarRules.range_at(module.level)
		# Restore exact raid hull after all saved armor has established its maximum.
		wagon.hp = minf(wagon.max_hp, health)
	refresh(progression)

static func refresh(progression: RefCounted) -> void:
	var player: Dictionary = progression.model.player
	var live := {"crawler": true}
	var destroyed := {}
	var mass := 0.0
	var count := 0
	for wagon: Dictionary in player.get("carriers", []):
		if wagon.get("dead", false):
			destroyed[wagon.id] = true
		if not wagon.get("dead", false) and wagon.get("attached", true):
			live[wagon.id] = true
			mass += float(wagon.get("mass", 8))
			count += 1
	for module: Dictionary in player.get("modules", []):
		module.disabled = not live.has(str(module.get("mount", {}).get("carrierId", "crawler")))
	# Remove effects before removing destroyed modules; detached survivors keep identities.
	progression._refresh_protocols()
	var inactive_mass := 0.0
	for module: Dictionary in player.get("modules", []).duplicate():
		if destroyed.has(str(module.get("mount", {}).get("carrierId", "crawler"))):
			player.modules.erase(module)
			progression.model.weapons.erase(module)
			progression._draft.clear()
			player.weight -= float(module.get("def", {}).get("weight", 0))
			continue
		if module.disabled:
			inactive_mass += float(module.get("def", {}).get("weight", 0))
	player.weight = maxf(1, float(player.get("weight", 12)) + mass - float(player.get("convoy_mass", 0)) - inactive_mass + float(player.get("inactive_module_mass", 0)))
	player.convoy_mass = mass
	player.inactive_module_mass = inactive_mass
	var fuel_factor := 1.0 + count * 0.055 + mass * 0.003
	player.fuel_burn_mult = float(player.get("fuel_burn_mult", 1)) / float(player.get("convoy_fuel_factor", 1)) * fuel_factor
	player.convoy_fuel_factor = fuel_factor
	player.weapon_capacity = int(player.get("weapon_capacity", 4)) + count - int(player.get("convoy_weapon_slots", 0))
	player.convoy_weapon_slots = count
	progression._refresh_protocols()

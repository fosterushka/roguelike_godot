extends RefCounted
const Radar = preload("res://modules/progression/radar_rules.gd")

static func target(player: Dictionary, module: Dictionary) -> Dictionary:
	var id := str(module.get("mount", {}).get("carrierId", "crawler"))
	if id == "crawler":
		return player
	for wagon: Dictionary in player.get("carriers", []):
		if str(wagon.id) == id:
			return wagon
	return {}

static func install(player: Dictionary, module: Dictionary) -> void:
	refresh(player)
	if module.type == "armor":
		var carrier := target(player, module)
		if not carrier.is_empty():
			carrier.hp = minf(carrier.max_hp, carrier.hp + 55)

static func refresh(player: Dictionary) -> void:
	player.radar_level = 0
	player.radar_range = 0.0
	player.has_bumper = false
	for module: Dictionary in player.get("modules", []):
		var enabled: bool = not module.get("disabled", false)
		match str(module.type):
			"armor":
				var carrier := target(player, module)
				var applied := bool(module.get("armor_applied", false))
				if carrier.is_empty() or applied == enabled:
					continue
				carrier.max_hp = maxf(1, float(carrier.max_hp) + (55 if enabled else -55))
				carrier.hp = minf(carrier.hp, carrier.max_hp)
				if enabled:
					module.armor_granted = minf(0.05, maxf(0, 0.6 - float(carrier.get("armor", 0))))
				carrier.armor = maxf(0, float(carrier.get("armor", 0)) + float(module.get("armor_granted", 0)) * (1 if enabled else -1))
				module.armor_applied = enabled
			"radar":
				if enabled:
					player.radar_level = maxi(player.radar_level, int(module.level))
					player.radar_range = Radar.range_at(player.radar_level)
			"bumper":
				player.has_bumper = player.has_bumper or enabled

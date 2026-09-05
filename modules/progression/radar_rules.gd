extends RefCounted

const BASE_MAP_RANGE := 18.0
const RANGES := [0.0, 40.0, 90.0, 160.0, 260.0]
const COSTS := [0, 55, 45, 70, 100]
const MAX_LEVEL := 4

static func range_at(level: int) -> float:
	return RANGES[clampi(level, 0, MAX_LEVEL)]

static func power_at(level: int) -> int:
	return roundi(range_at(level) / RANGES[MAX_LEVEL] * 100)

static func upgrade(player: Dictionary, requested_level: int) -> bool:
	for module: Dictionary in player.get("modules", []):
		if module.type != "radar":
			continue
		var current := int(module.level)
		if requested_level != current + 1 or requested_level > MAX_LEVEL or int(player.get("coins", 0)) < COSTS[requested_level] or int(player.get("pending_upgrades", 0)) > 0:
			return false
		player.coins -= COSTS[requested_level]
		module.level = requested_level
		module.def.range = range_at(requested_level)
		player.radar_level = requested_level
		player.radar_range = range_at(requested_level)
		return true
	return false

static func shop_row(player: Dictionary) -> Dictionary:
	for module: Dictionary in player.get("modules", []):
		if module.type != "radar":
			continue
		var current := int(module.level)
		var next := mini(MAX_LEVEL, current + 1)
		var cost: int = 0 if current >= MAX_LEVEL else COSTS[next]
		var reason := "Maximum tier" if current >= MAX_LEVEL else "Finish the level-up choices" if int(player.get("pending_upgrades", 0)) > 0 else "Need %d salvage" % cost if int(player.get("coins", 0)) < cost else ""
		return {"id": "radar:%d" % next, "label": "Radar Array MK %d" % next, "title": "Radar Array MK %d" % next, "description": "%.0f m → %.0f m · %d%%" % [range_at(current), range_at(next), power_at(next)], "cost": cost, "enabled": reason.is_empty(), "disabled_reason": reason}
	return {}

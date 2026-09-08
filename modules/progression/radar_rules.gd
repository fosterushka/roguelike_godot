extends RefCounted

const BASE_MAP_RANGE := 18.0
const RANGES := [0.0, 40.0, 90.0, 160.0, 260.0, 360.0]
const COSTS := [0, 55, 45, 70, 100, 140]
const MAX_LEVEL := 5
const MISSION_CONTACT_LEVEL := 3
const EXTRACTION_ZONE_LEVEL := 5
const SIGNAL_NEAR_DISTANCE := 150.0
const SIGNAL_FAR_DISTANCE := 700.0
const SIGNAL_NEAR_INTERVAL := Vector2(5.0, 10.0)
const SIGNAL_FAR_INTERVAL := Vector2(10.0, 20.0)
const SIGNAL_DURATION := 2.4

static func identifies_missions(level: int) -> bool:
	return level >= MISSION_CONTACT_LEVEL

static func reveals_extraction(level: int) -> bool:
	return level >= EXTRACTION_ZONE_LEVEL

static func signal_interval(distance: float, variation: float = 0.5) -> float:
	var proximity := clampf(inverse_lerp(SIGNAL_NEAR_DISTANCE, SIGNAL_FAR_DISTANCE, distance), 0.0, 1.0)
	var bounds := SIGNAL_NEAR_INTERVAL.lerp(SIGNAL_FAR_INTERVAL, proximity)
	return lerpf(bounds.x, bounds.y, clampf(variation, 0.0, 1.0))

static func signal_alpha(age: float) -> float:
	return sin(clampf(age / SIGNAL_DURATION, 0.0, 1.0) * PI)


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
		return {"id": "radar:%d" % next, "label": "Radar Array MK %d" % next, "title": "Radar Array MK %d" % next, "description": "%.0f m → %.0f m · %d%%" % [range_at(current), range_at(next), power_at(next)] + (" · Extraction zones" if next >= EXTRACTION_ZONE_LEVEL else " · Mission signals" if next >= MISSION_CONTACT_LEVEL else ""), "cost": cost, "enabled": reason.is_empty(), "disabled_reason": reason}
	return {}

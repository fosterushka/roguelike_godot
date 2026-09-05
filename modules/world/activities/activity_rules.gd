extends RefCounted
const LIVE := ["announced", "active"]
const MAJOR := ["raiderSupplyConvoy", "settlementDistress", "foundryDispatch"]
const LIMIT_MAJOR := 1
const LIMIT_MINOR := 2
const HISTORY := 16
const RECOVERY := 10.0
const ANNOUNCE := 2.5
const DURATIONS := {"raiderSupplyConvoy": 95.0, "settlementDistress": 62.0, "foundryDispatch": 60.0, "scavengerRoute": 82.0}
const REWARDS := {"raiderSupplyConvoy": 18, "settlementDistress": 14, "foundryDispatch": 10, "scavengerRoute": 8}
const REWARD_LABELS := {"raiderSupplyConvoy": "Weapon blueprint + weapon cargo", "settlementDistress": "Repair 35% hull + medical supplies", "foundryDispatch": "Rare upgrade cargo", "scavengerRoute": "Fuel + salvage cargo"}
const LOOT_SOURCES := {"raiderSupplyConvoy": "convoy", "settlementDistress": "settlement", "foundryDispatch": "foundry", "scavengerRoute": "salvage"}
const OBJECTIVES := {"raiderSupplyConvoy": "Destroy the convoy before it clears the road", "settlementDistress": "Clear the raiders threatening the village", "foundryDispatch": "Intercept the foundry reinforcement", "scavengerRoute": "Meet the scavenger crawler on the road"}

static func live_count(records: Array, major: bool) -> int:
	var count := 0
	for record: Dictionary in records:
		if record.state in LIVE and (record.type in MAJOR) == major:
			count += 1
	return count

static func route_length(points: Array) -> float:
	var length := 0.0
	for index in range(1, points.size()):
		length += point(points[index - 1]).distance_to(point(points[index]))
	return length

static func point(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	return Vector3(float(value.x), 0, float(value.z))

static func sample_route(points: Array, travelled: float) -> Dictionary:
	var total := route_length(points)
	var remaining := clampf(travelled, 0.0, total)
	for index in range(1, points.size()):
		var start := point(points[index - 1])
		var end := point(points[index])
		var length := start.distance_to(end)
		if remaining <= length or index == points.size() - 1:
			return {"position": start.lerp(end, clampf(remaining / maxf(length, 0.0001), 0.0, 1.0)), "yaw": atan2(end.x - start.x, end.z - start.z), "progress": clampf(travelled / maxf(total, 0.0001), 0.0, 1.0)}
		remaining -= length
	return {"position": point(points[0]) if not points.is_empty() else Vector3.ZERO, "yaw": 0.0, "progress": 1.0}

static func pressure_budget(wave: int, health_ratio: float) -> float:
	var budget := 72.0 if wave == 1 else 90.0 if wave == 2 else 108.0 if wave == 3 else 116.0 if wave == 4 else 128.0 if wave == 5 else 140.0
	var mercy := 1.0 if health_ratio >= 0.55 else 0.48 if health_ratio <= 0.2 else lerpf(0.48, 1.0, (health_ratio - 0.2) / 0.35)
	return roundf(budget * mercy * 10.0) / 10.0

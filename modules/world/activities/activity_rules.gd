extends RefCounted
const Fuel = preload("res://modules/caravan/vehicle_fuel.gd")
const MAX_SPAWN_DISTANCE := 700.0
const TRAVEL_SPEED_RATIO := 0.65
const TRAVEL_DETOUR_RATIO := 1.25
const FUEL_RESERVE_RATIO := 0.25
const COMPLETION_SECONDS := 25.0
const ARRIVAL_BUFFER_SECONDS := 10.0
const ROUTE_SAMPLE_DISTANCE := 40.0
const ROUTE_SPEEDS := {"raiderSupplyConvoy": 6.2, "scavengerRoute": 4.2}

static func travel_speed(fuel: float, stats: Dictionary) -> float:
	return Fuel.maximum_speed(fuel, stats) * TRAVEL_SPEED_RATIO

static func travel_seconds(distance: float, fuel: float, stats: Dictionary) -> float:
	return distance * TRAVEL_DETOUR_RATIO / maxf(travel_speed(fuel, stats), 0.1)

static func reachable_radius(fuel: float, stats: Dictionary) -> float:
	# Ask the fuel owner for full-speed, full-throttle consumption, including upgrades.
	var burn := Fuel.CAPACITY - Fuel.consume(Fuel.CAPACITY, Fuel.CAPACITY, Fuel.maximum_speed(fuel, stats), 1.0, 1.0, float(stats.get("fuel_burn_mult", 1.0)))
	var seconds := fuel * (1.0 - FUEL_RESERVE_RATIO) / maxf(burn, 0.001)
	return clampf((seconds - COMPLETION_SECONDS - ARRIVAL_BUFFER_SECONDS) * travel_speed(fuel, stats) / TRAVEL_DETOUR_RATIO, 0.0, MAX_SPAWN_DISTANCE)

static func encounter_seconds(distance: float, fuel: float, stats: Dictionary) -> float:
	return travel_seconds(distance, fuel, stats) + COMPLETION_SECONDS + ARRIVAL_BUFFER_SECONDS

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

static func sampled_route(points: Array) -> Array:
	var samples: Array = []
	if points.is_empty():
		return samples
	samples.append(point(points[0]))
	for index in range(1, points.size()):
		var start := point(points[index - 1])
		var end := point(points[index])
		var subdivisions := maxi(1, ceili(start.distance_to(end) / ROUTE_SAMPLE_DISTANCE))
		for step in range(1, subdivisions + 1):
			samples.append(start.lerp(end, float(step) / subdivisions))
	return samples

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

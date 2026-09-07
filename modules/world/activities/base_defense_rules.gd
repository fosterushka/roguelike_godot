extends RefCounted

const NETWORK_SIZE := 10
const SPAWN_ATTEMPTS := 180
const MIN_DISTANCE := 180.0
const MAX_DISTANCE := 1128.0
const PLAYER_CLEARANCE := 170.0
const BASE_CLEARANCE := 120.0
const EXTRACTION_CLEARANCE := 12.0
const COLLIDER_LAYER := 1
const DEFENDER_RADIUS := 0.7
const EXIT_CLEARANCE := 0.36
const EXIT_SPACING := 0.28
const EXIT_LANE_SPACING := 0.78
const DEPLOY_DURATION := 0.7
const RESPONSE_COOLDOWN := 2.4
const DAMAGE_RATIO_PER_RESPONSE := 0.12
const DAMAGE_THRESHOLD_EPSILON := 0.001
const DEFENDERS_BY_TIER := [3, 4, 5]
const EARLY_KINDS := ["rifleman", "ak", "rifleman", "ak"]
const LATE_KINDS := ["rifleman", "ak", "bazooka", "ak", "rifleman"]

static func defender_count(tier: int) -> int:
	return DEFENDERS_BY_TIER[clampi(tier, 1, DEFENDERS_BY_TIER.size()) - 1]

static func damage_threshold(max_hp: float) -> float:
	return maxf(1.0, max_hp * DAMAGE_RATIO_PER_RESPONSE)

static func defender_kind(tier: int, wave: int, random) -> String:
	var choices: Array = LATE_KINDS if wave >= 3 or tier >= 3 else EARLY_KINDS
	return str(choices[random.integer(0, choices.size() - 1)])

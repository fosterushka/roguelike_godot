extends RefCounted

const TYPES := ["sunny", "foggy", "rainy", "storm"]
const TRANSITION_SECONDS := 24.0
const PHASE_MIN_MS := 120000
const PHASE_MAX_MS := 180000
const WET_RETENTION := 6.0
const MUD_RADIUS := 5.0
const MUD_DURATION := 14.0
const MAX_MUD_ZONES := 10
const MUD_MOVEMENT := 0.62
const MUD_TURN := 0.55
const LIGHTNING_MIN_MS := 45000
const LIGHTNING_MAX_MS := 90000
const LIGHTNING_TARGET_CHANCE := 0.08
const LIGHTNING_PLAYER_CHANCE := 0.025
const LIGHTNING_RADIUS := 6.0
const TRACTION := {"sunny": 1.0, "clear": 1.0, "foggy": 0.92, "rainy": 0.78, "storm": 0.68}

static func imul(a: int, b: int) -> int:
	return (((a & 65535) * (b & 65535)) + (((((a >> 16) & 65535) * (b & 65535) + (a & 65535) * ((b >> 16) & 65535)) & 65535) << 16)) & 0xffffffff

static func unit(seed: int, phase: int, salt: int) -> float:
	var value := (seed ^ imul(phase + 1, 0x9e3779b1) ^ salt) & 0xffffffff
	value = imul(value ^ (value >> 16), 0x21f0aaad)
	value = imul(value ^ (value >> 15), 0x735a2d97)
	return float((value ^ (value >> 15)) & 0xffffffff) / 4294967296.0

static func phase_at(seed: int, elapsed_seconds: float) -> Dictionary:
	var index := 0
	var type_index := floori(unit(seed, 0, 0x51f15e) * 4.0)
	var previous_type: String = TYPES[type_index]
	var start := 0
	var elapsed := floori(elapsed_seconds * 1000.0)
	while true:
		var duration := roundi(PHASE_MIN_MS + unit(seed, index, 0x2c9277) * (PHASE_MAX_MS - PHASE_MIN_MS))
		if elapsed < start + duration:
			return {"index": index, "type": TYPES[type_index], "previous_type": previous_type, "starts_at": float(start) / 1000.0, "ends_at": float(start + duration) / 1000.0, "duration": float(duration) / 1000.0}
		start += duration
		index += 1
		previous_type = TYPES[type_index]
		type_index = (type_index + 1 + floori(unit(seed, index, 0x77a31d) * 3.0)) % 4
	return {}

static func cosmetic_unit(seed: int, phase: int, strike: int, salt: int) -> float:
	return unit(seed ^ imul(strike + 1, 0x45d9f3b), phase, salt)

static func lightning_sample(seed: int, phase: int, strike: int) -> Dictionary:
	return {"delay": float(roundi(LIGHTNING_MIN_MS + cosmetic_unit(seed, phase, strike, 0x18f4d3) * (LIGHTNING_MAX_MS - LIGHTNING_MIN_MS))) / 1000.0,
		"target_roll": cosmetic_unit(seed, phase, strike, 0x7f4a71), "target_index": cosmetic_unit(seed, phase, strike, 0x31c8ab),
		"screen_x": -0.72 + cosmetic_unit(seed, phase, strike, 0x6c8e9f) * 1.44,
		"screen_y": -0.55 + cosmetic_unit(seed, phase, strike, 0xa37b51) * 1.2,
		"effect_seed": floori(cosmetic_unit(seed, phase, strike, 0xd129a7) * 4294967296.0) & 0xffffffff}

static func wet(type: String) -> bool:
	return type in ["rainy", "storm"]

static func range_multiplier(type: String, radar: bool = false, npc: bool = false) -> float:
	return 1.0 if type != "foggy" else 0.72 if npc else 0.84 if radar else 0.68

# Every phase is longer than the fade, so the previous phase is fully settled.
# Absolute phase time keeps this identical across simulation/render step sizes.
static func mix_for_phase(phase: Dictionary, elapsed: float) -> Vector4:
	var current := str(phase.get("type", "sunny"))
	var previous := str(phase.get("previous_type", current))
	var t := clampf((elapsed - float(phase.get("starts_at", 0))) / TRANSITION_SECONDS, 0, 1)
	var blend := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	return type_mix(previous).lerp(type_mix(current), blend)

static func type_mix(type: String) -> Vector4:
	var result := Vector4.ZERO
	result[maxi(0, TYPES.find(type))] = 1.0
	return result

static func visibility_multiplier(fog_strength: float, radar: bool = false, npc: bool = false) -> float:
	return lerpf(1.0, 0.72 if npc else 0.84 if radar else 0.68, clampf(fog_strength, 0, 1))

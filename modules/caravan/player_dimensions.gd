extends RefCounted

# Authored pickup is normalized to the existing 0.88 tire radius.
const MODEL_SCALE := 0.88 / 0.705
const WHEEL_HALF_TRACK := 1.4396 * MODEL_SCALE
const WHEEL_FRONT_Z := 1.98 * MODEL_SCALE

const BASE_SCALE := 0.88
const MAX_SCALE := 1.42
const BASE_RADIUS := 3.5

static func target_scale(level: int) -> float:
	return minf(MAX_SCALE, BASE_SCALE + (maxi(1, level) - 1) * 0.075)

static func radius(scale_value: float) -> float:
	return BASE_RADIUS * maxf(0.0, scale_value if scale_value != 0.0 else BASE_SCALE) / BASE_SCALE

static func advance_scale(current: float, level: int, delta: float) -> float:
	return lerpf(current, target_scale(level), 1.0 - exp(-2.35 * maxf(0.0, delta)))

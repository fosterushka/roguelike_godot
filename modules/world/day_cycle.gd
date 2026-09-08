extends RefCounted

const CYCLE_SECONDS := 480.0
const START_PHASE := 0.18
const NIGHT_LIGHT := 0.55
const NIGHT_AMBIENT := 0.60
const DAY_AMBIENT := 2.0 / PI
const NIGHT_SKY := Color("607ea5")
const NIGHT_FOG := Color("6687b0")
const MOON_COLOR := Color("7399ff")
const SUN_COLOR := Color("ffe2ab")

static func sample(elapsed: float) -> Dictionary:
	var phase := fposmod(elapsed / CYCLE_SECONDS + START_PHASE, 1.0)
	var altitude := sin(phase * TAU)
	var daylight := smoothstep(-0.18, 0.3, altitude)
	return {"phase": phase, "daylight": daylight, "light": lerpf(NIGHT_LIGHT, 1.0, daylight), "ambient": lerpf(NIGHT_AMBIENT, DAY_AMBIENT, daylight), "direction": Vector3(cos(phase * TAU) * 0.65, -maxf(0.22, absf(altitude)), -0.4).normalized()}

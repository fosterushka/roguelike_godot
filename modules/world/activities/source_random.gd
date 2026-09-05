extends RefCounted
const Math32 = preload("res://modules/world/weather_rules.gd")
var state := 0

func seed_run(seed: int) -> void:
	var value := (seed ^ 0x4f1bbcdc) & 0xffffffff
	value = Math32.imul(value ^ (value >> 16), 0x7feb352d)
	value = Math32.imul(value ^ (value >> 15), 0x846ca68b)
	state = (value ^ (value >> 16)) & 0xffffffff

func next() -> float:
	state = (Math32.imul(1664525, state) + 1013904223) & 0xffffffff
	return float(state) / 4294967296.0

func between(minimum: float, maximum: float) -> float:
	return minimum + (maximum - minimum) * next()

func integer(minimum: int, maximum: int) -> int:
	return floori(between(minimum, maximum + 1))

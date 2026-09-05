extends RefCounted
var state: int
func _init(seed_value: int = 81173) -> void:
	state = seed_value & 0xffffffff
func next_float() -> float:
	state = (1664525 * state + 1013904223) & 0xffffffff
	return float(state) / 4294967296.0
func between(minimum: float, maximum: float) -> float:
	return minimum + (maximum - minimum) * next_float()

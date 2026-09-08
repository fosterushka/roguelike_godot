extends RefCounted

const CAPACITY := 3600
const USEC_PER_MS := 1000.0
const MS_PER_SECOND := 1000.0
const LOW_FRACTION := 0.01
const VERY_LOW_FRACTION := 0.001
var samples := PackedFloat64Array()
var cursor := 0

func record(milliseconds: float) -> void:
	if milliseconds <= 0.0 or not is_finite(milliseconds):
		return
	if samples.size() < CAPACITY:
		samples.append(milliseconds)
	else:
		samples[cursor] = milliseconds
	cursor = (cursor + 1) % CAPACITY

func reset() -> void:
	samples.clear()
	cursor = 0

func recent(count: int) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	var length := mini(count, samples.size())
	for index in length:
		result.append(samples[posmod(cursor - length + index, samples.size())])
	return result

func summary() -> Dictionary:
	if samples.is_empty():
		return {}
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for sample in sorted:
		total += sample
	var average := total / sorted.size()
	return {"count": sorted.size(), "seconds": total / MS_PER_SECOND,
		"current_ms": samples[posmod(cursor - 1, samples.size())],
		"average_ms": average, "min_ms": sorted[0], "max_ms": sorted[-1],
		"average_fps": MS_PER_SECOND / average, "min_fps": MS_PER_SECOND / sorted[-1],
		"max_fps": MS_PER_SECOND / sorted[0], "low_1": _low(sorted, LOW_FRACTION),
		"low_01": _low(sorted, VERY_LOW_FRACTION) if sorted.size() >= int(1.0 / VERY_LOW_FRACTION) else -1.0}

func _low(sorted: PackedFloat64Array, fraction: float) -> float:
	var count := maxi(1, ceili(sorted.size() * fraction))
	var total := 0.0
	for index in range(sorted.size() - count, sorted.size()):
		total += sorted[index]
	return MS_PER_SECOND * count / total

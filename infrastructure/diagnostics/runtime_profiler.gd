extends RefCounted

# Inclusive wall time: nested sections must not be added together.
static var enabled := false
static var totals: Dictionary = {}

static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func finish(section: StringName, started: int) -> void:
	if not enabled or started == 0:
		return
	var elapsed := Time.get_ticks_usec() - started
	var row: Dictionary = totals.get(section, {"usec": 0, "calls": 0, "max_usec": 0})
	row.usec += elapsed
	row.calls += 1
	row.max_usec = maxi(row.max_usec, elapsed)
	totals[section] = row

static func take() -> Dictionary:
	var result := totals
	totals = {}
	return result

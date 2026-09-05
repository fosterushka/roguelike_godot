extends RefCounted
const REQUIRED_CREDITS := 2
const ACTIVATION_RADIUS := 22.0
const ZONE_RADIUS := 12.0
const HOSTILE_RADIUS := 28.0
const SECURE_SECONDS := 30.0
const LEAVE_GRACE := 2.0
const MAXIMUM_SPEED := 1.5

static func empty() -> Dictionary:
	return {"active": false, "village_id": "", "anchor_id": "", "position": Vector3.ZERO, "progress": 0.0, "contested": false, "out_of_range": 0.0, "hostile_count": 0}

static func step(progress: float, delta: float, valid: bool, in_range: bool, contested: bool, out_of_range: float) -> Dictionary:
	var current := clampf(progress, 0.0, SECURE_SECONDS)
	if not valid:
		return {"status": "failed", "progress": 0.0, "out_of_range": 0.0, "completed": false}
	if not in_range:
		var leaving := maxf(0.0, out_of_range) + maxf(0.0, delta)
		return {"status": "abandoned" if leaving >= LEAVE_GRACE else "leaving", "progress": current, "out_of_range": leaving, "completed": false}
	if contested:
		return {"status": "contested", "progress": current, "out_of_range": 0.0, "completed": false}
	var next := clampf(current + maxf(0.0, delta), 0.0, SECURE_SECONDS)
	return {"status": "completed" if next >= SECURE_SECONDS else "securing", "progress": next, "out_of_range": 0.0, "completed": next >= SECURE_SECONDS}

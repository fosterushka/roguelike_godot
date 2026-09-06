extends RefCounted
const REQUIRED_CREDITS := 0
const ACTIVATION_RADIUS := 18.0
const ZONE_RADIUS := 18.0
const HOSTILE_RADIUS := 42.0
const SECURE_SECONDS := 20.0
const LEAVE_GRACE := 3.0
const MAXIMUM_SPEED := INF

static func empty() -> Dictionary:
	return {"active": false, "site_id": "", "zone_id": "", "village_id": "", "anchor_id": "", "position": Vector3.ZERO, "progress": 0.0, "contested": false, "out_of_range": 0.0, "hostile_count": 0, "next_wave_at": 0.0, "spawned": 0}

static func step(progress: float, delta: float, valid: bool, in_range: bool, _contested: bool, out_of_range: float) -> Dictionary:
	var current := clampf(progress, 0.0, SECURE_SECONDS)
	if not valid:
		return {"status": "failed", "progress": 0.0, "out_of_range": 0.0, "completed": false}
	if not in_range:
		var leaving := maxf(0.0, out_of_range) + maxf(0.0, delta)
		return {"status": "abandoned" if leaving >= LEAVE_GRACE else "leaving", "progress": current, "out_of_range": leaving, "completed": false}
	var next := clampf(current + maxf(0.0, delta), 0.0, SECURE_SECONDS)
	return {"status": "completed" if next >= SECURE_SECONDS else "defending", "progress": next, "out_of_range": 0.0, "completed": next >= SECURE_SECONDS}

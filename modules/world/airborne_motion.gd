extends RefCounted
const Policy = preload("res://modules/world/destruction_policy.gd")
const Ground = preload("res://modules/caravan/terrain_surface.gd")

static func create(point: Vector3, identity: String, center: Vector3) -> Dictionary:
	var offset := point - center
	offset.y = 0.0
	var direction := offset.normalized() if offset.length_squared() > 0.01 else Vector3.RIGHT
	return {"phase": "lifting", "age": 0.0, "position": Vector3(point.x, Ground.height_at(point.x, point.z), point.z), "velocity": Vector3.ZERO, "direction": direction, "spin": (Policy.roll(identity + ":spin") * 2.0 - 1.0) * 3.0, "roll": 0.0, "landed": false, "impact_speed": 0.0}

static func step(state: Dictionary, center: Vector3, delta: float) -> void:
	if delta <= 0.0 or state.landed:
		return
	var steps := maxi(1, ceili(delta * 120.0))
	var dt := delta / steps
	for index in steps:
		state.age += dt
		state.roll += float(state.spin) * dt
		if state.phase == "lifting":
			var offset: Vector3 = center - state.position
			offset.y = 0.0
			var tangent := Vector3(-offset.z, 0.0, offset.x)
			state.velocity = offset.limit_length(3.0) + tangent.limit_length(4.0) + Vector3.UP * 5.5
			state.position += state.velocity * dt
			if state.age >= float(Policy.settings().capture_seconds):
				var outward: Vector3 = state.position - center
				outward.y = 0.0
				outward = outward.normalized() if outward.length_squared() > 0.01 else state.direction
				state.velocity = outward * float(Policy.settings().throw_speed) + Vector3.UP * float(Policy.settings().throw_up_speed)
				state.phase = "falling"
		else:
			state.velocity.y -= float(Policy.settings().gravity) * dt
			state.position += state.velocity * dt
			var ground := Ground.height_at(state.position.x, state.position.z)
			if state.position.y <= ground:
				state.impact_speed = maxf(0.0, -state.velocity.y)
				state.position.y = ground
				state.landed = true
				break

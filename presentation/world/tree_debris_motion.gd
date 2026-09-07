extends RefCounted

const Ground = preload("res://modules/caravan/terrain_surface.gd")
const GRAVITY := 14.0
const RESTITUTION := 0.22
const FRICTION := 3.5
const ANGULAR_DRAG := 2.8
const TOPPLE_TORQUE := 18.0
const TRUNK_RADIUS := 0.22
const MAX_STEP := 1.0 / 120.0
const MAX_CATCHUP := 0.5

static func create(node: Node3D, point: Vector3, velocity: Vector3, spin: float) -> Dictionary:
	var half_length := 1.5
	for child: Node in node.get_children():
		if child is MeshInstance3D and child.visible and child.mesh != null:
			half_length = maxf(half_length, (child.transform * child.mesh.get_aabb()).end.y * 0.5)
	var up := node.basis.y.normalized()
	var center := point + up * half_length
	center.y = maxf(center.y, Ground.height_at(center.x, center.z) + absf(up.y) * half_length + TRUNK_RADIUS)
	var axis := Vector3.UP.cross(up.slide(Vector3.UP).normalized())
	if axis.length_squared() < 0.01:
		axis = Vector3.RIGHT
	return {"center": center, "rotation": node.quaternion, "velocity": velocity.limit_length(12.0), "angular_velocity": axis * maxf(1.0, absf(spin)), "half_length": half_length, "fallback_axis": axis}

static func step(state: Dictionary, delta: float, node: Node3D) -> void:
	var duration := clampf(delta, 0.0, MAX_CATCHUP)
	var steps := maxi(1, ceili(duration / MAX_STEP))
	var dt := duration / steps
	for index in steps:
		state.velocity.y -= GRAVITY * dt
		state.center += state.velocity * dt
		var up: Vector3 = state.rotation * Vector3.UP
		var ground := Ground.height_at(state.center.x, state.center.z)
		var support := absf(up.y) * float(state.half_length) + TRUNK_RADIUS
		if state.center.y <= ground + support:
			state.center.y = ground + support
			if state.velocity.y < 0.0:
				state.velocity.y *= -RESTITUTION
			state.velocity.x *= exp(-FRICTION * dt)
			state.velocity.z *= exp(-FRICTION * dt)
			# Ground contact converts the upright component into angular momentum.
			var axis := up.cross(up.slide(Vector3.UP).normalized())
			if axis.length_squared() < 0.0001 and absf(up.y) > 0.8:
				axis = state.fallback_axis
			state.angular_velocity += axis * TOPPLE_TORQUE * dt
			state.angular_velocity *= exp(-ANGULAR_DRAG * dt)
		var angular_speed: float = state.angular_velocity.length()
		if angular_speed > 0.00001:
			state.rotation = (Quaternion(state.angular_velocity / angular_speed, angular_speed * dt) * Quaternion(state.rotation)).normalized()
	node.quaternion = state.rotation
	var up: Vector3 = node.basis.y.normalized()
	node.position = state.center - up * float(state.half_length)

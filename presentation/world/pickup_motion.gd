extends RefCounted

## The same terrain-relative spin and bob applies to pooled scrap and item drops.
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const HOVER_HEIGHT := 0.72
const BOB_HEIGHT := 0.2
const BOB_SPEED := 3.4
const SPIN_SPEED := 4.4
const TILT_SPEED := 0.7
const TILT_ANGLE := 0.15

static func pose(point: Vector3, elapsed: float, phase_offset: float = 0.0) -> Transform3D:
	var phase := elapsed * BOB_SPEED + phase_offset
	point.y = Terrain.height_at(point.x, point.z) + HOVER_HEIGHT + sin(phase) * BOB_HEIGHT
	return Transform3D(Basis(Vector3.UP, elapsed * SPIN_SPEED) * Basis(Vector3.BACK, sin(phase * TILT_SPEED) * TILT_ANGLE), point)

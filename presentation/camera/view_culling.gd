extends RefCounted

## Shared owner of the camera view volume. Presentation systems ask it whether a world point
## is worth animating and submitting this frame, so actors the player cannot see cost nothing.
##
## The reserve around the viewport is expressed in screen pixels, so it covers the same
## on-screen distance at every zoom level. Instances take their pool slot while they are still
## outside the visible rect and are already in place by the time the camera reaches them.
const MARGIN_PIXELS := 100.0
# Headless runs can report an empty viewport rect; the project window height keeps the reserve sane.
const FALLBACK_VIEWPORT_HEIGHT := 800.0

static var _planes: Array[Plane] = []
static var _margin := 0.0
static var _active := false
static var _frame := -1

## Rebuilds the volume once per frame. Every consumer refreshes before its own loop; the
## calls after the first one in a frame reuse the planes the camera already produced.
static func refresh(camera: Camera3D) -> void:
	var frame := Engine.get_process_frames()
	if frame == _frame:
		return
	_frame = frame
	_active = false
	_planes = []
	# Only the orthographic gameplay camera has one world-per-pixel scale across the whole view.
	if not is_instance_valid(camera) or not camera.is_inside_tree() or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return
	var height: float = camera.get_viewport().get_visible_rect().size.y
	if height <= 0.0:
		height = FALLBACK_VIEWPORT_HEIGHT
	_margin = MARGIN_PIXELS * camera.size / height
	_planes = camera.get_frustum()
	_active = not _planes.is_empty()

## Frustum planes point outward, so a positive distance means the point left the view.
## Without an active camera every point counts as visible: culling never hides gameplay.
static func contains(point: Vector3, radius: float = 0.0) -> bool:
	if not _active:
		return true
	var reach := _margin + radius
	for plane: Plane in _planes:
		if plane.distance_to(point) > reach:
			return false
	return true

## World units the reserve covers at the current zoom.
static func margin() -> float:
	return _margin

static func active() -> bool:
	return _active

## Drops the cached camera so a new scene, or a test, rebuilds the volume immediately.
static func reset() -> void:
	_frame = -1
	_active = false
	_planes = []

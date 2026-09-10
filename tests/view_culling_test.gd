extends SceneTree

const Culling = preload("res://presentation/camera/view_culling.gd")
const CombatView = preload("res://presentation/combat/combat_view.gd")
const EnemyFactory = preload("res://modules/combat/enemy_factory.gd")
const SPREAD_COUNT := 80
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_no_camera()
	_orthographic_volume()
	_perspective_camera()
	_enemy_extent()
	await _combat_pools()
	print("View culling: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _no_camera() -> void:
	Culling.reset()
	Culling.refresh(null)
	check(not Culling.active(), "A missing camera leaves the volume inactive")
	check(Culling.contains(Vector3(9000, 0, 9000)), "An inactive volume keeps every instance visible")

func _orthographic_volume() -> void:
	var camera := _camera(Camera3D.PROJECTION_ORTHOGONAL)
	var height := root.get_visible_rect().size.y
	var expected := Culling.MARGIN_PIXELS * camera.size / height
	check(Culling.active(), "An orthographic gameplay camera activates the volume")
	check(is_equal_approx(Culling.margin(), expected), "The reserve is %.1f screen pixels at the current zoom" % Culling.MARGIN_PIXELS)
	check(Culling.contains(Vector3.ZERO), "The focused point stays visible")
	# The camera looks down the (-1, -1) diagonal, so this axis leaves the rect sideways.
	var side := Vector3(1, 0, -1).normalized()
	var edge := camera.size * 0.5 * root.get_visible_rect().size.x / height
	check(Culling.contains(side * (edge - 1.0)), "A point inside the visible rect is kept")
	check(Culling.contains(side * (edge + expected * 0.5)), "A point inside the reserve is placed before it reaches the screen")
	check(not Culling.contains(side * (edge + expected + 5.0)), "A point past the reserve is skipped")
	check(Culling.contains(side * (edge + expected + 5.0), 10.0), "A wide model reaching into the reserve is kept")
	check(not Culling.contains(Vector3(600, 0, -600)), "A distant actor is skipped")
	camera.queue_free()

func _perspective_camera() -> void:
	var camera := _camera(Camera3D.PROJECTION_PERSPECTIVE)
	check(not Culling.active(), "A perspective camera has no zoom independent pixel scale and keeps every instance")
	check(Culling.contains(Vector3(600, 0, -600)), "A perspective camera keeps distant instances visible")
	camera.queue_free()

func _enemy_extent() -> void:
	var garrison := {"radius": 5.76, "height": 4.485}
	var soldier := {"radius": 0.6}
	check(CombatView._enemy_extent(garrison) > CombatView._enemy_extent(soldier), "A garrison reserves more room than a soldier")
	check(CombatView._enemy_extent(soldier) >= CombatView.GROUND_RELIEF, "Every actor reserves the terrain relief it can stand on")
	check(CombatView._enemy_extent({"radius": 1.0, "lift_height": 12.0}) > CombatView._enemy_extent({"radius": 1.0}), "A lifted actor reserves its tornado height")

class FakeRuntime extends Node3D:
	signal state_changed(data: Dictionary)
	signal combat_event(event: Dictionary)
	func get_state() -> Dictionary:
		return {}

# The combat pools submit one instance prefix per model, so culling has to shrink the prefix
# itself: a skipped actor must cost no animation, no transform write and no GPU instance.
func _combat_pools() -> void:
	var enemies := _spread()
	var runtime := FakeRuntime.new()
	root.add_child(runtime)
	var vehicle := Node3D.new()
	root.add_child(vehicle)
	var view := CombatView.new()
	root.add_child(view)
	view.setup(runtime, vehicle)
	var wide := _camera(Camera3D.PROJECTION_PERSPECTIVE)
	var placed_without := await _placed(view, enemies)
	check(placed_without == SPREAD_COUNT, "Without an orthographic camera every actor keeps its instance")
	wide.queue_free()
	var camera := _camera(Camera3D.PROJECTION_ORTHOGONAL)
	var placed_with := await _placed(view, enemies)
	check(placed_with < placed_without, "A spread wave submits fewer actors than it holds: %d of %d" % [placed_with, placed_without])
	var culled := 0
	for enemy: Dictionary in enemies:
		if Culling.contains(enemy.position, CombatView._enemy_extent(enemy)):
			continue
		culled += 1
		# The engine frustum is the ground truth: nothing the camera can show may be skipped.
		check(not camera.is_position_in_frustum(enemy.position), "A culled actor is off camera")
	check(culled > 0, "A spread wave has actors to cull")
	# The reserve is what keeps the placement invisible: an actor one screen edge away is
	# already animated and submitted before the camera can reach it.
	var edge := camera.size * 0.5 + Culling.margin() * 0.5
	var inside := Vector3(1, 0, -1).normalized() * edge
	check(Culling.contains(inside, 0.0), "An actor inside the reserve is submitted before it reaches the screen")
	camera.queue_free()
	view.queue_free()
	runtime.queue_free()
	vehicle.queue_free()

func _placed(view: Node3D, enemies: Array) -> int:
	await process_frame
	view.apply_state({"generation": 1, "elapsed": 1.0, "focus_id": -1, "enemies": enemies, "projectiles": [], "pickups": [], "mines": [], "boss_components": []})
	var total := 0
	for count in view._active_counts.values():
		total += int(count)
	return total

func _spread() -> Array:
	var random := RandomNumberGenerator.new()
	random.seed = 72841
	var roster := ["rifleman", "shooter", "bike", "buggy", "garrison_2", "keep"]
	var enemies: Array = []
	for index in SPREAD_COUNT:
		var angle := TAU * index * 0.61803
		# Wave spawning reaches from the contact ring out to the far edge of the spawn band.
		var point := Vector3(cos(angle), 0, sin(angle)) * (20.0 + 180.0 * float(index) / float(SPREAD_COUNT))
		var enemy: Dictionary = EnemyFactory.create(roster[index % roster.size()], index, point, random)
		enemy.position = point
		enemies.append(enemy)
	return enemies

func _camera(projection: int) -> Camera3D:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = projection
	camera.size = 62.0
	camera.near = 0.1
	camera.far = 500.0
	camera.current = true
	camera.global_position = Vector3(34, 45, 34)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	Culling.reset()
	Culling.refresh(camera)
	return camera

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

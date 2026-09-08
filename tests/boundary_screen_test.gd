extends SceneTree

const Hud = preload("res://presentation/ui/hud.gd")
const World = preload("res://modules/world/world_runtime.gd")
const Vehicle = preload("res://modules/caravan/vehicle_controller.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	hud.set_loading(false)
	hud.set_gameplay_active(true)
	var vehicle := Vehicle.new()
	root.add_child(vehicle)
	vehicle.set_physics_process(false)
	var world := World.new()
	root.add_child(world)
	world.vehicle = vehicle
	for distance: float in [World.PLAYABLE_RADIUS, World.PLAYABLE_RADIUS + 0.01, World.PLAYABLE_RADIUS - 0.01]:
		vehicle.position = Vector3(distance, 0, 0)
		world._update_boundary(0.1)
		hud.update_world({"boundary": {"outside": world.outside, "remaining": world.outside_remaining}})
		check(hud.boundary_desaturation.visible == (distance > World.PLAYABLE_RADIUS), "Actual boundary drives screen at exact radius, exit and return")
	vehicle.position.x = World.PLAYABLE_RADIUS + 1.0
	world._update_boundary(0.1)
	hud.update_world({"boundary": {"outside": world.outside}})
	hud.set_paused(true)
	check(not hud.boundary_desaturation.visible, "Pause menu retains color")
	hud.set_paused(false)
	check(hud.boundary_desaturation.visible, "Resume outside restores grayscale")
	check(hud.boundary_desaturation.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Screen effect does not intercept input")
	check(hud.boundary_desaturation.layer > 5, "Final pass includes crew speech and HUD")
	hud.set_loading(true)
	hud.set_loading(false)
	check(not hud.boundary_desaturation.visible, "New run clears stale boundary screen state")
	world.free()
	vehicle.free()
	hud.free()
	print("Boundary screen: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

extends SceneTree
const Controller = preload("res://modules/caravan/vehicle_controller.gd")
const View = preload("res://presentation/vehicles/vehicle_view.gd")
const Camera = preload("res://presentation/camera/follow_camera.gd")
var checks := 0
var failures := 0

class Probe extends Node:
	var subject: Node3D
	var camera: Camera3D
	var frames: Array[Dictionary] = []
	func _process(_delta: float) -> void:
		frames.append({"tick": Engine.get_physics_frames(), "fraction": Engine.get_physics_interpolation_fraction(), "position": subject.global_position, "camera_forward": camera.global_basis.z})

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	preload("res://app/input_actions.gd").register()
	print("ENGINE_INTERPOLATION_ENABLED ", ProjectSettings.get_setting("physics/common/physics_interpolation", false))
	for rate in [60, 144]:
		Engine.max_fps = rate
		var controller := Controller.new()
		root.add_child(controller)
		controller.player_stats = {"visual_scale": 0.88}
		var view := View.new()
		view.name = "VehicleView"
		controller.add_child(view)
		view.apply_player_state({"position": Vector3.ZERO, "heading": 0.0, "visual_scale": 0.88, "speed": 0.0, "modules": [], "carriers": [{"id": "trailer-1"}]}, 1)
		var camera := Camera.new()
		camera.target = controller
		root.add_child(camera)
		camera._intro = 0.0
		var probe := Probe.new()
		probe.subject = view
		probe.camera = camera
		probe.process_priority = 200
		root.add_child(probe)
		Input.action_press("drive_forward")
		for frame in rate * 2:
			await process_frame
		Input.action_release("drive_forward")
		var interior := 0
		var between_ticks := 0
		var backwards := 0
		var stable_camera := true
		var bounded_fraction := true
		for index in range(1, probe.frames.size()):
			var previous: Dictionary = probe.frames[index - 1]
			var current: Dictionary = probe.frames[index]
			bounded_fraction = bounded_fraction and current.fraction >= 0.0 and current.fraction <= 1.0
			if current.fraction > 0.001 and current.fraction < 0.999:
				interior += 1
			if current.tick == previous.tick and current.position.z > previous.position.z + 0.000001:
				between_ticks += 1
			if current.position.z < previous.position.z - 0.000001:
				backwards += 1
			stable_camera = stable_camera and current.camera_forward.distance_to(previous.camera_forward) < 0.00001
		print("RUNTIME ", rate, " fps frames=", probe.frames.size(), " interior=", interior, " between_physics=", between_ticks, " backward=", backwards)
		check(bounded_fraction and (rate == 60 or interior > rate), "Real engine fraction is bounded and advances at render rates above physics;60Hz phase lock is valid")
		check(backwards == 0 and view.global_position.z > 1.0, "Live input moves interpolated vehicle forward without backwards jitter")
		check(stable_camera, "Actual camera process follows rendered body without orientation jitter")
		if rate == 144:
			check(between_ticks > 60, "144FPS live render advances body between60Hz physics ticks")
		probe.queue_free()
		controller.queue_free()
		camera.queue_free()
		await process_frame
	print("Vehicle render runtime: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

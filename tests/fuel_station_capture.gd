extends SceneTree

const Fixture = preload("res://tests/fuel_station_test.gd")
const Vehicle = preload("res://modules/caravan/vehicle_controller.gd")
const Combat = preload("res://modules/combat/combat_runtime.gd")
const World = preload("res://modules/world/world_runtime.gd")
const CombatView = preload("res://presentation/combat/combat_view.gd")
const Ground = preload("res://modules/caravan/terrain_surface.gd")
const OUT := "res://docs/validation/fuel-stations"

func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1440, 900)
	preload("res://app/input_actions.gd").register()
	var arena := preload("res://presentation/world/arena.tscn").instantiate()
	root.add_child(arena)
	var context := Fixture.pump_context()
	paused = true
	arena.rebuild_from_context(context)
	paused = false
	var vehicle := Vehicle.new()
	root.add_child(vehicle)
	vehicle.set_driving_enabled(false)
	var combat := Combat.new()
	root.add_child(combat)
	combat.setup(vehicle)
	var world := World.new()
	root.add_child(world)
	world.arena = arena
	world.combat = combat
	world.vehicle = vehicle
	world.props.setup(arena.world_layout)
	var view := CombatView.new()
	root.add_child(view)
	view.setup(combat, vehicle)
	var camera := Camera3D.new()
	root.add_child(camera)
	var center := Vector3(80, Ground.height_at(80, 0) + 1.5, 0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 21
	camera.position = center + Vector3(16, 15, 22)
	camera.look_at(center)
	await _capture("pump-intact")
	world.damage_props(Vector3(80, 0, 0), 0.01, 9999, preload("res://modules/world/damage_context.gd").create("shot"))
	var data: Dictionary = combat.get_state()
	data.pickups = combat.model.pickups
	data.elapsed = 0.3
	view.apply_state(data)
	camera.size = 12
	camera.position = center + Vector3(8, 11, 15)
	camera.look_at(center - Vector3.UP)
	await _capture("pump-fuel-dropped")
	print("FUEL_STATION_CAPTURE_PICKUPS ", combat.model.pickups.map(func(pickup): return {"kind": pickup.kind, "value": pickup.value}))
	view.free()
	world.free()
	combat.free()
	vehicle.free()
	camera.free()
	arena.free()
	await process_frame
	quit()
func _capture(label: String) -> void:
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := OUT + "/" + label + ".png"
	print("FUEL_STATION_CAPTURE %s error=%d" % [path, root.get_texture().get_image().save_png(path)])

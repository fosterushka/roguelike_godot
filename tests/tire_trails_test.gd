extends SceneTree
const Effects = preload("res://presentation/combat/impact_effects.gd")
const Surface = preload("res://presentation/world/track_surface.gd")
const Ground = preload("res://presentation/world/ground_surface_view.gd")
class ContactView extends Node3D:
	var contacts: Array[Dictionary] = []
	func get_tire_contacts() -> Array[Dictionary]:
		return contacts
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _init() -> void:
	_run.call_deferred()
func _contacts(offset: float = 0.0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for carrier in 2:
		for wheel in 4:
			result.append({"id": ("crawler" if carrier == 0 else "trailer-1") + ":wheel%d" % wheel, "position": Vector3(-2 if wheel % 2 == 0 else 2, 0, offset + (2 if wheel < 2 else -2) - carrier * 8), "heading": 0.0, "grounded": true, "radius": 0.88})
	return result
func _positions(effects) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for index in effects.tracks.count:
		points.append(effects.tracks.submitted_stamps[index].origin)
	points.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x if not is_equal_approx(a.x, b.x) else a.z < b.z)
	return points
func _run() -> void:
	Surface.configure_roads([])
	Surface.mud_zones = []
	var effects := Effects.new()
	var view := ContactView.new()
	root.add_child(effects)
	root.add_child(view)
	effects.set_process(false)
	effects.player_view = view
	var state := {"player": {"position": Vector3.ZERO, "speed": 0.0}, "enemies": [], "weather_type": "clear"}
	view.contacts = _contacts()
	effects.tracks.sync_state(state, 0.1, effects)
	for index in 120:
		for contact: Dictionary in view.contacts:
			contact.position.y = sin(index) * 0.12
		effects.tracks.sync_state(state, 1.0 / 60, effects)
	check(effects.tracks.count == 0, "Stationary wheel contacts and vertical suspension motion never darken the ground")
	var initial_rng: int = effects.random.state
	view.contacts = _contacts(3.0)
	effects.tracks.sync_state(state, 0.1, effects)
	check(effects.tracks.count == 80, "Car and trailer each leave all four distance sampled tire trails")
	check(effects.random.state == initial_rng, "Tire sampling never consumes combat effect RNG")
	var coarse := _positions(effects)
	effects.tracks.reset()
	view.contacts = _contacts()
	effects.tracks.sync_state(state, 0.1, effects)
	for index in range(1, 31):
		view.contacts = _contacts(index * 0.1)
		effects.tracks.sync_state(state, 1.0 / 120, effects)
	var fine := _positions(effects)
	check(fine.size() == coarse.size(), "Trail count depends on distance rather than frame count")
	for index in mini(fine.size(), coarse.size()):
		check(fine[index].distance_to(coarse[index]) < 0.0001, "Identical travel generates the same tread positions at different update rates")
	var frozen_count: int = effects.tracks.count
	view.contacts = _contacts(4.0)
	effects.tracks.sync_state(state, 0.0, effects)
	check(effects.tracks.count == frozen_count, "Pause never deposits pending tire marks")
	view.contacts = _contacts(100.0)
	effects.tracks.sync_state(state, 0.1, effects)
	check(effects.tracks.count == frozen_count, "Teleport does not connect distant positions with a long trail")
	for contact: Dictionary in view.contacts:
		contact.position.z += 2.0
		contact.grounded = false
	effects.tracks.sync_state(state, 0.1, effects)
	check(effects.tracks.count == frozen_count, "Airborne wheels deposit no ground texture")
	view.contacts = _contacts(102.3)
	effects.tracks.sync_state(state, 0.1, effects)
	check(effects.tracks.count == frozen_count + 8, "Landing starts short contact-local tracks without bridging airborne distance")
	effects.tracks.reset()
	view.contacts = _contacts()
	effects.tracks.sync_state(state, 0.1, effects)
	view.contacts = _contacts(23.0)
	effects.tracks.sync_state(state, 0.1, effects)
	check(effects.tracks.count == effects.tracks.MAX_FRAME_STAMPS, "Busy movement frame has a hard 128-stamp CPU/GPU upload budget")
	effects.tracks.sync_state(state, 0.1, effects)
	check(effects.tracks.count == effects.tracks.MAX_FRAME_STAMPS, "Budget exhaustion never creates deferred stationary spam")
	for index in 1900:
		effects.tracks.stamp(effects.random, Vector3(index * 0.3, 0, 0), 0, 0, 0, 1)
	check(effects.tracks.count == 1800 and effects.tracks.batch.multimesh.instance_count == 1800, "Retained tread geometry stays capped at 1800 instances")
	check(effects.tracks.batch.multimesh.visible_instance_count == 1800, "One gameplay MultiMesh renders all retained tread instances")
	var priority: int = effects.tracks.batch.multimesh.mesh.material.render_priority
	check(priority == -1 and priority < 0, "Tires have the highest ground priority without overriding airborne transparency")
	check(Ground.TRACK_OFFSET > Ground.BLOOD_OFFSET and Ground.TRACK_OFFSET > Ground.SCORCH_OFFSET and Ground.TRACK_OFFSET > Ground.MUD_OFFSET, "Tread geometry sits above all other ground texture offsets")
	var shader: Shader = effects.tracks.batch.multimesh.mesh.material.shader
	check(not shader.code.contains("depth_test_disabled") and shader.code.contains("depth_draw_never"), "Treads test actor depth and do not write transparent rectangle depth")
	check(effects.tracks.batch.multimesh.use_colors and effects.tracks.batch.multimesh.use_custom_data, "All tread palettes share one material and instance data")
	var palette_colors := {}
	for kind in 5:
		var color := Surface.color_for(kind)
		palette_colors[color.to_html()] = true
		check(color.r > 0.1 and color.a > 0.2 and color.a < 0.5, "Each surface has a restrained non-black tread tint")
	check(palette_colors.size() == 5, "Sand soil road wet mud and ash use distinct palettes")
	Surface.configure_roads([{"width": 6.0, "points": [{"x": -60, "z": 0}, {"x": -5, "z": 0}]}])
	check(Surface.kind_at(Vector3(-32, 0, 0), false) == Surface.Kind.ROAD, "Road palette follows actual road ribbon including negative spatial cells")
	check(Surface.kind_at(Vector3(-32, 0, 12), false) != Surface.Kind.ROAD, "Ground beside a road does not inherit its palette")
	Surface.mud_zones = [{"position": Vector3(-32, 0, 0), "radius": 5.0}]
	check(Surface.kind_at(Vector3(-32, 0, 0), false) == Surface.Kind.WET_MUD, "Visible mud overrides the underlying road palette")
	effects.spawn_scorch(Vector3(-32, 0, 0), 3)
	check(Surface.kind_at(Vector3(-32, 0, 0), false, effects.traces.entries) == Surface.Kind.SCORCH, "Retained crater above mud produces contrasting ash treads")
	Surface.configure_roads([])
	Surface.mud_zones = []
	var kinds := {}
	for index in 200:
		var point := Vector3(index * 3.7 + 12, 0, index * 1.73 - 60)
		kinds[Surface.kind_at(point, false)] = true
	check(kinds.has(Surface.Kind.SOIL) and kinds.has(Surface.Kind.SAND), "Natural palette changes with the actual terrain shader soil field")
	var before_count: int = effects.tracks.count
	var before_random: int = effects.random.state
	effects.set_warmup_visible(true)
	check(effects.tracks._warmup.visible and effects.tracks._warmup.multimesh.visible_instance_count == 1, "Loading draws the actual instanced tread shader variant")
	effects.set_warmup_visible(false)
	check(effects.tracks.count == before_count and effects.random.state == before_random, "Tread warmup does not mutate retained trails or randomness")
	Ground.Terrain.configure({})
	for index in 45:
		var x := (Ground.Terrain.CELLS / 2 + 15 + index) * Ground.Terrain.STEP - Ground.Terrain.HALF_SIZE
		var z := (Ground.Terrain.CELLS / 2 + 15 + index % 5) * Ground.Terrain.STEP - Ground.Terrain.HALF_SIZE
		if index % 3 == 0:
			x += Ground.Terrain.STEP * 0.5
			z += Ground.Terrain.STEP * 0.5 + 0.01
		else:
			x += 0.01 if index % 3 == 1 else -0.01
		effects.tracks.stamp(effects.random, Vector3(x, 0, z), index * 0.41, 0, 0, 1)
		var slot: int = (effects.tracks.cursor + effects.tracks.CAPACITY - 1) % effects.tracks.CAPACITY
		var transform: Transform3D = effects.tracks.submitted_stamps[slot]
		for corner: Vector3 in [Vector3(-0.31,0,-0.18), Vector3(0.31,0,-0.18), Vector3(-0.31,0,0.18), Vector3(0.31,0,0.18)]:
			var point := transform * corner
			check(point.y >= Ground.Terrain.height_at(point.x,point.z) + Ground.TRACK_OFFSET - 0.00003, "Tread corners clear decals when crossing uneven terrain")
	Ground.Terrain.heights = PackedFloat32Array()
	effects.queue_free()
	view.queue_free()
	await process_frame
	print("Tire trails tests: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

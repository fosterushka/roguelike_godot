extends SceneTree

const CrewView = preload("res://presentation/crew/crew_view.gd")
const Appearance = preload("res://presentation/crew/crew_appearance.gd")
const Source = preload("res://presentation/combat/source_model.gd")
const Crew = preload("res://modules/crew/crew_catalog.gd")
const Seats = preload("res://presentation/crew/crew_seats.gd")
const WorldScale = preload("res://modules/world/world_scale.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func near(a: Vector3, b: Vector3, label: String) -> void:
	check(a.distance_to(b) < 0.001, label + " expected=" + str(b) + " actual=" + str(a))

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var pickup := Node3D.new()
	pickup.position = Vector3(18, 1.2, -7)
	pickup.rotation.y = 0.63
	root.add_child(pickup)
	var wagon := Node3D.new()
	wagon.position = Vector3(-4, 1.4, 12)
	wagon.rotation.y = -0.48
	root.add_child(wagon)
	var view := CrewView.new()
	view.set_carrier_visuals({"crawler": pickup, "wagon-1": wagon})
	root.add_child(view)
	var people := [
		{"id": "crew-a", "name": "A", "name_en": "A", "role": "mechanic", "position": Vector3.ZERO, "boarded": true, "carrier_id": "crawler", "seat": 0, "heading": 0.0},
		{"id": "crew-b", "name": "B", "name_en": "B", "role": "loader", "position": Vector3.ZERO, "boarded": true, "carrier_id": "wagon-1", "seat": 1, "heading": 0.0},
	]
	view.update_people(people, 0.1)
	near(view.views[0].root.global_position, pickup.to_global(Seats.anchor("crawler", 0)), "Pickup crew follows interpolated pickup transform at its bed-edge seat")
	near(view.views[1].root.global_position, wagon.to_global(Seats.anchor("wagon-1", 1)), "Wagon crew follows its own rendered carrier transform")
	check(view.views[0].seated.visible and not view.views[0].body.visible, "Boarded living crew uses seated low-poly pose")
	check(view.views[0].body.scale.is_equal_approx(Vector3.ONE * WorldScale.SOLDIER_SCALE) and view.views[0].seated.scale.is_equal_approx(Vector3.ONE), "Standing crew shares the soldier scale while seated crew keeps the authored vehicle-safe size")
	check(view.views[0].seated.get_node_or_null("PickupBench") == null and pickup.get_node_or_null("PickupBench") != null and wagon.get_node_or_null("PickupBench") == null, "Pickup bench is mounted on the carrier instead of duplicated inside each person")
	var thigh := view.views[0].seated.get_node("Thigh") as MeshInstance3D
	var shin := view.views[0].seated.get_node("Shin") as MeshInstance3D
	var torso := view.views[0].seated.get_node("Torso") as MeshInstance3D
	var cushion := pickup.get_node("PickupBench/PickupBenchCushion") as MeshInstance3D
	check(thigh.position.z > 0 and shin.position.y < thigh.position.y and torso.position.y > thigh.position.y and cushion.position.y + 0.07 >= 0.32, "Seated anatomy keeps thighs forward, shins down, torso upright and pelvis supported")
	check((torso.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color("74805a")), "Mechanic seated uniform uses the military palette")
	var cached_uniform := torso.material_override
	view.update_people(people, 0.1)
	check(torso.material_override == cached_uniform, "Repeated seated updates reuse cached role material")
	pickup.global_position += Vector3(3, 0.2, -2)
	pickup.global_rotation.y += 0.35
	view._process(0.0)
	near(view.views[0].root.global_position, pickup.to_global(Seats.anchor("crawler", 0)), "Seat updates with carrier movement instead of terrain offset")
	people[0].dead = true
	view.update_people(people, 0.1)
	check(not view.views[0].seated.visible and view.views[0].body.visible, "Dead crew keeps its non-seated presentation")
	check(view.views[0].root.scale.is_equal_approx(Vector3.ONE), "Leaving a scaled carrier resets the on-foot crew scale")
	var role_meshes := {}
	for role: String in Crew.ROLES:
		var standing := Source.instantiate("rifleman")
		Appearance.apply(standing, role)
		var kit := standing.find_child(Appearance.KIT_NODE, true, false) as MeshInstance3D
		check(kit != null and kit.mesh != null, role + " has Blender-authored standing equipment")
		if kit != null:
			role_meshes[kit.mesh.get_instance_id()] = true
			check(kit.get_parent().has_meta("source_part") and kit.get_parent().get_meta("source_part").rig.role == "body", role + " equipment follows animated torso")
		var seated_model := Seats.build()
		Seats.apply_role(seated_model, role, "ally")
		check(seated_model.get_node_or_null("Torso/" + Appearance.KIT_NODE) != null, role + " retains equipment while seated")
		check(not (seated_model.get_node("Torso").mesh is BoxMesh), "Seated torso uses imported Blender geometry")
		standing.free()
		seated_model.free()
	check(role_meshes.size() == Crew.ROLES.size(), "Every crew role has its own equipment mesh")
	view.queue_free()
	pickup.queue_free()
	wagon.queue_free()
	await process_frame
	print("Crew seating tests: ", checks - failures, "/", checks)
	quit(1 if failures else 0)

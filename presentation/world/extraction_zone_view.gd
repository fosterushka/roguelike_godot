extends Node3D

const Models = preload("res://presentation/world/world_quality_models.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const Rules = preload("res://modules/world/activities/extraction_rules.gd")
const FlareSmoke = preload("res://presentation/world/airdrop_flare_smoke.gd")
const SETUP_SECONDS := 3.0
const DEPARTURE_SECONDS := 4.0
const GATE_RESPONSE := 2.5
const SEARCHLIGHT_SWEEP := 0.38
const LIGHT_DISTANCE := 240.0
const Locale = preload("res://presentation/ui/ui_locale.gd")
const IDLE := Color("a7bc91")
const ACTIVE := Color("dbb56a")
const LEAVING := Color("ee7257")
var sites: Dictionary = {}
var _elapsed := 0.0

func apply_state(state: Dictionary) -> void:
	var present := {}
	for site: Dictionary in state.get("sites", []):
		var id := str(site.id)
		present[id] = true
		if sites.has(id) and (sites[id].point != site.position or sites[id].radius != float(site.get("radius", Rules.ZONE_RADIUS))):
			sites[id].root.queue_free()
			sites.erase(id)
		if not sites.has(id):
			sites[id] = _create_site(site)
		_update_site(sites[id], id, state)
	for id: String in sites.keys():
		if not present.has(id):
			sites[id].root.queue_free()
			sites.erase(id)

func _create_site(site: Dictionary) -> Dictionary:
	var point: Vector3 = site.position
	var radius := float(site.get("radius", Rules.ZONE_RADIUS))
	var root := Node3D.new()
	root.name = str(site.id)
	add_child(root)
	var signal_material := _material(IDLE)
	var metal := _material(Color("37433a"))
	metal.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	metal.roughness = 0.92
	var ring := MeshInstance3D.new()
	ring.name = "LandingPerimeter"
	ring.mesh = _ground_ring(point, radius - 0.7, radius)
	var paint := _material(Color("777967"))
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	ring.material_override = paint
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	for index in 4:
		var angle := PI * 0.25 + index * PI * 0.5
		var pole_point := point + Vector3(cos(angle), 0, sin(angle)) * radius
		pole_point.y = Terrain.height_at(pole_point.x, pole_point.z)
		_box(root, "BeaconFoot", pole_point + Vector3.UP * 0.2, Vector3(1.7, 0.4, 1.7), metal)
		_box(root, "BeaconPole", pole_point + Vector3.UP * 2.7, Vector3(0.42, 5.0, 0.42), metal)
		_box(root, "BeaconLight", pole_point + Vector3.UP * 5.2, Vector3(0.95, 0.7, 0.95), signal_material)
		_box(root, "ExtractionFlag", pole_point + Vector3(1.2, 4.0, 0), Vector3(2.4, 1.35, 0.12), paint)
	for offset: Vector3 in [Vector3(0, 0, -6), Vector3(0, 0, 0), Vector3(0, 0, 6)]:
		var stripe := MeshInstance3D.new()
		stripe.name = "CheckpointLaneMark"
		var extent := Vector2(0.7, 3.0)
		stripe.mesh = _ground_quad(point + offset, extent)
		stripe.material_override = paint
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(stripe)
	var label := Label3D.new()
	label.name = "ExtractionCaption"
	label.position = Vector3(point.x, Terrain.height_at(point.x, point.z) + 8, point.z)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 38
	label.outline_size = 9
	label.pixel_size = 0.025
	label.outline_modulate = Color("17242c")
	label.no_depth_test = true
	root.add_child(label)
	var checkpoint := _checkpoint(root, point, radius, metal)
	checkpoint.merge({"root": root, "point": point, "radius": radius, "material": signal_material, "label": label, "active": false, "progress": 0.0})
	return checkpoint

func _update_site(site: Dictionary, id: String, state: Dictionary) -> void:
	var selected := str(state.get("site_id", state.get("zone_id", ""))) == id
	var active := bool(state.get("active", false)) and selected
	var leaving: bool = active and state.get("mode", "") == "leaving"
	var color := LEAVING if leaving else ACTIVE if active else IDLE
	site.active = active
	site.progress = float(state.get("progress", 0.0)) if active else 0.0
	site.material.albedo_color = color
	site.label.modulate = color
	var title := "КПП • ЭВАКУАЦИЯ [E]" if Locale.language == "ru" else "CHECKPOINT • EXTRACT [E]"
	if active:
		var seconds := ceili(float(state.get("remaining_seconds", Rules.SECURE_SECONDS)))
		title += "\n" + (("ВЕРНИТЕСЬ В ЗОНУ" if Locale.language == "ru" else "RETURN TO ZONE") if leaving else ("ЗАЩИЩАЙТЕ %dс" if Locale.language == "ru" else "DEFEND %ds") % seconds)
		if not leaving:
			if site.progress < SETUP_SECONDS:
				title += "\n" + ("НАСТРОЙКА РАДИО" if Locale.language == "ru" else "RADIO LINK")
			elif seconds <= DEPARTURE_SECONDS:
				title += "\n" + ("ВОРОТА ОТКРЫВАЮТСЯ" if Locale.language == "ru" else "GATE OPENING")
			else:
				title += "\n" + (("НА ПОДХОДЕ: %d" if Locale.language == "ru" else "HOSTILES NEARBY: %d") % int(state.get("hostile_count", 0)))
	site.label.text = title

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

func _box(parent: Node3D, label: String, point: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	visual.mesh = mesh
	visual.material_override = material
	visual.position = point
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	return visual

func _ground_ring(center: Vector3, inner: float, outer: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for index in 96:
		if index % 3 != 0:
			continue
		var angle := index * TAU / 96.0
		var next := (index + 1) * TAU / 96.0
		var a := center + Vector3(cos(angle), 0, sin(angle)) * inner
		var b := center + Vector3(cos(angle), 0, sin(angle)) * outer
		var c := center + Vector3(cos(next), 0, sin(next)) * inner
		var d := center + Vector3(cos(next), 0, sin(next)) * outer
		vertices.append_array([a, b, c, b, d, c])
	return _ground_mesh(vertices)

func _ground_quad(center: Vector3, extent: Vector2) -> ArrayMesh:
	var a := center + Vector3(-extent.x, 0, -extent.y) * 0.5
	var b := center + Vector3(extent.x, 0, -extent.y) * 0.5
	var c := center + Vector3(-extent.x, 0, extent.y) * 0.5
	var d := center + Vector3(extent.x, 0, extent.y) * 0.5
	return _ground_mesh(PackedVector3Array([a, b, c, b, d, c]))

func _ground_mesh(vertices: PackedVector3Array) -> ArrayMesh:
	var normals := PackedVector3Array()
	for index in vertices.size():
		vertices[index].y = Terrain.height_at(vertices[index].x, vertices[index].z) + 0.12
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _checkpoint(root: Node3D, point: Vector3, radius: float, metal: Material) -> Dictionary:
	var ground := Vector3(point.x, Terrain.height_at(point.x, point.z), point.z)
	var sand := _material(Color("777361"))
	sand.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var amber := _material(Color("d7ba7d"))
	var station := ground + Vector3(-radius * 0.65, 0, -radius * 0.55)
	station.y = Terrain.height_at(station.x, station.z)
	var shelter := Models.create("market_stall")
	shelter.name = "CheckpointFieldShelter"
	shelter.scale = Vector3.ONE * 2.4
	shelter.position = station + Vector3(4.5, 0, -0.5)
	shelter.position.y = Terrain.height_at(shelter.position.x, shelter.position.z)
	root.add_child(shelter)
	var dish := Models.create("satellite_dish")
	dish.name = "CheckpointRadioDish"
	dish.position = station + Vector3(-3.8, 0, 1.0)
	dish.position.y = Terrain.height_at(dish.position.x, dish.position.z)
	dish.scale = Vector3.ONE * 1.7
	root.add_child(dish)
	for index in 6:
		var crate := Models.create("crateInstances")
		crate.name = "CheckpointSupplyStack"
		crate.position = ground + Vector3(radius * 0.55 + (index % 3) * 2.2, 0, -radius * 0.56)
		crate.position.y = Terrain.height_at(crate.position.x, crate.position.z) + (index / 3) * 1.7
		crate.scale = Vector3.ONE * 1.7
		root.add_child(crate)
	_box(root, "Generator", station + Vector3.UP * 1.0, Vector3(3.5, 2, 2.1), metal)
	for index in 5:
		_box(root, "CoolingVent", station + Vector3(-1.15 + index * 0.55, 1.1, -1.07), Vector3(0.25, 1.0, 0.08), sand)
	_box(root, "Exhaust", station + Vector3(1.2, 2.6, 0.4), Vector3(0.22, 1.8, 0.22), metal)
	_box(root, "RadioConsole", station + Vector3(0, 2.4, 0), Vector3(1.8, 0.8, 1.1), sand)
	_box(root, "RadioDisplay", station + Vector3(0, 2.4, -0.56), Vector3(1.1, 0.4, 0.08), amber)
	_box(root, "Antenna", station + Vector3(-0.7, 5.4, 0.3), Vector3(0.12, 6.0, 0.12), metal)
	_box(root, "AntennaCrossbar", station + Vector3(-0.7, 7.7, 0.3), Vector3(3.5, 0.12, 0.12), metal)
	for side in [-1, 1]:
		var checkpoint_point := ground + Vector3(side * radius * 0.82, 0, radius * 0.58)
		checkpoint_point.y = Terrain.height_at(checkpoint_point.x, checkpoint_point.z)
		_box(root, "ConcreteBarrier", checkpoint_point + Vector3.UP * 0.8, Vector3(5.0, 1.6, 2.2), sand)
		for stripe in 3:
			_box(root, "BarrierStripe", checkpoint_point + Vector3(-1.6 + stripe * 1.6, 0.85, -1.12), Vector3(0.65, 0.9, 0.06), metal)
	var gate := Node3D.new()
	gate.name = "DepartureGate"
	gate.position = ground + Vector3(-radius * 0.4, 1.8, radius * 0.58)
	gate.position.y = Terrain.height_at(gate.position.x, gate.position.z) + 1.8
	root.add_child(gate)
	_box(root, "GatePost", gate.position - Vector3.UP * 0.9, Vector3(1.6, 1.8, 1.6), metal)
	_box(gate, "GateArm", Vector3(radius * 0.4, 0, 0), Vector3(radius * 0.8, 0.4, 0.4), amber)
	for index in 6:
		_box(gate, "GateStripe", Vector3(index * radius * 0.8 / 6.0, 0, -0.22), Vector3(0.8, 0.42, 0.08), metal)
	var light_pivot := Node3D.new()
	light_pivot.position = station + Vector3(0, 5.6, 0)
	root.add_child(light_pivot)
	_box(light_pivot, "SearchlightHousing", Vector3.ZERO, Vector3(1.1, 0.8, 1.1), metal)
	_box(light_pivot, "SearchlightLens", Vector3(0, 0, -0.58), Vector3(0.85, 0.55, 0.08), amber)
	var light := SpotLight3D.new()
	light.rotation.x = -0.65
	light.light_color = Color("ffe0a2")
	light.light_energy = 3.5
	light.spot_range = radius * 3.0
	light.spot_angle = 30.0
	light.shadow_enabled = false
	light_pivot.add_child(light)
	var smoke := FlareSmoke.new()
	root.add_child(smoke)
	return {"gate": gate, "searchlight": light_pivot, "light": light, "smoke": smoke, "station": station}

func _process(delta: float) -> void:
	_elapsed += delta
	var camera := get_viewport().get_camera_3d()
	for site: Dictionary in sites.values():
		var nearby := camera != null and camera.global_position.distance_to(site.point) < LIGHT_DISTANCE
		site.light.visible = nearby
		site.searchlight.rotation.y = sin(_elapsed * SEARCHLIGHT_SWEEP) * 1.1
		var opening: bool = site.active and site.progress >= Rules.SECURE_SECONDS - DEPARTURE_SECONDS
		site.gate.rotation.z = move_toward(site.gate.rotation.z, PI * 0.45 if opening else 0.0, delta * GATE_RESPONSE)
		site.smoke.apply_drop({"position": site.station, "height": 0.0} if site.active and nearby else {}, _elapsed)

extends Node3D

const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const IDLE := Color("7bdc9a")
const ACTIVE := Color("ffc064")
const LEAVING := Color("ee7257")
var sites: Dictionary = {}

func apply_state(state: Dictionary) -> void:
	var present := {}
	for site: Dictionary in state.get("sites", []):
		var id := str(site.id)
		present[id] = true
		if sites.has(id) and (sites[id].point != site.position or sites[id].radius != float(site.get("radius", 18))):
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
	var radius := float(site.get("radius", 18))
	var root := Node3D.new()
	root.name = str(site.id)
	add_child(root)
	var signal_material := _material(IDLE)
	var metal := _material(Color("263e42"))
	var ring := MeshInstance3D.new()
	ring.name = "LandingPerimeter"
	ring.mesh = _ground_ring(point, radius - 0.7, radius)
	ring.material_override = signal_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	for index in 4:
		var angle := PI * 0.25 + index * PI * 0.5
		var pole_point := point + Vector3(cos(angle), 0, sin(angle)) * radius
		pole_point.y = Terrain.height_at(pole_point.x, pole_point.z)
		_box(root, "BeaconFoot", pole_point + Vector3.UP * 0.2, Vector3(1.7, 0.4, 1.7), metal)
		_box(root, "BeaconPole", pole_point + Vector3.UP * 2.7, Vector3(0.42, 5.0, 0.42), metal)
		_box(root, "BeaconLight", pole_point + Vector3.UP * 5.2, Vector3(0.95, 0.7, 0.95), signal_material)
		_box(root, "ExtractionFlag", pole_point + Vector3(1.2, 4.0, 0), Vector3(2.4, 1.35, 0.12), signal_material)
	for offset: Vector3 in [Vector3(-2.6, 0, 0), Vector3(2.6, 0, 0), Vector3.ZERO]:
		var stripe := MeshInstance3D.new()
		stripe.name = "LandingMark"
		var extent := Vector2(0.7, 7.0) if offset != Vector3.ZERO else Vector2(5.9, 0.7)
		stripe.mesh = _ground_quad(point + offset, extent)
		stripe.material_override = signal_material
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(stripe)
	var label := Label3D.new()
	label.name = "ExtractionCaption"
	label.position = Vector3(point.x, Terrain.height_at(point.x, point.z) + 8, point.z)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.025
	label.outline_modulate = Color("17242c")
	label.no_depth_test = true
	root.add_child(label)
	return {"root": root, "point": point, "radius": radius, "material": signal_material, "label": label}

func _update_site(site: Dictionary, id: String, state: Dictionary) -> void:
	var selected := str(state.get("site_id", state.get("zone_id", ""))) == id
	var active := bool(state.get("active", false)) and selected
	var leaving: bool = active and state.get("mode", "") == "leaving"
	var color := LEAVING if leaving else ACTIVE if active else IDLE
	site.material.albedo_color = color
	site.label.modulate = color
	var title := "ЭВАКУАЦИЯ [E]" if Locale.language == "ru" else "EXTRACT [E]"
	if active:
		var seconds := ceili(float(state.get("remaining_seconds", 20)))
		title += "\n" + (("ВЕРНИТЕСЬ В ЗОНУ" if Locale.language == "ru" else "RETURN TO ZONE") if leaving else ("ЗАЩИЩАЙТЕ %dс" if Locale.language == "ru" else "DEFEND %ds") % seconds)
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

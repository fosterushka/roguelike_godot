extends SceneTree

const Catalog = preload("res://modules/caravan/wagon_catalog.gd")
const Rig = preload("res://presentation/vehicles/wheeled_rig.gd")
const Attachment = preload("res://presentation/vehicles/attachment_view.gd")
const Equipment = preload("res://presentation/vehicles/equipment_model.gd")
const VehicleView = preload("res://presentation/vehicles/vehicle_view.gd")
const CrewView = preload("res://presentation/crew/crew_view.gd")
const Seats = preload("res://presentation/crew/crew_seats.gd")

var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	check(Catalog.TYPES.size() == 6 and Catalog.ATTACHMENTS.size() == 10, "Convoy catalog exposes all six wagons and ten attachments")
	for type: String in Catalog.TYPES:
		var wagon := Rig.build_trailer(type)
		check(wagon.name == "SteeringWheelTrailer" and str(wagon.get_meta("wagon_type")) == type, "Wagon factory preserves runtime identity: " + type)
		check(str(wagon.get_meta("model_path", "")) == "res://assets/vehicles/military_wagon_%s.glb" % type and wagon.get_meta("model", null) != null, "Wagon uses its authored GLB adapter: " + type)
		var wagon_bounds := _bounds(wagon)
		check(absf(wagon_bounds.position.y) < 0.015 and wagon_bounds.end.y < 4.0 and wagon_bounds.size.x > 2.8 and wagon_bounds.size.z > 3.2, "Wagon body is ground-aligned and keeps its chassis footprint with role-specific upper bodywork: " + type)
		check(wagon.get_meta("wheels", []).size() == 4 and wagon.get_meta("springs", []).size() == 4, "Wagon retains four animated terrain-contact wheels: " + type)
		var drawbar := wagon.get_meta("drawbar") as Node3D
		var drawbar_valid := drawbar != null and drawbar.name.begins_with("SteeringDrawbar")
		if drawbar != null:
			var before := drawbar.rotation.y
			Rig.animate(wagon, {"wheel_offsets": PackedFloat32Array([0, 0, 0, 0])}, 0.7, 4.0, 0.0, true)
			drawbar_valid = drawbar_valid and not is_equal_approx(drawbar.rotation.y, before)
		check(drawbar_valid, "Authored wagon drawbar remains available for caravan hitch steering: " + type)
		wagon.free()
	for type: String in Catalog.ATTACHMENTS:
		var model := Attachment.build(type)
		check(model.get_meta("attachment_type") == type and str(model.get_meta("model_path", "")) == Equipment.MODEL_PATH and _mesh_count(model) > 0, "Attachment has an authored equipment batch: " + type)
		check(_bounds(model).size.length() <= 3.2, "Attachment fits an authored wagon mount: " + type)
		model.free()
	_test_equipment_animation()
	await _test_runtime_mounts()
	await _test_seated_crew()
	print("Convoy assets: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_runtime_mounts() -> void:
	var view := VehicleView.new()
	root.add_child(view)
	var carriers: Array = []
	var attachments: Array = Catalog.ATTACHMENTS.keys()
	for index in Catalog.TYPES.size():
		var installed: Array = []
		for slot in 3:
			var attachment_index := index * 3 + slot
			if attachment_index < attachments.size():
				installed.append({"type": attachments[attachment_index], "slot": slot})
		carriers.append({"id": "wagon-%d" % (index + 1), "type": Catalog.TYPES.keys()[index], "attachments": installed})
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_catalogs.json")).modules
	var modules: Array = []
	var slot := 0
	for type: String in _equipment_types(definitions):
		var mount := {"carrierId": "crawler", "slot": 12} if type == "bumper" else {"carrierId": "crawler", "slot": slot}
		if type != "bumper":
			slot += 1
		if slot > 12 and type != "bumper":
			mount = {"carrierId": "wagon-5", "slot": 0}
		modules.append({"type": type, "def": definitions[type], "mount": mount})
	view.apply_player_state({"position": Vector3.ZERO, "heading": 0.0, "speed": 0.0, "visual_scale": 0.88, "carriers": carriers, "modules": modules}, 1)
	view._process(1.0 / 60.0)
	check(view._trailers.size() == 6 and view._attachments.size() == Catalog.ATTACHMENTS.size(), "Actual vehicle view composes six wagons and every installed attachment")
	var attachment_positions_valid := true
	for key: String in view._attachments:
		var model: Node3D = view._attachments[key]
		var slot_index := int(key.get_slice(":", 1))
		attachment_positions_valid = attachment_positions_valid and model.position.distance_to(VehicleView.TRAILER_SLOTS[slot_index]) < 0.001
	check(attachment_positions_valid, "Every attachment is placed at its real wagon mount")
	check(view._modules.size() == _equipment_types(definitions).size(), "Actual vehicle view instantiates every equipment module")
	var module_positions_valid := true
	for key: String in view._modules:
		var module: Node3D = view._modules[key]
		module_positions_valid = module_positions_valid and module.position.length() < 5.5
	check(module_positions_valid, "Equipment module positions stay within their carrier bounds")
	view.queue_free()
	await process_frame

func _test_seated_crew() -> void:
	var carrier := Node3D.new()
	carrier.global_transform = Transform3D(Basis(Vector3.UP, 0.55), Vector3(18, 2, -9))
	carrier.scale = Vector3.ONE * 1.2
	root.add_child(carrier)
	var crew := CrewView.new()
	root.add_child(crew)
	crew.set_carrier_visuals({"wagon-seat": carrier})
	var person := {"id": "crew-seat", "role": "mechanic", "name": "Mechanic", "name_en": "Mechanic", "boarded": true, "carrier_id": "wagon-seat", "seat": 1, "dead": false, "airborne": false, "position": Vector3.ZERO, "heading": 0.0}
	crew.update_people([person], 0.0)
	var visual: Dictionary = crew.views[0]
	var expected := carrier.global_transform * Transform3D(Basis.IDENTITY, Seats.anchor("wagon-seat", 1))
	check(visual.root.global_transform.is_equal_approx(expected) and visual.seated.visible and not visual.body.visible, "Boarded NPC is seated at the real wagon seat and hides standing body")
	crew.queue_free()
	carrier.queue_free()
	await process_frame

func _test_equipment_animation() -> void:
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_catalogs.json")).modules
	var authored_types: Array = Catalog.ATTACHMENTS.keys() + _equipment_types(definitions)
	var material: Material
	var all_authored := true
	for type: String in authored_types:
		var model := Equipment.build(type)
		var meshes := _mesh_nodes(model)
		all_authored = all_authored and not meshes.is_empty()
		for node: MeshInstance3D in meshes:
			var current := node.get_active_material(0)
			if material == null:
				material = current
			all_authored = all_authored and current == material
		model.free()
	check(all_authored and material != null, "Every equipment type has mesh data with the shared authored material")
	var weapon := Equipment.build("assaultRifle")
	var pivot: Node3D = weapon.get_meta("elevation")
	var base := weapon.find_child("MountBase", true, false) as MeshInstance3D
	var base_position := base.position if base != null else Vector3.INF
	Equipment.animate(weapon, -0.24, 0.65)
	check(pivot != null and pivot.rotation.x < -0.2, "Negative weapon pitch raises the forward barrel through ElevationPivot")
	check(absf(pivot.position.z + 0.091) < 0.001 and base != null and base.position == base_position, "Recoil moves only the elevation assembly while MountBase stays fixed")
	var static_model := Equipment.build("repair_station")
	Equipment.animate(static_model, -0.24, 0.65)
	check(not static_model.has_meta("elevation"), "Static equipment accepts animation update without requiring an elevation pivot")
	weapon.free()
	static_model.free()

func _equipment_types(definitions: Dictionary) -> Array:
	return definitions.keys().filter(func(type: String) -> bool: return type != "walkerTrailer")

func _mesh_count(node: Node) -> int:
	var total := 1 if node is MeshInstance3D and node.mesh != null else 0
	for child in node.get_children():
		total += _mesh_count(child)
	return total

func _mesh_nodes(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D and node.mesh != null:
		result.append(node)
	for child in node.get_children():
		result.append_array(_mesh_nodes(child))
	return result

func _bounds(node: Node3D, parent_transform := Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	var has_mesh := false
	for child in node.get_children():
		if not child is Node3D:
			continue
		var transform: Transform3D = parent_transform * child.transform
		if child is MeshInstance3D and child.mesh != null:
			var box: AABB = transform * child.mesh.get_aabb()
			result = box if not has_mesh else result.merge(box)
			has_mesh = true
		else:
			var nested := _bounds(child, transform)
			if nested.has_volume():
				result = nested if not has_mesh else result.merge(nested)
				has_mesh = true
	return result

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

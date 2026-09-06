extends SceneTree

const Rig = preload("res://presentation/vehicles/wheeled_rig.gd")
const Suspension = preload("res://modules/caravan/wheel_suspension.gd")
const View = preload("res://presentation/vehicles/vehicle_view.gd")
const PICKUP_PATH := "res://assets/vehicles/military_pickup.glb"

var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	check(FileAccess.file_exists(PICKUP_PATH), "Military pickup GLB is shipped at the runtime asset path")
	check(FileAccess.get_file_as_string("res://data/asset_manifest.json").contains(PICKUP_PATH), "Loading manifest preloads the military pickup asset")
	var packed := load(PICKUP_PATH)
	check(packed is PackedScene, "Military pickup asset imports as an instantiable scene")
	if packed is PackedScene:
		var authored: Node = packed.instantiate()
		var authored_meshes := _mesh_nodes(authored)
		check(authored_meshes.size() == 5, "Authored pickup contains five exported mesh parts")
		check(_one_material(authored_meshes), "Authored pickup mesh parts share one material")
		authored.free()
	var rig := Rig.build_player()
	root.add_child(rig)
	check(rig.name == "ArmoredWheelVehicle", "Player factory keeps the vehicle root contract")
	check(str(rig.get_meta("model_path", "")) == PICKUP_PATH and rig.get_meta("model", null) != null, "Player factory records the authored pickup model")
	check(not rig.has_node("Cabin") and not rig.has_node("RearEquipmentDeck"), "Player factory no longer builds placeholder cabin and cargo boxes")
	check(_mesh_nodes(rig).size() == 5 and _one_material(_mesh_nodes(rig)), "Runtime pickup has only five authored meshes with a shared material")
	var wheels: Array = rig.get_meta("wheels", [])
	check(wheels.size() == 4, "Authored pickup keeps four wheel pivots for vehicle animation")
	var wheel_meshes: Array = []
	var wheel_contract := true
	for wheel: Node3D in wheels:
		var spin := wheel.get_node_or_null("WheelRotation") as Node3D
		var tire := spin.get_node_or_null("AllTerrainTire") as MeshInstance3D if spin != null else null
		wheel_contract = wheel_contract and spin != null and tire != null and wheel.has_meta("anchor")
		if tire != null:
			wheel_meshes.append(tire.mesh)
	check(wheel_contract, "Every wheel pivot retains WheelRotation and AllTerrainTire children")
	check(wheel_meshes.size() == 4 and _all_same(wheel_meshes), "All four articulated tires share the authored wheel mesh")
	var first_tire := wheels[0].get_node("WheelRotation/AllTerrainTire") as MeshInstance3D
	check(first_tire.global_position.distance_to(rig.to_global(wheels[0].get_meta("anchor"))) < 0.0001, "Authored tire center starts at the suspension contact anchor")
	var suspension := Suspension.create()
	suspension.wheel_offsets[0] = 0.23
	Rig.animate(rig, suspension, 0.75, 8.0, 1.4)
	check(wheels[0].rotation.y != 0.0 and wheels[1].rotation.y != 0.0 and is_zero_approx(wheels[2].rotation.y) and is_zero_approx(wheels[3].rotation.y), "Front pickup wheels steer while rear wheels stay aligned")
	var front_anchor: Vector3 = wheels[0].get_meta("anchor")
	check(absf(wheels[0].position.y - front_anchor.y - 0.23) < 0.0001 and absf(wheels[0].get_node("WheelRotation").rotation.x - 1.4) < 0.0001, "Wheel contact travel and spin still drive the authored pickup")
	var view := View.new()
	root.add_child(view)
	view.apply_player_state({"position": Vector3.ZERO, "heading": 0.0, "speed": 0.0, "visual_scale": 0.88, "modules": [{"type": "assaultRifle", "mount": {"carrierId": "crawler", "slot": 0}, "def": {"projectile": true}}]}, 1)
	view._process(1.0 / 60.0)
	var weapon: Node3D = view._modules.get("crawler:0:assaultRifle")
	check(weapon != null and weapon.get_parent() == view and weapon.position.distance_to(View.SLOTS[0]) < 0.0001, "Crawler weapon stays at its valid pickup hardpoint")
	rig.queue_free()
	view.queue_free()
	await process_frame
	print("Military pickup: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _mesh_nodes(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_mesh_nodes(child))
	return result

func _one_material(nodes: Array) -> bool:
	if nodes.is_empty():
		return false
	var material: Material = nodes[0].get_active_material(0)
	if material == null:
		return false
	for node: MeshInstance3D in nodes:
		if node.get_active_material(0) != material:
			return false
	return true

func _all_same(values: Array) -> bool:
	if values.is_empty():
		return false
	for value in values:
		if value != values[0]:
			return false
	return true

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

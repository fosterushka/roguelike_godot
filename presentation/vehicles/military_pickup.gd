extends RefCounted

const MODEL_PATH := "res://assets/vehicles/military_pickup.glb"
const Model = preload(MODEL_PATH)
const Dimensions = preload("res://modules/caravan/player_dimensions.gd")
const Suspension = preload("res://modules/caravan/wheel_suspension.gd")
const WHEEL_NAMES := ["FRONT_LEFT", "FRONT_RIGHT", "REAR_LEFT", "REAR_RIGHT"]

static func build() -> Node3D:
	var rig := Node3D.new()
	rig.name = "ArmoredWheelVehicle"
	var model: Node3D = Model.instantiate()
	rig.add_child(model)
	model.scale = Vector3.ONE * Dimensions.MODEL_SCALE
	model.position.y = -0.005 * Dimensions.MODEL_SCALE
	rig.set_meta("model_path", MODEL_PATH)
	rig.set_meta("model", model)
	var wheels: Array[Node3D] = []
	var springs: Array[Node3D] = []
	for index in 4:
		var source := model.find_child("PIVOT_WHEEL_" + WHEEL_NAMES[index], true, false) as Node3D
		var tire := source.get_child(0) as MeshInstance3D
		tire.owner = null
		source.remove_child(tire)
		var pivot := Node3D.new()
		pivot.name = ("Front" if index < 2 else "Rear") + ("LeftWheel" if index % 2 == 0 else "RightWheel")
		pivot.position = Suspension.ANCHORS[index] + Vector3.UP * Suspension.RADIUS
		pivot.set_meta("anchor", pivot.position)
		rig.add_child(pivot)
		var spin := Node3D.new()
		spin.name = "WheelRotation"
		pivot.add_child(spin)
		tire.name = "AllTerrainTire"
		tire.scale = Vector3.ONE * Dimensions.MODEL_SCALE
		spin.add_child(tire)
		source.free()
		wheels.append(pivot)
		# Preserve the suspension animation contract without extra rendered parts.
		var spring := Node3D.new()
		spring.name = "SuspensionAnchor" + str(index)
		spring.position = pivot.position
		spring.set_meta("anchor", spring.position)
		rig.add_child(spring)
		springs.append(spring)
	rig.set_meta("wheels", wheels)
	rig.set_meta("springs", springs)
	return rig

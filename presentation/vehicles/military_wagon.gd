extends RefCounted

# Blender owns the deck, fenders, benches, rails and wheels. This adapter only
# exposes the authored animation and hitch nodes to the common wheel rig.
const SCENES := {
	"cargo": preload("res://assets/vehicles/military_wagon_cargo.glb"),
	"repair": preload("res://assets/vehicles/military_wagon_repair.glb"),
	"weapon": preload("res://assets/vehicles/military_wagon_weapon.glb"),
	"fuel": preload("res://assets/vehicles/military_wagon_fuel.glb"),
	"anti_tank": preload("res://assets/vehicles/military_wagon_anti_tank.glb"),
	"anti_air": preload("res://assets/vehicles/military_wagon_anti_air.glb"),
}

static func build(type: String) -> Node3D:
	var scene: PackedScene = SCENES.get(type, SCENES.cargo)
	var rig := scene.instantiate() as Node3D
	rig.name = "SteeringWheelTrailer"
	rig.set_meta("wagon_type", type)
	rig.set_meta("model_path", scene.resource_path)
	rig.set_meta("model", rig)
	return rig

static func wheel_nodes(rig: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for name in ["FrontLeftWheel", "FrontRightWheel", "RearLeftWheel", "RearRightWheel"]:
		# Blender keeps a shared scene while exporting six variants and gives
		# later equivalent empties numeric suffixes.
		var candidates := rig.find_children(name + "*", "Node3D", true, false)
		var pivot := candidates[0] as Node3D if not candidates.is_empty() else null
		if pivot != null:
			pivot.set_meta("anchor", pivot.position)
			result.append(pivot)
	return result

static func spring_nodes(rig: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in rig.find_children("SuspensionStrut*", "Node3D", true, false):
		var spring := child as Node3D
		spring.set_meta("anchor", spring.position)
		result.append(spring)
	return result

extends RefCounted

const Catalog = preload("res://modules/combat/enemy_catalog.gd")
const BaseGeometry = preload("res://modules/world/activities/base_geometry_rules.gd")
const TYPES := ["soldier", "drone", "bike", "buggy", "keep", "garrison", "priorityVehicle"]
const REQUIRED := ["hp", "speed", "damage", "radius", "preferred", "range", "interval"]

static func create(kind: String, id: int, position: Vector3, random: RandomNumberGenerator, options: Dictionary = {}) -> Dictionary:
	if not Catalog.DEFINITIONS.has(kind):
		return {}
	return from_definition(kind, Catalog.DEFINITIONS[kind], id, position, random, options)

static func from_definition(kind: String, definition: Dictionary, id: int, position: Vector3, random: RandomNumberGenerator, options: Dictionary = {}) -> Dictionary:
	if not validation_errors(definition).is_empty():
		return {}
	var data := definition.duplicate(true)
	var recipe: Dictionary = data.get("spawn", {})
	data.erase("spawn")
	data.merge({"id": id, "kind": kind, "position": position, "x": position.x, "z": position.z,
		"max_hp": data.hp, "yaw": 0.0, "velocity": Vector3.ZERO, "cooldown": random.randf_range(0.3, 1.2),
		"counts_toward_wave": true, "collision_cooldown": 0.0, "dead": false, "hit_time": 0.0})
	if data.type == "drone":
		data.flight_height = data.height
		data.dodge_seed = random.randi()
		data.dodge_sign = -1.0 if random.randf() < 0.5 else 1.0
	if data.type == "garrison":
		var profile := BaseGeometry.profile(int(data.tier))
		data.height = profile.height
		data.hitbox_size = profile.hitbox_size
		data.door_distance = profile.door_distance
	if recipe.has("speed_range"):
		var limits: Array = recipe.speed_range
		data.speed = random.randf_range(float(limits[0]), float(limits[1])) * float(recipe.get("speed_multiplier", 1.0))
	if recipe.has("components"):
		data.phase = int(recipe.get("phase", 0))
		data.components = recipe.components
	data.merge(options, true)
	return data

static func validation_errors(definition: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(definition.get("model", "")).is_empty():
		errors.append("Missing visual model")
	if definition.get("type", "") not in TYPES:
		errors.append("Unknown AI type")
	for key: String in REQUIRED:
		var value: Variant = definition.get(key)
		if not (value is float or value is int):
			errors.append("Missing numeric field: " + key)
		elif not is_finite(float(value)) or float(value) < 0.0 or (key in ["hp", "radius"] and float(value) <= 0.0):
			errors.append("Invalid value: " + key)
	if definition.get("type") in ["drone", "garrison"]:
		var height: Variant = definition.get("height")
		if not (height is float or height is int) or not is_finite(float(height)) or float(height) <= 0.0:
			errors.append("Drone/garrison requires a positive finite height")
	var recipe: Variant = definition.get("spawn", {})
	if not recipe is Dictionary:
		errors.append("Spawn recipe must be a dictionary")
	elif recipe.has("speed_range"):
		var limits: Variant = recipe.speed_range
		if not limits is Array or limits.size() != 2:
			errors.append("Invalid spawn speed range")
		elif not (limits[0] is float or limits[0] is int) or not (limits[1] is float or limits[1] is int):
			errors.append("Spawn speed bounds must be numeric")
		elif not is_finite(float(limits[0])) or not is_finite(float(limits[1])) or float(limits[0]) < 0.0 or float(limits[1]) < float(limits[0]):
			errors.append("Invalid spawn speed range")
	if recipe is Dictionary and recipe.has("speed_multiplier"):
		var multiplier: Variant = recipe.speed_multiplier
		if not (multiplier is float or multiplier is int) or not is_finite(float(multiplier)) or float(multiplier) < 0.0:
			errors.append("Invalid spawn speed multiplier")
	return errors

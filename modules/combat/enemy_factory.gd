extends RefCounted

const Catalog = preload("res://modules/combat/enemy_catalog.gd")
const BaseGeometry = preload("res://modules/world/activities/base_geometry_rules.gd")
const TYPES := ["soldier", "drone", "bike", "buggy", "keep", "garrison", "priorityVehicle"]
const REQUIRED := ["hp", "speed", "damage", "radius", "preferred", "range", "interval"]
const FLIGHT_FIELDS := ["turn_rate", "strafe", "near_throttle", "hold_throttle", "altitude_bob"]
const EVASION_FIELDS := ["chance", "cooldown", "reaction", "duration", "minimum_radius", "padding", "strength", "urgency_strength"]
const REPAIR_FIELDS := ["stop_range", "turn_rate", "recheck", "range", "heal_rate", "tick_cap", "pulse_interval"]
const BEHAVIOR_KEYS := {"soldier": ["retreat", "detonation"], "drone": ["flight", "evasion", "detonation"], "priorityVehicle": ["repair", "mines"]}

static func create(kind: String, id: int, position: Vector3, random: RandomNumberGenerator, options: Dictionary = {}) -> Dictionary:
	if not Catalog.DEFINITIONS.has(kind):
		return {}
	return from_definition(kind, Catalog.DEFINITIONS[kind], id, position, random, options)

static func from_definition(kind: String, definition: Dictionary, id: int, position: Vector3, random: RandomNumberGenerator, options: Dictionary = {}) -> Dictionary:
	if not validation_errors(definition).is_empty():
		return {}
	var candidate := definition.duplicate(true)
	candidate.merge(options, true)
	if not options.is_empty() and not validation_errors(candidate).is_empty():
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
	if definition.has("salvage_drops") and (not (definition.salvage_drops is int) or definition.salvage_drops <= 0):
		errors.append("Salvage drops must be a positive integer")
	_validate_behavior(definition, errors)
	return errors

static func _validate_behavior(definition: Dictionary, errors: Array[String]) -> void:
	var raw_behavior: Variant = definition.get("behavior", {})
	if not raw_behavior is Dictionary:
		errors.append("Behavior must be a dictionary")
		return
	var behavior: Dictionary = raw_behavior
	var allowed: Array = BEHAVIOR_KEYS.get(definition.get("type"), [])
	for key: String in behavior:
		if key not in allowed:
			errors.append("Unknown behavior: " + key)
	if definition.get("type") == "drone":
		_validate_numeric_fields(behavior.get("flight"), FLIGHT_FIELDS, "flight", errors)
		_validate_numeric_fields(behavior.get("evasion"), EVASION_FIELDS, "evasion", errors)
		var flight: Variant = behavior.get("flight")
		if flight is Dictionary and flight.has("always_advance") and not (flight.always_advance is bool):
			errors.append("Flight always_advance must be boolean")
	if behavior.has("detonation"):
		var detonation: Variant = behavior.detonation
		_validate_numeric_fields(detonation, ["range", "effect_radius"], "detonation", errors)
		if detonation is Dictionary and not (detonation.get("jammed") is bool):
			errors.append("Detonation requires jammed flag")
	if behavior.has("repair"):
		_validate_numeric_fields(behavior.repair, REPAIR_FIELDS, "repair", errors)
	if behavior.has("mines"):
		_validate_numeric_fields(behavior.mines, ["interval"], "mines", errors)
	if behavior.has("retreat") and not (behavior.retreat is bool):
		errors.append("Retreat behavior must be boolean")

static func _validate_numeric_fields(profile: Variant, fields: Array, label: String, errors: Array[String]) -> void:
	if not profile is Dictionary:
		errors.append("Missing " + label + " behavior")
		return
	for key: String in profile:
		if key not in fields and not (label == "flight" and key == "always_advance") and not (label == "detonation" and key == "jammed"):
			errors.append("Unknown " + label + " field: " + key)
	for field: String in fields:
		var value: Variant = profile.get(field)
		var may_be_signed := label == "flight" and field in ["near_throttle", "hold_throttle"]
		if not (value is float or value is int) or not is_finite(float(value)) or (not may_be_signed and float(value) < 0.0):
			errors.append("Invalid " + label + " field: " + field)
		elif label == "evasion" and field == "chance" and float(value) > 1.0:
			errors.append("Invalid evasion chance")
		elif (label == "detonation" and field == "range") or (label == "mines" and field == "interval"):
			if float(value) <= 0.0:
				errors.append(label.capitalize() + " " + field + " must be positive")

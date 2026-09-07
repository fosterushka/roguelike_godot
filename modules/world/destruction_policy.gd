extends RefCounted

const TREE_KINDS := ["tree", "deadTree"]
static var _data: Dictionary = {}

static func settings() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/destruction_rules.json"))
	return _data

static func roll(identity: String) -> float:
	var value: int = 2166136261
	for byte in identity.to_utf8_buffer():
		value = ((value ^ byte) * 16777619) & 0xffffffff
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0xffffffff
	return float((value ^ (value >> 16)) & 0xffffffff) / 4294967296.0

static func falls(prop: Dictionary, context: Dictionary) -> bool:
	return prop.kind in ["tree", "deadTree"] and context.cause in ["collision", "shot"]

static func leaves_stump(prop: Dictionary) -> bool:
	return roll(str(prop.id) + ":stump") < float(settings().stump_chance)

static func can_throw(prop: Dictionary) -> bool:
	return prop.kind not in ["rock", "stump", "building", "monument", "well", "windmill"] and not prop.get("rock_obstacle", false) and float(prop.radius) <= 3.0

static func damage_on_landing(speed: float) -> float:
	return pow(maxf(0.0, speed - float(settings().landing_safe_speed)), 2.0) * float(settings().landing_damage_scale)

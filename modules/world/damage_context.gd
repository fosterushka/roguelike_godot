extends RefCounted

static func create(cause: String, direction: Vector3 = Vector3.ZERO, source: String = "", impact_id: String = "") -> Dictionary:
	direction.y = 0.0
	return {"cause": cause, "direction": direction.normalized(), "source": source, "impact_id": impact_id, "rewarded": cause not in ["tornado", "landing"]}

static func normalized(value: Dictionary, fallback: String = "shot") -> Dictionary:
	var result := create(str(value.get("cause", fallback)), value.get("direction", Vector3.ZERO), str(value.get("source", "")), str(value.get("impact_id", "")))
	result.merge(value, true)
	return result

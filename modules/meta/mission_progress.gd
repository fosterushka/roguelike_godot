extends RefCounted

const LIMIT := 5
const LEGACY := ["first_delivery", "road_keeper", "helping_hand"]

static func number(value: Variant, maximum: float) -> float:
	if not (value is int or value is float) or not is_finite(float(value)):
		return 0.0
	return clampf(float(value), 0.0, maximum)

static func counts(state: Dictionary, mission: Dictionary) -> Dictionary:
	var result := {}
	var saved: Variant = state.get("counts", {})
	for index in mission.objectives.size():
		var objective: Dictionary = mission.objectives[index]
		var target := float(objective.target)
		var value: Variant = saved.get(objective.metric, 0) if saved is Dictionary else 0
		if state.get("status", "") == "claimed":
			value = target
		elif index == 0 and str(mission.id) in LEGACY and not (saved is Dictionary and saved.has(objective.metric)):
			value = state.get("progress", 0)
		result[objective.metric] = number(value, target)
	return result

static func total(values: Dictionary) -> float:
	var result := 0.0
	for value: Variant in values.values():
		result += float(value)
	return result

static func normalize(saved: Variant, definitions: Dictionary) -> Dictionary:
	var result := {}
	if not saved is Dictionary:
		return result
	var active := 0
	for id: String in definitions:
		if not saved.get(id) is Dictionary:
			continue
		var state: Dictionary = saved[id]
		var status := str(state.get("status", ""))
		if status not in ["active", "claimed", "ready"]:
			continue
		var values := counts(state, definitions[id])
		if status == "claimed":
			result[id] = {"status": "claimed", "progress": total(values)}
		elif active < LIMIT:
			result[id] = {"status": "active", "progress": total(values), "counts": values}
			active += 1
	return result

static func active_count(quests: Dictionary) -> int:
	var count := 0
	for state: Dictionary in quests.values():
		count += int(state.get("status", "") == "active")
	return count

static func objectives_met(mission: Dictionary, values: Dictionary) -> bool:
	for objective: Dictionary in mission.objectives:
		if float(values.get(objective.metric, 0)) + 0.00001 < float(objective.target):
			return false
	return true

static func conditions_met(mission: Dictionary, metrics: Dictionary) -> bool:
	for condition: Dictionary in mission.get("conditions", []):
		var value := float(metrics.get(condition.metric, 0))
		if condition.op == "min" and value + 0.00001 < float(condition.value):
			return false
		if condition.op == "max" and value - 0.00001 > float(condition.value):
			return false
	return true

static func commit(quests: Dictionary, definitions: Dictionary, metrics: Dictionary) -> void:
	for id: String in quests:
		var state: Dictionary = quests[id]
		if state.status != "active" or not definitions.has(id):
			continue
		var mission: Dictionary = definitions[id]
		if not conditions_met(mission, metrics):
			continue
		var values := counts(state, mission)
		if mission.scope == "raid" and not objectives_met(mission, metrics):
			continue
		for objective: Dictionary in mission.objectives:
			var gain := maxf(0.0, float(metrics.get(objective.metric, 0)))
			values[objective.metric] = float(objective.target) if mission.scope == "raid" else minf(float(objective.target), float(values[objective.metric]) + gain)
		state.counts = values
		state.progress = total(values)

static func delivery_ready(mission: Dictionary, stash: Dictionary) -> bool:
	for item: String in mission.get("delivery", {}):
		if int(stash.get(item, 0)) < int(mission.delivery[item]):
			return false
	return true

static func row(mission: Dictionary, state: Dictionary, metrics: Dictionary, level: int, in_raid: bool, active: int, stash: Dictionary) -> Dictionary:
	var result := mission.duplicate(true)
	var values := counts(state, mission)
	var status := str(state.get("status", "available"))
	if status == "active" and objectives_met(mission, values):
		status = "ready"
	elif status == "available" and level < int(mission.get("min_level", 1)):
		status = "locked"
	result.title = result.name
	result.status = status
	result.can_accept = not in_raid and status == "available" and active < LIMIT
	result.can_claim = not in_raid and status == "ready" and delivery_ready(mission, stash)
	result.can_abandon = not in_raid and status in ["active", "ready"]
	result.progress = total(values)
	result.target = 0.0
	result.raid_progress = 0.0
	for objective: Dictionary in result.objectives:
		objective.current = float(values[objective.metric])
		objective.raid_progress = minf(float(objective.target), float(metrics.get(objective.metric, 0))) if in_raid and status == "active" else 0.0
		result.target += float(objective.target)
		result.raid_progress += objective.raid_progress
	for condition: Dictionary in result.get("conditions", []):
		condition.current = float(metrics.get(condition.metric, 0))
		condition.met = condition.current >= float(condition.value) if condition.op == "min" else condition.current <= float(condition.value)
	result.reward_label = "%d кредитов · %d XP" % [result.credits, result.xp]
	return result

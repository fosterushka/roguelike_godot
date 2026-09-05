extends RefCounted

var profile: Dictionary
var catalog: Dictionary
var selected: Array = []
var progress: Dictionary = {}
var families: Dictionary = {}
var seen: Dictionary = {}
var active := false
var ended := false
var entity_count := 0
var activity_count := 0

func setup(profile_value: Dictionary, definitions: Dictionary) -> void:
	profile = profile_value
	catalog = definitions
	profile.completedContractIds = profile.completedContractIds.filter(func(id: String) -> bool: return catalog.has(id))
	for id: String in catalog:
		if profile.contractProgress.get(id, 0) >= catalog[id].target and not profile.completedContractIds.has(id):
			profile.completedContractIds.append(id)
		if profile.completedContractIds.has(id):
			profile.contractProgress.erase(id)
			var reward: String = catalog[id].rewardSidegradeId
			if not profile.unlockedSidegradeIds.has(reward):
				profile.unlockedSidegradeIds.append(reward)
	profile.selectedContractIds = profile.selectedContractIds.filter(func(id: String) -> bool: return catalog.has(id) and not profile.completedContractIds.has(id))

func begin_run() -> void:
	selected = profile.selectedContractIds.duplicate()
	progress.clear()
	families.clear()
	seen.clear()
	entity_count = 0
	activity_count = 0
	active = true
	ended = false
	profile.lifetimeStats.runs += 1

func record(event: Dictionary) -> bool:
	if not active or ended:
		return false
	var kind: String = event.get("kind", event.get("type", ""))
	var foundry: bool = kind in ["death", "entityKilled"] and event.get("entityType", event.get("type", "")) == "garrison"
	var activity: bool = kind in ["activity_completed", "activityCompleted"]
	var finish: bool = kind in ["result", "runEnded"]
	var shot: bool = kind in ["shot", "weaponFired"] and event.get("team", "player") == "player"
	if not (foundry or activity or finish or shot):
		return false
	if shot:
		var family: String = event.get("projectile_kind", event.get("projectileFamily", ""))
		if family.is_empty() or families.has(family):
			return false
		families[family] = true
	else:
		var id := kind + ":" + str(event.get("id", "end" if finish else ""))
		if seen.has(id) or (not finish and not event.has("id")):
			return false
		if foundry and entity_count >= 128 or activity and activity_count >= 1024:
			return false
		seen[id] = true
		if foundry:
			entity_count += 1
			profile.lifetimeStats.foundriesDestroyed += 1
		if activity:
			activity_count += 1
			profile.lifetimeStats.activitiesCompleted += 1
	var won: bool = event.get("won", event.get("victory", false))
	for id: String in selected:
		if profile.completedContractIds.has(id):
			continue
		var amount := 0
		match id:
			"break-the-line": amount = int(foundry)
			"answer-the-call": amount = int(activity and event.get("activity_type", event.get("activityType", "")) == "settlementDistress")
			"bad-weather-work": amount = int(activity and event.get("weather", "") in ["rainy", "storm"])
			"mixed-battery": amount = families.size() if shot else 0
			"powder-dry": amount = int(finish and event.get("elapsed", event.get("durationSeconds", 0)) >= 180 and not families.has("rocket"))
			"combined-arms":
				var modules: Array = event.get("module_types", event.get("moduleTypes", []))
				amount = int(finish and won and modules.has("assaultRifle") and modules.has("bazooka"))
		if amount <= 0:
			continue
		var definition: Dictionary = catalog[id]
		var target: Dictionary = progress if definition.scope == "run" else profile.contractProgress
		var previous := int(target.get(id, 0))
		target[id] = mini(int(definition.target), maxi(previous, amount) if definition.scope == "run" else previous + amount)
		if target[id] >= definition.target:
			profile.completedContractIds.append(id)
			profile.selectedContractIds.erase(id)
			profile.contractProgress.erase(id)
			if not profile.unlockedSidegradeIds.has(definition.rewardSidegradeId):
				profile.unlockedSidegradeIds.append(definition.rewardSidegradeId)
	if finish:
		ended = true
		active = false
		if won:
			profile.lifetimeStats.victories += 1
	return true

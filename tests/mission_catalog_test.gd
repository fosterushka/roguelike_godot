extends SceneTree

const Catalog = preload("res://modules/meta/mission_catalog.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _signature(row: Dictionary) -> String:
	var parts: Array[String] = [row.scope]
	for goal: Dictionary in row.objectives:
		parts.append("goal:" + str(goal.metric))
	for condition: Dictionary in row.conditions:
		parts.append("condition:" + str(condition.metric) + ":" + str(condition.op))
	for item: String in row.delivery:
		parts.append("delivery:" + item)
	parts.sort()
	return "|".join(parts)

func _run() -> void:
	var all := Catalog.all()
	check(all.size() == 120 and Catalog.errors().is_empty(), "Catalog loads all 120 valid missions")
	var categories := {}
	var names_ru := {}
	var names_en := {}
	var descriptions_ru := {}
	var descriptions_en := {}
	var signatures := {}
	var used_metrics := {}
	var complete_schema := true
	var valid_deliveries := true
	var valid_conditions := true
	var achievable := true
	var labels_available := true
	var raid_count := 0
	var multigoal_count := 0
	var conditioned_count := 0
	for id: String in all:
		var row: Dictionary = all[id]
		complete_schema = complete_schema and Catalog.validate(row).is_empty() and id == row.id
		names_ru[row.name] = true
		names_en[row.name_en] = true
		descriptions_ru[row.description] = true
		descriptions_en[row.description_en] = true
		categories[row.category] = int(categories.get(row.category, 0)) + 1
		signatures[_signature(row)] = true
		raid_count += int(row.scope == "raid")
		multigoal_count += int(row.objectives.size() > 1)
		conditioned_count += int(not row.conditions.is_empty())
		var objectives := {}
		for goal: Dictionary in row.objectives:
			objectives[goal.metric] = goal.target
			used_metrics[goal.metric] = true
			labels_available = labels_available and Catalog.label(goal.metric, "ru") != goal.metric and Catalog.label(goal.metric, "en") != goal.metric
			achievable = achievable and goal.metric != "loot_fuel_cell"
			if goal.metric in ["loot_types", "sectors", "speed_max", "combo_max", "health_pct", "fuel_pct", "min_health_pct"]:
				achievable = achievable and row.scope == "raid"
			if goal.metric == "loot_types":
				achievable = achievable and goal.target <= 5
			if goal.metric == "speed_max":
				achievable = achievable and goal.target <= 13
		var slots := 0
		for item: String in row.delivery:
			slots += int(Catalog.ITEMS[item]) * int(row.delivery[item])
			valid_deliveries = valid_deliveries and objectives.get("loot_" + item, 0) >= row.delivery[item]
		valid_deliveries = valid_deliveries and slots <= 24
		for condition: Dictionary in row.conditions:
			used_metrics[condition.metric] = true
			labels_available = labels_available and Catalog.label(condition.metric, "en") != condition.metric
			if condition.op == "max" and objectives.has(condition.metric):
				valid_conditions = valid_conditions and float(objectives[condition.metric]) <= float(condition.value)
			achievable = achievable and not (condition.metric == "shots" and condition.op == "max" and condition.value == 0)
	check(complete_schema, "Every definition has validated IDs, localized copy, scope, level, objectives and bounded rewards")
	check(names_ru.size() == 120 and names_en.size() == 120, "All Russian and English mission titles are unique")
	check(descriptions_ru.size() == 120 and descriptions_en.size() == 120, "Every mission has an individual bilingual briefing")
	check(categories.size() == 10 and categories.values().all(func(count: int) -> bool: return count == 12), "Each of ten categories contains exactly twelve missions")
	check(signatures.size() >= 90, "At least ninety distinct objective/condition/delivery signatures without using numeric target differences")
	check(multigoal_count >= 85 and conditioned_count >= 25 and raid_count >= 85, "Content includes substantial combined objectives, constraints and single-raid challenges")
	check(used_metrics.size() >= 55 and labels_available, "At least fifty-five real gameplay metrics have human-readable bilingual labels")
	check(valid_deliveries, "Deliveries require newly recovered items and fit the maximum twenty-four-slot backpack")
	check(valid_conditions and achievable, "No contradictory targets, impossible fresh fuel, additive distinct-count tricks, or unavailable hold-fire mechanic")
	var legacy := {"first_delivery": ["loot_scrap", 6, 180, 120], "road_keeper": ["kills", 12, 260, 180], "helping_hand": ["rescues", 2, 350, 240]}
	for id: String in legacy:
		var row: Dictionary = all[id]
		var expected: Array = legacy[id]
		check(row.min_level == 1 and row.scope == "career" and row.objectives.size() == 1 and row.objectives[0].metric == expected[0] and row.objectives[0].target == expected[1] and row.credits == expected[2] and row.xp == expected[3], "Legacy objective and rewards preserved: " + id)
	check(all.first_delivery.delivery.size() == 1 and int(all.first_delivery.delivery.get("scrap", 0)) == 6, "Legacy delivery still consumes six scrap")
	var bad: Dictionary = all.first_exit.duplicate(true)
	bad.objectives[0].metric = "imaginary_interaction"
	check(not Catalog.validate(bad).is_empty(), "Unknown gameplay metric is rejected")
	bad = all.first_exit.duplicate(true)
	bad.objectives[0].target = -1
	check(not Catalog.validate(bad).is_empty(), "Negative objective target is rejected")
	bad = all.first_exit.duplicate(true)
	bad.conditions = [{"metric": "damage_taken", "op": "maybe", "value": 0}]
	check(not Catalog.validate(bad).is_empty(), "Unsupported condition operator is rejected")
	bad = all.first_exit.duplicate(true)
	bad.delivery = {"relic": 13}
	check(not Catalog.validate(bad).is_empty(), "Oversized rare cargo delivery is rejected")
	bad = all.first_exit.duplicate(true)
	bad.credits = INF
	check(not Catalog.validate(bad).is_empty(), "Non-finite reward cannot enter persistence")
	bad = all.first_exit.duplicate(true)
	bad.description_en = ""
	check(not Catalog.validate(bad).is_empty(), "Missing English briefing is rejected")
	print("Mission variety: %d signatures, %d metrics, %d multiobjective, %d conditional" % [signatures.size(), used_metrics.size(), multigoal_count, conditioned_count])
	print("Mission catalog tests: ", checks - failures, "/", checks)
	quit(1 if failures else 0)

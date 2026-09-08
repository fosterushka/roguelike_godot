extends SceneTree
const Rules = preload("res://modules/progression/radar_rules.gd")
var checks := 0
var failures := 0
func _init() -> void:
	run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func run() -> void:
	var model := preload("res://modules/combat/combat_model.gd").new()
	var progression := preload("res://modules/progression/progression.gd").new("/private/tmp/iron-radar-upgrade-%d.json" % Time.get_ticks_usec())
	progression.setup(model)
	model.player.coins = 1000
	check(not progression.buy_upgrade("radar:2") and model.player.coins == 1000, "Radar must be installed before upgrades")
	check(progression.buy_upgrade("module:radar") and model.player.radar_level == 1 and model.player.radar_range == 40, "Installation begins with short40m range")
	var radar := preload("res://presentation/ui/radar.gd").new()
	root.add_child(radar)
	radar.size = Vector2(188, 208)
	var data := {"player": model.player, "enemies": [{"id": 1, "position": Vector3(35,0,0)}, {"id": 2, "position": Vector3(80,0,0)}, {"id": 3, "position": Vector3(150,0,0)}, {"id": 4, "position": Vector3(250,0,0)}, {"id": 5, "position": Vector3(270,0,0)}]}
	for level in range(1,Rules.MAX_LEVEL + 1):
		radar.update_state(data,null)
		check(radar.detected_hostiles().size() == level, "Each actual upgrade extends detected contacts, tier%d" % level)
		check(Rules.power_at(level) <= 100 and (Rules.power_at(level) == 100) == (level == Rules.MAX_LEVEL), "Full power is reached only at final tier")
		var coins: int = model.player.coins
		check(not progression.buy_upgrade("radar:%d" % (level+2)) and not progression.buy_upgrade("radar:-1") and not progression.buy_upgrade("radar:oops") and model.player.coins == coins, "Cannot skip tiers or charge invalid upgrade")
		if level < Rules.MAX_LEVEL:
			var row: Dictionary = progression.get_shop_state().radar_upgrade
			model.player.coins = row.cost - 1
			check(not progression.buy_upgrade(row.id) and model.player.radar_level == level, "Insufficient funds leave level untouched")
			model.player.coins = coins
			check(progression.buy_upgrade(row.id) and model.player.coins == coins - Rules.COSTS[level+1], "Upgrade spends exact advertised price once")
			coins = model.player.coins
			check(not progression.buy_upgrade(row.id) and model.player.coins == coins, "Stale double click does not buy next tier")
	check(not progression.get_shop_state().radar_upgrade.enabled and model.player.radar_range == Rules.RANGES[Rules.MAX_LEVEL], "Maximum tier caps at final range")
	model.player.radar_range = 0
	model.player.radar_level = 0
	data.running = true
	radar.cells.fill(0)
	radar.update_state(data,null)
	check(radar.effective_range == 18 and radar.explored(Vector3.ZERO) and not radar.explored(Vector3(45,0,0)) and radar.detected_hostiles().is_empty(), "Basic map reveals tiny local area without enemy contacts")
	radar.cells.fill(1)
	var strips: Array[Rect2i] = radar.explored_strips(Vector2i(100,100),40)
	check(strips.size() == 81, "Fully explored81x81cells use81 strips instead of6561 polygons")
	var covered := 0
	for strip: Rect2i in strips:
		covered += strip.size.x * strip.size.y
	check(covered == 6561, "Strip batching preserves exact revealed area")
	radar.cells.fill(0)
	for column in [99,100,102]:
		radar.cells[100 * radar.GRID + column] = 1
	strips = radar.explored_strips(Vector2i(100,100),4)
	check(strips == [Rect2i(99,100,2,1),Rect2i(102,100,1,1)], "Batching never reveals unexplored gaps")
	for distance in [50.0, 150.0, 700.0, 1400.0]:
		for variation in [0.0, 0.5, 1.0]:
			var interval := Rules.signal_interval(distance, variation)
			check(interval >= (5.0 if distance <= 150 else 10.0) and interval <= (10.0 if distance <= 150 else 20.0), "Signal timing matches near/far bounds")
	check(Rules.signal_interval(200) < Rules.signal_interval(600), "Approaching the target increases signal frequency")
	radar.update_world({"extraction": {"visible": true, "sites": [{"id": "site", "position": Vector3(500, 0, 0)}]}})
	for level in range(Rules.MAX_LEVEL + 1):
		model.player.radar_level = level
		radar.update_state(data, null)
		check((not radar.extraction_sites().is_empty()) == (level == 5), "Exact extraction map zones require radar five")
		check(Rules.identifies_missions(level) == (level >= 3), "Mission identification requires radar three")
	radar.queue_free()
	await process_frame
	print("Radar progression tests: %d/%d passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)

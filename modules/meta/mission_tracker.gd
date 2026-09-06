extends RefCounted

const RECENT_EVENT_LIMIT := 4096
const EVENT_KINDS := ["death", "activity_completed", "shot", "player_hit", "ability", "extraction_started", "extraction_failed", "ram_impact", "roadkill_impact", "overdrive_started", "airdrop_claimed", "healer_claimed", "mine_hacked", "boss_component_destroyed", "crew_rescued", "crew_died"]

var metrics: Dictionary = {}
var _seen: Dictionary = {}
var _recent_ids: Array[String] = []
var _recent_cursor := 0
var _sectors: Dictionary = {}
var _acquired: Dictionary = {}
var _site := ""
var _finalized := false
var _max_hp := 1.0
var _repair_totals: Dictionary = {}
var _rescued_crew: Dictionary = {}
var _lost_crew: Dictionary = {}

func reset(player: Dictionary) -> void:
	metrics = {"min_health_pct": 100.0}
	_seen.clear()
	_recent_ids.clear()
	_recent_cursor = 0
	_sectors.clear()
	_acquired.clear()
	_site = ""
	_finalized = false
	_repair_totals.clear()
	_rescued_crew.clear()
	_lost_crew.clear()
	for person: Dictionary in player.get("crew", []):
		if person.get("role", "") == "mechanic":
			_repair_totals[str(person.id)] = maxf(0.0, float(person.get("work_total", 0.0)))
	sample(player, 0.0, "sunny")

func add(metric: String, amount: float = 1.0) -> void:
	if not _finalized and is_finite(amount) and amount > 0.0:
		metrics[metric] = minf(1000000000.0, float(metrics.get(metric, 0)) + amount)

func sample(player: Dictionary, delta: float, weather: String) -> void:
	if _finalized or not is_finite(delta) or delta < 0.0:
		return
	for person: Dictionary in player.get("crew", []):
		if person.get("role", "") == "mechanic":
			_record_repair(str(person.get("id", "")), float(person.get("work_total", 0.0)))
	var speed := absf(float(player.get("speed", 0.0)))
	add("seconds", delta)
	add("distance", speed * delta)
	if speed >= 0.15:
		add("moving_seconds", delta)
	if player.get("handbraking", false) and speed >= 4.5 and absf(float(player.get("slip_angle", 0.0))) >= 0.18:
		add("drift_seconds", delta)
		add("drift_distance", speed * delta)
	if weather in ["sunny", "foggy", "rainy", "storm"]:
		add(weather + "_seconds", delta)
	metrics.speed_max = maxf(float(metrics.get("speed_max", 0)), speed)
	metrics.combo_max = maxf(float(metrics.get("combo_max", 0)), float(player.get("road_fury_combo", 0)))
	_max_hp = maxf(1.0, float(player.get("max_hp", 1)))
	metrics.health_pct = clampf(float(player.get("hp", 0)) / _max_hp * 100.0, 0.0, 100.0)
	metrics.fuel_pct = clampf(float(player.get("fuel", 0)) / maxf(1, float(player.get("max_fuel", 1))) * 100.0, 0.0, 100.0)
	metrics.min_health_pct = minf(float(metrics.get("min_health_pct", 100)), metrics.health_pct)
	var point: Vector3 = player.get("position", Vector3.ZERO)
	var key := "%d:%d" % [floori(point.x / 100.0), floori(point.z / 100.0)]
	if not _sectors.has(key) and _sectors.size() < 4096:
		_sectors[key] = true
		metrics.sectors = _sectors.size()

func loot(id: String, count: int) -> void:
	if not _finalized and count > 0:
		_acquired[id] = mini(9999, int(_acquired.get(id, 0)) + count)

func consumable(id: String) -> void:
	add("consumables_used")
	var metric := str({"repair_kit": "repair_uses", "fuel_cell": "fuel_uses", "weapon_parts": "weapon_uses"}.get(id, ""))
	if not metric.is_empty():
		add(metric)

func record(event: Dictionary) -> void:
	if _finalized:
		return
	var kind := str(event.get("kind", ""))
	if kind == "crew_repaired":
		if event.has("total"):
			_record_repair(str(event.get("id", "")), float(event.total))
		return
	if kind not in EVENT_KINDS or (kind == "shot" and event.get("team", "") != "player") or (kind == "death" and not event.get("rewarded", true)):
		return
	if event.has("id"):
		var key := kind + ":" + str(event.id)
		if _seen.has(key):
			return
		if _recent_ids.size() < RECENT_EVENT_LIMIT:
			_recent_ids.append(key)
		else:
			_seen.erase(_recent_ids[_recent_cursor])
			_recent_ids[_recent_cursor] = key
			_recent_cursor = (_recent_cursor + 1) % RECENT_EVENT_LIMIT
		_seen[key] = true
	match kind:
		"death":
			if not event.get("rewarded", true):
				return
			add("kills")
			var type := str(event.get("type", ""))
			if type in ["soldier", "bike", "buggy", "drone", "keep", "garrison"]:
				add("kills_" + type)
			elif type == "priorityVehicle":
				add("kills_priority")
			if event.get("boss", false):
				add("kills_boss")
			var enemy_kind := str(event.get("enemy_kind", ""))
			if enemy_kind in ["ak", "bazooka", "bomber", "shooter", "kamikaze", "jammerTruck", "repairCrawler", "minelayer"]:
				add("kills_" + enemy_kind)
		"activity_completed":
			add("activities")
			var metric := str({"raiderSupplyConvoy": "convoys", "settlementDistress": "rescues", "foundryDestroyed": "foundries", "scavengerRoute": "scavengers"}.get(str(event.get("activity_type", "")), ""))
			if not metric.is_empty():
				add(metric)
		"shot":
			if event.get("team", "") == "player":
				add("shots")
				var weapon := str(event.get("module_type", ""))
				if not weapon.is_empty():
					add("shots_" + weapon)
		"player_hit":
			if float(event.get("damage", 0)) > 0.0:
				add("damage_taken", float(event.damage))
				add("hits_taken")
				if event.has("hp"):
					metrics.min_health_pct = minf(float(metrics.get("min_health_pct", 100)), clampf(float(event.hp) / _max_hp * 100.0, 0.0, 100.0))
		"ability":
			if int(event.get("slot", -1)) == 0:
				add("nitro_uses")
			elif int(event.get("slot", -1)) == 2:
				add("repair_uses")
		"extraction_started":
			_site = str(event.get("site_id", ""))
			add("extraction_attempts")
		"extraction_failed": add("extraction_cancels")
		"ram_impact": add("rams")
		"roadkill_impact": add("roadkills")
		"overdrive_started": add("overdrives")
		"airdrop_claimed": add("airdrops")
		"healer_claimed": add("healers")
		"mine_hacked": add("mine_hacks")
		"boss_component_destroyed": add("boss_components")
		"crew_rescued":
			var id := str(event.get("id", ""))
			if not id.is_empty() and not _rescued_crew.has(id):
				_rescued_crew[id] = true
				add("crew_rescued")
		"crew_died":
			var id := str(event.get("id", ""))
			if not id.is_empty() and not _lost_crew.has(id):
				_lost_crew[id] = true
				add("crew_lost")

func _record_repair(id: String, total: float) -> void:
	if id.is_empty() or not is_finite(total) or total < 0.0:
		return
	var previous := float(_repair_totals.get(id, 0.0))
	add("crew_repair_hp", maxf(0.0, total - previous))
	_repair_totals[id] = maxf(previous, total)

func _finalize_caravan(player: Dictionary) -> void:
	var carriers := {"crawler": true}
	for wagon: Dictionary in player.get("carriers", []):
		var id := str(wagon.get("id", ""))
		if not id.is_empty() and not carriers.has(id) and wagon.get("attached", false) and not wagon.get("dead", false) and float(wagon.get("hp", 0)) > 0:
			carriers[id] = true
			add("wagons_extracted")
	var counted := {}
	for person: Dictionary in player.get("crew", []):
		var id := str(person.get("id", ""))
		if id.is_empty() or counted.has(id) or person.get("faction", "ally") != "ally":
			continue
		counted[id] = true
		if not person.get("dead", false) and float(person.get("hp", 0)) > 0 and person.get("boarded", false) and carriers.has(str(person.get("carrier_id", ""))):
			add("crew_extracted")
			if person.get("rescued", false) or _rescued_crew.has(id):
				add("rescued_crew_extracted")
		elif not _lost_crew.has(id):
			_lost_crew[id] = true
			add("crew_lost")

func current_metrics(backpack: Dictionary, items: Dictionary) -> Dictionary:
	if _finalized:
		return metrics.duplicate()
	var current := metrics.duplicate()
	current.loot_items = 0.0
	current.loot_types = 0.0
	current.loot_slots = 0.0
	for id: String in items:
		var amount := mini(int(_acquired.get(id, 0)), int(backpack.get(id, 0)))
		current["loot_" + id] = amount
		current.loot_items += amount
		current.loot_types += int(amount > 0)
		current.loot_slots += amount * int(items[id].size)
	return current

func finalize(player: Dictionary, backpack: Dictionary, items: Dictionary, result: Dictionary) -> void:
	if _finalized:
		return
	sample(player, 0.0, "")
	metrics = current_metrics(backpack, items)
	if result.get("extracted", false) or result.get("won", false):
		_finalize_caravan(player)
	if result.get("extracted", false):
		add("extractions")
		if _site in ["extract-1", "extract-2", "extract-3"]:
			add(_site.replace("-", "_"))
	if result.get("won", false):
		add("wins")
	_finalized = true

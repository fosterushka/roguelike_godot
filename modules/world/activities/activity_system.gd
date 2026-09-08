extends RefCounted

const Rules = preload("res://modules/world/activities/activity_rules.gd")
const SourceRandom = preload("res://modules/world/activities/source_random.gd")
const Extraction = preload("res://modules/world/activities/extraction_rules.gd")
const ExtractionSites = preload("res://modules/world/activities/extraction_sites.gd")
var world: Node3D
var random := SourceRandom.new()
var records: Array[Dictionary] = []
var participants: Dictionary = {}
var credits := 0
var next_sequence := 1
var next_major := 0.0
var next_minor := 0.0
var recovery_until := 0.0
var elapsed := 0.0
var extraction := Extraction.empty()
var extraction_sites: Array[Dictionary] = []
var _extraction_attempt := 0
var events: Array[Dictionary] = []
var _villages: Dictionary = {}
var _village_props: Dictionary = {}

func setup(runtime: Node3D) -> void:
	world = runtime
	_villages.clear()
	_village_props.clear()
	for village: Dictionary in world.arena.world_layout.villages:
		_villages[str(village.id)] = village
		_village_props[str(village.id)] = []
	for prop: Dictionary in world.props.records.values():
		var village_id := str(prop.get("village_id", ""))
		if _village_props.has(village_id):
			_village_props[village_id].append(prop)

func reset(seed_value: int) -> void:
	cancel_all("run reset")
	records.clear()
	participants.clear()
	credits = 0
	next_sequence = 1
	elapsed = 0.0
	recovery_until = 0.0
	extraction = Extraction.empty()
	extraction_sites = ExtractionSites.generate(world.arena.world_layout, world.props, seed_value)
	_extraction_attempt = 0
	world.combat.model.player.extraction_active = false
	events.clear()
	random.seed_run(seed_value)
	next_major = random.between(9, 14)
	next_minor = random.between(5, 9)
	world.combat.model.player.activity_credits = 0

func step(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	if world.vehicle.health <= 0:
		cancel_all("player unavailable")
		return
	for record in records.duplicate():
		_update(record, delta)
	_update_extraction(delta)
	if extraction.active:
		return
	if elapsed >= recovery_until:
		if elapsed >= next_major and Rules.live_count(records, true) < Rules.LIMIT_MAJOR and _pressure_allows(6):
			var preferred := "settlementDistress" if random.next() < 0.46 else "raiderSupplyConvoy"
			var record := request(preferred)
			if record.is_empty():
				record = request("raiderSupplyConvoy" if preferred == "settlementDistress" else "settlementDistress")
			next_major = elapsed + (random.between(24, 34) if not record.is_empty() else 5.0)
		if elapsed >= next_minor and Rules.live_count(records, false) < Rules.LIMIT_MINOR:
			var record := request("scavengerRoute")
			next_minor = elapsed + (random.between(20, 28) if not record.is_empty() else 5.0)
	while records.size() > Rules.HISTORY:
		var removed := false
		for index in records.size():
			if records[index].state not in Rules.LIVE:
				records.remove_at(index)
				removed = true
				break
		if not removed:
			break

func request(type: String) -> Dictionary:
	var major := type in Rules.MAJOR
	if elapsed < recovery_until or Rules.live_count(records, major) >= (Rules.LIMIT_MAJOR if major else Rules.LIMIT_MINOR):
		return {}
	if major and not _pressure_allows(3 if type == "settlementDistress" else 6):
		return {}
	if type == "settlementDistress":
		var villages: Array = _villages.values()
		if villages.is_empty():
			return {}
		var first := random.integer(0, villages.size() - 1)
		for offset in villages.size():
			var village: Dictionary = villages[(first + offset) % villages.size()]
			if reachable(Rules.point(village)) and village_eligible(str(village.id)) and placement_safe(Rules.point(village), 76.0):
				return announce(type, {"position": Rules.point(village), "source_id": village.id})
		return {}
	var route := _select_route()
	return announce(type, route) if not route.is_empty() else {}

func announce(type: String, options: Dictionary) -> Dictionary:
	var major := type in Rules.MAJOR
	if not Rules.REWARDS.has(type) or Rules.live_count(records, major) >= (Rules.LIMIT_MAJOR if major else Rules.LIMIT_MINOR):
		return {}
	var encounter_time := Rules.encounter_seconds(options.position.distance_to(world.vehicle.global_position), world.vehicle.fuel, world.vehicle.player_stats)
	var route: Array = options.get("route", [])
	var route_speed := minf(float(Rules.ROUTE_SPEEDS.get(type, 0.0)), Rules.route_length(route) / maxf(encounter_time, 1.0))
	var record := {"route_speed": route_speed, "encounter_seconds": encounter_time, "id": "activity-%04d" % next_sequence, "type": type, "state": "announced", "objective": Rules.OBJECTIVES[type],
		"position": options.position, "marker_position": options.position, "route": options.get("route", []), "source_id": options.get("source_id", ""),
		"announced_at": elapsed, "starts_at": elapsed + (1.5 if type == "scavengerRoute" else Rules.ANNOUNCE), "expires_at": elapsed + maxf(float(Rules.DURATIONS[type]), encounter_time),
		"completed_at": -1.0, "route_progress": 0.0, "route_ratio": 0.0, "participant_ids": [], "deployment_anchors": [],
		"reward_claimed": false, "reward": Rules.REWARDS[type], "reward_label": Rules.REWARD_LABELS[type], "telegraph_until": -1.0, "intrusion_until": -1.0, "yaw": 0.0}
	next_sequence += 1
	records.append(record)
	events.append({"kind": "activity_announced", "id": record.id, "activity_type": type, "position": record.position, "objective": record.objective})
	return record

func reachable(point: Vector3) -> bool:
	return point.distance_to(world.vehicle.global_position) <= Rules.reachable_radius(world.vehicle.fuel, world.vehicle.player_stats)

func _select_route() -> Dictionary:
	var routes: Array = world.arena.world_layout.get("activityRoutes", [])
	if routes.is_empty():
		return {}
	var first := random.integer(0, routes.size() - 1)
	for offset in routes.size():
		var source: Array = routes[(first + offset) % routes.size()].points
		var points: Array = []
		# Sample existing roads so sparse distant vertices cannot hide a nearby road.
		for point: Vector3 in Rules.sampled_route(source):
			if reachable(point) and point.length() < world.PLAYABLE_RADIUS - 40.0:
				points.append(point)
			elif points.size() >= 3:
				break
			else:
				points.clear()
		if points.size() < 3:
			continue
		# Traffic approaches the player instead of starting nearby and fleeing outward.
		if Rules.point(points[0]).distance_to(world.vehicle.global_position) < Rules.point(points[-1]).distance_to(world.vehicle.global_position):
			points.reverse()
		if placement_safe(Rules.point(points[0]), 92.0) and position_clear(Rules.point(points[0])) and position_clear(Rules.sample_route(points, 5.0).position):
			return {"position": Rules.point(points[0]), "route": points}
	return {}

func placement_safe(point: Vector3, minimum_distance: float) -> bool:
	if point.length() > world.PLAYABLE_RADIUS - 40.0 or point.distance_to(world.vehicle.global_position) < minimum_distance:
		return false
	var camera := world.get_viewport().get_camera_3d()
	if camera != null and not camera.is_position_behind(point):
		return not world.get_viewport().get_visible_rect().grow(24).has_point(camera.unproject_position(point))
	return true

func position_clear(point: Vector3) -> bool:
	return world.props.first_segment(point, point, 0.9).is_empty() and point.length() < world.PLAYABLE_RADIUS - 40.0

func _pressure_allows(cost: float) -> bool:
	var model: RefCounted = world.combat.model
	if model.status != "combat" or world.vehicle.health / maxf(1.0, world.vehicle.max_health) <= 0.28:
		return false
	var pressure := 0.0
	var mobile := 0
	for enemy: Dictionary in model.enemies:
		if enemy.dead or enemy.type == "garrison":
			continue
		mobile += 1
		pressure += float({"ak": 1.5, "bazooka": 2.5, "bomber": 2, "bike": 2, "buggy": 4, "shooter": 3, "kamikaze": 3, "keep": 12, "leviathan": 30}.get(str(enemy.kind), 1))
	var health_ratio: float = world.vehicle.health / maxf(1.0, world.vehicle.max_health)
	var mercy := 1.0 if health_ratio >= 0.55 else 0.48 if health_ratio <= 0.2 else lerpf(0.48, 1.0, (health_ratio - 0.2) / 0.35)
	var capacity := 0.0
	for enemy: Dictionary in model.enemies:
		if not enemy.dead and enemy.type == "garrison":
			capacity += 1.5
	return mobile + 2 <= 94 and pressure + cost <= Rules.pressure_budget(int(model.wave), health_ratio) + capacity * mercy

func _update(record: Dictionary, delta: float) -> void:
	if record.state not in Rules.LIVE:
		return
	if elapsed >= float(record.expires_at):
		finish(record, "expired", "Activity expired")
		return
	if record.type == "settlementDistress" and not village_eligible(str(record.source_id)):
		finish(record, "failed", "Village destroyed")
		return
	if record.state == "announced" and elapsed >= float(record.starts_at):
		_activate(record)
	if record.state != "active":
		return
	if record.type in ["settlementDistress", "foundryDispatch"]:
		if not record.participant_ids.is_empty() and _living(record).is_empty():
			_finish_combat_activity(record, "Raiders cleared")
		elif record.type == "foundryDispatch" and not _living(record).is_empty():
			record.position = _living(record)[0].position
		return
	var points: Array = record.route
	var total := Rules.route_length(points)
	if record.type == "raiderSupplyConvoy":
		var living := _living(record)
		if living.is_empty():
			_finish_combat_activity(record, "Convoy destroyed")
			return
		for enemy in living:
			if float(enemy.get("stagger_remaining", 0.0)) > 0.0 or enemy.get("airborne", false) or float(enemy.get("tornado_recovery", 0.0)) > 0.0:
				return
		record.route_progress = minf(total, record.route_progress + float(record.route_speed) * delta)
		for index in record.participant_ids.size():
			var enemy: Dictionary = participants.get(record.participant_ids[index], {})
			if enemy.is_empty() or enemy.dead:
				continue
			var sample := Rules.sample_route(points, maxf(0.0, record.route_progress - index * 5.0))
			enemy.tornado_offset_x = float(enemy.get("tornado_offset_x", 0)) * exp(-1.15 * delta)
			enemy.tornado_offset_z = float(enemy.get("tornado_offset_z", 0)) * exp(-1.15 * delta)
			enemy.position = sample.position + Vector3(enemy.tornado_offset_x, 0, enemy.tornado_offset_z)
			enemy.yaw = sample.yaw
			enemy.x = enemy.position.x
			enemy.z = enemy.position.z
	else:
		record.route_progress = minf(total, record.route_progress + float(record.route_speed) * delta)
	var sample := Rules.sample_route(points, record.route_progress)
	record.position = sample.position
	record.yaw = sample.yaw
	record.route_ratio = sample.progress
	if record.type == "scavengerRoute" and record.position.distance_to(world.vehicle.global_position) < 5.0:
		finish(record, "completed", "Scavengers contacted")
	elif record.route_progress >= total:
		finish(record, "failed" if record.type == "raiderSupplyConvoy" else "expired", "Route destination reached")

func _activate(record: Dictionary) -> void:
	if record.type == "scavengerRoute":
		if placement_safe(Rules.point(record.route[0]), 92.0):
			record.state = "active"
		return
	if not _pressure_allows(3 if record.type == "settlementDistress" else 6):
		return
	var positions: Array = []
	var kinds: Array = []
	if record.type == "raiderSupplyConvoy":
		for index in 2:
			var point: Vector3 = Rules.sample_route(record.route, float(5 - index * 5)).position
			if not placement_safe(point, 92) or not position_clear(point):
				return
			positions.append(point)
			kinds.append("buggy" if index == 0 else "bike")
		record.route_progress = 5.0
	elif record.type == "settlementDistress":
		var village: Dictionary = _villages[record.source_id]
		if record.deployment_anchors.is_empty():
			for anchor: Dictionary in village.deploymentAnchors:
				if position_clear(Rules.point(anchor)) and placement_safe(Rules.point(anchor), 42):
					record.deployment_anchors.append(anchor)
					if record.deployment_anchors.size() == 3:
						break
			if record.deployment_anchors.size() != 3:
				finish(record, "failed", "No clear deployment route")
				return
			record.telegraph_until = elapsed + random.between(1.5, 2.0)
			events.append({"kind": "activity_telegraph", "id": record.id, "position": record.position, "duration": record.telegraph_until - elapsed})
			return
		if elapsed < record.telegraph_until:
			return
		for anchor: Dictionary in record.deployment_anchors:
			if not position_clear(Rules.point(anchor)) or not placement_safe(Rules.point(anchor), 42):
				if record.intrusion_until < 0:
					record.intrusion_until = elapsed + 1.25
				elif elapsed >= record.intrusion_until:
					finish(record, "failed", "Deployment obstructed")
				return
			positions.append(Rules.point(anchor))
			kinds.append("rifleman")
	else:
		return
	var created: Array[Dictionary] = []
	for index in positions.size():
		var enemy: Dictionary = world.combat.model.spawn_enemy(kinds[index], positions[index], {"counts_toward_wave": false, "activity_route_controlled": record.type == "raiderSupplyConvoy", "activity_id": record.id})
		if enemy.is_empty():
			for previous in created:
				previous.dead = true
				world.combat.model.enemies.erase(previous)
			return
		created.append(enemy)
	for enemy in created:
		record.participant_ids.append(enemy.id)
		participants[enemy.id] = enemy
	record.state = "active"
	if record.type == "settlementDistress":
		record.expires_at = maxf(record.expires_at, elapsed + Rules.DURATIONS.settlementDistress)

func register_dispatch(source_id: String, point: Vector3, spawned: Array, existing: Dictionary = {}) -> Dictionary:
	if existing.is_empty() and (elapsed < recovery_until or not reachable(point)):
		return {}
	var record := existing if not existing.is_empty() else announce("foundryDispatch", {"position": point, "source_id": source_id})
	if record.is_empty():
		return {}
	for enemy: Dictionary in spawned:
		if enemy.is_empty():
			continue
		record.participant_ids.append(enemy.id)
		participants[enemy.id] = enemy
	record.state = "active"
	return record

func _living(record: Dictionary) -> Array:
	var result: Array = []
	for id in record.participant_ids:
		var enemy: Dictionary = participants.get(id, {})
		if not enemy.is_empty() and not enemy.dead:
			result.append(enemy)
	return result

func _finish_combat_activity(record: Dictionary, reason: String) -> void:
	var natural_only: bool = not record.participant_ids.is_empty()
	for id in record.participant_ids:
		var enemy: Dictionary = participants.get(id, {})
		natural_only = natural_only and not enemy.get("death_rewarded", true)
	finish(record, "failed" if natural_only else "completed", "Storm destroyed the target" if natural_only else reason)

func finish(record: Dictionary, outcome: String, reason: String = "") -> bool:
	if record.is_empty() or record.state not in Rules.LIVE:
		return false
	record.state = outcome
	record.completed_at = elapsed
	record.outcome_reason = reason
	recovery_until = maxf(recovery_until, elapsed + Rules.RECOVERY)
	if outcome == "completed" and not record.reward_claimed:
		record.reward_claimed = true
		credits += 1
		world.combat.model.player.activity_credits = credits
		world.combat.model.player.coins += int(record.reward)
		world.combat.model.player.xp += maxi(1, roundi(float(record.reward) * 0.6))
		record.reward_info = _apply_route_reward(str(record.type))
		world.combat.model.events.append({"kind": "activity_completed", "id": "%d:%s" % [world.combat.model.generation, record.id], "generation": world.combat.model.generation, "activity_type": record.type, "weather": world.weather.phase.type, "position": record.position, "loot_source": Rules.LOOT_SOURCES[record.type], "loot_count": 2 if record.type == "raiderSupplyConvoy" else 1, "reward_info": record.reward_info})
	for id in record.participant_ids:
		var enemy: Dictionary = participants.get(id, {})
		if not enemy.is_empty():
			enemy.dead = true
		participants.erase(id)
	events.append({"kind": "activity_finished", "id": record.id, "activity_type": record.type, "outcome": outcome, "reason": reason, "reward": record.reward if outcome == "completed" else 0, "reward_info": record.get("reward_info", {})})
	return true

func _apply_route_reward(type: String) -> Dictionary:
	var player: Dictionary = world.combat.model.player
	var reward := {"repair": 0.0, "fuel": 0.0, "blueprint": "", "reward_label": Rules.REWARD_LABELS[type]}
	if type == "settlementDistress":
		reward.repair = minf(world.vehicle.max_health - world.vehicle.health, world.vehicle.max_health * 0.35)
		world.vehicle.health += reward.repair
		player.hp = world.vehicle.health
	elif type == "scavengerRoute":
		reward.fuel = minf(world.vehicle.max_fuel - world.vehicle.fuel, 25.0)
		world.vehicle.fuel += reward.fuel
		player.fuel = world.vehicle.fuel
	elif type == "raiderSupplyConvoy":
		var unlocked: Array = player.get("unlocked_weapons", [])
		var candidates: Array[String] = []
		for weapon: String in world.combat.model._catalog:
			if world.combat.model._catalog[weapon].has("projectile") and not unlocked.has(weapon):
				candidates.append(weapon)
		if not candidates.is_empty():
			reward.blueprint = candidates[random.integer(0, candidates.size() - 1)]
			unlocked.append(reward.blueprint)
			player.unlocked_weapons = unlocked
	return reward

func village_eligible(id: String) -> bool:
	if not _villages.has(id):
		return false
	for prop: Dictionary in _village_props.get(id, []):
		if prop.destroyed:
			return false
	return true

func _nearest_site() -> Dictionary:
	var result: Dictionary = {}
	var best := INF
	for village: Dictionary in _villages.values():
		if not village_eligible(str(village.id)):
			continue
		var distance := Rules.point(village).distance_to(world.vehicle.global_position)
		if distance >= best:
			continue
		best = distance
		result = {"village": village, "distance": distance, "anchor": {}}
	if result.is_empty():
		return result
	var anchor_distance := INF
	for anchor: Dictionary in result.village.deploymentAnchors:
		var distance := Rules.point(anchor).distance_to(world.vehicle.global_position)
		if distance < anchor_distance and position_clear(Rules.point(anchor)):
			anchor_distance = distance
			result.anchor = anchor
	return result

func _nearest_extraction_site() -> Dictionary:
	var nearest: Dictionary = {}
	var closest := INF
	var player_position: Vector3 = world.vehicle.global_position
	player_position.y = 0.0
	for site: Dictionary in extraction_sites:
		var distance := player_position.distance_to(site.position)
		if distance < closest:
			closest = distance
			nearest = site.duplicate()
			nearest.distance = distance
	return nearest

func request_extraction() -> bool:
	if extraction.active or not world.running or not world.combat.model.running or world.combat.model.status in ["dead", "complete", "extracted"] or world.get_tree().paused or world.vehicle.health <= 0 or world.combat.model.player.hp <= 0:
		return false
	var nearest := _nearest_extraction_site()
	if nearest.is_empty() or nearest.distance > Extraction.ZONE_RADIUS:
		return false
	extraction = Extraction.empty()
	extraction.merge({"active": true, "site_id": nearest.id, "zone_id": nearest.id, "position": nearest.position}, true)
	_extraction_attempt += 1
	world.combat.model.player.extraction_active = true
	events.append({"kind": "extraction_started", "position": extraction.position, "site_id": nearest.id, "duration": Extraction.SECURE_SECONDS})
	_spawn_extraction_wave()
	extraction.next_wave_at = 5.0
	return true

func _spawn_extraction_wave() -> void:
	var model: RefCounted = world.combat.model
	var alive := 0
	for enemy: Dictionary in model.enemies:
		if not enemy.dead and enemy.get("extraction_defender", false):
			alive += 1
	var quota := mini(3, mini(10 - alive, 10 - int(extraction.spawned)))
	var spawned := 0
	for attempt in 48:
		if spawned >= quota:
			break
		var angle := float(attempt) / 16.0 * TAU + float(_extraction_attempt) * 0.73 + float(extraction.spawned) * 0.38
		var distance := 34.0 + float(attempt / 16) * 8.0
		var point: Vector3 = extraction.position + Vector3(cos(angle), 0, sin(angle)) * distance
		if not world.props.is_clear(point, 1.8):
			continue
		var kind := "ak" if extraction.progress >= 10.0 and spawned == 2 else "rifleman"
		var enemy: Dictionary = model.spawn_enemy(kind, point, {"counts_toward_wave": false, "extraction_defender": true, "extraction_site": extraction.site_id})
		if enemy.is_empty():
			continue
		extraction.spawned += 1
		spawned += 1
	if spawned > 0:
		events.append({"kind": "extraction_wave", "position": extraction.position, "count": spawned, "site_id": extraction.site_id})

func _update_extraction(delta: float) -> void:
	if not extraction.active:
		return
	var hostiles := 0
	for enemy: Dictionary in world.combat.model.enemies:
		if not enemy.dead and enemy.position.distance_to(extraction.position) <= Extraction.HOSTILE_RADIUS:
			hostiles += 1
	var player_position: Vector3 = world.vehicle.global_position
	player_position.y = 0.0
	var alive: bool = world.vehicle.health > 0.0 and world.combat.model.player.hp > 0.0
	var result := Extraction.step(extraction.progress, delta, alive, player_position.distance_to(extraction.position) <= Extraction.ZONE_RADIUS, hostiles > 0, extraction.out_of_range)
	extraction.progress = result.progress
	extraction.contested = false
	extraction.hostile_count = hostiles
	extraction.out_of_range = result.out_of_range
	if result.status in ["failed", "abandoned"]:
		cancel_extraction(str(result.status))
	elif result.completed:
		extraction = Extraction.empty()
		world.combat.model.player.extraction_active = false
		world.combat.finish_run(false, "extracted")
		world.running = false
		cancel_all("extracted")
		events.append({"kind": "extracted"})
	elif result.status == "defending" and extraction.progress >= extraction.next_wave_at:
		_spawn_extraction_wave()
		extraction.next_wave_at = (floorf(extraction.progress / 5.0) + 1.0) * 5.0

func cancel_extraction(reason: String) -> void:
	if extraction.active:
		extraction = Extraction.empty()
		world.combat.model.player.extraction_active = false
		events.append({"kind": "extraction_failed", "reason": reason})

func cancel_all(reason: String) -> void:
	cancel_extraction(reason)
	for record in records:
		if record.state in Rules.LIVE:
			finish(record, "failed", reason)

func get_extraction_state() -> Dictionary:
	var nearest := _nearest_extraction_site()
	var ready: bool = not nearest.is_empty() and nearest.distance <= Extraction.ZONE_RADIUS and world.vehicle.health > 0.0 and world.combat.model.player.hp > 0.0 and world.running and world.combat.model.running and world.combat.model.status not in ["dead", "complete", "extracted"] and not world.get_tree().paused
	var active: bool = extraction.active
	var point: Vector3 = extraction.position if active else nearest.get("position", Vector3.ZERO)
	var id := str(extraction.site_id) if active else str(nearest.get("id", ""))
	return {"available": not extraction_sites.is_empty(), "visible": true, "sites": extraction_sites.duplicate(true), "site_id": id, "zone_id": id,
		"mode": ("leaving" if extraction.out_of_range > 0.0 else "defending") if active else "ready" if ready else "route",
		"active": active, "can_request": ready and not active, "credits": credits, "required_credits": 0, "position": point,
		"radius": Extraction.ZONE_RADIUS, "duration": Extraction.SECURE_SECONDS, "distance": nearest.get("distance", -1.0),
		"progress": extraction.progress, "progress_percent": extraction.progress / Extraction.SECURE_SECONDS * 100.0,
		"remaining_seconds": maxf(0, Extraction.SECURE_SECONDS - extraction.progress), "hostile_count": extraction.hostile_count,
		"leave_remaining": maxf(0.0, Extraction.LEAVE_GRACE - extraction.out_of_range)}

func get_state() -> Dictionary:
	var live: Array = []
	for record in records:
		if record.state in Rules.LIVE:
			live.append(record.duplicate(true))
	live.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.type in Rules.MAJOR) and not (b.type in Rules.MAJOR))
	return {"available": true, "records": live, "current": live[0] if not live.is_empty() else {}, "credits": credits}

func drain_events() -> Array[Dictionary]:
	var result := events.duplicate()
	events.clear()
	return result

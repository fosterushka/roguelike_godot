extends RefCounted

const Rules = preload("res://modules/world/activities/activity_rules.gd")
const SourceRandom = preload("res://modules/world/activities/source_random.gd")
const Extraction = preload("res://modules/world/activities/extraction_rules.gd")
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
			if village_eligible(str(village.id)) and placement_safe(Rules.point(village), 76.0):
				return announce(type, {"position": Rules.point(village), "source_id": village.id})
		return {}
	var route := _select_route()
	return announce(type, route) if not route.is_empty() else {}

func announce(type: String, options: Dictionary) -> Dictionary:
	var major := type in Rules.MAJOR
	if not Rules.REWARDS.has(type) or Rules.live_count(records, major) >= (Rules.LIMIT_MAJOR if major else Rules.LIMIT_MINOR):
		return {}
	var record := {"id": "activity-%04d" % next_sequence, "type": type, "state": "announced", "objective": Rules.OBJECTIVES[type],
		"position": options.position, "marker_position": options.position, "route": options.get("route", []), "source_id": options.get("source_id", ""),
		"announced_at": elapsed, "starts_at": elapsed + (1.5 if type == "scavengerRoute" else Rules.ANNOUNCE), "expires_at": elapsed + Rules.DURATIONS[type],
		"completed_at": -1.0, "route_progress": 0.0, "route_ratio": 0.0, "participant_ids": [], "deployment_anchors": [],
		"reward_claimed": false, "reward": Rules.REWARDS[type], "telegraph_until": -1.0, "intrusion_until": -1.0, "yaw": 0.0}
	next_sequence += 1
	records.append(record)
	events.append({"kind": "activity_announced", "id": record.id, "activity_type": type, "position": record.position, "objective": record.objective})
	return record

func _select_route() -> Dictionary:
	var routes: Array = world.arena.world_layout.get("activityRoutes", [])
	for attempt in routes.size() * 6:
		var route: Dictionary = routes[random.integer(0, routes.size() - 1)]
		if route.points.size() < 3:
			continue
		var first := random.integer(0, route.points.size() - 3)
		var points: Array = route.points.slice(first, first + 3)
		if random.next() < 0.5:
			points.reverse()
		if not placement_safe(Rules.point(points[0]), 92.0):
			continue
		var valid := true
		for point in points:
			valid = valid and Rules.point(point).length() < world.PLAYABLE_RADIUS - 40.0
		if valid:
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
			finish(record, "completed", "Raiders cleared")
		elif record.type == "foundryDispatch" and not _living(record).is_empty():
			record.position = _living(record)[0].position
		return
	var points: Array = record.route
	var total := Rules.route_length(points)
	if record.type == "raiderSupplyConvoy":
		var living := _living(record)
		if living.is_empty():
			finish(record, "completed", "Convoy destroyed")
			return
		for enemy in living:
			if float(enemy.get("stagger_remaining", 0.0)) > 0.0:
				return
		record.route_progress = minf(total, record.route_progress + 6.2 * delta)
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
		record.route_progress = minf(total, record.route_progress + 4.2 * delta)
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
		record.expires_at = elapsed + Rules.DURATIONS.settlementDistress

func register_dispatch(source_id: String, point: Vector3, spawned: Array, existing: Dictionary = {}) -> Dictionary:
	if elapsed < recovery_until and existing.is_empty():
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
		world.combat.model.events.append({"kind": "activity_completed", "id": "%d:%s" % [world.combat.model.generation, record.id], "generation": world.combat.model.generation, "activity_type": record.type, "weather": world.weather.phase.type})
	for id in record.participant_ids:
		var enemy: Dictionary = participants.get(id, {})
		if not enemy.is_empty():
			enemy.dead = true
		participants.erase(id)
	events.append({"kind": "activity_finished", "id": record.id, "activity_type": record.type, "outcome": outcome, "reason": reason, "reward": record.reward if outcome == "completed" else 0})
	return true

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

func request_extraction() -> bool:
	if extraction.active or not world.running or world.get_tree().paused or world.vehicle.health <= 0 or credits < Extraction.REQUIRED_CREDITS or absf(world.vehicle.motion.speed) > Extraction.MAXIMUM_SPEED:
		return false
	var nearest := _nearest_site()
	if nearest.is_empty() or nearest.distance > Extraction.ACTIVATION_RADIUS or nearest.anchor.is_empty():
		return false
	credits -= Extraction.REQUIRED_CREDITS
	world.combat.model.player.activity_credits = credits
	extraction = Extraction.empty()
	extraction.merge({"active": true, "village_id": nearest.village.id, "anchor_id": nearest.anchor.id, "position": Rules.point(nearest.anchor)}, true)
	events.append({"kind": "extraction_started", "position": extraction.position})
	return true

func _update_extraction(delta: float) -> void:
	if not extraction.active:
		return
	var valid := village_eligible(str(extraction.village_id)) and position_clear(extraction.position)
	var hostiles := 0
	for enemy: Dictionary in world.combat.model.enemies:
		if not enemy.dead and enemy.position.distance_to(extraction.position) <= Extraction.HOSTILE_RADIUS:
			hostiles += 1
	var result := Extraction.step(extraction.progress, delta, valid, world.vehicle.global_position.distance_to(extraction.position) <= Extraction.ZONE_RADIUS, hostiles > 0, extraction.out_of_range)
	extraction.progress = result.progress
	extraction.contested = result.status == "contested"
	extraction.hostile_count = hostiles
	extraction.out_of_range = result.out_of_range
	if result.status in ["failed", "abandoned"]:
		cancel_extraction(str(result.status))
	elif result.completed:
		extraction = Extraction.empty()
		world.combat.finish_run(false, "extracted")
		world.running = false
		cancel_all("extracted")
		events.append({"kind": "extracted"})

func cancel_extraction(reason: String) -> void:
	if extraction.active:
		extraction = Extraction.empty()
		events.append({"kind": "extraction_failed", "reason": reason})

func cancel_all(reason: String) -> void:
	cancel_extraction(reason)
	for record in records:
		if record.state in Rules.LIVE:
			finish(record, "failed", reason)

func get_extraction_state() -> Dictionary:
	if extraction.active:
		return {"available": true, "visible": true, "mode": "contested" if extraction.contested else "leaving" if extraction.out_of_range > 0 else "securing", "active": true, "can_request": false, "credits": credits, "required_credits": 2, "position": extraction.position, "progress_percent": extraction.progress / 30.0 * 100.0, "remaining_seconds": maxf(0, 30.0 - extraction.progress), "hostile_count": extraction.hostile_count}
	var nearest := _nearest_site()
	var ready: bool = credits >= 2 and not nearest.is_empty() and nearest.distance <= 22 and not nearest.anchor.is_empty() and absf(world.vehicle.motion.speed) <= 1.5 and world.running and not world.get_tree().paused
	return {"available": true, "visible": credits > 0, "mode": "locked" if credits < 2 else "ready" if ready else "route", "active": false, "can_request": ready, "credits": credits, "required_credits": 2, "position": Rules.point(nearest.anchor) if not nearest.is_empty() and not nearest.anchor.is_empty() else Vector3.ZERO, "distance": nearest.get("distance", -1.0), "progress_percent": 0.0, "remaining_seconds": 30.0, "hostile_count": 0}

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

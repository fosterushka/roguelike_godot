extends RefCounted

var _active_ids: Array = []
var salvage_charge := 0.0
var last_family := ""
var last_hit_at := -INF
var primed_until := 0.0

func reset() -> void:
	_active_ids.clear()
	salvage_charge = 0.0
	last_family = ""
	last_hit_at = -INF
	primed_until = 0.0

func sync(player: Dictionary, enemies: Array[Dictionary]) -> void:
	var ids: Array = player.get("active_protocols", [])
	if ids == _active_ids:
		return
	_active_ids = ids.duplicate()
	if not active(player, "salvageLoop"):
		salvage_charge = 0.0
	if not active(player, "combinedFeed"):
		last_family = ""
		last_hit_at = -INF
		primed_until = 0.0
	for target: Dictionary in enemies:
		if not active(player, "breachCrew"):
			target.breached_until = 0.0
		if not active(player, "targetRelay"):
			target.relay_until = 0.0
		if not active(player, "suppressionCycle"):
			target.suppression = 0
			target.suppression_until = 0.0
			target.stagger_remaining = 0.0

static func active(player: Dictionary, id: String) -> bool:
	return id in player.get("active_protocols", [])

static func family(module_type: String) -> String:
	if module_type in ["assaultRifle", "akTurret", "minigun"]:
		return "ballistic"
	if module_type in ["bazooka", "grenadeLauncher", "missileRack"]:
		return "explosive"
	return ""

static func can_breach(target: Dictionary) -> bool:
	return not target.get("dead", false) and target.get("damageable", true) and not target.get("boss", false) and target.get("type", "") not in ["soldier", "bike", "buggy", "drone"] and not target.get("is_component", false)

static func mark_focus(player: Dictionary, target: Dictionary, now: float) -> void:
	if active(player, "targetRelay") and not target.is_empty() and not target.get("dead", false) and target.get("damageable", true):
		target.relay_until = now + 8.0

static func ram(player: Dictionary, target: Dictionary, now: float) -> void:
	if active(player, "breachCrew") and player.ram_timer > 0.0 and can_breach(target):
		target.breached_until = now + 6.0

func hit(player: Dictionary, target: Dictionary, shot: Dictionary, now: float, direct: bool) -> float:
	if shot.get("synergy_eligible", true) == false or shot.team != "player":
		return 1.0
	var multiplier := 1.0
	var module_type: String = shot.get("module_type", "")
	var group := family(module_type)
	if active(player, "breachCrew") and group == "explosive" and can_breach(target) and target.get("breached_until", 0.0) > now:
		target.breached_until = 0.0
		multiplier += 0.35
	if active(player, "targetRelay") and direct and module_type in ["railgun", "missileRack"] and target.get("relay_until", 0.0) > now:
		target.relay_until = 0.0
		multiplier += 0.4
	if active(player, "suppressionCycle") and not target.get("boss", false) and not target.get("is_component", false):
		if target.get("suppression_until", 0.0) <= now:
			target.suppression = 0
		if group == "ballistic":
			target.suppression = mini(5, target.get("suppression", 0) + 1)
			target.suppression_until = now + 2.5
		elif module_type == "grenadeLauncher":
			var stacks: int = target.get("suppression", 0)
			if stacks > 0:
				target.stagger_remaining = maxf(target.get("stagger_remaining", 0.0), minf(0.65, 0.25 + stacks * 0.08))
			target.suppression = 0
			target.suppression_until = 0.0
	if active(player, "combinedFeed") and direct and not group.is_empty():
		if not last_family.is_empty() and last_family != group and now - last_hit_at <= 4.0:
			primed_until = now + 3.0
		last_family = group
		last_hit_at = now
	return multiplier

func combined_weapon(player: Dictionary, weapons: Array[Dictionary], now: float) -> Dictionary:
	if not active(player, "combinedFeed") or primed_until <= now:
		return {}
	var next_family := "explosive" if last_family == "ballistic" else "ballistic"
	for weapon: Dictionary in weapons:
		if family(weapon.type) == next_family:
			return weapon
	return {}

func salvage_multiplier(player: Dictionary) -> float:
	return player.coin_mult * (1.0 if active(player, "salvageLoop") else pow(1.15, player.get("treasury_count", 0)))

func collect(player: Dictionary, raw_amount: float) -> void:
	if active(player, "salvageLoop"):
		salvage_charge = minf(20.0, salvage_charge + maxf(0.0, raw_amount))
		pulse(player)

func pulse(player: Dictionary) -> void:
	if not active(player, "salvageLoop"):
		salvage_charge = 0.0
	elif salvage_charge >= 20.0 and player.hp < player.max_hp:
		player.hp = minf(player.max_hp, player.hp + 30.0)
		salvage_charge = 0.0

static func advance_status(target: Dictionary, delta: float) -> bool:
	var interrupted: bool = target.get("stagger_remaining", 0.0) > 0.0
	target.stagger_remaining = maxf(0.0, target.get("stagger_remaining", 0.0) - delta)
	target.slow_remaining = maxf(0.0, target.get("slow_remaining", 0.0) - delta)
	if target.slow_remaining <= 0.0:
		target.slow_multiplier = 1.0
	return interrupted

static func conductor_target(enemies: Array[Dictionary], source: Dictionary, now: float) -> Dictionary:
	if source.get("wet_until", 0.0) <= now or source.type == "drone" or source.get("targetable", true) == false or source.get("damageable", true) == false:
		return {}
	var nearest: Dictionary = {}
	var best := 14.0 * 14.0
	for enemy: Dictionary in enemies:
		if enemy == source or enemy.type == "drone" or enemy.get("targetable", true) == false or enemy.dead or enemy.get("wet_until", 0.0) <= now or enemy.get("damageable", true) == false:
			continue
		var distance: float = enemy.position.distance_squared_to(source.position)
		if distance <= best:
			best = distance
			nearest = enemy
	return nearest

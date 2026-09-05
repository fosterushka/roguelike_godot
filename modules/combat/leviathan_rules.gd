extends RefCounted
const Terrain = preload("res://modules/caravan/terrain_surface.gd")

const ANCHORS := {"missilePod": Vector3(0, 6.3, -1.2), "gunPod": Vector3(1.5, 5.5, 1.3), "leftDrive": Vector3(-3.55, 2.25, -0.35), "rightDrive": Vector3(3.55, 2.25, -0.35), "core": Vector3(0, 4.45, 0.2)}
const RADII := {"missilePod": 1.35, "gunPod": 1.15, "leftDrive": 1.45, "rightDrive": 1.45, "core": 1.55}

static func setup(enemy: Dictionary, model) -> void:
	enemy.core_cooldown = 2.8
	enemy.core_telegraph = -1.0
	enemy.targetable = false
	enemy.damageable = false
	for component: Dictionary in enemy.components:
		component.merge({"id": model._id(), "type": "bossComponent", "is_component": true,
			"parent_id": enemy.id, "radius": RADII[component.kind], "priority": 8.0,
			"position": enemy.position, "velocity": Vector3.ZERO, "dead": false,
			"exposed": component.phase == 0, "targetable": component.phase == 0,
			"damageable": true, "collidable": false, "repairable": false,
			"cooldown": 1.2 if component.kind == "missilePod" else 0.45})
	sync(enemy)

static func sync(enemy: Dictionary) -> void:
	var rotation := Basis(Vector3.UP, enemy.yaw)
	for component: Dictionary in enemy.components:
		component.position = enemy.position + Vector3.UP * Terrain.height_at(enemy.position.x, enemy.position.z) + rotation * (ANCHORS[component.kind] * 1.32)
		component.velocity = enemy.velocity
		component.wet_until = enemy.get("wet_until", 0.0)
		component.exposed = not component.dead and component.phase == enemy.phase
		component.targetable = component.exposed

static func damage(model, parent: Dictionary, component: Dictionary, amount: float) -> bool:
	if component.dead or not component.exposed or not component.targetable or parent.dead:
		return false
	component.hp = maxf(0.0, component.hp - maxf(0.0, amount))
	component.hit_time = 0.12
	model._emit("hit", {"id": component.id, "type": "bossComponent", "position": component.position, "damage": amount, "parent_id": parent.id})
	if component.hp <= 0.0:
		component.dead = true
		component.exposed = false
		component.targetable = false
		if model.focus_id == component.id:
			model.focus_id = -1
		model._emit("boss_component_destroyed", {"id": component.id, "parent_id": parent.id, "component_kind": component.kind, "position": component.position})
		if component.kind == "core":
			model.kill_enemy(parent)
		else:
			var remaining := false
			for candidate: Dictionary in parent.components:
				if candidate.phase == parent.phase and not candidate.dead:
					remaining = true
			if not remaining:
				parent.phase = mini(2, parent.phase + 1)
				model._emit("boss_phase", {"id": parent.id, "phase": parent.phase, "position": parent.position})
	parent.hp = 0.0
	for candidate: Dictionary in parent.components:
		parent.hp += candidate.hp
	sync(parent)
	return true

static func step(model, enemy: Dictionary, delta: float, distance: float) -> void:
	sync(enemy)
	var acquired: bool = distance < 64.0 * (model.weather_range_multiplier(false, true))
	for component: Dictionary in enemy.components:
		if not component.exposed or component.dead:
			continue
		component.cooldown -= delta
		if component.kind == "missilePod" and component.cooldown <= 0.0 and distance < 72.0 and acquired:
			model.fire_projectile("rocket", "enemy", component.position, model.player.position + Vector3.UP * 2.4, 34.0)
			component.cooldown = 2.75
		elif component.kind == "gunPod" and component.cooldown <= 0.0 and distance < 58.0 and acquired:
			var lead: Vector3 = Vector3(sin(model.player.heading), 0.0, cos(model.player.heading)) * model.player.speed * 0.18
			model.fire_projectile("bullet", "enemy", component.position, model.player.position + Vector3.UP * 2.4 + lead, 13.0)
			component.cooldown = 0.82
	if enemy.phase != 2:
		return
	var origin: Vector3 = enemy.components.back().position
	if enemy.core_telegraph >= 0.0:
		enemy.core_telegraph = maxf(0.0, enemy.core_telegraph - delta)
		if enemy.core_telegraph == 0.0:
			_fire_volley(model, enemy, origin, acquired)
			enemy.core_telegraph = -1.0
			enemy.core_cooldown = 6.5
	else:
		enemy.core_cooldown -= delta
		if enemy.core_cooldown <= 0.0:
			enemy.core_telegraph = 0.9
			model._emit("telegraph", {"id": enemy.id, "position": origin, "radius": 52.0, "duration": 0.9})

static func _fire_volley(model, enemy: Dictionary, origin: Vector3, acquired: bool) -> void:
	for index in 8:
		var angle: float = enemy.yaw + index / 8.0 * TAU
		var target := origin + Vector3(sin(angle), 0, cos(angle)) * 52.0
		target.y = Terrain.height_at(target.x, target.z) + 1.2
		model.fire_projectile("rocket", "enemy", origin, target, 24.0)
	if not acquired:
		return
	var offset: Vector3 = model.player.position - origin
	var aim_angle := atan2(offset.x, offset.z)
	for index in 5:
		var angle := aim_angle + (index - 2) * 0.18
		var target := origin + Vector3(sin(angle), 0, cos(angle)) * 58.0
		target.y = Terrain.height_at(target.x, target.z) + 2.2
		model.fire_projectile("rocket", "enemy", origin, target, 28.0)

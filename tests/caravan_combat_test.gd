extends SceneTree
const Combat = preload("res://modules/combat/combat_model.gd")
var checks := 0
var failures := 0
var damage: Array[Dictionary] = []

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _run() -> void:
	var model := Combat.new()
	model.player.position = Vector3(20, 0, 0)
	model.friendly_targets_query = func() -> Array:
		return [{"id": "wagon-1", "position": Vector3(5, 2.2, 0), "radius": 1.0}, {"id": "crew-2", "position": Vector3(7, 2.2, 1), "radius": 0.6}]
	model.friendly_damage_query = func(id: String, amount: float, cause: String) -> bool:
		damage.append({"id": id, "amount": amount, "cause": cause})
		return true
	model.fire_projectile("bullet", "enemy", Vector3(0, 2.2, 0), Vector3(25, 2.2, 0), 10)
	model._update_projectiles(0.5)
	check(damage.size() == 1 and damage[0].id == "wagon-1", "Nearest wagon intercepts swept enemy bullet before player")
	check(model.player.hp == model.player.max_hp, "Intercepted bullet cannot also damage player")
	damage.clear()
	model.fire_projectile("rocket", "enemy", Vector3(0, 2.2, 0), Vector3(25, 2.2, 0), 30)
	model._update_projectiles(0.25)
	check(damage.size() == 2, "Direct rocket hit also damages nearby foot crew")
	if damage.size() == 2:
		check(damage[0].amount == 30 and damage[1].amount < 30, "Direct target gets one full hit; splash falls off")
		check(damage.all(func(hit: Dictionary) -> bool: return hit.cause == "explosion"), "One explosion damage path avoids double direct damage")
	damage.clear()
	model.fire_projectile("bullet", "player", Vector3(0, 2.2, 0), Vector3(25, 2.2, 0), 10)
	model._update_projectiles(0.2)
	check(damage.is_empty(), "Player and crew shots do not target their own caravan")
	model.projectiles.clear()
	model.world_collision_query = func(shot: Dictionary) -> bool:
		shot.position = Vector3(2, 2.2, 0)
		return true
	model.fire_projectile("bullet", "enemy", Vector3(0, 2.2, 0), Vector3(25, 2.2, 0), 10)
	model._update_projectiles(0.2)
	check(damage.is_empty(), "World obstacles block shots before wagon collision")
	print("Caravan combat tests: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

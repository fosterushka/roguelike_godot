extends SceneTree

const Model = preload("res://modules/combat/combat_model.gd")
const Shots = preload("res://modules/combat/projectile_rules.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	check(Shots.box_hit_fraction(Vector3(-10, 5, 0), Vector3(10, 5, 0), Vector3.ZERO, Vector3(10, 3, 8), 0.0, 0.14) < 0.0, "Base radius never extends hitbox above roof")
	check(Shots.box_hit_fraction(Vector3(-10, -1, 0), Vector3(10, -1, 0), Vector3.ZERO, Vector3(10, 3, 8), 0.0, 0.14) < 0.0, "Base radius never extends hitbox beneath ground")
	check(Shots.box_hit_fraction(Vector3(-10, 2, 0), Vector3(10, 2, 0), Vector3.ZERO, Vector3(10, 3, 8)) > 0.0, "Horizontal projectile hits actual hull")
	check(Shots.box_hit_fraction(Vector3(0, 10, 0), Vector3(0, 0, 0), Vector3.ZERO, Vector3(10, 3, 8)) > 0.0, "Descending projectile hits roof cap")
	check(Shots.box_hit_fraction(Vector3(3, 1, -10), Vector3(3, 1, 10), Vector3.ZERO, Vector3(8, 3, 2), PI * 0.5) < 0.0, "Rotated narrow hull rejects old unrotated footprint")
	check(Shots.box_hit_fraction(Vector3(-10, 1, 3), Vector3(10, 1, 3), Vector3.ZERO, Vector3(8, 3, 2), PI * 0.5) >= 0.0, "Rotated hull hit follows visible orientation")
	Terrain.configure({})
	for kind: String in ["garrison_1", "garrison_2", "garrison_3"]:
		var model := Model.new()
		model.enemies.clear()
		var base := model.spawn_enemy(kind, Vector3(200, 0, 250))
		var ground := Terrain.height_at(base.position.x, base.position.z)
		var aim := model._target_aim(base)
		check(aim.y > ground and aim.y < ground + float(base.height), "Auto aim stays inside " + kind)
		var roof_height := ground + float(base.height) + 0.5
		var miss := _shot(Vector3(200, roof_height, 230), Vector3(200, roof_height, 270))
		var health: float = base.hp
		check(not model._resolve_projectile_segment(miss) and base.hp == health, "Projectile clears roof without ghost damage " + kind)
		var hit := _shot(Vector3(200, aim.y, 230), Vector3(200, aim.y, 270))
		check(model._resolve_projectile_segment(hit) and base.hp < health, "Projectile hits terrain-aligned hull " + kind)
	print("Base collision: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _shot(start: Vector3, end: Vector3) -> Dictionary:
	return {"previous": start, "position": end, "team": "player", "kind": "bullet", "radius": 0.14, "damage": 5.0, "hit_targets": [], "pierce_remaining": 0}

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

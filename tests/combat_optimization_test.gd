extends SceneTree

const Model = preload("res://modules/combat/combat_model.gd")
const Runtime = preload("res://modules/combat/combat_runtime.gd")
const Progression = preload("res://modules/progression/progression.gd")
const CombatView = preload("res://presentation/combat/combat_view.gd")
const Source = preload("res://presentation/combat/source_model.gd")
const Visuals = preload("res://presentation/combat/projectile_visuals.gd")
const Main = preload("res://app/main.gd")

class CountingExpedition extends "res://modules/meta/expedition.gd":
	var snapshot_calls := 0
	func snapshot() -> Dictionary:
		snapshot_calls += 1
		return super.snapshot()

class UncachedCombat extends "res://modules/combat/combat_model.gd":
	func _resolve_projectile_segment(shot: Dictionary, _targets: Variant = null) -> bool:
		return super._resolve_projectile_segment(shot)

var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var grid = preload("res://modules/world/spatial_grid.gd").new()
	var obstacle := {"id": "near", "position": Vector3.ZERO, "radius": 2.0}
	grid.insert(obstacle)
	var nearby: Array = grid.nearby(Vector3.ZERO, 3.0)
	nearby.clear()
	check(grid.nearby(Vector3.ZERO, 3.0) == [obstacle], "Caller edits cannot poison cached obstacle candidates")
	obstacle.radius = 3.0
	check(grid.nearby(Vector3.ZERO, 3.0)[0].radius == 3.0, "Cached candidates retain live record references")
	grid.remove(obstacle)
	check(grid.nearby(Vector3.ZERO, 3.0).is_empty(), "Removal invalidates obstacle query cache")
	obstacle.position = Vector3(60, 0, 0)
	obstacle.radius = 65.0
	grid.insert(obstacle)
	check(grid.nearby(Vector3.ZERO, 3.0) == [obstacle], "Insertion and a larger maximum radius invalidate cached empty regions")
	for index in grid.MAX_CACHED_REGIONS + 20:
		var point := Vector3(index * grid.CELL_SIZE, 0, -index * grid.CELL_SIZE)
		var actual: Array = grid.nearby(point, 3.0)
		var expected: Array = []
		var reach: float = 3.0 + grid.maximum_radius
		for x in range(floori((point.x - reach) / grid.CELL_SIZE), floori((point.x + reach) / grid.CELL_SIZE) + 1):
			for z in range(floori((point.z - reach) / grid.CELL_SIZE), floori((point.z + reach) / grid.CELL_SIZE) + 1):
				expected.append_array(grid.buckets.get(Vector2i(x, z), []))
		check(actual == expected, "Bounded region cache preserves candidate order at cell boundaries")
	check(grid._regions.size() <= grid.MAX_CACHED_REGIONS, "Obstacle cache remains bounded during travel")
	var model := Model.new()
	var progression := Progression.new("/private/tmp/combat-optimization-%d.json" % Time.get_ticks_usec())
	progression.setup(model)
	var expedition := CountingExpedition.new(progression)
	progression.profile.expedition.credits = 5000
	expedition.caravan.buy_wagon("cargo")
	progression.profile.expedition.loadout = {"repair_kit": 1}
	check(expedition.cargo_used() == expedition.snapshot().used, "Cargo usage matches the loadout before a raid")
	expedition.begin_run(model.player)
	expedition.collect_loot("scrap", 15)
	check(expedition.cargo_used() == expedition.snapshot().used and expedition.cargo_used() > expedition.base_capacity(), "Cargo usage includes both backpack and wagon with catalog item sizes")
	var host := Main.new()
	host.expedition = expedition
	host._cargo_label = Button.new()
	var calls := expedition.snapshot_calls
	for index in 100:
		host._on_combat_event({"kind": "bullet_segment", "from": Vector3.ZERO, "to": Vector3.ONE, "team": "enemy"})
		host._update_cargo()
	check(expedition.snapshot_calls == calls, "Neither tracer events nor cargo HUD rebuild expedition menus")
	check(str(expedition.cargo_used()) in host._cargo_label.text, "Cargo HUD still shows current inventory usage")
	host._cargo_label.free()
	host.session_flow.free()
	host.free()

	var cached := Model.new()
	var reference := UncachedCombat.new()
	for sample in [cached, reference]:
		sample.player.position = Vector3(100, 0, 100)
		sample.weapons.clear()
		sample.spawn_queue.clear()
		sample.spawn_enemy("rifleman", Vector3(4, 0, 0))
		sample.spawn_enemy("rifleman", Vector3(8, 0, 0))
		sample.spawn_enemy("leviathan", Vector3(40, 0, 0))
		for index in 8:
			sample.fire_projectile("bullet", "player", Vector3(0, 1.05, 0), Vector3(80, 1.05, 0), 100, -1, {"pierce": 2})
		for index in 6:
			sample.fire_projectile("rocket", "player", Vector3(0, 4, 0), Vector3(40, 4, 0), 100)
	for index in 80:
		cached._update_projectiles(1.0 / 60.0)
		reference._update_projectiles(1.0 / 60.0)
		check(cached.snapshot() == reference.snapshot(), "Cached targets preserve piercing, kills and boss state")
		check(cached.drain_events() == reference.drain_events(), "Cached targets preserve event and hit order")

	# A first hit exposes a new boss phase; the next bullet in the same tick must see it.
	for sample in [cached, reference]:
		sample.reset_run()
		sample.running = true
		var boss: Dictionary = sample.spawn_enemy("leviathan", Vector3(40, 0, 0))
		var first: Dictionary = {}
		var second: Dictionary = {}
		for component: Dictionary in boss.components:
			if component.phase == 0:
				if first.is_empty():
					first = component
					component.hp = 1.0
				else:
					component.dead = true
					component.hp = 0.0
			elif component.phase == 1 and second.is_empty():
				second = component
		sample.Leviathan.sync(boss)
		for component: Dictionary in [first, second]:
			sample.fire_projectile("bullet", "player", component.position, component.position + Vector3.UP, 5)
		for shot: Dictionary in sample.projectiles:
			shot.velocity = Vector3.ZERO
		sample._update_projectiles(0.01)
	check(cached.snapshot() == reference.snapshot(), "Next bullet sees the boss phase exposed by an earlier hit in the same tick")
	check(cached.drain_events() == reference.drain_events(), "Boss transition event order stays unchanged")
	check(cached.enemies[0].phase == 1 and cached.enemies[0].components.any(func(c: Dictionary) -> bool: return c.phase == 1 and c.hp < c.max_hp), "The phase transition fixture actually damages a newly exposed component")

	var vehicle := Node3D.new()
	root.add_child(vehicle)
	var runtime := Runtime.new()
	root.add_child(runtime)
	runtime.set_physics_process(false)
	var view := CombatView.new()
	root.add_child(view)
	view.setup(runtime, vehicle)
	check(not view._pools.has("projectile_enemy_bullet"), "NPC bullet bodies have no render pool")
	check(not Visuals.model_id({"team": "enemy", "kind": "rocket"}).is_empty(), "NPC rockets remain visible")
	check(not Visuals.model_id({"team": "enemy", "kind": "grenade"}).is_empty(), "NPC grenades remain visible")
	var shot_model = runtime.model
	shot_model.running = true
	shot_model.player.position = Vector3(0, 0, 5)
	shot_model.fire_projectile("bullet", "enemy", Vector3(0, 2.2, -10), Vector3(0, 2.2, 10), 5)
	var id: int = shot_model.projectiles[0].id
	view.apply_state(shot_model.snapshot())
	check(not view._projectile_age.has(id), "NPC bullet does not allocate model animation state")
	view._effects.sync_state(shot_model.snapshot(), 0.01)
	check(not view._effects._trail_timers.has(id), "NPC bullet creates no second particle trail")
	var hp: float = shot_model.player.hp
	shot_model._update_projectiles(0.2)
	for event: Dictionary in shot_model.drain_events():
		view.on_event(event)
	check(shot_model.player.hp < hp, "Tracer-only NPC bullets still collide and deal damage")
	check(view.tracers.ages.enemy.any(func(age: float) -> bool: return age > 0), "Impact in one tick still leaves a visible enemy tracer")

	var pool := Source.create_pool("projectile_bullet", 8)
	root.add_child(pool.root)
	check(pool.batches[0].mesh.visible_instance_count == 0, "Empty pool submits zero instances")
	Source.set_pool_instance(pool, 0, Transform3D.IDENTITY)
	Source.set_pool_instance(pool, 1, Transform3D.IDENTITY)
	check(pool.batches[0].mesh.visible_instance_count == 2, "Only active prefix is submitted")
	Source.set_pool_visible_count(pool, 1)
	check(pool.batches[0].mesh.visible_instance_count == 1, "Shrinking active count removes stale GPU instances")
	Source.hide_pool_instance(pool, 0)
	check(pool.batches[0].mesh.visible_instance_count == 0, "Hiding warmup instance restores zero count")
	for node in [pool.root, view, runtime, vehicle]:
		node.queue_free()
	await process_frame
	print("Combat optimization: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

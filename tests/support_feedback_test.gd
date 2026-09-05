extends SceneTree
const Effects = preload("res://presentation/combat/impact_effects.gd")
const Activity = preload("res://presentation/world/activity_view.gd")
const Flare = preload("res://presentation/world/airdrop_flare_smoke.gd")
const World = preload("res://modules/world/world_runtime.gd")
const Vehicle = preload("res://modules/caravan/vehicle_controller.gd")
const Combat = preload("res://modules/combat/combat_runtime.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	preload("res://app/input_actions.gd").register()
	var vehicle := Vehicle.new()
	root.add_child(vehicle)
	vehicle.set_physics_process(false)
	vehicle.position = Vector3(2, 0, 0)
	var combat := Combat.new()
	root.add_child(combat)
	combat.setup(vehicle)
	combat.set_physics_process(false)
	var world := World.new()
	root.add_child(world)
	world.vehicle = vehicle
	world.combat = combat
	world.support.setup(world)
	world.support.reset(47)
	var effects := Effects.new()
	root.add_child(effects)
	effects.set_process(false)
	effects.player_view = vehicle
	var activity := Activity.new()
	root.add_child(activity)
	activity.set_process(false)
	var pickup: Node3D = effects.support_pickup
	var node_count := pickup.get_child_count()
	var drop: Dictionary = world.support.spawn_airdrop(Vector3.ZERO)
	drop.landed = true
	drop.height = 0
	drop.yaw = 0.7
	var coins: int = combat.model.player.coins
	world.support._update_airdrops(0)
	var claims := world.support.events.filter(func(event: Dictionary) -> bool: return event.kind == "airdrop_claimed")
	check(claims.size() == 1 and world.support.airdrops.is_empty(), "Actual claim removes airdrop and emits one event")
	check(combat.model.player.coins == coins + 28, "Animation preserves actual level one salvage reward")
	check(claims[0].target_position == vehicle.global_position and claims[0].yaw == 0.7, "Claim captures collector and source orientation before deletion")
	effects.on_world_event(claims[0])
	activity.apply_state({"support": {"airdrops": [], "heal_carts": []}})
	check(pickup.active_count() == 1 and pickup.entries[0].visual.visible, "Claim ghost survives empty activity snapshot")
	var entry: Dictionary = pickup.entries[0]
	var ghost: Node3D = entry.models.airdrop
	check(ghost.visible and not entry.models.heal_cart.visible, "Airdrop claim uses crate ghost")
	check(ghost.position.is_equal_approx(Vector3.ZERO) and is_equal_approx(ghost.rotation.y, 0.7), "Crate animation starts at claimed pose")
	for part: MeshInstance3D in ghost.get_children():
		var material: StandardMaterial3D = part.material_override
		check(not material.no_depth_test and material.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED, "Pickup translucent model retains actor depth testing")
		for binding: Dictionary in part.get_meta("source_part").bindings:
			if str(binding.role).begins_with("airdrop_"):
				check(not part.visible, "Claim clone omits canopy and source ground/flare decorations")
	effects.on_world_event(claims[0])
	check(pickup.active_count() == 1, "Duplicate airdrop event does not replay ghost")
	effects.advance_cinematic(0.4)
	check(ghost.position.y > 1.5 and ghost.scale.x < 0.8 and ghost.scale.x > 0.05, "Claim visibly lifts and shrinks through its middle")
	var frozen := ghost.transform
	effects.advance_cinematic(0)
	check(ghost.transform == frozen, "Zero simulation delta freezes claim animation")
	var cursor_before: int = pickup.cursor
	effects.set_warmup_visible(true)
	effects.on_world_event({"kind": "airdrop_claimed", "id": 999})
	effects.advance_cinematic(0.4)
	check(pickup.cursor == cursor_before and ghost.transform == frozen, "Warmup advances neither claim queue nor live ghost")
	check(pickup._preview.visible and pickup._preview.get_child_count() == 3, "Dedicated warmup exposes both ghost models and mote material")
	effects.set_warmup_visible(false)
	check(not pickup._preview.visible and ghost.transform == frozen, "Warmup preview hides without consuming animation")
	vehicle.position.x = 5
	effects.advance_cinematic(0.5)
	check(ghost.position.x > 4.7, "Claim follows collector as vehicle moves")
	effects.advance_cinematic(0.1)
	check(pickup.active_count() == 0 and not entry.visual.visible, "Completed pickup retires independently of removed actor")
	vehicle.position.x = 2
	vehicle.health = 20
	var cart: Dictionary = world.support.spawn_healer(Vector3.ZERO)
	world.support._update_healers(0)
	claims = world.support.events.filter(func(event: Dictionary) -> bool: return event.kind == "healer_claimed")
	check(claims.size() == 1 and world.support.heal_carts.is_empty() and vehicle.health == 115, "Actual support claim heals once and removes car")
	effects.on_world_event(claims[0])
	check(pickup.active_count() == 1 and pickup.entries[1].models.heal_cart.visible, "Support claim dispatches independent car animation")
	check(is_equal_approx(pickup.entries[1].models.heal_cart.rotation.y, cart.yaw), "Support car lift preserves its final heading")
	world.support._update_healers(0)
	check(world.support.events.filter(func(event: Dictionary) -> bool: return event.kind == "healer_claimed").size() == 1, "Support collection emits no second reward event")
	for id in 30:
		pickup.spawn({"kind": "airdrop_claimed", "id": 100 + id, "position": Vector3.ZERO})
	check(pickup.active_count() == pickup.CAPACITY and pickup.entries.size() == 4, "Burst collection remains bounded to four animation slots")
	check(pickup.get_child_count() == node_count and pickup._seen.size() <= 16, "Claims allocate no additional scene nodes and dedupe history is bounded")
	effects.reset_effects()
	check(pickup.active_count() == 0 and pickup._seen.is_empty(), "Restart clears pickup slots and previous run identities")
	check(pickup.spawn({"kind": "airdrop_claimed", "id": 100}), "Reset permits reused new-run claim IDs")
	effects.reset_effects()
	var smoke: Node3D = activity._flare_smoke
	var plume_count := smoke.get_child_count()
	var state := {"game_time": 2.0, "support": {"airdrops": [{"id": 42, "position": Vector3(5, 0, 8), "height": 12.0, "landed": false, "yaw": 0.0}], "heal_carts": []}}
	activity.apply_state(state)
	check(smoke.visible and smoke.plumes.size() == 12, "Flying airdrop has bounded twelve-plume smoke trail")
	for plume: MeshInstance3D in smoke.plumes:
		check(plume.position.y >= 15.55 and plume.position.y < 22.1, "Descending flare smoke remains airborne above crate")
		check(plume.material_override.get_shader_parameter("uColor").is_equal_approx(Vector3(Flare.RED.r, Flare.RED.g, Flare.RED.b)), "Descending flare smoke is red")
		check(plume.material_override.render_priority == 0 and not plume.material_override.shader.code.contains("depth_test_disabled"), "Smoke uses normal depth tested transparency")
	state.support.airdrops[0].height = 0
	state.support.airdrops[0].landed = true
	activity.apply_state(state)
	check(activity._flare_light.visible and activity._flare_light.light_color == Flare.GREEN, "Landed collectible flare glows green")
	for plume: MeshInstance3D in smoke.plumes:
		check(plume.material_override.get_shader_parameter("uColor").is_equal_approx(Vector3(Flare.GREEN.r, Flare.GREEN.g, Flare.GREEN.b)), "Landed plume palette switches green")
	var plume_pose: Transform3D = smoke.plumes[0].transform
	var plume_time: float = smoke.plumes[0].material_override.get_shader_parameter("uTime")
	activity.process_mode = Node.PROCESS_MODE_PAUSABLE
	activity.set_process(true)
	paused = true
	await process_frame
	await process_frame
	check(smoke.plumes[0].transform == plume_pose and smoke.plumes[0].material_override.get_shader_parameter("uTime") == plume_time, "Scene pause freezes real activity smoke process")
	activity.set_process(false)
	paused = false
	activity.set_warmup_visible(true)
	activity.set_warmup_visible(false)
	check(smoke.plumes[0].transform == plume_pose and state.support.airdrops.size() == 1, "Flare warmup restores active drop pose and leaves state intact")
	activity.apply_state({"support": {"airdrops": [], "heal_carts": []}})
	check(not smoke.visible and not activity._flare_light.visible, "Claim/reset removes standing flare smoke and light")
	for index in 30:
		activity.apply_state(state)
	check(smoke.get_child_count() == plume_count, "Repeated smoke snapshots reuse all preallocated plume nodes")
	for node in [activity, effects, world, combat, vehicle]:
		node.queue_free()
	await process_frame
	print("Support feedback tests: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

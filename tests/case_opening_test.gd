extends SceneTree

const Main = preload("res://app/main.tscn")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _key(game: Node, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	game._input(event)

func _run() -> void:
	var game = Main.instantiate()
	game.profile_path = "/private/tmp/case-opening-%d.json" % Time.get_ticks_usec()
	game.run_seed_override = 72841
	root.add_child(game)
	await game.game_ready
	for node: Node in [game, game.session_flow, game.combat, game.world, game.vehicle]:
		node.set_physics_process(false)
	game.restart_run()
	await game.run_prepared
	for index in 60:
		game.session_flow.advance(0.05)
	game.combat.model.enemies.clear()
	game.combat.model.spawn_queue.clear()
	game.combat.model.player.pending_upgrades = 0
	var support = game.world.support
	support.airdrops.clear()
	support.heal_carts.clear()
	support.events.clear()
	var drop: Dictionary = support.spawn_airdrop(game.vehicle.global_position)
	drop.landed = true
	drop.height = 0
	support._update_airdrops(0)
	var claims: Array = support.drain_events().filter(func(event: Dictionary) -> bool: return event.kind == "airdrop_claimed")
	check(claims.size() == 1, "Real proximity pickup produces one reward receipt")
	var receipt: Dictionary = claims[0].case
	game._on_world_event(claims[0])
	game._on_world_event(claims[0])
	await process_frame
	check(game.screen_state == "case_opening" and paused, "Real world reward event opens a paused modal")
	check(game.session_flow.clock.phase == "paused", "Reward screen pauses the authoritative run clock")
	check(not game.world.running and not game.combat.model.running, "Enemies and world stop during the opening")
	var panel = game.case_flow.panel
	panel.set_process(false)
	check(panel.reward_name({"kind": "fuel", "amount": 0.5}).ends_with("+0.5"), "Fractional fuel reward is not rounded to a different award")
	check(panel.reward.selected == receipt.selected and panel.reward.pool == receipt.pool, "Visible pool and winner exactly match the awarded domain receipt")
	check(game.case_flow.pending.is_empty(), "Duplicate events cannot queue a second case")
	var coins: int = game.combat.model.player.coins
	var unlocks: Array = game.combat.model.player.unlocked_weapons.duplicate()
	_key(game, KEY_J)
	check(game.screen_state == "case_opening", "Crew shortcut cannot interrupt the reveal")
	panel.advance(1.5)
	check(not panel.revealed and panel.strip.position.x < 0, "Reward reel moves before decelerating to the winner")
	_key(game, KEY_ENTER)
	check(panel.revealed and game.screen_state == "case_opening", "Enter skips animation without skipping the reward result")
	var center: float = panel.strip.position.x + panel.WINNER_INDEX * (panel.CARD_WIDTH + panel.CARD_GAP) + panel.CARD_WIDTH * 0.5
	check(is_equal_approx(center, panel.window.size.x * 0.5), "Awarded card lands exactly at center marker")
	check(game.combat.model.player.coins == coins and game.combat.model.player.unlocked_weapons == unlocks, "Reveal cannot reroll or re-award rewards")
	game.vehicle.health = game.vehicle.max_health
	support.spawn_healer(game.vehicle.global_position)
	support._update_healers(0)
	var cars: Array = support.drain_events().filter(func(event: Dictionary) -> bool: return event.kind == "healer_claimed")
	check(cars.size() == 1, "Full-health resource vehicle is still collectible")
	game._on_world_event(cars[0])
	await process_frame
	check(game.case_flow.pending.size() == 1, "Same-frame second pickup waits behind current case")
	panel.button.pressed.emit()
	check(panel.visible and panel.reward.source == "resource_car" and not panel.revealed, "Continue opens queued resource case without resuming combat")
	panel.advance(4)
	check(panel.revealed, "Automatic animation finishes without input")
	_key(game, KEY_ESCAPE)
	check(game.screen_state == "running" and not paused, "Escape from result resumes the game after the queue drains")
	game.case_flow.enqueue(claims[0])
	await process_frame
	check(game.screen_state == "running", "Seen receipt cannot replay after closing")
	game._set_screen("loading")
	check(game.case_flow.seen.is_empty() and not panel.visible, "New run clears receipt history and modal")
	game.queue_free()
	await process_frame
	print("Case opening tests: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

# Progression implementation and validation

Implemented in focused modules:

- `modules/progression/progression.gd`: source module purchases, blueprint unlocks, replacement/refunds, weapon/core/draft upgrade sequence, trailer mounts, passive repair, shop view models and session orchestration.
- `modules/progression/upgrade_rules.gd`: all 17 trait effects, 3 core tracks, weapon upgrade formulas, 6 protocol prerequisites and 4 sidegrade tuning transforms.
- `modules/progression/contract_progress.gd`: all 6 contracts, run/lifetime counters, event deduplication, rewards and run resets.
- `infrastructure/persistence/profile_store.gd`: bounded version-1 local profile, version-0 migration, corruption recovery, future-version read-only mode, temporary-write/flush/atomic-rename, failed-save status and retry.

Source references: `src/client/contexts/caravan/{catalog,index,vehicle-upgrades,carrier-catalog,build-layout,build-rules,movement}.ts`; `src/client/contexts/progression/{contracts,sidegrades,index,profile-repository}.ts`.

Runtime API: construct `Progression.new(optional_profile_path)`, then `setup(model)`. Call `begin_run()` when the user starts, `reset_run()` after resetting combat, `step(delta)` for progression and save timers, `on_combat_event(event)` for combat/world records, `buy_upgrade(action_id)` for purchases/current choices, and `flush()` at close. Profile paths are injectable; tests exclusively use unique `/private/tmp` files.

`get_shop_state()` returns `modules`, `weapons`, `choices`, `trailer`, `protocols`, `contracts`, `sidegrades`, `pending_upgrades`, `choice_stage`, `storage_status`, `dirty`. Rows provide `id`, `label`, `description`, `cost`, `enabled`, `disabled_reason`. Contract rows additionally expose selected/completed/progress/target/reward; sidegrades bucket/selected. No invented purchasable blueprints or paid core upgrades: original level-up grants a free core choice followed by one draft choice. Non-purchasable passives remain draft rewards. Pause simulation while `pending_upgrades > 0`, but continue progression save timers when possible.

The initial model stays 250 HP, 35 coins, level 1, XP threshold 70, M4 installed, total weight 12. XP thresholds use `floor(previous * 1.46 + 40)`, with +24 max HP/heal42 per level. Weapon buy cost is `18 + round(weight * 4)`, upgrade cost `22 + level * 18`, removal refund `max(4, round((18 + level * 9) * .4))`. Last weapon removal and duplicate weapons are blocked. Mounts use trailer-first allocation and bumper-only crawler slot12. Trailer cost90, +8 weight, *1.12 fuel burn, levels2/4, cap2. Every source trait mutation is implemented without changing base tuning.

Headless test: `Godot --headless --path GODOT_ROOT --log-file /private/tmp/godot-progression-test.log --script res://tests/progression_test.gd`: **66/66 assertions pass**. Covers source costs/formulas/XP batches, all17 traits, capacities/refunds/trailers, prerequisites/tuning, all6 contract outcomes, event duplication/stale generations, restart rearming, atomic reload, corrupt and future files, and unavailable save paths. Godot emits a macOS system certificate lookup error in this headless environment; tests themselves finish with exit0.

Integration boundaries and remaining parity work:

- Combat must consume `player.active_protocols`, `selected_sidegrades`, and `treasury_count`. This module validates/stores choices; actual mark/chain/interrupt/bonus-shot effects and sidegrade projectile effects belong to combat. `upgrade_rules.sidegrade_tuning()` provides the exact range/damage/blast/pierce/slow values.
- Original salvage bonus is `coin_mult * 1.15 ** treasury_count`, except Salvage Loop removes the locker bonus. Combat owns pickup amount/XP and this multiplier.
- Workshop repair is implemented here: 2 HP per installed workshop every4s. Combat already owns low-health regen, emergency armor and ability cooldowns; avoid duplicate application.
- Sidegrade unlocks/contracts/settings persist. Selected run sidegrades are intentionally session configuration as in the source profile schema; they are copied into `player.selected_sidegrades` when starting a run.
- Contract IDs are accepted from world `activity_completed` events with `id`, `activity_type`, `weather`; combat events use `kind`, `generation`, and source-specific fields. Foundry kills only count when type is `garrison`.
- Draft categories, eligibility, caps and 72% blueprint probability follow source. Godot uses seeded Fisher-Yates shuffle instead of JavaScript random sort; exact offer order for a shared numeric seed is not yet cross-engine equivalent.
- Source armory before/after delta formatting, evolution/trailer animation, detailed protocol cues, persisted sound routing and rendered UI interaction still require integration verification. This document does not claim visual parity.
- Browser multi-tab durable-profile reconciliation is not implemented; the offline Godot app uses one atomic local file. A second concurrent Godot process writing the same profile is not currently merged.

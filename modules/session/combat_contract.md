# Offline combat integration

`modules/combat/combat_runtime.gd` extends Node3D, processes only while `model.running`, uses PROCESS_MODE_PAUSABLE. Construct and add as a child before `setup(vehicle)`. Initial/reset state does not simulate until `set_running(true)`.

Public API:
- `setup(vehicle: CharacterBody3D)` expects current vehicle_controller.gd properties and methods.
- `reset_run(seed_value = 72841)` clears every entity, reward, cooldown, focus and weapon upgrade; restores source player defaults; resets vehicle. Then call set_running(true) when ready.
- `set_running(bool)`, `get_state()`, `focus_next()`, `focus_at(Vector3)`.
- `activate_ability(slot)` returns bool. Source slots: 0 Nitro, 1 Ram, 2 Repair.
- `install_weapon(type)`: low-level construction from data/game_catalogs.json; capacity, duplicates, price and unlock checks belong to progression.
- `apply_player_stats(Dictionary)`: updates existing snake_case player fields and syncs vehicle health/fuel.
- `progression`: optional RefCounted implementing buy_upgrade(id); runtime delegates buy_upgrade(id) to it.
- `model.player`, `model.weapons` are the mutable progression integration points. Weapon shape: `{type, level, cooldown, def}`. def copies original camelCase catalog values.

Signals: `state_changed(data: Dictionary)` every active physics tick, `combat_event(event: Dictionary)`.
Snapshots include generation, wave, final_wave, status/phase, elapsed, intermission, safe_radius, remaining, kills, scrap/coins, health/max_health, level/xp/xp_next, focus_id, player, weapons, enemies, projectiles, pickups. Arrays are copies.
Enemy fields: id/type/kind, position Vector3, x/z, yaw, velocity, hp/max_hp, dead, hit_time. Drone position is ground-plane position; `height` is flight height. Boss kind leviathan/type keep, phase0/1/2, components array with exact component HP and phase.
Projectile fields: id/kind/team, position/previous/velocity Vector3, target, radius, damage, life. Pickup: id/kind, position, value, life.
Events discriminator is `kind`: spawn/death/shot/hit/pickup/result, plus player_hit/explosion/wave/wave_cleared/boss_phase/telegraph/ability. All contain generation and applicable id, position, type. Shot projectile name is projectile_kind. Pickup discriminator is pickup_kind. Result includes won,wave,kills,elapsed.

## Verified ported portion

Six source wave compositions, 0.45 second spawning, 5 second intermission, 1248 maximum world radius with area fraction scaling; source soldier/drone/bike/buggy health/speed/ranges/damage/cadence; all seven original gun definitions and ballistic projectile speeds/gravity; swept collision, explosive falloff; source salvage/fuel drop probabilities and values, pull radius/expiry, exact-once collection; source armor and low-HP traits, counter-drone jammer cadence/detonation suppression; dead/win stop; reset; focus; abilities. Boss component HP gates and original missile/gun attack values, core 0.9 second telegraph and 8 radial+5 aimed rocket volley.

## Explicit remaining fidelity gaps

- Enemy obstacle navigation and projectile collision with world objects are not connected. Current simulation follows/retreats directly in ground plane. Source vehicle steering/orbit paths and drone evasion are not ported.
- Boss uses one parent target; damage selects first living exposed component. Distinct component target selection, source local offsets and phase visual destruction need implementation.
- Player ramming currently uses a simplified collision impulse damage model; full Road Fury, facing/ram shove, source contact hull geometry and small/large distinctions need porting.
- Nitro and ram timers exist; driver must consume them via motion tuning. Runtime does not independently modify vehicle velocity.
- Progression must consume collected XP to perform level ups, choices and evolution; it also owns passive repair, traits, weapon upgrade pricing and capacity.
- Keeps, garrisons, priority vehicles, director/encounters, mine hacking, tornado, weather, blast/world destruction, weapon sidegrades/synergies are not implemented in this model yet.
- No visual parity claim is made by these tests.

Test command: Godot --headless --path PROJECT --script res://tests/combat_test.gd --log-file /private/tmp/iron-caravan-combat-tests.log
Result: 35/35 assertions passed (including source numeric values, auto-fire kill chain, duplicate rewards, reset, focus, swept collision, death, next wave, final boss phase gates, capacity, ability semantics, runtime loading).

## Advanced pass update

The advanced implementation and current remaining gaps are tracked in `docs/advanced-combat-parity.md`; its implemented items supersede corresponding entries in the earlier gap list above.

`spawn_enemy(kind, position, options = {})` supports regular `keep` and `garrison_1`/`garrison_2`/`garrison_3`. Options are merged before the spawn event. Set `counts_toward_wave: false` for world/roaming/activity NPCs. `activity_route_controlled: true` skips normal AI. `encounter_movement_multiplier` and `encounter_cadence_multiplier` default to one. `priority` affects auto-target selection; valid manual focus wins.

Advanced runtime fields: `player.active_protocols: Array`, `player.selected_sidegrades: Dictionary` keyed by module type, `player.treasury_count`, heading/yaw_velocity/slip_angle/handbraking/interact. Runtime samples hold-E for hacking. Post-collision model position/speed are synchronized back to the actual carrier.

Snapshot adds `mines`, `hack_status`, `salvage_charge`; player adds `road_fury_combo`, `road_fury_multiplier`, `momentum`. Mine fields: id, owner, position, arm_remaining, life, radius, damage, allegiance (`enemy`/`friendly`), hack_progress (0..3), armed, triggered, dead. Hack status: available, active, progress (0..1), mine_id. Events: `mine_drop`, `mine_hacked`, `mine_explosion` (id, position, optional radius), `conductor_arc` (position, target_position).

World collision remains `world_collision_query(shot) -> bool`; it may mutate shot.position to its contact point. The model clips the query segment at the next NPC intersection before calling it. Enemy-motion and spawn-validity callbacks retain their previous API.

`CombatRuntime.finish_run(won: bool, reason = "") -> bool` is the public external completion API. It emits the result immediately and once; reason `extracted` yields terminal status `extracted`. Result events include reason and extracted. Never mutate the event queue to tag a result.

## AI and component update

See `docs/enemy-ai-parity.md`. `weapon_origin_query(weapon) -> Vector3` returns the actual world muzzle including +0.6 world Y. `enemy_steering_query(enemy, desiredDirection, speed) -> Vector3` returns the desired navigation direction before actual movement. `spawn_visibility_query(point) -> bool` is optional and returns whether the point is outside the camera view.

Boss parent records stay in `enemies`, but are untargetable/undamageable. `boss_components` snapshot adds all five component records, also available in `parent.components`. Each has id, type `bossComponent`, is_component, parent_id, kind, phase, hp/max_hp, radius, position, velocity, exposed, targetable, dead. Focus IDs may refer to components. Parent/component records have no cyclic references. `boss_component_destroyed` event contains component id, parent_id, component_kind and position; it does not award a separate enemy kill. Only core death kills/rewards the parent.

Drone positions remain ground-plane positions; dynamic altitude is `height`, and visual bank is `roll`. Repair support emits `repair_pulse` and stores `repair_beam_target`. `snapshot.threat` follows the active source managed-wave formula. `player.jammed` reflects the living, uninterrupted Jammer Truck field for callers that explicitly create that dormant-source type.

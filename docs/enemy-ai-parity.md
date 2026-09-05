# Enemy AI and managed-wave parity

The second combat pass implements the source behavior in focused modules:

- `enemy_ai.gd`: infantry approach/retreat and heading smoothing, gated deployment interpolation, bomber contact detonation, bike/buggy steering and throttles, drone strafe/altitude/evasion, keep steering, exact shot origins/leading/cadence and contact damage. Ground AI consumes world steering before motion and collision resolution after motion.
- `drone_evasion.gd`: source seeded dodge sampling, bullet threat prediction, vertical miss checks, per-kind chance/reaction/cooldown/duration, persistent dodge direction, same-projectile reroll prevention.
- `priority_rules.gd`: source repair target selection, healing bounds and beam/pulse data, jammer radius/interruption semantics. Priority factories, one-per-kind cap and minelayer movement/drop logic exist for explicit callers. They are not injected into managed waves.
- `spawn_rules.gd`: infantry 62..92, other mobile NPCs 85..260, Leviathan 180..650 distance bands; 48 random placement attempts, source radial fallback searches, safe-radius margin, 0.25-second failed placement retry, 84 soldier/12 drone/10 vehicle caps. Optional visibility query receives the point and returns whether it is outside the view; world collision validation remains separate.
- `leviathan_rules.gd`: five individual component targets with exact source anchor transforms, radii, health and phases. Parent hull is untargetable and undamageable. Pod destruction exposes both drives; drives expose core; only core death rewards and kills the parent. Exposed components participate in auto-fire, direct projectile collision, splash, focus, and wet rail chains. Attacks use actual component origins. Core begins with 2.8-second cooldown, telegraphs for 0.9, then emits eight radial rockets and five aimed rockets only if the player is acquired.
- Actual player muzzle origins come from `weapon_origin_query(weapon)` including source `world UP * 0.6`, and weapon range is measured from the mount. Double-shot offsets follow carrier heading. Aim heights are separate from collision-center heights.

## Active behavior versus dormant source code

`src/client/contexts/combat/wave-lifecycle.ts:createWaveLifecycleState` unconditionally initializes `managed: true`. `director.ts:updateDirector` returns early for this mode, updating threat and boss flags without choosing pressure events. The managed queue explicitly contains infantry, drones, bikes/buggies and the final-wave Leviathan. Repository search found no assignment setting managed false. The migrated run therefore preserves these six managed waves and their threat calculation. It does not enable the legacy pressure/recovery director, mandatory crawler sequence or priority spawn selection on top of the active mode.

The priority vehicle constructors/support code remain callable and tested because they are part of the original catalog. Their natural pressure-director spawns and Jammer Rocket deflection/wobble/premature detonation are dormant in the active source mode. No new gameplay spawn path was invented to activate them.

## Verification

Godot 4.7.2 headless, clean logs:

- `tests/enemy_ai_test.gd`: 46/46 assertions, including exact movement/throttle numbers, steering callback, fog/contact behavior, predictive dodge, repair selection/rate, minelayer drops, jammer suppression, component gates/anchors/attacks/rewards, spawn bands/retry/caps, muzzle-range integration and pause.
- `tests/advanced_combat_test.gd`: 103/103.
- `tests/combat_test.gd`: 35/35; the old parent-damage test now explicitly rejects hull damage and destroys individual components.
- `tests/integration_test.gd`: 16/16.
- `tests/world_gameplay_test.gd`: 39/39.

This validates the model and integration. Rendered animation, component mesh visibility and audio matching belong to the presentation checks.

## Remaining exactness boundaries

The optional offscreen spawn visibility query is not intrinsically a camera projection in the model; a presentation caller must supply it. The injected random generator is Godot's generator, not a source-JavaScript random-stream replay. Aggregate entity/projectile/pickup limits remain bounded by the existing Godot pool budgets. Source screen-space focus picking remains different from ground-point selection unless presentation supplies that behavior. Protocol status cleanup after removing and re-adding prerequisite modules within a mark lifetime remains a reconciliation task. Dormant Jammer Rocket interference and the legacy pressure director are recorded above rather than enabled in the active run.

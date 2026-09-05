# Advanced offline combat, first verified pass

Implemented from the executable source rules, not the callback-free catalog alone:

- `sidegrade_rules.gd`: all four PvE variants, including exact tradeoffs, bucket validation, bounded slow, drone/boss/garrison control exclusions, and one additional pierced victim without repeat hits.
- `protocol_rules.gd`: six protocol effects. Charged ram breaches eligible heavy NPCs for six seconds; focus marks for eight seconds; explosive breach and direct missile/rail relay bonuses add. Ballistic suppression caps at five, expires after 2.5 seconds and grenades consume it for up to 0.65 seconds of interruption. Alternating families primes a three-second opportunity; the next opposite-family bonus uses the source base damage and cannot trigger synergies itself. Salvage Loop charges from raw salvage and heals 30 at 20 charge; treasury bonuses otherwise multiply by `1.15 ** treasury_count`. Wet rail impacts chain once to the nearest valid wet ground NPC within 14 units for 45% damage.
- `rocket_rules.gd`: original moving-carrier spread, seeded corkscrew profile, attack/decay and nitro influence. Tracking Rockets is a range/damage sidegrade in the source, not homing. Ballistic flight remains the source initial-aim trajectory.
- `road_fury_rules.gd`: source drift distance rewards, combo thresholds, grace/decay, near-miss rearm, small-NPC roadkills, bumper facing/charged damage, heavy contact damage, player speed retention and shove. Runtime synchronizes carrier heading, yaw, slip, handbrake, position and speed so these change actual driving.
- `mine_rules.gd`: bounded six-per-owner/36-global mine model; 0.9-second arm, 25-second life, 2.35 trigger radius, swept vehicle trigger, 30 damage; hold E within 4.5 units for three seconds, progress decays at twice that rate; friendly mine damages nearby NPCs once. Pause freezes hazards; death/reset clears them. Minelayer spawning remains in the next AI/director pass.
- Source regular keep and three garrison tiers can be spawned with options. Keep/garrison health, footprints, shot cadence/range and salvage drop counts/values are connected. Non-wave activities no longer prevent wave completion. Route-controlled entities skip normal AI. Foundry movement/cadence multiplier fields and priority-based targeting are consumed.
- Swept hit candidates are ordered by entry distance. World collision callbacks receive only the segment before the next entity, so a wall behind an NPC cannot consume a shot or take damage first. Piercing advances through the remaining segment with the same ordering.
- Low-health regeneration follows the source threshold check and then clamps to maximum HP, allowing a tick to cross 35% HP.

Sources: `src/client/contexts/combat/{combat-synergies,projectiles,rocket-flight,rocket-spread,rocket-motion,hazards,mine-hacking,enemy-system,spawning,damage,targeting,counter-drone-jammer}.ts`, `src/client/contexts/caravan/road-fury.ts`, `src/client/contexts/progression/sidegrades.ts`, `src/shared/{gameplay-weather,player-visual}.ts` in the original project.

## Verification

Godot 4.7.2 headless, stage workspace:

- `tests/advanced_combat_test.gd`: 103 assertions cover variant values/statuses, all six protocol interactions/expiry/consumption, actual projectile piercing and collision order, rocket bounds, Road Fury timing and charged impact numbers, mine hacking/trigger/lifetime/pause/reset, actual treasury collection, garrison/route/wave/overclock integration.
- `tests/combat_test.gd`: 35/35 original combat regressions.
- `tests/integration_test.gd`: 16/16 integration checks.
- `tests/world_gameplay_test.gd`: 39/39 world checks.

These are model and integration checks, not rendered visual/audio parity.

`CombatRuntime.finish_run(won, reason)` synchronizes and publishes external boundary/extraction results immediately and once. Extraction is a terminal status, cannot resume, and includes `reason`/`extracted` in the result event.

## Follow-up status

The source AI, predictive drone evasion, priority support, mount muzzle origins, source spawn bands and individual Leviathan component targeting were implemented in the second pass. See `docs/enemy-ai-parity.md` for the verified behavior, dormant director call path and remaining exactness boundaries. Mine state rendering, real component visibility, protocol removal cleanup, shared grown collision radius and nonlethal component/player APIs are now connected. See docs/presentation-parity.md for numerical animation/VFX evidence and remaining rendered boundaries.

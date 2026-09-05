# Offline feature parity ledger

Scope: transfer the complete local singleplayer game, including its visual details, to Godot. Multiplayer transport, remote players, PvP and server authority are excluded by the user's explicit offline scope. Singleplayer counterparts of shared systems remain required.

This is a source inventory, not a completion claim. A catalog export preserves data only. Every unchecked item below still requires Godot implementation verification and, where visual, rendered comparison. Existing driving prototype work is partial until compared against the original. No item becomes complete merely because a similarly named GDScript file exists.

## Evidence and repeatable extraction

`data/game_catalogs.json` is produced by `scripts/export_game_catalogs.mjs SOURCE_ROOT GODOT_ROOT`. The exporter bundles and evaluates the actual TypeScript exports. Each of 28 source modules has its path and SHA-256 recorded. It preserves 13 modules, 12 crawler mount positions, 17 level-up upgrades, 3 core tracks, Walker Trailer settings, 6 protocols, 4 infantry kinds, 2 drone kinds, priority vehicles, 4 sidegrades, 6 contracts, 6 evaluated wave compositions, and exported world/combat constants.

`_meta.omittedFunctions` explicitly lists 215 executable exports/callbacks not represented by JSON. In particular, level-up `apply`/`available` callbacks, core upgrade mutations, AI, random spawn construction, damage rules, event reducers and world generation require behavior ports. Exporting their descriptions is not an implementation. Private constants and numbers inside those functions require source inspection as well. Numeric JSON values are copied or computed by original functions, never estimated. Original icon strings remain source data; presentation can obey the user's no-emoji preference.

Top-level JSON keys: `modules`, `moduleSlots`, `levelUpgrades`, `coreUpgrades`, `carriers`, `protocols`, `moduleBuildProfiles`, `soldiers`, `drones`, `priorityVehicles`, `sidegrades`, `contracts`, `waves`, `constants`. Original camelCase fields are retained. Constants use their original export names under a source alias, for example `constants.hazards.MINE_DAMAGE`.

## Current implementation evidence, 2026-09-05

All new work below is in `/private/tmp/iron-caravan-full-cg8ddxzh`; the target project has not received this complete migration yet. Checkboxes represent the complete stated behavior including its remaining integration or visual detail. An unchecked compound item can have substantial implementation already delivered.

| Area | Concrete staged implementation | Automated evidence | Remaining acceptance |
|---|---|---|---|
| Native source world | generation context/layout/natural/authored/battlefield/scatter, generated world renderer, atomic arena rebinding | world_generation, natural_props, authored_props, world_builder, composed_world_seed tests; authored31187 clean assertions, full builder164286 reported clean | Real rendered original/Godot comparison and full rebuild final gate |
| Driving and build | shared motion port, vehicle controller/fuel, all module/core/trait/trailer rules and actual mounted models | vehicle_motion, progression, integration, ui_flow tests | Final animation, collision and balance playthrough |
| Local combat | managed six-wave queue, actual projectiles/damage/AI, five Leviathan component targets, protocols/sidegrades/mines | combat, advanced_combat, enemy_ai tests; reviewer combat_soak2872 clean assertions over1800 simulated seconds | Controlled full_run16 checks clean; actual player six-wave run still pending; source gameplay RNG stream differs |
| World gameplay | prop destruction/collision, weather/mud/lightning/tornado, fuel/boundary, source activities/support/extraction and village tribute/ambient | world_gameplay, world_activities, world_result, ambient tests | Tornado/lightning/debris visual exactness and random-call interleaving |
| Profile/UI/audio | versioned atomic profile, contracts/sidegrades, flat native armory preview/search, HUD/radar/touch/focus, source audio recipes | progression, presentation, ui_flow, integration tests | Audio event bridges/listening, rendered acceptance and export |
| Loading/resources | manifest validation, staged loading curtain, representative draw before simulation, bounded view pools | preparation/UI checks and headless integration | Cold first-use GPU profiling; headless is not GPU evidence |

`tests/run_all.py` is the explicit automated gate manifest. It rejects nonzero exit, engine/script error text and missing success summaries. A Godot process exiting0 with SCRIPT ERROR is a failure. Graphical reference captures and actual listening remain separate from headless checks.

## Reachable offline behavior versus dormant source systems

The current source unconditionally creates `waveLifecycle.managed=true` (`combat/wave-lifecycle.ts`). `director.ts:updateDirector` returns before pressure-event selection for this mode. No source assignment changing managed to false was found. Therefore pressure/recovery event spawning, mandatory crawler sequence and priority-vehicle director spawning are dormant in the actual original offline run. Their catalogs/rules are preserved and tested without introducing unsolicited extra spawns.

The same applies to Foundry Dispatch: `world-activity.ts:onTelegraphQueued` creates it only for `foundryReinforcement`; only the dormant director selects that event. `spawnFromGarrisons` has a definition/export but no client callsite. Initial10 foundries, their initial guards, shooting and sector overclock are reachable and remain required. An autonomous Godot foundry production loop found in review is being removed by its owner before final gate. Do not enable dormant behavior merely to check an inventory box.

Source profile persists unlocked sidegrades, contracts and sound settings; selected run sidegrades are session configuration, not a missing durable-profile field. The source has no separate shelter interaction, cache activity, guided-homing Tracking Rockets effect, or dedicated skid/rain sound loop. Use source callsites rather than inferred feature names.

## Local session timing evidence

`docs/session-flow-parity.md` records the reachable offline2.65-second3/2/1/GO intro, raw-weather versus eased gameplay clocks, hit-stop and2.4-second delayed local death result/camera/effects. Independent540-frame source fixtures and composed restart/input/death scenarios verify these behaviors. `run_prepared` means built and warmed; `run_ready` means intro finished. Camera/effects can continue while gameplay is paused without a global timescale hack.

## Concrete remaining detail audit

- Presentation pass is still active: actual exported articulation metadata must be consumed for infantry gait, crawler/trailer tracks/legs, turrets/recoil, original muzzle/trail origins, boss destroyed component visibility, wrecks, material debris/shockwaves and retained battlefield marks. Geometry export alone does not close these items.
- Weather still uses approximate Godot fog/sun/dust mapping. Tornado cinematic swallowing/camera dust, route-owned NPC displacement, camera-projected untargeted lightning, source bolt branching and thunder scheduling require comparison or a documented remaining difference.
- Reachable audio bridges were audited: low-health and actual contract completion/progress are now connected; generic menu contractProgress was removed. Source countdown and manual repair tones are separate from NPC repairPulse. Minor/major activity and thunder distance-delay routing are being completed by the audio owner. Prepared WAV files alone do not prove these routes or listening quality.
- Gameplay uses Godot combat RNG and separate source-style activity/ambient streams. Exact arbitrary-seed world layout/factory RNG is proven; complete original shared random-call interleaving and draft JavaScript random-sort ordering are not.
- Source numeric rules and callbacks are broadly implemented, but full rendered six-wave playthrough, cold first-shot/destruction/weather GPU times, long rendered FPS/memory and clean offline executable export remain open.

## Session, controls and vehicle

Sources: `src/client/contexts/session/index.ts`, `src/client/contexts/caravan/index.ts`, `movement.ts`, `road-fury.ts`, `vehicle-upgrades.ts`; `src/shared/vehicle-motion.ts`; `src/client/presentation/input-controller.ts`.

- [x] Start/load/countdown/run/pause/death/victory/restart transitions; stop gameplay during loading and menus.
- [ ] Exact initial player stats, currencies, experience, weapon selection and reset state.
- [x] Forward/reverse acceleration, top speed, steering, lateral grip, braking, handbrake/drift, weight effects and angle normalization.
- [ ] Nitro duration/cooldown/recovery, ram activation/cooldown, manual repair cost/power/cooldown and interaction controls.
- [ ] Fuel capacity 100, burn base 0.45/s, speed/throttle/trailer-dependent consumption, empty-fuel speed multiplier 0.35, fuel pickup 28, station radius 11 and refill 24/s.
- [ ] Road Fury drift distance/slip/speed qualification, near misses, roadkills, ordinary/charged rams, combo tiers, grace, momentum gain/decay and HUD feedback.
- [ ] Vehicle/environment/NPC collision, slide/shove/impact response and ram-specific damage resistance.
- [ ] Evolution models and exact module mounting through player levels.
- [ ] Keyboard/mouse focus and pointer-drag distinction; camera drag/zoom; blocked input/focus in paused or dead states.
- [ ] Touch steering/abilities and responsive layout if the Godot export supports mobile; no silent removal of original touch play.

## Armory and build progression

Sources: `src/client/contexts/caravan/{catalog,carrier-catalog,build-layout,build-rules,vehicle-upgrades,index}.ts`; `src/client/presentation/{armory-ui,armory-catalog,progression-ui}.ts`; `src/client/presentation/components/armory-*`.

- [x] All weapons: M4 Turret (`assaultRifle`), AK Battle Station, Bazooka Pod, Grenade Launcher, M134 Minigun, Coil Railgun, Guided Missile Rack. Preserve costs, weight, rate, range, damage and max level.
- [x] All passives: Field Repair Bay, Composite Armor, Logistics Locker, Assault Ram, Radar Array, Counter-Drone Jammer; uniqueness and purchase requirements.
- [ ] Install/replace/remove/refund weapons, replacement cursor, unavailable/insufficient-currency feedback and original slot allocation.
- [x] Crawler weapon capacity 4 to 6; Expanded Weapon Rack level gates 2 and 4; equipment capacity distinct from weapon capacity.
- [ ] Two Walker Trailers, three mounts each, level gates 2/4, cost 90, weight 8 and 12% fuel penalty each; attachment, walking animation and trailer-targeted mount origin.
- [x] Core Motor/Armor/Fuel upgrades, five levels, exact mutations/caps and before/after previews.
- [x] Weapon upgrade formula: damage rounded from damage * 1.24 + 1, range * 1.07, cooldown max(0.22, cooldown * 0.9), max-level restrictions.
- [ ] XP thresholds, leveling, pending-choice batches, guaranteed early mobility options, random rarity/eligibility and exactly-once choice commits.
- [x] All 17 upgrades: High-Flow Turbo, Racing Transmission, Nitro Calibration, Reinforced Core, Salvage Chains, Combat Engineer, Layered Plating, Salvage Rush, Plow Momentum, Fire Control Officer, Overdrive Feed, Targeting Computer, Emergency Nanoweld, Twin Feed Mechanism, Pressure Recovery, Fire Suppression, Expanded Weapon Rack.
- [ ] Armory filters/search, equipment and core details, actual 3D previews, purchase/upgrade results, selected/installed/locked/max-level states.

## Combat, targeting and interactions

Sources: `src/client/contexts/combat/{index,damage,blast-damage,projectiles,targeting,rocket-flight,rocket-motion,rocket-spread,combat-synergies,counter-drone-jammer,jammer-rocket,mine-hacking,hazards}.ts`; `src/client/infrastructure/three/weapon-aim.ts`.

- [ ] Automatic target selection, focus override, priority scoring, range acquisition and target validity.
- [ ] Weapon-specific target height, aiming, turret traverse, muzzle origin, recoil and cooldown; source-correct moving muzzle/projectile alignment.
- [ ] Bullets, arcing grenades, ballistic/direct/guided rockets, sabot piercing; trajectory, speed, gravity/arc, spread, hit radius, lifetime and impact.
- [x] Direct and splash damage, team/source ownership, per-target explosion deduplication, armor and boss-component restrictions.
- [ ] Death/reward attribution; XP/salvage/coin multiplier, pickup lifetime, attraction/collection and salvage repair; no duplicate rewards.
- [ ] Health regeneration/repair, emergency armor, overdrive feed, double shots and status expiry.
- [ ] Enemy jammer range loss, radar/UI interference and rocket deflection/instability/early detonation with original tuning.
- [x] Counter-drone jammer from its actual carrier: 32m radius, movement/fire cadence 55%, kamikaze detonation blocked.
- [x] Mine deployment, arming 0.9s, lifetime 25s, segment crossing, trigger radius 2.35, damage 30, global/per-owner limits.
- [x] Mine hacking at 4.5m for 3s, interruption decay and friendly/hacked mine target filtering.
- [ ] Six selectable protocols, prerequisites and deactivation when required modules disappear.
- [x] Breach Crew: charged ram mark, 6s expiry, next qualifying explosive consumes +35% damage.
- [x] Target Relay: focus mark, 8s expiry, direct railgun/missile hit consumes +40% damage.
- [x] Salvage Loop: 20 reserve, 30 repair, locker-value replacement and full-health behavior.
- [x] Suppression Cycle: ballistic stacks capped at 5, 2.5s expiry, grenade consumption and interruption.
- [x] Combined Feed: alternating families within 4s, one opportunity expiring after 3s and reduced bonus-shot rules.
- [x] Storm Conductor: wet-target rail hit, one nearest valid wet target within 14m, 45% chain damage.

## Enemies, director and bosses

Sources: `src/client/contexts/combat/{enemy-system,enemy-semantics,spawning,director,priority-vehicles,garrison-tuning,leviathan,encounter-effects,encounter-lifecycle,spawn-telegraphs,drone-evasion,wave-lifecycle,wave-entity-cleanup,state}.ts`; `src/shared/wave-progression.ts`.

- [ ] Infantry rifleman, AK, bazooka and armored bomber/juggernaut: exact health, speed, damage, attack cadence, armor, pursuit, attacks and death behavior.
- [ ] Bikes/motorcycles and buggies: road/terrain motion, collision, attacks, mine payload and caps.
- [ ] Shooter and kamikaze drones: orbit/preferred ranges, altitude, flight banking, evasion, shots/detonation, jammer and weather interactions.
- [ ] Priority jammer and repair vehicles: uniqueness/caps, target priority, repair target selection/range/rate/rechecks and range-jamming sectors.
- [ ] Raider foundries/garrisons: tiers, model footprint, HP, gate reinforcement deployment, control radius, allied speed/cadence bonus and pressure capacity.
- [ ] Enemy crawler/mobile fortress (`keep`): movement, subordinate spawning, gate/anchor safety, pressure reservation, weapon behavior and destruction lifecycle.
- [ ] Leviathan: missile pod, gun pod, left/right drives and core; component HP, phase locks, targetability, movement reduction, opening exposed core and death.
- [ ] Leviathan attack telegraphs and core radial/aimed volleys; correct component aim/collision/health display.
- [ ] Dormant source rules, not active managed-run spawning: director pressure/recovery phases, health mercy, enemy family unlocks, weighted events, cooldowns, boss reserves and hard population limits.
- [ ] Offscreen spawns with minimum safety distances, arena/rock constraints, bounded retries and failed-placement rollback.
- [ ] Spawn telegraphs: ordinary 1.5–2s, crawler 3s, Leviathan 5s, intrusion grace and committed placement.
- [x] Six waves with exact composition from JSON, area expansion by square-root area fraction, intermission 5s, spawn pacing 0.45s and clear grace.
- [ ] Final-wave boss accounting, cleanup of mines/projectiles/transients, defeat/victory transitions and completion rewards.

## World, weather and activities

Sources: `src/shared/{world-layout,world-collision-manifest,world-boundary,gameplay-weather}.ts`; `src/client/core/world-generation.ts`; `src/client/contexts/world/*`; `src/client/contexts/combat/{combat-weather,tornado}.ts`; `src/client/infrastructure/three/{world-builder,road-network,terrain-surface}.ts`.

- [ ] Seeded world generation/map name, terrain palette/height, procedural roads, intersections and unobstructed road centers.
- [ ] Settlements/villages, buildings, monuments, landmarks, fuel stations, rocks, vegetation, debris and props with original placement density/variation.
- [ ] Playable radius 1248, outer simulation 1648, wave-specific safe area and 15s outside-boundary grace/countdown/reset/death behavior.
- [ ] Spatial collision/steering for rocks and structures; destructible prop durability, projectile/blast/ram damage, breakage, rubble and rewards.
- [ ] Clear/sunny/foggy/rainy/storm schedule, transitions, phase lengths 120–180s and seeded lightning sampling.
- [x] Fog acquisition penalties and radar mitigation; rain/storm wetness retained 6s; flying-vs-ground susceptibility.
- [ ] Mud zones: radius 5, duration 14s, max 10, movement 0.62, turning 0.55; terrain marks and no first-use shader hitch.
- [ ] Rare nonlethal lightning, warning/strike, radius, target probabilities, ground impacts and NPC/player damage boundaries.
- [ ] Tornado seeded path, fade, influence/danger/dust radii, pull/lift/spin/kill restrictions, vulnerable NPC types and camera dust effect.
- [ ] Ambient figures/animals/scavengers, threat avoidance, weather shelter/behavior and world activity presentation.
- [ ] Activity scheduler limits (1 major, 2 minor), seed independence, announcement, expiry/recovery, placement safety and completion.
- [ ] Raider Supply Convoy: road route, formation, escorts, interception, expiry and reward.
- [ ] Settlement Distress: village validity, raider deployment, defeat/failure and reward.
- [ ] Dormant source event: Foundry Dispatch source validity, reinforcement interception, expiry and reward.
- [ ] Scavenger Route minor activity, route interaction and reward.
- [ ] Activity credits and settlement extraction: 2 credits, stationary activation, 30s secure, hostile contest, departure grace and destroyed-site failure.
- [ ] Extraction outcome distinct from final-wave victory and ordinary death; event/progression reporting.

## Durable offline progression

Sources: `src/client/contexts/progression/{contracts,sidegrades,index,profile-repository}.ts`; `src/client/presentation/{progression-ui,profile-lifecycle}.ts`.

- [ ] Local profile schema/defaults/normalization, persistence, corruption recovery, debounced save/retry and visible storage errors.
- [x] Select up to three contracts; run-scoped vs lifetime counters and restart/session boundaries.
- [x] Break the Line, Answer the Call, Mixed Battery, Keep the Powder Dry, Bad Weather Work and Combined Arms conditions/rewards.
- [x] Exactly-once run/entity/activity events, weapon-family set and completion/unlock notices.
- [x] Fragmentation Shells (+30% blast/-18% range), Penetrator Sabots (+1 pierce/-20% damage), Concussion Rounds (25% slow 1.5s/-18% damage), Tracking Rockets (+20% range/-15% damage).
- [ ] Sidegrade unlocks, selection bucket validation, equipped tuning, slowing/expiry and persistence across future runs.

## Presentation, sound and performance

Sources: `src/client/presentation/*`, `src/client/presentation/components/*`, `src/client/audio/sound-system.ts`, `src/client/infrastructure/three/*`, `src/client/infrastructure/assets/asset-manifest.ts`, `src/client/core/{loading-pipeline,frame-policy,performance-monitor}.ts`.

- [ ] Source crawler/evolution silhouette, layered armor, tracks, wheels, exhaust, lights, attachments, materials, colors and mounted module geometry.
- [ ] Source-specific infantry, drone, bike, buggy, support truck, foundry, crawler and Leviathan silhouettes/details; damage states and articulated parts.
- [ ] Orthographic follow camera, heading, smooth lag, zoom, shake, aspect resizing and correct projected edge focus indicators.
- [ ] Radar/minimap visibility tied to module, five zoom levels, camera-aligned orientation, compass, world labels and priority enemy styles.
- [ ] Persistent exploration grid/fog reveal per run, explored activity routes and radar range vs map display range.
- [ ] HUD: integrity, fuel, XP, level, salvage/currency, kills, wave, time, Road Fury, ability cooldowns, build/protocol/status indicators.
- [ ] World health bars, boss component UI, focus marker, offscreen indicators, boundary warning, activity objective/timer, extraction progress and weather status.
- [ ] Main menu/background, loadout/build/armory/progression screens, pause/help/settings, outcome statistics and restart flow. Use flat/rectangular controls, no bubble UI.
- [ ] Recoil, muzzle flash, tracer, grenade trail, rocket smoke/sparks, explosion fireballs, dust/blood/impact bursts and camera feedback.
- [ ] Damage smoke, destroyed-vehicle wrecks, debris/scorch/crater decals, battlefield retention caps and lifetime cleanup.
- [ ] Weather precipitation, fog layers, lighting transitions, wind-blown debris, tornado funnel/skirt and lightning illumination.
- [ ] Tire tracks, drifting dust, surface-dependent contact effects and trail pooling.
- [ ] Original bitmap assets: menu background; dirt road; mud patch/rut/splash; explosion fireball; blood splash; crater/scorch textures. Check mapping/filtering/transparency in Godot.
- [ ] Engine/throttle/nitro/skid, every weapon family, explosions/impacts, UI/upgrade/pickup/ability sounds and weather ambience; volume/mute/pause behavior.
- [ ] Asset preload, decoded resources, GPU texture/shader warm-up, loading progress/errors, inert gameplay until ready; first shot/destruction/weather hitch checks.
- [ ] Bounded actors/projectiles/effects/pickups/tracks/wrecks/decals, pooling, culling/LOD, frame-time monitoring and long-run stability.

## Explicitly excluded while scope remains offline

- WebSocket rooms/lobbies, room host/reconnect, remote interpolation/snapshot correction and server-authenticated input.
- PvP damage/economy/loadout rules, remote players/nameplates, online salvage arbitration and synchronized run generation/weather.
- Killcam spectating of other players, multiplayer presence, shared victory and server profile synchronization.
- Server HTTP/cache/backpressure/security/network metrics infrastructure. Equivalent local lifecycle, persistence and performance remain required above.

## Acceptance before any full-parity claim

- [ ] Each inventory behavior maps to concrete Godot implementation and a relevant source-based test or recorded manual scenario.
- [ ] Original-vs-Godot scenarios use matched seed/loadout/wave and compare trajectories, costs, damage, rewards and status expiry.
- [ ] Actual rendered scenes compare vehicle, all enemy families, scenery, weather and combat effects; exported geometry alone is insufficient.
- [ ] Complete offline run, death/restart, all six waves and extraction; all catalogs reachable through player UI.
- [ ] Profile reload verifies contracts/sidegrades; pause does not advance simulation; repeated restarts do not leak entities/events.
- [ ] Warm start and cold first-use shots/destruction/weather checked; long run respects population/effect caps.
- [ ] Final report separates automated checks, rendered/manual checks and remaining unchecked parity items.

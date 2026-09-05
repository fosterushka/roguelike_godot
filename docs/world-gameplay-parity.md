# World gameplay migration

## Implemented

`modules/world/world_runtime.gd` composes focused prop, spatial-grid, weather and tornado modules. Public API: `setup(arena, combat, vehicle)`, `set_running(bool)`, `reset_run(seed)`, `get_state()`, `set_warmup_visible(bool)`, `damage_props(position, radius, damage)`. Signals: `state_changed(Dictionary)`, `world_event(Dictionary)`.

- Uses complete native seeded source props and rock obstacles; seed72841 has6,400 props plus125 rocks. Spatial buckets are 32 units, matching the original prop system; query reach includes object radius so neighboring-cell objects cannot be skipped.
- Prop HP, radial falloff minimum 0.2, source salvage amount, ram minimum speed 3.2, radius 3.4, normal/active ram damage multipliers 7.5/16, impact retention 0.9/0.97 and bounded repeat cooldown follow source rules.
- Destruction hides the exact mesh/instances through `arena.set_prop_destroyed`, removes its existing collider and spawns salvage once. Reset restores HP, source meshes and colliders. Fuel stations cease refueling when their source monument is destroyed.
- Projectile swept segments stop at first prop/rock surface. Nonexplosive world impact applies damage ×1.8. Explosive projectiles are consumed by the combat hook and explode once; the emitted explosion applies world blast damage ×1.6 and creates wet-weather mud. No duplicate direct-plus-blast damage.
- Ground enemy motion slides around original major-prop/rock volumes. Airborne drones bypass ground obstruction. Spawn validity uses the same grid; composition installs callbacks on the combat model, which retries a bounded number of wave spawn positions.
- Pumpjack/refinery stations refill 24 fuel/second within 11 units, clamped to capacity. Uses source landmark IDs and destroyed-state records.
- World boundary radius 1,248, 15-second outside countdown, immediate countdown reset on re-entry, lethal expiry independent of armor. State exposes warning values for HUD.
- Weather schedule is a direct port of source unsigned integer hash, phase selection and 120–180-second durations. Source golden samples match: seed 72841 begins storm for154.613 seconds; phase2 is foggy ending437.307 seconds; first lightning delay89.339 seconds.
- Fog player acquisition multipliers0.68, radar-equipped0.84 and NPC0.72 are published via `model.weather_type`; combat integration applies them. Traction targets sunny1.0, fog0.92, rain0.78, storm0.68 use the source12-second smoothstep transition and pass into vehicle surface tuning.
- Ground enemy wet retention6 seconds uses absolute combat-model elapsed time. Drones remain dry. Mud radius5, lifetime14 seconds, maximum10 zones, movement0.62 and turn0.55; original three irregular mud textures render on planes.
- Storm lightning delay45–90 seconds and source deterministic target sampling; targeted roll8%, player-target roll2.5%; radius6. Player strike damage max(14, maxHP×0.14), enemy max(18,maxHP×0.18), both retain at least1HP and grant no kill rewards.
- Tornado source deterministic phase path, spawn radius32–48, outward path radius1088, influence17, lethal NPC core3.6, fade2.4/3.2 seconds. Player inward/swirl force5.2/8.4, steering disruption/speed loss; vulnerable soldier/bike/buggy core kills give no rewards. Ground motion respects obstacle resolution.
- Reusable source presentation:1100 rain streaks,220 ground splashes,20 mist layers,260 tornado particles, two source funnel cylinders plus dust skirt,10 mud planes,31 branching lightning meshes and84 wind-debris slots. Shaders are translated from original equations; all clocks are explicit and pause freezes them. Shared combat effects render material-specific prop debris/dust/leaves/shockwaves. Covered warmup includes every weather layer.

## Tests

`Godot --headless --log-file /private/tmp/iron-caravan-world-test.log --path . --script tests/world_gameplay_test.gd`

41 checks pass: source record counts; damage→exact visual hidden→collider removed→salvage once→reset; station refill and destroyed station shutdown; boundary grace/re-entry/lethal expiry; swept rock hit; enemy motion and spawn blocking; source weather golden values/delta partition; fog constants; mud bounds/expiry; nonlethal lightning through armor and actual camera projection; inert warmup and repeated restart actor bounds. Godot reports the existing macOS CA-certificate warning. Headless tests do not establish rendered quality or frame time.

## Still pending / bounded approximations

- Activities, foundries, support and extraction are implemented in focused modules; see `world-activities-parity.md`.
- Arbitrary native world generation is now composed into Start/Restart; see `world-generation-parity.md`.
- Projectile and NPC world queries use source XZ collision radii with approximate prop heights. Ground enemy steering slides locally; it is not complete route planning around entire settlements. Drone obstruction by tall buildings remains pending.
- Existing major-prop/rock colliders are removed/restored. Small destructibles still use damage/ram volumes rather than individual Godot physics bodies, matching bounded scene goals; detailed source collision shapes need visual assessment.
- Vehicle ram impact currently applies source retention immediately; source duration-based slowdown interpolation and camera/audio response remain pending.
- Native fog maps source FogExp2 density to Godot exponential fog at a65-unit reference distance; hemispheric lighting and tone mapping remain renderer approximations. Actual matched images are required before claiming visual equivalence.
- Thunder starts after exact min(1.8,distance/343) delay, but waveform timbre still uses four pre-rendered distance buckets. Listening remains unverified.
- Rain/mud/tornado/debris GPU compilation, first destruction performance and real frame times require the graphical benchmark; headless success does not establish these properties.
- The original source has no separate tornado swallowing animation. `contexts/combat/damage.ts` ignores the cause tag for presentation and preserves ordinary death FX while disabling rewards; the native port follows that reachable behavior.

## Ambient figures and settlement tribute

`ambient_system.gd` uses generated original villagers/grazers and machinery descriptors. Figure behavior follows source42-unit nearest-threat detection, storm fleeing2.5s / enemy fleeing3.5s, recovery2s, roaming/fleeing radii8/18, speed multipliers1/1.8/4.5 and original bob/heading/turn formulas. Garrison, friendly and dead actors are excluded. Windmills/pumpjacks animate original pivot nodes; reset restores all poses, and pause freezes them. Source contains no distinct shelter interaction: severe weather invokes fleeing.

Driving through a village inside7.4units at absolute speed>2.2 consumes it once, hides owned houses/signal and removes their colliders, invalidates activity/extraction eligibility, and spawns5source tribute pickups. Individual prop salvage is bypassed. Reset restores the settlement. World event routes original horn audio.

`tests/ambient_test.gd`:306 checks pass. Actual TS-generated480frame fixtures cover roaming, nearest-threat flight/recovery, storm at origin and returning home. Runtime tests cover threshold/once-only tribute,5pickups,no duplicate prop salvage, activity eligibility and reset.

Source gust timing/strength now drives machinery and84 source wind-debris slots, using camera-projected spawn points. Village consumption emits one original per-house debris/dust burst and one center shockwave/horn/banner. Both prop ram and village collision scale with the live crawler visual scale. The native runtime still uses a separate deterministic ambient random stream rather than the entire source app's interleaved cosmetic stream.

## World presentation source checks

`tests/world_presentation_test.gd`:1838 checks pass. Actual executed TypeScript fixtures cover branching bolt geometry at three seeds, wind trajectories/colors, rain/mist/splash seeded attributes and four weather transitions, drift and lightning fades. Native checks cover source traction transition, bounded pools, warmup/reset, exact thunder delay, support canopy restoration/flare pulse and pause. These compare computed transforms, not headless GPU readbacks.

Untargeted bolts intersect the actual camera ray at ground height. Targeted and area damage include exposed Leviathan components through the combat nonlethal damage API; player armor/emergency armor apply before the1HP floor. Airdrops use original canopy collapse, flare pulse/light, beacon alpha and rotating aura; heal carts use original bob, wheels and aura. New runs restore flying canopy state.

`tests/render_benchmark.gd` requires a graphical renderer and an isolated temporary profile. It records imported-cache cold boot, first run including countdown, first shots, village/destruction, storm/lightning and source actor-cap phases with p50/p95/p99/max frame intervals plus native allocator/renderer memory. Three world rebuilds record retained node/memory values. Output `/private/tmp/iron-caravan-render-benchmark.json`; this fixture is not a measurement until actually run. Static allocator memory is not process RSS.


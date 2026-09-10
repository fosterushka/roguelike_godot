# Claude Code task: diagnose and improve late-wave 1% low FPS

Work in `/Users/fosterushka/Work/vibe/roguelike_godot/new-game-project`.
Read `AGENTS.md` and preserve the existing uncommitted changes. Respond briefly in plain Russian. Do the investigation and safe, measured optimizations; do not stop at advice. Prioritize 1% low and slow frame times over average FPS.

## User problem

Waves 5–7 become noticeably uneven with many NPC. F3 shows about 39 FPS 1% low and about 20,000 objects. Investigate AI, world rendering/culling, repeated updates, and UI costs. The user specifically wants comparisons with different NPC counts and individual UI elements enabled/disabled, while observing frame time in F3.

The white top-center messages for nitro attempts and pickups were already removed. Preserve that change. Do not silently lower production resolution, remove enemies, disable shadows, change AI behavior, or remove gameplay UI to manufacture an FPS improvement. Diagnostic toggles are allowed in the test harness.

## Read these files first

- `docs/low-fps-investigation.md`: this investigation, accepted/rejected experiments and limitations.
- `docs/gpu-fx-optimization.md` and `docs/late-wave-optimization.md`: earlier work and checks.
- `tests/combat_performance_capture.gd` and `.tscn`: real-game rendered benchmark.
- `tests/combat_performance_host.gd`: test-only Main subclass; prevents automatic focus-pause through `_toggle_pause()`.
- `presentation/debug/performance_bar.gd`: F3 HUD, frame samples, profiler and OS measurements.
- `infrastructure/diagnostics/frame_metrics.gd`, `runtime_profiler.gd`, `process_metrics.gd`.
- `modules/combat/combat_runtime.gd`, `combat_model.gd`, and the AI systems they call.
- `presentation/ui/hud.gd`, `radar.gd`, `world_markers.gd`, `jammer_vhs.gd`.
- `app/main.gd`: `_on_state`, `_on_world_state`, telemetry/event connections and UI updates.
- `presentation/world/spatial_batches.gd`, `generated_world_view.gd`, `arena.gd`.

## What is already known

1. The entire world is resident in memory, but it is already spatially batched and culled. Static MultiMeshes use 256-unit chunks; terrain visuals use 32×32 terrain-cell chunks. MultiMesh culling works per batch, not per instance.
2. `OBJECT_COUNT` counts allocated engine objects, including resources and nodes. It is not the number of objects rendered. A representative heavy frame had about 20,700 allocated objects and about 1,700 rendering objects. Do not subtract these different counters to claim a precise culled-object count.
3. F3 now separates `Rendered objects` from `allocated ... objects`, and displays resolution/3D scale. F3 toggles the panel; Shift+F3 resets samples.
4. In 4112×2514 captures, AI cost about 2.2–2.3 ms in the slowest 1% of frames; world publication about 0.35 ms. Most slow frames had one physics tick. AI is not yet proven to be the main bottleneck.
5. VSync on/off gave roughly 41.0/42.0 FPS 1% low. Hiding world visuals gave 44.2 → 55.5 in another paired diagnostic run. Hiding visuals did not disable world physics.
6. An experiment with 128-unit chunks did not help: at the same 1280×800 resolution, 1% low was 60.45 vs 62.43 with 256-unit chunks, and node count rose from 8,971 to 10,736. It was reverted. Do not repeat it as an established fix.
7. Retained optimizations include GPU rocket smoke animation, cached static spatial queries, unchanged route-geometry caching, and radar road culling before subdivision. Radar culling preserves the original road samples and exploration rules.
8. Last fixed-resolution before/after radar comparison, both 4112×2514, scale 1.0, MSAA enum 2, 75 surviving NPC, two miniguns, 3,600 frames:
   - `docs/validation/low-fps/4k-before/sustained.json`: average 78.71 FPS; 1% low 42.12; radar 0.800 ms/rendered frame.
   - `docs/validation/low-fps/4k-after/sustained.json`: average 82.38 FPS; 1% low 43.17; radar 0.442 ms/rendered frame.
   This is a small observed improvement in one pair, not a resolution of the user's stutter complaint or statistical proof.
9. `render-fixed` contains a full-quality phase with large transient spikes absent from subsequent phases. Do not report its 24 → 62 FPS comparison as a proven graphics optimization. Some earlier runs also used different actual window sizes despite the same requested size.
10. GPU timing returns zero on this Metal setup. Treat it as unavailable, not zero GPU workload. Native `sample` output lacked useful Godot symbols.

## Existing commands that work

Run graphical benchmarks sequentially, never alongside tests, another benchmark, an export, or a profiler capture. Do not kill unrelated user processes. Record other active renderers/background load. Use a unique output directory for every run.

```sh
cd /Users/fosterushka/Work/vibe/roguelike_godot/new-game-project
/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" \
  --scene res://tests/combat_performance_capture.tscn \
  --log-file /tmp/claude-perf-baseline.log -- \
  --late-waves --sustained --frame-trace --capture-size=4112x2514 \
  --output=res://docs/validation/claude-perf/baseline-01
```

Use `--capture-size=1280x800` for a separate low-resolution comparison. Verify `window_size`, `viewport_size`, `render_scale`, `msaa`, `vsync` and `fps_limit` in the output, not just command arguments.

Available diagnostic switches, used ONE at a time with the baseline command:

| Switch | Existing phases |
| --- | --- |
| `--world-check` | World visible; world hidden through `game.arena.visible = false` |
| `--pacing-check` | VSync enabled; VSync disabled |
| `--render-check` | Full; 3D scale 0.5; restored scale 1.0 with sun shadows disabled |
| `--isolate` | Full; combat effects/tracers hidden; combat presentation disconnected, hidden and processing disabled |
| `--verify-feedback` | Additional assertions/captures for nitro and pickup status text |

`--sustained` currently means 600 warmup frames and 3,600 measurement frames. Without it the default sample is only 240 frames. `--preview` uses only 30 measured frames and is not performance evidence.

Completion requires `COMBAT_PERFORMANCE_CAPTURE_DONE`, successful process exit, and no script/engine errors. Results are in `sustained.json`; `--frame-trace` also writes `<phase>-frames.json`; each phase saves a PNG after measurement.

## Extend the harness for the requested matrix

NPC-count and individual UI-isolation command-line switches DO NOT EXIST YET. Implement and document them first; do not pass invented flags that the current harness silently ignores. Reuse `_phase(title, count, guns)`. Keep test configuration in the harness/host or focused test helpers, not in normal gameplay rules.

Run a staged matrix, rather than an enormous Cartesian product:

1. NPC scaling: 0, 20, 40, 60, 80 requested actors; fixed camera, seed, graphics and two miniguns where enemies exist. Record actual spawned/alive counts: late-wave spawn caps currently mean 80 requested is typically 75 alive. Keep caps intact. Fix the harness's current shot assertion for the legitimate zero-target scenario; assert firing only when targets exist.
2. NPC roles: riflemen only, shooters only, and mixed final-wave roster including support/jammer/boss actors. Preserve health, positions and loadout across each paired comparison. Record per-kind counts and active projectiles/mines/FX.
3. UI isolation at the heaviest reproducible count, ONE component at a time: radar, world markers/enemy labels, jammer VHS post-effect, jammer overlay, boundary post-effect, health/speed/fuel/target text and hotbar updates, reward/status overlays, then all gameplay HUD except F3.
4. Compare rendering-only removal with full UI-work removal for the components that actually matter. A hidden node may still receive signals, execute update methods, mutate text or set shader uniforms. `set_process(false)` does not disconnect signals or prevent explicit calls. Record exactly what each toggle disables.
5. World isolation: visuals hidden while simulation remains; separately freeze world activity/weather publication while retaining the last visuals; separate shadows from base world geometry. Do not disable all of `_on_state` or `_on_world_state` without checking their non-UI responsibilities.
6. AI isolation, only after the matrix: freeze selected AI calculations while retaining the same presented actors, or use deterministic recorded states for a render-only comparison. Mark this as an artificial diagnostic, not gameplay-preserving optimization. Do not call hiding enemies an AI test.
7. After finding a useful change, repeat a moving-camera/driving route, a dense settlement, and an actual wave 5–7 run. Stationary invulnerable actors are only one stress scenario.

For UI toggle implementation inspect these current handles: `game.hud.radar`, `markers`, `jammer_vhs`, `jammer_overlay`, `boundary_desaturation`, `_stats_panel`, `_target_label`, `_hotbar`, `reward_notice`, `_status_label`, and `_gameplay`. These are test-only inspection points; do not build new production cross-system access to private fields.

Visibility is sometimes rewritten by `update_state`, `update_world`, or HUD `_process`, so one `.hide()` before a phase may not stay effective. Verify the target remains disabled throughout measurement and save a rendered screenshot. Use focused test-host gates or disconnections, restore them completely, and return to baseline after each intervention. Include A/B/A checks to detect accumulated state and order effects. Reset transient visual pools and diagnostic state consistently when phases restart.

Provide a simple debug-only way to choose/identify the active test scenario while keeping F3 visible. Follow existing UI style, no new bubble controls. Also compare F3 visible vs hidden with measurement still running to quantify the profiler panel's own overhead.

## Measurement rules

- The current harness sets `game.performance_bar.set_process(false)` and manually records frames/refreshes the panel. Re-enabling its normal `_process` at the same time would double-count samples. There must be ONE owner of frame recording and `Profiler.take()`.
- Keep profiling enabled when hiding only the F3 visuals. `set_open(false)` disables `Profiler.enabled`; it is not equivalent to hiding presentation while retaining instrumentation.
- The 1% low formula is `1000 / mean(slowest ceil(N * 0.01) frame times in ms)`. Do not substitute the 99th percentile or minimum FPS without labeling the different metric.
- Include average, 1% low, 0.1% low, p95/p99 frame ms, worst frame, frames over 16.67/33.33 ms, sample duration and count. Keep raw samples. Compare equal conditions; repeat promising pairs at least three times and report the spread.
- For longer sustained sessions, note that `FrameMetrics` holds only the last 3,600 frames. Aggregate the full raw trace separately if claiming full-run statistics.
- Group the slowest frames by number of physics ticks and inspect their profiler sections. Also report milliseconds per physics call: faster rendering means fewer physics calls per rendered frame and can otherwise fake a simulation improvement.
- Timers are inclusive. Do not sum `combat_tick`, `simulation`, `ai`, `publish`, `combat_view`, `snapshot`, and `hud` together. Full combat timing includes support, simulation and publication; AI is nested in simulation. World publication is nested in session timing in this harness. `radar_draw` is separate deferred drawing work.
- Important current harness limitation: `game.world.set_physics_process(false)` suppresses world activity simulation; session weather updates still publish. `--late-waves` picks the final-wave roster but does not recreate actual wave progression. Record these limitations; add a separate real-world simulation scenario.
- A hidden-rendering experiment may reduce CPU submission as well as GPU work. A lower-resolution result suggests a rendering bottleneck but does not supply missing GPU timings.
- Warm both variants equally. Record window resize, focus loss, shader warmup and interruptions instead of silently dropping spikes. Separate first-use stutter from steady-state results. Keep genuine gameplay spikes in the outcome.
- Do not claim multithreading solves the issue without profiling. If a worker is justified, operate on owned snapshots/data and apply results safely on the main thread; do not move live SceneTree nodes into arbitrary workers.

## Tests and rendered verification

After an actual change, run suitable tests from the existing manifest, separately from timing runs:

```sh
python3 tests/run_all.py --only \
  minimap_test.gd performance_bar_test.gd combat_optimization_test.gd \
  session_flow_test.gd vehicle_response_test.gd \
  --output /tmp/claude-perf-tests
```

Add relevant tests for touched systems: `enemy_ai_test.gd`, `combat_test.gd`, `combat_soak_test.gd`, `world_presentation_test.gd`, `spatial_batches_test.gd`, `terrain_chunks_test.gd`, `source_fx_test.gd`, `jammer_feedback_test.gd`, etc. Use the manifest's real names. Headless results cannot establish rendered appearance or FPS.

Existing radar pixel comparison:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" \
  --script res://tests/radar_culling_capture.gd \
  --log-file /tmp/claude-radar-pixels.log -- \
  baseline=res://docs/validation/low-fps/radar-pixels/original-radar.gd \
  output=/tmp/claude-radar-pixels
```

Check that the baseline artifact exists before using it. This is a graphical helper, not part of the headless manifest. Require `Radar culling render: 0 failures` and inspect captures.

Handoff verification status: five selected headless tests previously passed, and three radar pixel comparisons passed. Afterward the F3 resolution label was added, the session profiler wrapper was simplified, and the radar capture window was changed from 360×260 to 1280×800. These latest small edits have not yet had their final test/capture rerun because the user requested this handoff. The fixed-resolution 4k-after benchmark completed successfully before handoff.

## Deliverables

1. A reproducible harness with documented NPC-count and UI-isolation controls, plus exact commands.
2. Raw JSON/CSV traces and screenshots under unique `docs/validation/claude-perf/` run directories.
3. A compact table: scenario, actual NPC count/roles, resolution, disabled work, average FPS, 1% low, p99 ms, slow-frame stage timings, draw calls and rendered objects.
4. A conclusion distinguishing confirmed causes, plausible causes and unmeasured time. Identify the largest repeatable improvement in 1% low.
5. Only retain production optimizations with measured benefit and preserved gameplay/appearance. Restore diagnostic toggles, leave existing user settings intact, and run `git diff --check` plus appropriate tests.
6. Update `docs/low-fps-investigation.md` with evidence and remaining limitations. Do not claim the stutter is fixed merely because average FPS increased.

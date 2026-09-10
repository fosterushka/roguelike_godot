# Late-wave 1% low investigation

## What the counters mean

The world is resident in memory, but it is not submitted in full every frame. Static MultiMeshes already use 256-unit spatial batches. Terrain rendering uses 32×32-cell chunks. Godot culls each batch as a unit; instances within a visible batch are not culled separately. Allocated engine objects include nodes and resources and must not be read as visible meshes.

The full-world 4112×2514 capture submitted about 1,700 rendering objects while approximately 20,700 engine objects were allocated. These counters cover different categories; their difference is not a count of culled meshes. F3 now labels allocated and rendered counters separately and displays the window resolution and 3D scale.

## Controlled diagnostic observations

All captures use the debug Godot 4.7.2 Metal Forward+ binary, seed 72841, a synthetic final-wave roster (75 surviving NPC), two firing miniguns, invulnerable actors, 600 warmup and 3,600 measured frames. World activity simulation is disabled to prevent extra test actors; weather publication and the real rendered world remain active. This is not a complete wave 5–7 playthrough. Other desktop applications and pre-existing headless Godot processes were not stopped.

- `validation/low-fps/pacing`: at 4112×2514, VSync on/off produced 41.04/42.04 FPS 1% low. Slow frames were mostly single physics ticks. AI averaged 2.30/2.18 ms within the slowest 1%; world publication averaged 0.37/0.34 ms. This does not explain all frame time.
- `validation/low-fps/world`: hiding world visuals, while retaining simulation, changed 1% low from 44.18 to 55.47 FPS. This identifies a material rendering cost, not permission to remove the environment.
- `validation/low-fps/chunk128` and `chunk256`: at 1280×800, 128-unit batches yielded 60.45 FPS 1% low versus 62.43 for the existing 256-unit batches. Nodes increased from 8,971 to 10,736. The smaller-chunk experiment was reverted.
- `validation/low-fps/render-fixed`: lower 3D resolution and disabled shadows were diagnostic only. The first full-quality phase contains multi-tick spikes up to 124 ms that are absent from later phases. It is not a clean before/after improvement claim. Production quality, shadow settings, and VSync are unchanged.
- Do not compare results recorded at 1280×800 with 4112×2514. The harness now accepts `--capture-size=WIDTHxHEIGHT` and records actual dimensions, render scale and MSAA.
- Native sampling of the standalone editor binary lacked useful Godot symbols. A GPU time of zero is unavailable timing, not evidence that GPU work costs zero.

## Changes retained

The radar used to subdivide every world road on every redraw, even when the road was entirely outside the minimap. It now clips the projected parent segment before visiting subdivision indices. The original indices, fog-of-exploration samples and final line clipping remain unchanged. No road geometry or discovery rules were removed.

Optional profiler sections now also cover full combat ticks, caravan support, vehicle ticks, session ticks, app ticks and radar drawing. They are inactive when the F3 profiler is closed. Temporary broad process instrumentation was removed.

## Validation

Five selected headless tests passed: minimap, performance bar, combat optimization, session flow and vehicle response. The road regression checks conservatively retain every original visible subsegment across multiple positions, headings and zoom levels. The new real-render capture compares the original and optimized minimap at three views, including partly explored roads: all pixels matched. The fully explored capture was visually inspected.

Reproduce the pixel comparison with `tests/radar_culling_capture.gd`, supplying `baseline=/absolute/path/to/original-radar.gd` and `output=/tmp/radar-culling-render`. This capture is intentionally outside the headless manifest.

## NPC and UI matrix, 2026-09-11

### New harness controls

`tests/combat_performance_capture.gd` gained diagnostic switches. They are test-only; production rules and owners are unchanged.

| Switch | Effect |
| --- | --- |
| `--npc-count=N` | Actor count for `--role-check`, `--ui-check`, `--f3-check`, `--fps-cap-check` and `--late-waves` (default 80). |
| `--npc-scaling` | One phase per count. `--npc-counts=0,20,40,60,80` overrides the list. |
| `--role-check` | Riflemen only, shooters only, mixed final-wave roster. |
| `--ui-check` | Baseline, then one HUD component at a time, then baseline again. `--ui-targets=` selects from radar, markers, jammer_vhs, jammer_overlay, boundary, stats, target_label, hotbar, reward_notice, status_label, gameplay_hud. |
| `--f3-check` | F3 panel visible, hidden with profiling still enabled, visible again. |
| `--fps-cap-check` | `Engine.max_fps` per phase. `--fps-caps=0,60,120,0` overrides the list. |
| `--world-check` | World visible, hidden, visible without sun shadows, visible again. |

Every scenario starts with a `warmup_discard` phase, because the first measured phase after startup still carries pipeline warmup. Repeated phase titles get a numeric suffix so traces and screenshots do not overwrite each other.

UI isolation is rendering-only. The gate is a `Node` with `process_priority` 500, so it re-applies `visible = false` after every owner update and before the frame is drawn; the phase records how many times the owner tried to show the node again (`ui_gate_corrections`) and asserts the node was hidden at draw time (`ui_hidden_at_draw`). Update methods, signals and shader uniform writes keep running. Radar is the clear case: hiding it removed about 30 draw calls but left `radar_draw` at 0.399 ms/frame against 0.397 ms in the baseline, so its `_draw` work is not what a hidden node stops paying.

Commands, one scenario per process:

```sh
cd /Users/fosterushka/Work/vibe/roguelike_godot/new-game-project
/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" \
  --scene res://tests/combat_performance_capture.tscn \
  --log-file /tmp/claude-perf-npc.log -- \
  --late-waves --npc-scaling --sustained --frame-trace --capture-size=4112x2514 \
  --output=res://docs/validation/claude-perf/npc-scaling-01
python3 tests/perf_trace_report.py docs/validation/claude-perf/npc-scaling-01
python3 tests/perf_trace_report.py --table docs/validation/claude-perf/*
```

### Measurement conditions and two methodology corrections

Godot 4.7.2 debug binary, Metal Forward+, Apple M4 Pro, seed 72841, requested window 4112x2514 with logical viewport 1308x800, 3D scale 1.0, MSAA enum 2, VSync enabled, 600 warmup and 3600 measured frames per phase, stationary player, invulnerable actors, world activity physics disabled, clear weather, two miniguns.

1. A capture launched into a background window is throttled by the desktop and produces no usable timing: one 5-phase run made no measurable progress in eight minutes and the same run in a foreground window finished in under ten. Run captures in the foreground.
2. Sustained 4K captures heat the machine. Baselines held at 90.3 +/- 0.6 average FPS across the first nine runs and then decayed to 84.7, 79.9 and 62.4 in later repeats of the same phase. Only compare phases inside one run, and treat cross-run absolute numbers as drift.

A pre-existing user process, `Godot --headless --script res://tests/item_preview_test.gd` started on 7 September, held a full core at 100 percent for the entire session. Every number here includes that load. It was not stopped, because it is not this task's process.

### Where the time goes at 77 late-wave NPC

Per 60 Hz physics tick, from `docs/validation/claude-perf/npc-scaling-02`:

| Stage | 0 NPC | 40 NPC | 77 NPC |
| --- | ---: | ---: | ---: |
| Whole physics frame (`TIME_PHYSICS_PROCESS`) | 3.24 ms | 6.76 ms | 9.93 ms |
| `combat_tick` | 1.02 | 3.73 | 6.38 |
| ... `simulation` | 0.06 | 1.41 | 2.65 |
| ... ... `ai` | 0.00 | 1.10 | 2.10 |
| ... `publish` | 0.57 | 1.94 | 3.31 |
| ... ... `combat_view` | 0.26 | 1.17 | 2.13 |
| ... ... `hud` | 0.27 | 0.30 | 0.35 |
| ... ... `snapshot` | 0.03 | 0.17 | 0.34 |
| `session_tick` | 0.30 | 0.35 | 0.36 |
| `vehicle_tick` | 0.23 | 0.16 | 0.18 |

Timers are inclusive and must not be summed across levels. Publishing the combat state costs more than simulating it: 3.31 ms against 2.65 ms, and inside publication the presentation consumer `combat_view.apply_state` is 2.13 ms, more than `ai` at 2.10 ms. Temporary instrumentation inside `apply_state`, since removed, attributed 1.63 ms of that to the per-enemy placement loop and 0.60 ms to effects, at about 21 microseconds per enemy per tick. `Performance.PHYSICS_3D_ACTIVE_OBJECTS` and `PHYSICS_3D_COLLISION_PAIRS` are both zero, so the physics server is not the cost. About 3.0 ms of the 9.93 ms physics frame is outside every profiler section.

### Frame pacing is bimodal, and that is the reported unevenness

Splitting the raw trace by physics ticks per rendered frame at 77 NPC:

| Frame kind | Count | Mean ms |
| --- | ---: | ---: |
| Carried a physics tick | 2387 | 15.18 |
| Carried no tick | 1213 | 2.94 |

Physics runs at 60 Hz and rendering is uncapped, so the sequence repeats as roughly 15.2, 15.2, 2.9 ms. Average FPS reads 90 while consecutive frames differ by 10.7 ms on average. Hiding the entire world moved the tick frame only from 15.16 to 14.68 ms and the free frame from 2.98 to 2.11 ms: rendering is about 3 ms and the tick frame is insensitive to it. Disabling sun shadows cut draw calls from 683 to 379 and the free frame to 2.43 ms while leaving the tick frame at 15.14 ms.

### Matrix results

Full per-phase table with resolutions, disabled work, draw calls and rendered objects: [validation/claude-perf/summary.md](validation/claude-perf/summary.md). Raw traces are the gzipped `<phase>-frames.json.gz` files, screenshots are the per-phase JPEGs.

NPC scaling, one run, two miniguns, final-wave roster:

| Requested | Spawned | Avg FPS | 1% low | 0.1% low | p99 ms | Frames over 16.7 ms | `combat_tick` ms/frame |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 0 | 119.86 | 83.30 | 74.79 | 11.72 | 0 | 0.50 |
| 20 | 20 | 114.76 | 66.24 | 57.71 | 14.61 | 1 | 1.36 |
| 40 | 40 | 109.25 | 56.77 | 53.92 | 17.09 | 66 | 2.05 |
| 60 | 57 | 98.85 | 50.84 | 48.26 | 19.27 | 958 | 3.08 |
| 80 | 77 | 90.48 | 47.16 | 45.92 | 20.89 | 1212 | 4.23 |

The 0 and 20 NPC phases sit against the 120 Hz VSync ceiling, so their averages understate the headroom. Catalog caps are intact: 80 requested gives 77 alive on the final-wave roster, and a shooters-only roster caps at 12.

Roles at the same request of 80, one run: riflemen only 106.85 average and 53.99 1% low with 619 draw calls; final-wave mixed 90.36 and 47.04 with 688 draw calls; shooters only reached 120.00 and 75.93 but spawned 12 actors, so it is not a comparison of equal crowds.

UI isolation, rendering-only, one component at a time. Within-run baselines are quoted as first and last:

| Component hidden | Avg FPS | 1% low | Baselines in that run (1% low) |
| --- | ---: | ---: | --- |
| Whole gameplay HUD except F3 | 102.73 | 51.34 | 46.70 / 46.97 |
| Jammer VHS post effect | 95.17 | 49.35 | 46.70 / 46.97 |
| World markers and enemy labels | 93.47 | 47.07 | 46.70 / 46.97 |
| Radar | 87.96 | 44.47 | 46.70 / 46.97 |
| Player stats panel | 91.11 | 46.95 | 47.46 / 47.12 |
| Target and boss label | 90.47 | 46.89 | 47.46 / 47.12 |
| Ability hotbar | 91.34 | 46.94 | 47.46 / 47.12 |
| Jammer overlay | 90.59 | 46.87 | 47.46 / 47.12 |
| Boundary post effect | 90.29 | 47.08 | 46.63 / 46.64 |
| Reward notice | 90.11 | 46.76 | 46.63 / 46.64 |
| Status text | 90.34 | 46.82 | 46.63 / 46.64 |

Only the jammer VHS layer and the HUD as a whole move the 1% low. The seven small controls are inside baseline noise. The radar row is below its own baselines and its 0.1% low fell to 36.40 on one outlier frame; hiding it is not an improvement.

The F3 panel itself costs about 1 FPS of 1% low and adds spikes: 46.82 and 46.59 with the panel visible against 47.71 hidden, worst frame 32.82 and 29.91 against 21.55. Profiling stayed enabled in all three phases, only the panel visuals were gated. Read F3 numbers as slightly pessimistic.

### Frame cap, the only large pacing lever found

`Engine.max_fps` is already a player setting (`fpsLimit` in `modules/settings/settings_catalog.gd`). Five runs, `--fps-cap-check`:

| Run | Machine state | Uncapped 1% low | Capped to 60 1% low | Uncapped pacing ms | Capped pacing ms |
| --- | --- | ---: | ---: | ---: | ---: |
| fps-cap | fresh | 46.80 / 46.92 / 46.72 | 53.79 | 10.69 | 0.85 |
| fps-cap-02 | warm | 45.94 | 49.68 | 10.42 | 0.90 |
| fps-cap-03 | hot | 43.03 | 34.25 | 8.90 | 1.63 |
| fps-cap-04 | hot | 28.12 | 27.23 | 8.93 | 2.00 |
| fps-cap-05 | cooled | 39.82 / 45.02 | 52.25 | 9.82 | 0.69 |

Pacing here is the mean absolute difference between consecutive frame times. The cap removes the alternation in every run, by five to fourteen times. The 1% low gain is not universal: it is worth between 3.7 and 8.8 FPS while the machine can hold 60, and it inverts once the machine cannot, because a 60 FPS cap leaves no headroom for a slow frame. A 120 cap changes nothing, as expected on a 120 Hz display.

### Conclusions

Confirmed:
- Cost scales with actor count almost entirely through the 60 Hz combat tick, not through rendering. Rendering is about 3 ms per frame at this resolution; the physics frame is 9.9 ms at 77 late-wave NPC.
- Publication is more expensive than simulation, and its most expensive consumer is `combat_view.apply_state` at 2.13 ms per tick, slightly above `ai` at 2.10 ms.
- Frame time is bimodal, 15.2 ms with a tick and 2.9 ms without. This is the mechanism behind uneven late waves even when average FPS reads 90.
- Of the gameplay HUD only the jammer VHS layer has a measurable cost, about 2.5 FPS of 1% low when jammers are on the field. The other seven isolated controls are inside noise.
- Catalog caps limit a request of 80 to 77 alive on the final-wave roster and to 12 shooters.

Plausible, not established:
- The remaining 3.0 ms per tick outside all profiler sections. No section covers it and no native profile with useful Godot symbols is available on this setup.
- Whether the user's reported 39 FPS 1% low has the same composition. This harness reproduces a load level, not a wave 5 to 7 playthrough: model wave stays 1, world activity physics is off, the player does not drive.

Not measured:
- GPU time. Metal returns zero here, which is unavailable timing, not zero work.
- A moving camera, a dense settlement and a real wave 5 to 7 progression. All numbers are a stationary stress crowd.

Largest repeatable improvement in 1% low: none of the permissible single toggles beat the frame cap. Capping to the physics rate is the only change that reliably removes the 10.7 ms frame-to-frame swing, and it costs average FPS. It is a pacing mitigation, not a fix. The fix is per-tick cost, and the two largest addressable pieces are the per-enemy presentation loop inside `combat_view.apply_state` and `ai`.

No production optimization was retained in this pass. The candidates inspected in `combat_view.apply_state`, `enemy_animation.gd` and `source_animation.gd` are per-call allocations worth an estimated 0.05 to 0.3 ms per tick, below what these runs can separate from noise, and `enemy_ai.gd` has no quadratic loop to remove. The only production change here is the F3 scenario label. Claiming a fix would need a change worth about 1 ms per tick, verified in a fresh-machine A/B/A pair.

### Validation

Nine headless tests passed through `tests/run_all.py`: performance_bar, minimap, combat_optimization, session_flow, vehicle_response, world_presentation, hud_layout, jammer_feedback, source_fx. Architecture guard and `git diff --check` passed. The F3 scenario label has its own assertion in `tests/performance_bar_test.gd`, which fails when the label is removed. Temporary `combat_view` instrumentation was reverted; `git diff` for `presentation/combat/combat_view.gd` is empty.

# GPU smoke and obstacle-query optimization, 2026-09-10

Rocket smoke now uses one live MultiMesh, one shared material and a separate warmup instance. Particle birth time, lifespan, seed, opacity, drift and initial rotation are uploaded once. The vertex shader computes movement, rotation, expansion and opacity from the simulation clock; CPU advancement updates one uniform. The 192-slot ring remains bounded. Zero delta freezes it and reset hides the old prefix before reusing slots. Normal depth testing remains enabled. A culling margin covers shader displacement and expansion.

The original procedural smoke fragment shading and random stream are retained. Lateral drift is now integrated analytically, so appearance is similar but trajectories are not pixel-identical to the old per-frame Euler integration. Side-by-side render: `docs/validation/gpu-fx/gpu-smoke-compare.png` (old left, GPU right).

Static effect-pool transforms are no longer written when motion/spin/growth/shrink are zero. SpatialGrid caches up to 128 cell-region candidate lists. Insert/remove invalidate the cache. Queries return shallow array copies because projectile collision appends dynamic obstacles; cached records remain live references and ordering is preserved.

## Checks

13/13 selected tests passed cleanly through tests/run_all.py, including source FX, combat optimization, loading/warmup, scene depth, presentation, world gameplay, crew missions, base collisions, world activities, AI, combat, advanced combat and combat soak. Logs: `docs/validation/gpu-fx/tests/`. The soak is a headless model test, not a long graphical playthrough. Architecture guard and diff whitespace checks passed. Full suite and standalone export were not run.

The source FX test also passed with the real Metal renderer: 1479/1479. Headless dummy RenderingServer does not retain custom MultiMesh data, so GPU payload round-trip assertions run only with a graphical renderer; the headless tests still cover lifecycle, pause, warmup, bounded capacity and reset.

## Measurements

Isolated development microbenchmarks (not whole-game FPS):
- 192 live smoke particles, 1000 tiny advancement steps: old CPU path 347.614 microseconds/step; new shared-clock path 0.126 microseconds/step. This excludes emission and GPU execution.
- 20,000 repeated local obstacle queries: 3.094 microseconds/query before, 0.324 with cache. This measures repeated regions, not cache misses or frequent obstacle mutations.

Rendered comparison uses the existing late-wave roster stress harness, 600 warmup frames and 3600 sample frames, two miniguns, high-health actors, stationary player and disabled world activity physics. It is not a saved late-session reproduction. Actual large window was 4112x2514 with logical viewport 1308x800 despite the requested 1280x800; compare actual output sizes. Vsync stayed enabled. Runs are sequential on a non-isolated desktop.

Initial isolation: full presentation 78.35 FPS; hiding only FX rendering 80.72 FPS; disconnecting/hiding all combat presentation 88.31 FPS. Hiding FX leaves their CPU updates running. Disabling all combat presentation also stops visual state consumers, so it is not a pure GPU measurement. Simulation remains active in all three cases.

With GPU smoke and skipped no-op effect transforms, before the spatial cache: 77.81 FPS overall versus 78.35 initially, so no overall FPS gain established at that stage. FX CPU time decreased from 0.847 to 0.536 ms/frame (about 37%). Node count fell from 9355 to 8971. These numbers do not establish that the reported severe slowdown is fixed.

A further fix caches activity-route dash geometry until its points or world seed change. Previously every raw-weather publication rebuilt up to 256 ground dashes per route. The cache preserves hide/reappear behavior and detects in-place point edits. `world_publish` now has its own profiler section for future diagnosis.

Final combined run with route caching: **82.54 FPS**, 12.115 ms/frame, 1% low 41.27 FPS, FX 0.504 ms/frame, AI 1.539 ms/frame, world publication 0.234 ms/frame. Initial full run: 78.35 FPS, 12.764 ms/frame, 1% low 42.45 FPS, FX 0.847 ms/frame, AI 1.736 ms/frame. Thus average FPS was about 5% higher in this comparison and FX CPU cost about 40% lower; slow-frame lows did not improve. Do not describe this as a complete fix of the user's reported late-session slowdown. Non-isolated sequential runs are subject to timing noise.

Four follow-up tests passed after route caching: world_presentation, support_feedback, world_gameplay and session_flow. Combined with the prior 13-test pass, this is 16 unique passing test files (world_gameplay ran twice), not one full-suite pass. Logs: `docs/validation/gpu-fx/route-tests/`. Final rendered scene: `docs/validation/gpu-fx/final-route/late_waves.png`; final JSON is alongside it.

Reproduction:
```sh
/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" --scene res://tests/combat_performance_capture.tscn -- --late-waves --isolate --sustained --output=res://docs/validation/gpu-fx/recheck
```

The packed per-instance data follows the [Godot MultiMesh API](https://docs.godotengine.org/en/4.7/classes/class_multimesh.html). Game AI and collision code were not moved into threads; this change removes redundant CPU work and moves cosmetic smoke animation onto the GPU.

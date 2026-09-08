> Исторический отчёт отдельного прохода. Не описывает текущий FPS или полный статус тестов. Актуальные правила: [PROJECT.md](PROJECT.md); статус артефактов: [ARTIFACTS.md](ARTIFACTS.md).

# World rendering performance, 2026-09-08

Implemented from `GODOT4_PERFORMANCE_CODEX.md`. This is a conservative rendering pass for the existing **3D** game. It reduces submitted world geometry; it does **not** establish a general gameplay FPS increase or complete streaming implementation.

## Configuration and audit

- Baseline commit: `26d1d15564f67c580bfd7a809446b2464e098967`.
- Project declares Godot 4.7 / Forward+; executable `/Applications/Godot.app/Contents/MacOS/Godot` reports **4.7.2.stable.official.ed1daf0bf**.
- Actual renderer: Metal 4.0, Forward+, Apple M4 Pro (Apple9), macOS 26.6.2. Editor executable running scripts, 1280 × 800; no exported release benchmark.
- `modules/world/generation/world_generator.gd` creates a finite seeded world. `generation_context.gd` owns procedural instances and prop identity; `generated_world_view.gd` builds its runtime visuals. The boot reference world also passes through `arena.gd`.
- Terrain: 512 × 512 heightfield cells, shared height sampling in `terrain_surface.gd`; Jolt `HeightMapShape3D`. Prop collision bodies and `spatial_grid.gd`/`rock_steering.gd` remain active independently of rendering.
- Camera: orthographic `follow_camera.gd`, zoom, movement lead, shake and limited drag. Engine frustum culling now operates on bounded batches without camera-distance polling. Minimap does not control world activity.
- World radius 1248 is the playable boundary. The existing larger ground/horizon and boundary grace period remain intentional legacy content. This change creates no new procedural spawn positions or chunk requests. Terrain subregion requests are clipped before building vertices; wholly invalid requests produce no geometry.
- Persistence remains `infrastructure/persistence/profile_store.gd` and existing caravan/expedition saves. No save-format, seed-stream, reward, AI, physics-rate, renderer or density change. Offline single-player scope remains unchanged.

## Changes and ownership

| File | Change and reason |
| --- | --- |
| `presentation/world/spatial_batches.gd` | Shared factory partitions occupied X/Z cells, using floor coordinates and **256 world-unit** batches. Keeps source child slots and returns instance remapping. Shared meshes/materials stay shared; per-batch instance buffers are independent. No polling callbacks or historical cache. |
| `presentation/world/generated_world_view.gd` | Uses the factory after tree substitution; remaps each prop's destruction slot, preserving ID and restore matrix. Writes instance transforms once. |
| `presentation/world/arena.gd` | Applies the same partitioning to boot-reference scenery. Skips replaced tree components and replaced road batches. Hidden destroyed instances stay at their original anchor, preventing bounds from expanding toward world origin. Terrain uses 32 × 32-cell visual pieces, reusing their nodes on rebuild. |
| `modules/caravan/terrain_surface.gd` | Existing mesh builder accepts a clipped subregion. Vertex positions, normals, UVs and triangle winding match the old mesh exactly, including shared edges. Heightfield collision is unchanged. |
| `presentation/world/prop_motion_view.gd` | Warm-up deduplicates mesh/material combinations rather than spatial batch IDs, preserving material variants. The existing actual-world GPU warm-up remains in place. |
| `tests/spatial_batches_test.gd`, `tests/terrain_chunks_test.gd`, `tests/run_all.py` | Boundary/remapping/resource-sharing and exact terrain equivalence regression checks. |
| `tests/spatial_batches_render_test.gd` | Repeatable rendered route and image capture; optional baseline factory and capped run. |

A 128-unit decoration trial produced 4000 source-world children and about 28 MiB additional static allocation. The selected 256-unit setting reduced that to **2290 children and about 12 MiB additional allocation**, retaining nearly all measured geometry savings. Terrain has 256 bounded visual pieces instead of one world-wide mesh. These are resident visual batches, not streaming chunks.

Godot's [4.7 MultiMesh documentation](https://docs.godotengine.org/en/4.7/classes/class_multimesh.html) describes group-level culling. The implementation leaves bounds renderer-managed, so moved props and mesh overhang remain included. There are no manually frozen bounds to become stale after movement/destruction.

## Reproducible comparison

The same seeded static world, roads, terrain, lighting and camera route are used for both versions. No combat actors are stepped in this route. Camera targets: `(0,0,35)`, `(-128,0,-128)`, first generated village, `(128,0,128)`, then return to start. Orthographic size is 70, except zoom-out size 140. Offset is `(40,45,40)`.

Each phase records 45 first-visit/settling frames separately, then 180 warmed frames. Percentiles use measured frame intervals, not reciprocal FPS. Rendering is explicitly driven once per iteration with [`RenderingServer.force_draw()`](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#class-renderingserver-method-force-draw), because normal draw-signal waits stalled when a desktop window stopped receiving redraws. This is a **static desktop render benchmark**, not isolated GPU time or an interactive playthrough. It retains desktop scheduling and presentation noise.

```sh
git show 26d1d15564f67c580bfd7a809446b2464e098967:presentation/world/generated_world_view.gd > /tmp/iron-original-generated-world.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/spatial_batches_render_test.gd -- baseline=/tmp/iron-original-generated-world.gd output=/tmp/iron-before
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/spatial_batches_render_test.gd -- output=/tmp/iron-after
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/spatial_batches_render_test.gd -- capped output=/tmp/iron-capped
```

The baseline option restores the old generated-view factory and a monolithic ground mesh. Run graphical comparisons sequentially, with no other active Godot rendering/tests. Imported assets and shader caches are already present; first application launch without those caches was **not measured**.

## Results

Numbers below use the repeated baseline and final 256-unit capture. Raw phase reports and pixel-comparison summaries are retained in [performance-measurements.json](performance-measurements.json). Local screenshots/logs are under `docs/validation/performance/` (ignored by Git).

| Metric / scenario | Before | After | Conditions / caveat |
| --- | --- | --- | --- |
| Start frame median / p95 / p99, ms | 8.318 / 8.876 / 9.208 | 8.520 / 8.699 / 10.522 | Uncapped request, desktop presentation; no median gain here |
| Negative boundary median / p95 / p99, ms | 8.293 / 10.853 / 15.196 | 8.447 / 8.621 / 8.697 | Same camera target |
| Village median / p95 / p99, ms | 8.317 / 11.279 / 14.826 | 8.302 / 9.255 / 9.448 | Same static village |
| Zoom-out median / p95 / p99, ms | 8.359 / 11.085 / 13.395 | 8.266 / 9.329 / 9.385 | Orthographic size 140 |
| Return median / p95 / p99, ms | 8.333 / 8.926 / 10.196 | 8.220 / 9.304 / 9.384 | Same view as start |
| First visible start: worst settling frame, ms | 34.384 | 42.608 | Coldest captured frame regressed; keep separate from warmed samples |
| Worst later camera-transition settling frame, ms | 15.335 | 9.569 | No runtime chunk loading; actual streaming transition: not applicable |
| Start draw calls | 75 | 117 | More small batches; draw calls alone are not success |
| Submitted primitives, start | 3,168,930 | 435,848 | 86.2% reduction; includes render passes |
| Submitted primitives, negative boundary | 2,643,698 | 100,076 | 96.2% reduction |
| Submitted primitives, village | 3,191,314 | 167,886 | 94.7% reduction |
| Submitted primitives, zoom-out | 3,169,038 | 473,116 | 85.1% reduction |
| Active actors / resident source-world children | 0 / 653 | 0 / 2290 | Static route; terrain visual children separately: 0 / 256 |
| Static allocation after return | 230,330,957 B | 242,656,416 B | Approximately +11.8 MiB; allocator monitor, not process RSS |
| Renderer video allocation after return | 187,809,792 B | 188,678,144 B | Shared-memory GPU monitor, not physical VRAM usage |
| Procedural generation, ms | 2775.420 | 2865.759 | One sample; generator unchanged |
| Generated-view build/replacement, ms | 395.636 | 251.564 | One sample; excludes terrain construction, import and loading-screen GPU warm-up |
| Final capped route median, ms | not measured | 16.636–16.664 | VSync + explicit 60 FPS cap; p99 17.575–18.467 ms |
| Script hotspots / physics / navigation / separate GPU time | not measured | not measured | No claim from headless or draw counters |
| Long exploration RSS / VRAM / scaling with larger distant world | not measured | not measured | No streaming or distant-world-growth experiment |

Frame timing varies across runs. Earlier final-build samples had medians near 2 ms in several phases, while repeated captures approached the desktop's 8.3 ms cadence. Those lower numbers are **not used as a claimed FPS speedup**. The reliable result is reduced submitted geometry with preserved images. Start-frame p99 and first-visit latency remain regression risks to measure in a release build.

## Regression and visual validation

- Final full headless suite with 256-unit batches: **101/101 clean**, including engine-error and leak checks (`/tmp/iron-performance-final-256`, copied to `docs/validation/performance/full-suite/`).
- Final focused coordinate/terrain/world-rebuild checks: **3/3 clean**.
- Actual Metal renderer: **47/47** spatial mapping/color checks; **33/33** world rebuild/destruction/reset checks.
- All five before/after images were compared. Maximum difference is **1/255 per channel**; village image is byte-equivalent in pixel content. Start and village captures were also visually inspected. No missing visible geometry or terrain seams were observed at those views.
- Existing tests cover seed determinism, reset, terrain/wheel collision, tornado movement, destruction, villages, progression, loading, minimap and combat. They do not prove a long interactive fight at a chunk edge or release-device behavior.
- One early sandbox test run reported macOS system-certificate errors despite passing assertions. Re-running with normal system access passed. The error matcher was not weakened.
- The existing full-game `render_benchmark.gd` completed the original run, but the after-run stalled around a pause/focus transition. That incomplete run is excluded from final comparisons; it does not establish a new gameplay failure or successful full-game performance validation.

## Remaining work and next justified step

The largest measured preparation cost is still **approximately 2.8 seconds of synchronous procedural generation**, followed by visual application. Profile generation before adding workers or a new streaming lifecycle. First visible frame latency (42.6 ms in the selected uncapped capture) also needs an exported release measurement with controlled first-load/first-visit conditions.

The finite world's gameplay records, colliders and actors remain resident. Existing spatial queries already bound nearby collision/steering work. Ambient animation, wildlife and other gameplay timers were not put to sleep, because changing their evolution would risk procedural/gameplay consistency without a simulation profile. Full distant-simulation scheduling, road-ribbon subdivision, long-travel memory tests, more camera rotations/resolutions and simultaneous gameplay viewports remain outside this verified pass.

No new worker jobs, pending queues, streaming pins, persistence migrations, asset dependencies, pools, renderer changes or quality reductions were introduced. There is therefore no new asynchronous reset/cancellation state to validate. Additional streaming is not justified by the measurements gathered here.

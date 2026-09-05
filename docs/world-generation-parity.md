# Seeded world generation migration

## Verified source ports

- `layout_generator.gd`: original roads, map names, villages, monuments, forests, ruins, trenches, rock formations, craters; exact source unsigned32 LCG and retry/clearance order.
- `collision_manifest.gd`: source segmented rock colliders and monument durability manifest.
- `rock_steering.gd`: source look-ahead avoidance with deterministic FNV fallback normal, integrated into combat callback.
- `road_view.gd` / `road.gdshader`: original ribbon vertices, UVs, reversed Godot winding, junction geometry and source soft alpha edge noise. Live72841 arena replaces only original hard-edged road rendering with this exact recipe.
- `generation_context.gd` / `natural_props.gd` / `rock_formations.gd`: bounded source static pools, exact runtime prop identity hashing, tree/crown/branch variants, boulders, scrub, dead trees, fences, ground cover, cliff silhouettes/strata/caps/shards. Source random draws preserved.

`tests/world_generation_test.gd`:13067 checks pass against actual TS fixtures for seeds0/72841/991827/4294967295. Scalar layout/manifest tolerance1e-8, float32 ribbon tolerance1e-4, steering1e-6.

`tests/natural_props_test.gd`:6468 checks pass against actual extracted source function calls, including RNG state, semantic IDs/HP/salvage, source matrices, and cliff collision segments. Float32 render transform tolerance1.5e-4; semantics remain doubles.

## Native full-world integration

`battlefield_features.gd`, `scatter_generator.gd`, `world_generator.gd` and the authored factory facade now build complete source worlds in GDScript. `generated_world_view.gd` reuses original primitive buffers as geometry templates; there is no Node dependency or finite baked-seed fallback for a running game.

`tests/world_builder_test.gd`:164286 checks pass for actual source seeds0/72841/991827, including every semantic prop, village, rocks, dressing counts, pool counts and representative matrices. Fixtures clone source data before source disposal so rock arrays cannot be accidentally cleared. Outer dressing radii are source1630 and pebbles1636, outer world1648.

Every Start/Restart chooses a new local unsigned32bit seed. `run_seed_override` is an explicit test injection, default-1. Main freezes input/simulation, flushes the existing profile, paints a loading curtain, builds the whole context, atomically replaces geometry/roads/colliders and rebinds world spatial/activity/ambient references. Combat, weather, support, activities and radar receive the same seed/layout. The first covered frame completes before gameplay resumes. The menu alone uses the original72841 environment before a run exists.

`tests/composed_world_seed_test.gd`:30 checks pass across2fixed composed seeds and2random new runs: full collider/prop/radar consistency, old geometry freed, bounded runtime children, safe source player spawn, ambient pause, real prop destruction, retained isolated profile and zero simulation/fuel consumption during generation.

`tests/world_rebuild_test.gd` keeps30 focused lifecycle checks. Three additional GPU MultiMesh readback checks require a display renderer and are explicitly skipped headless.

## Reference rendering

`tests/build_source_reference.mjs <original checkout>` builds a standalone actual Three reference under `/private/tmp/iron-caravan-source-reference`. Source scene lights/materials/terrain/road shaders remain unchanged; canvas only. Serve that directory over HTTP and await `window.__referenceReady`; error/details are `window.__referenceError` / `window.__referenceMetadata`. Query seed,x,z,zoom; defaults72841,0,5,31 match settled Godot camera. It is a developer test fixture; no Node dependency is introduced into the Godot game.

Headless data tests do not establish rendered visual parity or frame time. Matched source/Godot captures are a separate review.

`tests/render_reference.gd` captures an actual Godot arena and starterM4 with matched camera(34,45,39), target(0,0,5), orthographic size62 at1280x800, without HUD, intro or weather. Optional user args `x=... z=...` move the reference camera. Three fixture uses original `moduleMountPosition` so starter turret coordinates are finite.

Gameplay3D textures now import mipmaps; road sampler uses linear mipmap anisotropy8. Main/menu image import is unchanged. Actual parent render review confirmed the earlier road pixel grain disappeared; lighting calibration remains separate.

# Authored world factories

Implemented in staging, not yet evidence of deployment to the target folder.

`authored_props.gd` and `authored_monuments.gd` port all20 source facade factories: utility pole, wreck, prop cluster, well, market stall, windmill, watchtower, pumpjack, rock spire, dead grove, scrap yard, water tower, recycling factory, cargo crane, refinery, satellite array, figure, grazer, house and village. Ruined houses/villages belong to existing `battlefield_features.gd`.

Factories retain literal primitive dimensions, child hierarchy, Three XYZ rotations, cast/receive-shadow overrides, source material identities, shared LCG evaluation order including the random loop condition in prop clusters, windmill/pumpjack pivots, ambient records, semantic prop IDs/durability/salvage, village ownership, blockers and eight deployment anchors. Semantic x/z remain double precision independently of Godot's float32 render transforms.

`tests/export_world_primitives.mjs` reads original world-builder and scene material definitions and creates52 exact Three primitive buffers. Sphere helper recipes use original IcosahedronGeometry(radius,1), never Godot SphereMesh. `world_primitive_catalog.gd` shares cached source meshes/materials. Exporters are development-only; native generation uses no Node.js or original checkout.

`tests/export_authored_props.mjs` evaluates original source factory bodies with original Three helpers, independently of the port. `tests/authored_props_test.gd` compares60 source cases across seeds0,72841,991827: hierarchy, every local XYZ transform, primitive dimensions/material identity, shadows, RNG state, every prop semantic, ambient descriptors, blockers and pool counts, plus all primitive vertex buffers and clockwise index winding. Result:31187 checks,0 failures, clean Godot4.7.2 headless log `/private/tmp/authored-factories-final.log`.

Full builder gate after integration corrections:164286 checks,0 failures across three seeds (integration agent execution). During review, corrected source outer radius1648 usage in scatter by its owner, and fixed source fixture reference aliasing: disposing source world had emptied the expected rock array. All source props, pool counts and sampled transforms now agree. See `world-generation-parity.md` for renderer/collision rebinding and final composed seed gates.

Not established by these tests: pixel equality of Lambert shading in another engine, antialiasing/shadow quality, camera framing, runtime FPS, GPU warmup completion, exact cosmetic RNG interleaving, or all original weather/particle/debris animations. Those remain separate presentation and performance acceptance work.

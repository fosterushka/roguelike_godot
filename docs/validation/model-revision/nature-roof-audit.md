# Trees, house and roadside wreck

| Model | Before, visually checked | Implemented in Blender MCP | Triangles / surfaces |
|---|---|---|---:|
| Spruce | Crown formed from large pointed blobs; no branch sprays | Tapered trunk, visible radial boughs, drooping opaque needle fans, roots; no cones | 3,724 / 1 |
| Birch | Crown formed from coarse polygon balls | Forked pale trunk, individual thin broad leaves, irregular crown and roots | 3,724 / 1 |
| House | Roof panels rotated on the wrong Blender axis; ribs floated beyond the roof | Explicit closed sloping sheets, outward normals, filled front/rear gables, fitted ridge/seams/eaves and downpipes | 2,780 / 1 |
| Roadside wreck | Basic open box with wheels and a simple roof | Exposed engine and radiator, bent cab, detached door, missing wheel and loose wheel, bed seams, drivetrain and bumper damage | 4,012 / 1 |

Both tree species share the quiet bark/foliage atlas, without noisy grain or alpha transparency. They have different geometry and silhouettes. The runtime `tree` alias is handled by the gallery/model deduplication work.

The tree importer already generated LODs, but `environment_library.gd` discarded them while adding vertex colors. The library now preserves imported birch LOD index arrays and transition distances, plus the shadow mesh. The generated spruce LOD reduced its crown to 12 triangles and removed the foliage, so spruce now uses a separately authored 1,444-triangle distant crown in the same cached runtime surface. Its near and far vertex data are joined once, with separate index sets. Primary geometry is capped at 4,000 triangles; the far LOD is tested against a 2,000-triangle budget. Meshes remain cached and instanced.

The models were built and exported through the connected Blender MCP, not a CLI Blender process. Clean Blender material-preview views were inspected from front and rear for the house and wreck; tree density was corrected after the first viewport review. Godot integration captures and test results are collected in the same validation folder. `spruce-lod-before.png` and `spruce-lod-after.png` show the broken automatic LOD and repaired authored LOD from exactly the same camera, using explicit LOD index meshes for inspection. They were both personally inspected. Both primary tree meshes are normalized so the lowest root vertex rests at terrain height zero.

Latest focused results: vegetation, military environment (including root grounding), world quality, and environment LOD all pass. Logs: `nature-tests-final/` and `nature-lod-final-rerun/`. The first LOD assertion used an exact dictionary key for a float32 threshold; its corrected rerun compares approximately and passes. These tests verify geometry and runtime integration, not frame time. Final world-performance capture is coordinated separately to avoid concurrent GPU workloads.

Final coordinator tuning sets `TREE_LOD_EDGE_LENGTH` to **0.08**. `tree-lod-stats.json` was refreshed from the running Godot API after that change: spruce retains the authored 1,444-triangle index set. Final LOD verification remains **22 checks, zero failures**, recorded in `lod-final/`.

The completed `world-lod-tuned/` capture sampled 120 static-world frames: median 6.904 ms, p95 33.038 ms, 75 draw calls and 3,173,594 rendered primitives. Other Godot windows/processes changed between captures, so these figures do **not** establish an optimization gain or stable gameplay frame rate. The allegedly stuck capture finished normally. World vegetation currently uses one `MultiMeshInstance3D` per pool across the generated map; effective per-tree LOD/culling at that batch scale was not established by this inspection. No batching architecture changes were made.

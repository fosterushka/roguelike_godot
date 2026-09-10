# Actor model optimization

Historical first pass. [Current armor optimization audit](armor-optimization-audit.md).

Blender sources and runtime GLBs rebuilt on 2026-09-11.

| Asset | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| Rifleman / bazooka | 1288 | 924 | 28.3% |
| AK | 1324 | 960 | 27.5% |
| Bomber | 1264 | 900 | 28.8% |
| Seated source assembly (including bench) | 1164 | 1020 | 12.4% |
| Raider, jammer, minelayer | 44 per glass pane | 2 per glass pane | 95.5% |
| Repair crawler | 44 per glass pane | 2 per glass pane | 95.5% |

Vehicle totals fall by 126–168 triangles (3.2–4.0%) per variant. Buggy, boss, player pickup and ambulance geometry are unchanged; the pickup and ambulance already use flat panes.

The shared infantry atlas is now 256×128. Goggles, nose shading and mouth use UVs on the existing head faces. Small boot laces, pouch fasteners and intermediate limb rings were removed. Adjacent pouches were merged. Weapons, role backpacks/tools, helmet silhouette, rig pivots and shared limb meshes remain. One shared material and seven animated infantry parts remain; this change does not reduce draw calls. Windows are opaque single-sided quads using the existing glass palette UV, with no extra material or transparency pass.

## Validation

8/8 focused tests passed: military people, military enemies, crew seating, crew encounters, model deduplication, model gallery, enemy AI and loading. Architecture guard passed. People tests additionally enforce a 1000-triangle body budget, 150-triangle head budget and face-atlas UV presence.

Godot Metal / Forward+ renders at 1440×900 were compared before and after. The additional infantry view uses the default gameplay camera offset and orthographic size. These are rendered model checks, not an FPS benchmark or full gameplay playthrough. Existing stippled vehicle shadows also appear in the before captures.

- [Infantry before](validation/actor-optimization/before/infantry.png) / [after](validation/actor-optimization/after/infantry.png)
- [Gameplay scale before](validation/actor-optimization/before/infantry-game-scale.png) / [after](validation/actor-optimization/after/infantry-game-scale.png)
- [NPC roles](validation/actor-optimization/after/crew-front.png)
- [Truck before](validation/actor-optimization/before/jammerTruck.png) / [after](validation/actor-optimization/after/jammerTruck.png)
- [Exact geometry counts](validation/actor-optimization/geometry-report.json)
- [Test results](validation/actor-optimization/tests/report.json)

## Rebuild

Run Blender with `--background --factory-startup --python scripts/blender/build_people.py` for infantry. For vehicles, import `build_enemy_revision` inside Blender, call `setup(preserve=True)`, then `build_one(name, variant)` for raider, jammerTruck, repairCrawler and minelayer in each variant, followed by `finish()`.

Capture with Godot `--path . --script res://tests/actor_quality_capture.gd -- --output=res://docs/validation/actor-optimization/after`.

The original unsaved Blender scene was copied to `/tmp/npc-optimization-original.blend` before rebuilding. The GUI displays a separate optimized review scene and retains the original scene. Existing unrelated gameplay/performance edits were preserved.

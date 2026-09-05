# Visual migration parity

## Delivered and verified at source-data level

- `tests/export_visual_models.mjs` evaluates the original Three.js factories, not hand-redrawn substitutes. Rebuild with `EXPORT_WORLD=1 node --import <source>/node_modules/tsx/dist/loader.mjs tests/export_visual_models.mjs <source>` from the Godot project.
- `data/visual_models/catalog.json` records SHA-256 provenance for the original factory, detail, world, material and shader source files.
- 39 exported models, 3,963 mesh parts. Original armored crawler includes tracks, eight road wheels, wrapped tread shoes, bolts, sloped armor, cabin glazing/doors/wipers, mirrors, engine vents, exhaust shields, fuel cans/straps, roof hatch, antenna and original outlines/contact shadow. Full player AABB reproduced to tolerance 0.001 (6.6 × 4.8708 × 6.17738, including contact shadow).
- Original evolution tiers 2–4 and all 13 module factories exported. Original infantry variants (rifleman/AK/bazooka/bomber), motorcycle, buggy, shooter/kamikaze drones, enemy fortress/Leviathan, three garrison tiers, airdrop, heal cart, salvage/fuel and four projectile types exported.
- Source materials preserve color, linear vertex color, faceted normals, roughness/metalness, alpha, additive blend, emissive and backface outlines. Original shipped textures copied locally, explicitly referenced by importer/effect resources.
- Full original `buildWorld(72841)` map: 3,324 source meshes and 25,176 instances. Roads, all villages and landmarks, forests, ruined villages, trenches/craters, rock formations, grass/pebbles, fences, barrels/crates, wrecks, wells/stalls, windmills, water towers and industrial structures retain source geometry/placement. Playable source arena radius 1,248; exterior scenery extends approximately 1,630 units.
- Original terrain shader noise layers and numeric palette ported to Godot shader language. Lighting is an initial Godot approximation and needs rendered comparison.
- `world_layout.json` preserves 6,400 destructible prop records with original hp/radius/salvage and semantic mesh/instance references; `arena.set_prop_destroyed(id, bool)` hides/restores exact owned mesh parts and disables/restores existing major prop collider. This is a presentation hook, not a gameplay damage system.
- `combat_view.gd.setup(runtime, vehicle)` consumes state/events. All enemy families use bounded reusable MultiMesh pools, projectiles/pickups similarly. No geometry rebuilt per frame. Current combat transform buffers have 54,828 slots, about 2.51 MiB excluding engine overhead; geometry/materials shared.
- `set_warmup_visible(true/false)` exposes inert representative visuals for a covered render frame. It does not consume gameplay RNG, simulate attacks or grant rewards. Source-model CPU construction alone is not proof of GPU readiness.
- Pooled source-texture fireballs, blood, crater/scorch marks, muzzle flash and sparks are wired to combat events. Their lifetimes/pool limits are bounded.

## Validation

`Godot --headless --log-file /private/tmp/iron-caravan-visual-smoke.log --path . --script tests/visual_smoke.gd` passes: source crawler bounds, full world construction, enemy family mapping, state/event pools, warmup/reset and prop hide/restore. The macOS CA certificate warning is environment-level. Headless execution does not validate actual appearance, GPU timing or frame rate.

## Still pending, explicitly not full parity

- [ ] Rendered comparison with the original camera, lighting, tonemapping, shadows, material opacity and terrain coloration. Verify imported triangle winding and the silhouette at playable zoom.
- [ ] Original road side/junction alpha shader falloff; current source ribbon geometry/UV/texture is retained but edge-noise shader patch is not yet ported.
- [ ] Full runtime regeneration for arbitrary run seeds. This export is the exact fixed seed 72841, not a GDScript port of the generator.
- [ ] Tie every prop to gameplay damage, debris, salvage, collision lifecycle and run reset; the semantic ownership hook is available. Major physical props/rocks currently have coarse cylinder colliders.
- [ ] Source ambient animation (windmills, pumpjacks, trees, critters/grazers) and wind deformation. Static poses/geometry retained.
- [ ] Source soldier articulated gait/attack animation, vehicle wheel/track suspension and drone rotor animation in pooled enemy instances. Player road wheels rotate; no claim of full articulation parity.
- [ ] Evolution tier lifecycle, visual growth, module installation layouts, weapon recoil/cooldowns, jammer scan/interference animation. Source module/evolution geometry is exported but all upgrades are not yet attached by runtime.
- [ ] Leviathan component-specific visual state, break-off pieces, phases, exposed targets and destruction. All source component geometry is present, semantic component tags still need explicit export.
- [ ] Source projectile smoke trails, missile flight attitude/sabot tracers, grenade fuse/arc, fireball timing and original explosion debris. Current bounded event effects are initial Godot adapters.
- [ ] Source persistent vehicle wrecks/body fragments, blood spread timing, grass crushing/tire tracks and mud splash/drag visual state.
- [ ] Source weather cycles, rain, lightning, fog transitions, mud zones, tornado and hazardous area presentation.
- [ ] Source airdrop parachute/flare/beam/point-light lifecycle and heal cart aura/route behavior. Models exported; dynamic light objects are not encoded in mesh export.
- [ ] Complete HUD/minimap/offscreen direction indicators, labels, target bars and encounter telegraphs; managed separately from world/model export.
- [ ] Original menu background, armory preview, loadout cards and audio integration; assets may be cataloged separately.
- [ ] Export preset must include `data/**/*.json` as non-resource files so shipped offline builds retain source mesh/catalog/layout data.
- [ ] Measure GPU warmup on a real renderer, frame time with full wave and full-world visibility, memory, first explosion and first destruction; shrink pool capacities only against verified combat maxima.

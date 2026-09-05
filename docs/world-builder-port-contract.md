# Native seeded world builder split

Staging only: `/private/tmp/iron-caravan-full-cg8ddxzh`. Source reference: original `src/client/infrastructure/three/world-builder.ts` (1386 lines). The live arena still uses source72841 geometry until a complete consistent renderer+generation bridge is ready; never swap just roads/POIs and leave old props behind.

## Ownership

- visual_parity owns `modules/world/generation/generation_context.gd`, `layout_generator.gd`, `collision_manifest.gd`, `natural_props.gd`, future `rock_formations.gd`, `world_generator.gd`, renderer bridge/arena and golden tests.
- Next factory agent owns new `modules/world/generation/authored_props.gd` (or focused authored submodules), `presentation/world/world_primitive_catalog.gd`, new source primitive exporter/catalog assets if useful, factory golden tests. Do not edit context/orchestration without coordinating.
- Source factories to port: utility pole392, wreck426, prop cluster474, well515, market546, windmill579, watchtower636, pumpjack658, rock-spire706, dead-grove716, scrap-yard729, water-tower743, recycling-factory753, cargo-crane770, refinery781, satellite-array791, critter812, grazer856, house895, village943. Also ruined house1013 / ruined village1028 can stay visual_parity orchestration if agent capacity limited; message explicitly.

## Context API (already present)

`setup(seed)` creates exact layout and source world RNG (`seed ^ 0x68bc21eb`). `random.next()`, `.between(min,max)`, `.integer(min,max)` match source LCG. Preserve exact evaluation order and every RNG draw, including discarded choices and loop conditions such as `index < random.int(2,5)` re-evaluated on each iteration.

- `context.layout`: exact source arrays/fields (roads,villages,monuments,forests,ruinedVillages,trenches,rockFormations,craters).
- `context.append(pool:String, position:Vector3, rotation:Vector3, scale:Vector3)->Dictionary`: returns `{pool,instance,transform}`; instance=-1 on original pool capacity overflow. XYZ Euler order matches Three. Pool names exactly source variable names, `context.POOLS` maps source72841 geometry template index and source capacity.
- `context.structure(pool,x,y,z,width,height,depth,rotation=0,tilt=0)->part`.
- `context.rotate_offset(x,z,offset_x,offset_z,rotation)->{x,z}` uses double scalar math; `context.landmark_box(pool,x,z,offset_x,y,offset_z,width,height,depth,rotation=0,tilt=0)->part`.
- `context.register_prop(kind,x,z,scale=1,visual={},overrides={})->Dictionary` creates exact durability + source runtime ID, appends `context.props`. Visual `{parts:[part...],groups:[Node3D...]}`. Overrides use `id` for source `networkId`, `village_id` string instead of circular village object. Also radius,hp,salvage. `aggregate_destructible` suppresses inner registrations (source monument aggregation).
- `context.groups:Array`: append root Node3D groups here; keep them unparented during generation, renderer bridge will attach. Group members can retain authored hierarchy for animations. Primitive meshes use source geometry/material helpers, cache meshes/materials, no per-frame geometry rebuild.
- `context.ambient_animators:Array` and `context.ambient_critters:Array` are available for source animation descriptors.

- `context.villages:Array`, `.activity_blockers:Array`, `.landmarks:Array`, `.rock_obstacles:Array` hold source semantic data.
- `context.open_dressing_point(x,z,road_clearance=8,start_clearance=16)`, `.near_village(x,z,clearance)`, `.point_in_disc(min,max)`, `.find_open_point(min,max,road_clearance=10,village_clearance=22,start_clearance=16)` are provided.

## Authored factory facade expected

`setup(context,natural)`; methods `utility_pole`, `wreck`, `prop_cluster`, `well`, `market_stall`, `windmill`, `watchtower`, `pumpjack`, `rock_spire`, `dead_grove`, `scrap_yard`, `water_tower`, `recycling_factory`, `cargo_crane`, `refinery`, `satellite_array`, `critter`, `grazer`, `house`, `village`. Args preserve source defaults; optional random defaults must draw at call time. `house(x,z,rotation=0)` returns Node3D, `village(id,x,z,count=4)` appends village semantic record incl8 deployment anchors, tribute28+count*5 and registers all house/signal props.

`natural` already has `tree(x,z,scale=1,sparse=false,destructible=true)`, `boulder(x,z,scale=1,light=false)`, `scrub(x,z,scale=1,dead=false)`, `dead_tree(x,z,scale=1)`, `fence(x,z,rotation=0,count=5)`, `ground_cover(x,z,radius,count,flowers=false)`.

## Geometry/material fidelity

Use exact source authored primitive recipes. IMPORTANT: original `scene.ts` helper `sphere(radius,material,segments)` actually creates `THREE.IcosahedronGeometry(radius,1)`; it ignores segments. Do not use SphereGeometry. Source `mesh` helper initially sets castShadow/receiveShadow=true, then authored factories override most world meshes to castShadow=false. All world `box/cylinder/cone/sphere` factory calls have fixed numeric geometry parameters; can export source Three primitive buffers in a small dedicated catalog to avoid approximation with different Godot triangulation. Source static instanced pools already have exact buffers in `world_72841.json` indices listed context.POOLS; these are geometry templates, not finite seed layouts. `SourceModel._prepare`, `._templates`, `._material` can share original cache. Material names: iron,metal,stoneDark,woodDark,wood,enemyRed,gold,goldBright,clothRed,clothBlue,skin,sheep,stone,leaf,leaf2,grassDark,dirt. Parse original scene.ts material block as existing `tests/export_visual_models.mjs` does; don't retune source colors ad hoc.

Preserve literal dimensions, poses, localXYZ rotations and source emissive/transparent flags. Avoid helper implementations that consume RNG. Double precision semantic coordinates/hp/salvage and runtime IDs must match TS; Godot Vector3 render coordinates have expected float32 rounding tolerance. Keep semantic x/z doubles separately when house Node3D position quantizes.

## Validation and remaining integration

`tests/world_generation_test.gd` currently13067 checks exact source layout/manifest plus road ribbon/indices and rock-steering goldens across seeds0,72841,991827,4294967295. Add factory source goldens to compare RNG state, source semantic props, part counts and representative transforms. Entire arbitrary-seed gameplay rebuild is not shipped until full source builder orchestration, actor reset/rebind and collisions/visibility agree. No Node or source checkout is required at runtime; exporter is development-only.

# Actor and tree quality pass

Reference: the player pickup's authored military palette, recognizable silhouettes, visible hardware, and bounded meshes. This is a stylized geometry pass; it does not add photorealistic texture maps.

## Gaps found and fixed

| Family | Before | Blender changes |
| --- | --- | --- |
| Bike | Flat cylinder wheels, sparse engine/frame | Separate tire profile, treads, rims, hubs, lug hardware, engine cooling fins, exhaust, frame rails, strapped panniers; retained rider |
| Buggy | Simple nose and roll bars | Wheel hardware, access panels/fasteners, seat, roll brace, suspension shocks, step rails |
| Jammer/minelayer | Slab cabin, glass partly inside the hull | Shaped sloped cabin, two properly facing windshield panes, mirrors, side glass, bumper, roof hatch, doors, handles, grille, stowage detail |
| Raider | Box-like fort body | Detailed wheels, body access panels, stowage, command hatch, steps, grille, fasteners |
| Repair crawler | Plain track blocks, sparse workshop | Track shoes, wheel hardware, workshop drawers, crane cable, beacon, panels |
| Boss and removable parts | Plain hull and drive slabs | Drive shoes and wheel hardware, spaced armor, mantlet, panel/vent detail; five gameplay component anchors retained |
| Drone/kamikaze | Plain flat rotors and body | Motor hubs inside rotor pivots, landing gear, sensor gimbal/lens, cooling vents |
| Five wreck families | Generic low slabs | Collapsed versions of the corresponding real vehicle geometry; one static mesh per wreck |
| Four infantry types | Rectangular head, limbs and torso | Shaped eight-sided anatomy, helmet/goggles/face, glove and boot details, fitted vest, straps, pouches and buckles |
| Seated crew | Runtime BoxMesh bodies | Authored Blender anatomy, shared infantry helmet/face, fitted vest and kneepads, named seat parts and anchors preserved |
| Eight crew roles | Same standing appearance | Distinct tool belt, ammo carrier, backpack, fuel can, spare AT rockets, AA radio, rifleman kit, civilian scarf/satchel; same kit follows the standing torso and seated torso |
| Spruce | Four stacked solid cones | Branch whorls with irregular individual needle sprays and a narrow crown |
| Birch | Three large spheres | Forked branches, thirteen irregular foliage clusters and bark scars |

## Validation

- `actor-tests/report.json`: all seven focused suites passed before the final isolated windshield winding correction. Coordinator rerun validates final aggregate state.
- Vehicle geometry: 628–5,516 triangles, one to seven mesh parts. Regular budget 6,000; boss 7,000. Wrecks are one part each.
- Infantry keeps seven animated parts with shared left/right limb meshes. Crew kits add one mesh per visible crew member. Seat and kit libraries are read once and cached.
- `vegetation_test.gd` confirms both trees remain below 2,000 triangles and retain the existing species/pool contract.
- `actors/*.png` are Godot Metal captures. `crew-back.png` confirms distinct role equipment; actor captures also caught and led to fixing the original missing-kit and windshield issues.
- `../trees-rebuilt/trees.png` shows the actual gameplay tree provider. Its original capture harness was updated to release scene nodes before shutdown.

Raw legacy projectile primitives and non-actor world props are outside this actor-specific audit and are handled by the coordinator's world/model coverage work.

# Village decoration

Decorative standing humans are removed from both village generation and ruined villages. `authored_props.critter()` keeps the four historical random draws but allocates no mesh or ambient entity. This preserves existing seed layouts and all following prop placement. Grazing animals remain; actual combat soldiers use the independent enemy factory.

The original reference world contains 80 figures with eight meshes each. `world_decor_filter.gd` identifies their complete template using source part metadata, material colors, scale and relative positions, then hides all 640 meshes. It does not alter mesh indices or any registered destructible prop. Arena integration calls this after creating the original reference world.

Village houses, wells, market stalls and signal masts already have destructible records. All remaining non-instanced reference decoration outside those records consists of the 14 grazing animals and five terrain/road meshes. Native grass, flowers and tiny surface pebbles remain ground dressing; turning these into individual damage targets would add many records for little gameplay value. Large props already register through the natural/authored factories.

Validation: `village_decoration_test.gd` checks no native humans across three seeds, retained animals/houses/hostile soldier creation, all reference heads hidden, every registered reference prop still visible, and historical RNG consumption. Existing authored factory and world-builder fixtures pass without regeneration. These are headless scene/model checks, not a graphical playthrough.

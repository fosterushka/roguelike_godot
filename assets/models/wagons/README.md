# Military wagons

Six authored variants: cargo, repair, weapon, fuel, anti-tank and anti-air.
Each variant includes an editable `.blend`, a static `.obj`/`.mtl`, and shares
`palette.png`. Keep the OBJ, MTL and PNG together. Runtime GLBs are under
`assets/vehicles/military_wagon_<type>.glb` and include their palette.

Four wheels share one mesh; the body, variant detail and steering drawbar use
three more mesh resources. Each variant uses one material and 1,624–1,672
triangles. Exact bounds and counts are in `stats.json`.

Godot coordinates: front +Z, ground Y=0, tires radius 0.88; axle centers X=±1.8,
Z=±1.55. The drawbar attaches at (0,0.95,1.55), with hitch 1.7 forward of it.
Three raised mounting plates leave room for two rear bench seats and footrests.
The same models and slot positions are used in the game and Armory.

Rebuild from project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python scripts/blender/build_wagons.py
```

# Military wagons

Six authored variants: cargo, repair, weapon, fuel, anti-tank and anti-air.
Each variant includes an editable `.blend`, a static `.obj`/`.mtl`, and shares
`palette.png`. Keep the OBJ, MTL and PNG together. Runtime GLBs are under
`assets/vehicles/military_wagon_<type>.glb` and include their palette.

Wheel geometry is shared. Exact bounds, triangle counts and material counts
for each export are in `stats.json`; old one-material and 1,624–1,672 triangle
figures no longer describe these assets.

Godot uses Y-up and front +Z. The runtime adapter in
`presentation/vehicles/military_wagon.gd` owns the model connection;
`modules/caravan/caravan_formation.gd` owns coupling and movement.
Gameplay and Armory reuse the same model builder and attachment positions.
Preserve wheel, drawbar and mounting node contracts when rebuilding.

Rebuild from project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python scripts/blender/build_wagons.py
```

Current caravan and model rules: [project guide](../../../docs/PROJECT.md#караван-и-экипаж).

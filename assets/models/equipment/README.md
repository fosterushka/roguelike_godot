# Military equipment

The equipment library uses a shared packed palette. Exact model IDs and mesh
counts are recorded in `stats.json`. Weapons have separate static and moving parts. The runtime adapter gives guns
an elevation pivot and recoil while the mounting plate stays fixed.

- `equipment.blend`: editable library, one named root per equipment type.
- `<type>.obj`, `<type>.mtl`, `palette.png`: individual portable exports.
- `stats.json`: measured triangle and mesh counts per model.
- Runtime: `assets/vehicles/military_equipment.glb` (embedded palette).

Rebuild from project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python scripts/blender/build_equipment.py
```

Blender Z-up, forward -Y; Godot Y-up, forward +Z. Equipment mounting plane is
Y=0 in Godot. Gameplay and Armory share the same equipment factory and slots.

Current gameplay ownership and shared model rules: [project guide](../../../docs/PROJECT.md#модели-и-загрузка). `armor_panels` uses the canonical armor model; do not restore the removed duplicate from an older count.

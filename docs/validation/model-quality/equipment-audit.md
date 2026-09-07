# Equipment and convoy model audit

Reference: Blender-authored military player pickup, shared 32px palette, readable
mechanical silhouette, panel relief and separate animation pivots.

Completed:

- All 25 equipment library entries: chamfered main panels and role-specific details.
  Rifle receivers/stock/optics, recoilless launcher collars and sights, anti-tank
  recoil mechanism and muzzle brake, twin AA cooling jackets/radar grill, rotary
  gun motor/collars/feed, grenade drum, flamethrower hoses, railgun coils,
  missile housing, antenna fins, pump gauge, crane pins/piston, workshop tools,
  armor relief, winch and crate handles.
- All six wagon variants: chamfered bodywork, leaf springs, dampers, axle braces,
  mudflaps, latches and rear lamps. Existing silhouettes, seats and mount space
  preserved. Wheels still share the player tire mesh.
- Heal cart: replaced box stack with a raked ambulance cab, front/side glass,
  doors, mirrors, grille, bumper, lamps, medical beacon, rear service doors,
  suspension and treaded wheels with hub bolts.

No added runtime mesh nodes for decorative details. Equipment retains BASE and
MOVING batches, trailers retain steering/wheel/hitch anchors, heal cart retains
four Wheel_* nodes. Editable .blend, OBJ, palette and runtime GLB regenerated.

Blender studio captures: equipment-blender.png, wagons-blender.png,
heal-cart-blender.png. These establish authored appearance; game mounting and
animation are separately checked by Godot convoy/field/wheel tests.

Unchanged by this scope: legacy gallery source meshes, NPCs and world props
(other parallel workstreams own those). Player remains the quality reference.

Final small-prop pass: fuel can cap/ribs/latches (572 triangles), salvage crate
corner guards and shaped scrap (608), all three mine colors share bolted cases
and fixing tabs (616 each). Factory gets wall vents, door ribs, roof housings and
an access ladder inside its existing footprint (3692). Heal cart was reduced from
8580 to 4740 triangles by removing unnecessary chamfers from tiny tire tread
blocks, preserving the existing 5000-triangle test budget.

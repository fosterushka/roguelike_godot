# Convoy asset validation

- Full Godot headless suite: 82/82 clean (`headless-report.json`).
- Final wheel, geometry, seat and loading checks: 4/4 clean after the last wagon export.
- Seat check: clean after final bench support adjustment.
- Real Metal render: `tests/convoy_assets_capture.tscn`, three images saved, exit 0, no engine errors.
- Capture contains six wagon variants, ten attachments, fourteen equipped modules and four seated passengers.
- The capture uses a temporary profile; user save data is untouched.

`gameplay-pickup-wagons-crew.png` shows the pickup and first trailers close up.
`equipment-and-wagons.png` shows the complete equipped train.
`attachments-all-wagons.png` shows trailer attachment loadouts before adding all modules.

Authoring exports: `assets/models/wagons/` and `assets/models/equipment/`.

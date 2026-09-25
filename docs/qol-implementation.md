# Gameplay and preparation QOL · 2026-09-12

## Player flow

Garage opens the owned convoy. Select the pickup to tune it or a trailer to
inspect a specific mount. Base and field mount selectors use the same component;
occupied mounts remain selectable for inspection/removal. Field weapon progression
and the distinction between base credits and raid scrap remain intact.

Supplies use compact paired inventories, a shared quantity selector, and a fixed
selected-item description. The model provides the current transfer limit/reason.
The previous departure's supplies can be refilled atomically from existing stock.
UI refresh restores the selected item, keyboard focus and scroll position.

The pickup supports purchased road/mud tires and fog lamps, cosmetic paint and
emblems, and three saved convoy/tuning sets. A set references existing trailers
and crew; it never recreates lost property or copies installed equipment.

## Ownership

- `vehicle_customization.gd` is the definition source for upgrades, effects and
  appearance choices. `caravan_roster.gd` owns purchases/selections/sets through
  existing profile transactions. `caravan_save.gd` normalizes stored data.
- `WheeledRig` and `customization_view.gd` build the same configured pickup for
  previews and gameplay. Per-instance paint retains the authored palette texture;
  shared materials and meshes are not recolored in place.
- `visibility_rules.gd` owns directional lamp coverage and weather-adjusted target
  acquisition. Shader uniforms are supplied from these definitions. Equipped lamps
  replace depth fog with a depth-aware local pass; unequipping restores native fog.
- `occlusion_fade.gd` checks parallel orthographic camera rays for the player and
  nearby detected hostiles. `arena.gd` owns visual proxies, original instance
  visibility, movement notifications and destruction. Collision state is independent.
- Activities own the pinned reachable primary objective and raid-local aftermath.
  A saved settlement offers a proximity-gated, one-use hull repair through the
  same activity owner. Full health keeps the service available.
- `extraction_departure.gd` animates the vehicle view after the result has been
  saved. Authoritative poses and combat remain paused; attached trailers and crew
  follow the visual offset. Save failure opens retry immediately.

## Validation and report

Headless behavior checks are registered in `tests/run_all.py`. Dedicated tests
cover six-wagon boosted road travel at multiple timesteps, purchases and disk
reload/rollback, inventory capacity/quantities/refill, and lamp/occlusion lifecycle.

Real render helpers:

- `tests/qol_ui_capture.tscn`: RU/EN, 960×600 and 1280×800.
- `tests/visibility_qol_capture.tscn`: lamps off/on/turned, player/enemy/building
  occlusion comparisons, using the actual seeded game and its components.
- `tests/vehicle_customization_capture.gd`: shared models in an inspection scene.
- `tests/qol_activity_capture.tscn`: extraction, objectives and raid aftermath.

Generated evidence lives in `docs/validation/qol-audit/` (intentionally ignored).
The portable HTML embeds its PNGs and includes the exact consolidated test results,
baseline failures, capture provenance and verification limits. Build it with
`scripts/build_qol_audit.py --full <report.json> --recheck <report.json>`;
`--recheck` may be repeated and `--baseline` attaches isolated-HEAD evidence.

No deployment, separate macOS export, sustained performance comparison or long
balance playtest is implied by these automated and rendered checks.

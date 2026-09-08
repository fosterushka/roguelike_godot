# Vehicle terrain suspension

The previous solver computed terrain pitch only for the uphill speed modifier, forced roll to zero, and animated wheel travel against a level chassis.

The shared suspension solver now springs pitch and roll toward the four sampled wheel heights while preserving acceleration/braking load transfer. Vertical support and compression stops use the tilted hub mounts. Wheel hubs retain steering/spin and upright tire axes; their travel is relative to those mounts. Pose interpolation includes terrain roll. Shared damper meshes connect fixed body mounts to moving wheel mounts for the pickup and trailers.

The horizontal movement controller, steering rules, collision shape and terrain sampler are unchanged. This remains the existing sampled-terrain vehicle model, with bounded suspension travel and body tilt, rather than a full rigid-body vehicle simulation.

Validation (2026-09-08):

- 11/11 selected suites passed through `tests/run_all.py`: wheel_vehicle, vehicle_response, vehicle_motion, vehicle_render_runtime, caravan_formation, tire_trails, military_pickup, convoy_assets, model_dedup, tornado_interaction, caravan_integration.
- 36 slope/heading/scale combinations cover pickup and trailer tire contact plus both damper endpoints. Moving one-sided bump checks cover 30/60/120 Hz, compression limits, ground penetration and settling.
- Real Metal Forward+ render: `tests/vehicle_terrain_capture.gd`; captures in `docs/validation/suspension-terrain/`. Flat, uphill, side slope, diagonal slope, single-wheel obstacle, transient frames and recovery. On the 20% side slope roll settled to 11.31 degrees; all four contacts remained supported. Recovery returned pitch/roll to zero.
- Logs: `/tmp/vehicle-suspension-final/report.json`, `/tmp/vehicle-terrain-render-final.log`.

The complete project suite and a long manual driving session were not run.

## Airborne response and controls

Spring damping now uses relative support/mount velocity and softer damping. Uphill motion carries vertical momentum over a crest. There is no average-terrain height clamp; only compression stops prevent penetration. Ground support speed is bounded at discontinuities. Without contacts, gravity controls vertical velocity and terrain stops steering body pitch/roll. Unloaded wheels hang at free spring extension instead of stretching down to the ground.

Space (and the existing Shift alternative) holds the handbrake, including stopping with throttle held. F activates the selected ability; E interacts; Q or left click selects a target. Space is consumed before focused gameplay/armory buttons can activate. English and Russian pause hints match the bindings.

Validation for this follow-up: airborne/terrain/response/render-runtime/formation/trails tests, motion parity/controller tests, HUD layout, mine interaction, and the assembled offline session passed. The latter verifies that Space does not activate nitro and F does. At 14 m/s over the test crest, pickup airtime is approximately 0.25 s and minimum wheel clearance reaches 0.47 m; at 3 m/s it stays grounded. Tests cover 30/60/120 Hz, gravity-only flight, wheel separation, landing and pause.

Metal render captures include `jump-airborne.png`, `jump-landing.png`, `jump-settled.png`, and `controls-en.png` / `controls-ru.png`. No long manual playthrough was performed.

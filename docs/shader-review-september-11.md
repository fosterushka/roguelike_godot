# Shader review, 2026-09-11

Reviewed all 22 `.gdshader` files and the shared fireball include in `presentation/`.

## Implemented

- `ui/jammer_vhs`: broadband monochrome static replaces tracking, scanlines, frame offsets and RGB separation. One screen texture sample instead of three. Integer pixel hashing avoids visible repeating stripes. Lens droplets skip geometry calculations in inactive cells and skip the whole branch in dry weather. Jammer entrance/exit fades are 0.65/1.0 seconds, with smoothstep applied to the shader strength.
- `ui/screen_desaturation`: sepia with 0.8/1.2 second entrance/exit fades, a centered localized pulsing warning, and no active screen copy after fade completion. Pause hides the pass and freezes its transition. World boundary state remains authoritative.
- `world/weather_rain`: uniform color mixing runs per vertex instead of per fragment. Particle count, frustum coverage, streak shape and depth occlusion are retained.
- `world/weather_mist`: reject fragments whose maximum possible opacity is below the existing threshold before computing two noise octaves.
- `combat/fx/rocket_smoke`: reject subthreshold opacity before computing procedural curl and density.
- `combat/fx/dust`: rotate UVs and calculate uniform color per vertex instead of per fragment; affine UV interpolation preserves the shape.
- `world/tornado_skirt`: reject the empty eye and pixels beyond the maximum perturbed radius before noise evaluation.
- `world/tornado_overlay`: integer-cell noise reduces exactly to its first hash; use that hash directly for flecks.
- `world/road`: reject fully transparent edges before sampling the road texture.

## Reviewed and retained

`ink_outline`, `rock_detail`, `tornado_particles`, `weather_splash`, `hemisphere_sky`, `terrain`, `tornado_funnel`, `burning_hull`, `tire_tread`, `fireball`, `fireball_core`, `smoke`, `countdown_blur`, and the shared fireball include retain their existing rendering rules. Their remaining sampling, noise, vertex animation, color conversion and blur serve the current appearance. This pass does not reduce effect density or remove noise octaves merely to change every file.

## Validation

- `tests/run_all.py`: architecture guard and 8/8 focused scripts passed: boundary screen, jammer feedback, weather transition, world presentation, source FX, ground surface, tire trails, tornado interaction. Logs: `/private/tmp/shader-tests-final`.
- Real Metal Forward+ rendering: `boundary_screen_capture.tscn` completed with six captures, including intermediate entry/return, full sepia, simultaneous static/lens rain, and restored scene colors. Output: `/private/tmp/iron-boundary-*.png`.
- Real Metal Forward+ rain coverage: 38 checks, zero failures. Normal/ultrawide/zoom-and-drag coverage, frozen positions and opaque occlusion passed. Output: `/private/tmp/iron-rain-coverage-*.png`.
- Main-scene warmup completed without shader errors. The captures validate rain and screen appearance; the other shader edits preserve their mathematical output but have no dedicated before/after visual comparison here.
- No controlled before/after GPU timing or sustained gameplay FPS benchmark was performed. Reduced source operations are not an FPS measurement.

Existing staged work and concurrent unrelated edits were preserved.

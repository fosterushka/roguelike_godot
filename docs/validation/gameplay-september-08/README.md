# Gameplay and weather update, 2026-09-08

## Implemented

- Starter top speed is 50 km/h off-road and 75 km/h on roads. Upgrades, weight, weather and empty fuel still modify speed. Vehicle presentation and driving share the same speed calculation.
- Survivors require E or clicking the existing E prompt within 5 metres. The prompt is outlined nearby and dimmed farther away. Opening dialogue no longer happens automatically.
- Driving away during a recruit's approach triggers a seeded 5–10 second boarding refusal after 3 seconds of chasing, with a sad face and five English/Russian offended lines. Climbing cannot teleport a recruit into a departed vehicle.
- Eight survivors are distributed around the playable circular world, at least 180 metres from the initial player position. Obstructed destinations are rejected early; failed navigation routes wait briefly before another search.
- Leaving the playable world makes the entire gameplay screen grayscale. Returning restores color; menus and a new run clear/hide the effect.
- Blender MCP rebuilt spruce as four solid cones and birch as three solid spheres. Trees share their material; the redundant distant spruce model was removed.
- Dropped items resolve their identity before collection and display their actual inventory model, localized name and quantity. Scrap and item drops share their rotation/bobbing component. Crew cargo preserves the displayed item identity.
- Root `AGENTS.md` records shared constants, catalogs, models, components, factories and builders as project conventions.
- Rain now covers the camera viewport, including wider aspect ratios, zoom and camera displacement. Rain keeps depth occlusion, wind, weather fades and pause behavior.
- Night uses brighter blue moon/ambient light. In fixed-scene captures, mean displayed night luminance increased from 0.198 to 0.373 in clear weather, 0.155 to 0.345 in rain, and 0.139 to 0.328 in storms. These image averages are visual comparison metrics, not physical luminance units.
- Existing oil pump stations now drop 36 units of physical fuel plus their existing scrap when destroyed by rewarded player damage. Existing fuel models, collection and full-tank behavior are reused. Passive refueling stops when the station is destroyed; a new run restores the station.

## Automated validation

[Consolidated report](report.json): 99/99 unique headless test files have clean results. The initial full run was 96/98; two tests still assumed the previous speed and near-start survivor placement. After updating the tornado speed assertion, correctly parking the test convoy, and fixing repeated blocked path searches, focused reruns passed. Follow-up weather and station tests also passed. The report retains the source run for each result; it is not one uninterrupted final run.

Key additional evidence: crew runtime 41/41, encounters 49/49, seating 43/43, caravan integration 39/39, loot 26/26, fuel station 26/26. Final coordinator weather/boundary/station selection: 6/6 files clean. `git diff --check` is clean.

## Rendered validation

Godot 4.7.2 using Metal on Apple M4 Pro; screenshots inspected:

- [Nearby E](crew-calling-nearby.png), [dimmed E](crew-calling-distant.png), [offended recruit](crew-offended-en.png).
- [Simple trees](../trees-rebuilt/trees.png), [named loot models](../loot/items-en.png).
- [Grayscale boundary](iron-boundary-outside.png): four captures verified color/grayscale by sampled rendered pixels, including simultaneous rain and jammer effects.
- [Old night](iron-night-sunny-night-before.png), [new night](iron-night-sunny-night-after.png), [storm night](iron-night-storm-night-after.png).
- [Rain coverage evidence](../rain-coverage/README.md): 38 GPU checks, all nine screen sectors populated, paused frames identical, opaque blocker fully occludes rain; actual rain/storm scenes inspected.
- [Intact pump](../fuel-stations/pump-intact.png), [fuel after destruction](../fuel-stations/pump-fuel-dropped.png).

Capture scripts are in `tests/`: `boundary_screen_capture`, `crew_encounter_capture`, `tree_revision_capture`, `raid_loot_capture`, `night_lighting_capture`, `rain_coverage_capture`, `rain_world_capture`, and `fuel_station_capture`. GPU captures are separate from the headless manifest. These checks do not establish long-session performance, play-feel, audio or an exported macOS package.

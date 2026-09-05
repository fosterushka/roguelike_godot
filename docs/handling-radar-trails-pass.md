# Handling, radar progression and tyre traces

2026-09-05. Candidate: `/private/tmp/iron-godot-finish-9siuihzq`.

The previous wheel-vehicle delivery is installed in `/Users/fosterushka/Work/vibe/roguelike_godot/new-game-project` (verified by hashes before this pass). New changes are prepared in the candidate because the target remains read-only for this session.

## Radar

The base map reveals only an18m neighbourhood and does not detect hostiles. Installing Radar Array starts at40m. Three further upgrades increase range to90m,160m and260m. Costs are55 for installation, then45,70 and100 scrap. The final tier reaches100% rated coverage. Fog and jammers still reduce effective range.

Armory shows the installed MK, current range, next range/cost, and a disabled maximum-level button. Domain validation refuses skipped levels, stale repeat clicks, insufficient funds and upgrades before installation. The module retains its mount while upgrading.

Map exploration uses finer216x216 cells. Contiguous revealed cells are drawn as row strips without bridging unknown gaps. A fully explored81x81 region needs81 polygons before clipping instead of6561 individual cell polygons. This is a verified reduction in geometry submissions, not a measured FPS increase.

## Handling and traces

Vehicle position previously used render-frame smoothing while heading/height snapped to physics, and the camera aimed at a different unsmoothed target. Player and trailers now keep previous/current physics poses and interpolate position, yaw, wheel travel and wheel rotation together. The camera follows that rendered pose and smooths look-ahead rather than lagging behind the chassis. Physics uses the controller's current motion, not an older player snapshot.

Steering response rises at24/s, the extra yaw smoothing stage is removed and ordinary tyre grip is stronger. Maximum speed, braking, reverse and handbrake remain governed by the driving rules. Stationary cars still cannot turn in place. Collision radius is changed only when vehicle size changes, avoiding repeated shape updates.

Car and trailer bodies use yaw-only bases with uniform scale; suspension pitch/roll and impact tilt do not rotate the body. The drawbar rotates without being stretched. Independent tyre contact travel and steering remain visible.

New deterministic tests cover30/60/144 render rates. A separate real headless engine loop caps rendering at60 and144 with60Hz physics, feeds real Input actions, and checks vehicle/camera positions. It confirms that the manual interpolation fraction works with the current project settings and motion advances between physics ticks. The test allows valid60Hz phase locking. This is not a rendered FPS benchmark.

Tyre traces now use a procedural tread shader with chevron blocks, shoulders, channels and edge breakup. Five surface palettes cover sand, soil, road, wet mud and ash. Terrain noise classification matches the ground shader formula; roads use a spatial index, and current mud/scorch footprints override the ground class. Existing trace colors stay stable.

Marks are spaced by distance along individual wheel paths, including steering front wheels and trailer wheels. The sampler carries unused distance between updates, produces the same trace positions for different update counts, and suppresses marks while idle, airborne or teleporting. A single gameplay MultiMesh retains at most1800 marks and submits at most128 new marks per update. The tread shader gets a separate covered warmup instance with the same material and instance attributes; this does not consume gameplay marks or random state.

Tyre material priority is-1, above the other ground overlays and below ordinary airborne transparency. Depth testing remains enabled. Ground clearance starts at0.04m and increases only enough to keep each corner above the sampled terrain, including triangle boundaries. Raised buildings, actors and coins still occlude tyre marks.

Graphical driving feel and final shader appearance require a rendered check; headless does not establish either.

## Verification

Final strict headless suite: **44/44 scripts clean**, with stdout and engine logs in `validation/handling-headless/` and `validation/handling-headless-report.json`. The new tests cover radar progression, GUI upgrades, vehicle response, the real engine interpolation loop and tyre traces. Shader pixels and driving feel have not been manually inspected.

Updated offline PCK: `build/iron-caravan.pck`, 29318504 bytes, SHA-256 `7a7456add0ef630b010bfc169220e537a8bdb22c8496f448b7b7d9c410a488d0`. Separate-folder runtime smoke completed with **0 failures**, clean stdout/engine log. It checks menus, EN/RU,18m base map, radar installation and all tiers through260m, wheel model preparation, generated run and Armory. Pack startup loads72 resources and81 JSON files.

The editor export still logs sandbox errors reading the macOS certificate keychain and saving global editor settings; these are preserved in `validation/handling-export.log`. The separate pack runtime is clean. No standalone macOS application export or GPU performance improvement is claimed.

## Installation

The installer verifies hashes, refuses conflicts and backs up replaced files:

```sh
python3 /private/tmp/iron-godot-finish-delivery/apply_changes.py --apply
```

Run this in a user terminal or a session where the Godot target is writable. Source, tests and documentation are included; editor cache, build output and the local certificate override are excluded.

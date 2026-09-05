# Wheel vehicle and gameplay feedback, 2026-09-05

Исторический отчёт. Этот пакет уже установлен; текущие изменения управления, радара и следов описаны в [handling-radar-trails-pass.md](handling-radar-trails-pass.md).

Candidate: `/private/tmp/iron-godot-finish-9siuihzq`.
Target: `/Users/fosterushka/Work/vibe/roguelike_godot/new-game-project`.

The previous UI delivery is already present in the target. Its editor-saved `project.godot` has been preserved. This new pass is prepared separately because the target is read-only in this session. Installation is not claimed.

## Changes

- Wet explosion mud previously inherited the altitude of a rocket hit, producing a horizontal texture through the vehicle. Mud now projects onto the terrain. Mud, blood and crater triangles conform to the actual ground triangles with depth testing enabled. Wheel traces follow surface height and normal. Airborne explosions and smoke retain their height.
- Mud textures are selected by stable zone ID, so retiring an earlier pool entry cannot change a surviving patch. Ground winding is checked against Godot's PlaneMesh.
- The selected ability slot has a bright three-pixel border and amber background, including cooldown and hover states.
- Airdrops emit actual credited scrap, XP and fuel, plus the unlocked blueprint ID/name. A separate eight-second receipt survives wave announcements and pauses, switches EN/RU, and clears on restart. It explains that blueprints are installed in Armory.
- The basic map remains available from the start. Hostile map contacts and enemy edge indicators require Radar Array. Detection respects its range, fog and jammers. Supply and objective guidance remains available immediately.
- The player vehicle is a detailed wheeled armored car. Both car and trailer have four wheels, steering front wheels, wheel tread, hubs, suspension struts and mounting points. The old trailer type ID remains compatible with existing progression data; its active appearance and shop name are wheeled.
- Ground geometry, heightfield collision and wheel support use the same terrain sampler. Roads and prop footprints are flattened. Spring/damper suspension controls body height, pitch and roll. Acceleration, steering load, ground contact and traction affect the vehicle; wheels do not use idle time bob. Trailer drawbar and axle distances remain constrained while turning.
- This is a four-contact suspension model with kinematic horizontal vehicle collisions, not a separate RigidBody for each tyre or a full articulated rigid-body drivetrain. Trailer terrain response is simulated; obstacle collision impulses through a physical hitch are outside this pass.
- Dynamic enemies, pickups, mines, support, wrecks, targeting and projectile ground impact use terrain height. Existing player height is not added twice.
- Armory uses compact tiles and a large vehicle preview. Drag rotates, the wheel zooms, and Reset view restores the camera. Carrier/slot selection installs purchases at the selected mount. Invalid or occupied mounts do not charge currency. Models and mounted equipment remain visible in the preview.
- Both procedural wheel rigs and the new player destruction parts enter covered loading preparation. CPU preparation is verified; reduced first-use GPU frame time is not claimed.

## Verification

Result: **39/39 test scripts clean**, comprising a full run and five targeted rechecks after the final CPU transform helper extraction. The initial wheel test attempted dummy-renderer MultiMesh readback and failed; final tests use the production CPU transform builders for headless height assertions. The original failure is preserved separately in validation logs.

Validation results are recorded in `validation/wheel-feedback-headless-report.json` with stdout and engine logs in `validation/wheel-feedback-headless/`.

The full gate checks script/engine errors as well as exit codes. UI tests dispatch viewport pointer events for tile selection, rotation, zoom, reset and purchases. Mount dropdown selection uses its signal in the automated test. The purchase chain checks currency and the mounted trailer weapon.

Headless uses the dummy renderer. It cannot verify final pixels or read back MultiMesh transforms reliably. CPU geometry, contact maths and UI interaction checks are separate from graphical validation. No current rendered screenshot, manual driving/balance session, GPU performance pass or standalone macOS application export is claimed.

## Offline pack

Updated PCK: `build/iron-caravan.pck`, 29304096 bytes, SHA-256 `53305cb986ae91c715d92a91aa3e79cbf60205a8d298f8b20a81c24c3c45f601`. It starts from a separate folder containing only the pack, external smoke script and test-only system certificate configuration. The smoke checks EN/RU menus, generated run start, basic map without enemy contacts, the four-wheel player, procedural rig preparation, compact Armory and language-free upgrade screen: **0 failures**, clean runtime stdout/engine log.

The editor export produced the pack but logged sandbox errors reading the macOS certificate keychain and saving global editor settings. These are retained in `validation/wheel-feedback-export.log`; export is not described as error-free. The independently launched pack runtime is clean. A standalone macOS application still requires installed export templates and a separate launch check.

## Install and run

The prepared installer checks hashes, refuses conflicts, and backs up replaced files:

```sh
python3 /private/tmp/iron-godot-finish-delivery/apply_changes.py --apply
cd /Users/fosterushka/Work/vibe/roguelike_godot/new-game-project
/Users/fosterushka/Downloads/Godot.app/Contents/MacOS/Godot --path .
```

The `--apply` command must run in a user terminal or a session with this target as a writable workspace. New files are included; `.godot`, local build output and the test-only CA override are excluded.

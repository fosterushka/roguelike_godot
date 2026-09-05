Текущие UI-исправления и проверка35/35: [ui-repair-pass.md](ui-repair-pass.md). Ниже предыдущий проход.

# Completion pass, 2026-09-05

Working copy: `/private/tmp/iron-godot-finish-9siuihzq`.
Target: `/Users/fosterushka/Work/vibe/roguelike_godot/new-game-project`.
This pass is not installed: target is read-only in the active workspace.

## Implemented

- Compact rectangular HUD; controls help lives in pause. Pause fully covers and hides gameplay controls, including touch and minimap input. Restart is a pause button; `R` has no restart binding.
- English on a fresh launch, selectable Russian in main/pause menus, persisted language. Catalog descriptions, loadout, upgrades, result and in-game labels use the shared locale adapter.
- Camera-aligned rectangular minimap: clipped roads/fog cells, boundary and extraction markers, XZ contact distance, friendly-jammer filtering, consumed villages/completed activity filtering, paused zoom lock. Perspective and orthographic edge pointers keep their respective projection semantics.
- Dynamic mine pulse, hacking bar and expiry; embedded spent projectiles; counter-rotating fireball layers; dust pixel ratio; enemy wheel hit scale; source wreck smoke identity.
- Actual generated world overview and close village/landmark views render under the loading cover. Camera processing stops during preparation and its state is restored. Headless does not claim rendered views. All shader resources and includes are listed in the loading manifest.
- Hemisphere sky/ground ambient lighting replaces the flat ambient color. Source colors and light intensity are retained; Godot sky convolution is still a renderer approximation and needs a fresh visual comparison.

## Verification boundaries

**Final strict headless gate: 32/32 passed**, zero engine/script errors. Results: [report](validation/completion-headless-report.json); per-test logs: `validation/completion-headless/`. This includes 32 minimap checks, 23 UI pointer/language checks, 12 complete menu language-flow checks, 35 presentation-detail checks and 11 loading checks. The full gate includes six-wave controlled victory and combat soak.

**PCK resource export verified** from `/private/tmp/iron-finish-pack-only`, containing only PCK, external verifier and temporary certificate override. Menu, English/Russian switch and generated run started; all 70 resource and 81 JSON entries loaded. Exit 0, `Offline pack: 0 failures`, clean stdout and engine log. The source Godot project and TS project were not the launch working directory. Artifact: `build/iron-caravan.pck` (29,250,812 bytes). Requires the Godot engine; not a standalone application.
Headless verifies behavior and loading, not GPU timing, appearance, audible sound or a human playthrough.

Shell graphical Godot exited 134 in this environment. MCP accepted a graphical test launch, but automatic approval rejected `get_debug_output` because approval is required and policy is `never`. Existing `/private/tmp/iron-caravan-render-*.png` files predate this pass and are not evidence for these changes. No current graphical success is claimed.

The previous 826 ms settlement / 140 ms shot spikes are historical measurements. Covered whole-world rendering addresses a missing preparation path, but eliminating those spikes needs a fresh graphical benchmark.

The sandbox cannot access the macOS system certificate store. Tests use a temporary `override.cfg` pointing to the readable `/etc/ssl/cert.pem` system bundle. This avoids the environment startup error while retaining the strict engine-log gate. This override is excluded from export and delivery.

macOS export templates are absent. A PCK can be exported and checked separately using the installed Godot engine; it is not a standalone macOS app. The editor also reports inability to save global editor settings in this sandbox; export artifact verification is tracked separately from that error.

## Engine references

- [Godot pipeline precompilation](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html): mesh/node preparation and covered rendering address different first-use stages.
- [Sky shaders](https://docs.godotengine.org/en/latest/tutorials/shaders/shader_reference/sky_shader.html): a sky provides radiance for ambient illumination.
- [TLS bundle setting](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-network-tls-certificate-bundle-override): test-only use of a readable system certificate bundle.

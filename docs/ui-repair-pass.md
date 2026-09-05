# UI and explosion-depth repair, 2026-09-05

Исторический отчёт предыдущего UI-прохода. На начало следующего прохода его код уже присутствовал в основном проекте. Новые изменения и актуальное состояние установки: [wheel-vehicle-feedback-pass.md](wheel-vehicle-feedback-pass.md).

Current runnable copy: `/private/tmp/iron-godot-finish-9siuihzq`.
Pre-change snapshot: `/private/tmp/iron-ui-baseline-pp1blcm9`.
The original Godot folder is still read-only in this session; these edits are not installed there.

## Player-facing changes

- Three compact ability slots, total330x54: key, name, simple drawn icon, availability and cooldown. Clicking a slot selects and activates it in one action. Keyboard1/2/3 plus Space remains available. Disabled states explain missing bumper, cooldown, full hull or insufficient scrap.
- Bottom-left vertical panel: HP, fuel, speed, currency, level/XP, kills/time and compact Armory/Pause buttons. Top center contains wave/hostile count and announcements. Basic map is bottom-right.
- Explicit main menu with Start, Sound, Quit and language selection. Removed contract/loadout menu routes. Internal progression data is preserved; no save migration/deletion. Upgrade and result screens have no language button. Pause retains language settings.
- Main menu buttons have a measured unclipped hit area; the ScrollContainer reserves enough space for every action.
- Map visible from the start:90m basic nearby detection/exploration; purchased radar extends detection to260m. Same camera-aligned projection and fog exploration.
- Up to6 labeled edge hints: focus, boss, nearest hostile, priority target, activity, supplies/rescue and extraction. They avoid current HUD rectangles and disappear under menus.
- Countdown uses original2.65s thresholds and displays3,2,1,RIDE!, Prepare the crawler/Break the siege captions, amber96px glyph, darkened/blurred background, pulse and300ms fade. Russian captions included. The previous numeric0 is gone.
- Scorch/blood marks stay horizontal. Their random rotation now uses the plane's local Z after its ground rotation; old XYZ Y rotation tilted marks upright through enemies/coins. Ground marks keep depth testing and deterministic chronological alpha ordering. Reused pool entries reset material draw state. Fireballs use ordinary transparency ordering instead of global positive priority.

## Validation

**Final strict full headless gate:35/35 passed**, clean stdout and engine logs. [Report](validation/ui-repair-headless-report.json), per-test logs in `validation/ui-repair-headless/`. Focused totals: HUD24/24, map/edge46/46, depth297/297, countdown12/12, menu/language and composed-run tests also clean. The runner checks both stdout and engine logs and rejects engine errors even when Godot exits0.

Focused checks cover three HUD viewport sizes (960x600,1280x800,1920x1080), actual pointer routing, localization, main menu hit areas, always-on map, edge hint placement, grounded/scar material state across40 collision events and24 retained marks, countdown sequence/fade, and the composed six-wave run without contracts.

The rebuilt PCK was launched from `/private/tmp/iron-ui-pack-only` with only the package, external test script and test-only system-certificate override. It loaded all71 resource and81 JSON manifest entries, switched EN/RU, started a generated run with the basic map and hid language settings in the upgrade screen. Exit0, `Offline pack: 0 failures`, clean stdout and engine log. It requires the installed Godot engine; it is not a standalone macOS app.

Automatic approval denied Computer Use access to Godot (`Computer Use was not approved to use Godot`). Rendered appearance and GPU depth behavior could not be checked in this pass. Headless plane geometry/material checks do not substitute for a graphical comparison. Historical screenshots/benchmarks are not current validation.

## Source references

- Original countdown content/layout: TS `src/client/presentation/screen-ui.ts`, `public/index.html` gameplayTransition; thresholds: `src/client/contexts/session/index.ts`.
- Godot letter spacing uses [FontVariation](https://docs.godotengine.org/en/stable/classes/class_fontvariation.html); the source UI's desktop font is approximated with the local system font.
- Explosion plane conversion and tests: `presentation/combat/impact_effects.gd`, `tests/ground_effect_depth_test.gd`.

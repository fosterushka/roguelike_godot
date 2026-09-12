# FIELDWORK UI implementation

Design source: [project skill](../../../.agents/skills/iron-caravan-ui/SKILL.md), its PNG/SVG references and tokens. [Reference / runtime comparison](comparison.html).

## Implemented

| Area | Runtime behavior | Main owner |
|---|---|---|
| Visual system | Graphite/olive surfaces, warm text, amber actions, exact SVG symbols from the supplied kit, shared icon colors, visible focus | `presentation/ui/fieldwork_tokens.gd`, `ui_styles.gd`, `ui_icons.gd` |
| Main menu | Left action column, supplied illustration on the right, language in service corner, multiplayer as information | `run_menu.gd` |
| Hideout | Five primary sections, separate settings, Caravan subnavigation, fixed departure footer | `hideout_hub.gd` |
| Armory | Vehicle / selectable catalog / fixed inspector; narrow layout collapses vehicle preview; description scrolls independently of actions | `armory_panel.gd` |
| Storage | Base inventory and next-raid supplies in adjacent columns, original pack/unpack commands | `expedition_panel.gd` |
| Trading | Compact trader selectors, explicit buy/sell modes, original one-item transactions | `expedition_panel.gd` |
| Tasks | Searchable task list and one selected task inspector; original accept/claim/abandon operations | `mission_board.gd` |
| Garage / crew | Existing convoy, shop, equipment and crew functions accessible from Caravan; shared theme | `caravan_panel.gd`, `hideout_hub.gd` |
| Settings | Top header and back action, 180 px tab rail, aligned parameter rows and separators; return to originating hideout section | `settings_panel.gd`, `app/main.gd` |
| Raid HUD | Compact meters, action strip near abilities, one tracked mission, zero combo hidden, no permanent X/Z diagnostics | `hud.gd`, `mission_hint.gd`, `road_fury_meter.gd`, `radar.gd` |
| Level choice | Selecting a card does not apply it; a separate confirmation applies the selected original upgrade ID once | `run_menu.gd` |
| Encounter | Right-side dialogue; NPC interaction layer hidden behind modal screens and restored for gameplay | `crew_encounter_panel.gd`, `crew_view.gd`, `crew_runtime.gd` |
| Pause / results / loading | Shared styles with existing run controls, result data and real loading progress | `hud.gd`, `run_menu.gd` |

## Data and design decisions

- Gameplay formulas, prices, catalog definitions, persistence and item models remain owned by their existing modules. The design packet's example values are not gameplay configuration.
- Upgrade scrap, stored scrap and raid cargo remain distinct. Garage/crew wages still use the original inventory rules.
- Existing English default and Russian switching are preserved. Godot's installed fallback font renders both; Inter is not bundled.
- Original key bindings and radar discovery rules are preserved. A mostly unexplored radar is not filled with invented map information.
- The kit contains proposed features as well as restyled existing screens. UI scale 125/150%, new accessibility settings, a display-mode rollback flow and a different save-slot model are not implemented by this pass.
- Garage uses the existing convoy/equipment renderer and operations. It is themed and regrouped, not a new vehicle configuration system. Main-menu illustration is supplied artwork, not a replacement of world assets.
- On narrow armory screens, long item descriptions scroll while purchase controls and the departure footer stay visible.

## Verification

- `tests/fieldwork_ui_test.gd`: real pointer navigation to settings, return context, RU/EN at 960×600 and 1280×800, paired inventories, selected-only transaction controls, inspector/footer bounds and modal prompt suppression.
- Existing armory/radar tests still perform real pointer purchases and check costs, installed mounts and upgrade results.
- Existing progression, mission, expedition, crew, settings, language, HUD and icon tests check the original gameplay contracts. Tests expecting the removed grid, immediate level selection, inline trading actions or a fake multiplayer button were updated to the new interaction contract.
- Full selected-run results are stored in `verification.json`. This is a focused gate, not the full project suite or an exported-build playthrough.
- `tests/fieldwork_capture.tscn` produced 54 real Metal/Forward+ screenshots covering menu, hideout sections, traders, settings and HUD at both languages and target sizes. Representative captures are in `captures/`.
- Level-up and encounter components were also rendered. The encounter capture verifies suppression of the world prompt and is a component stage, not a complete playable-world screenshot.
- No claim is made for 125/150% scaling, gamepad accessibility, all 48 proposed kit states, a standalone export or long-session gameplay balance.

## Reference fidelity correction

- Replaced custom icon drawings with the reference SVG paths; added the menu, navigation, currency, equipment and settings symbols.
- Matched the supplied palette, 164/136 px hideout rail, 24/16 px body padding, 16 px panel padding, 32 px tabs and 56 px footer. Removed borders from inactive navigation and ghost actions.
- Armory rows use line icons and a selected outline; inspector text uses the shared heading and muted text colors. Search and item summaries refresh with the selected language.
- Main-menu artwork uses the reference fade; the action column has explicit responsive placement. Settings use the reference header, left tabs and separated rows.
- Actual vehicle models, available settings and mount selection controls still follow the running game; reference-only functionality has not been added.

Latest evidence: 18 focused tests passed; menu layout and language tests were rerun after the last positioning fix and both passed. The latest graphical pass refreshed all 48 menu/hideout/settings captures. Its subsequent raid startup stalled and was stopped; the six HUD/pause captures are from the earlier completed 54-frame capture pass.

# Mine hacking

Buy and mount **Mine Hacking Kit** in the armory (60 scrap, weight 2, one per caravan). The existing mount selector supports the main vehicle or an owned trailer. The kit uses the existing support-mast geometry registered under its own model ID and included in loading/prewarm catalogs.

An armed hostile mine within 4.5m shows a localized E prompt. Hold E for 3 uninterrupted seconds. Releasing E, moving out of range, switching the nearest mine, or losing the module immediately resets the hold. Pausing or opening the armory cancels the hold while freezing mine lifetime and preserving the mine. Without the installed kit, the HUD explains which module is required.

A converted mine turns green and ignores the player, friendly NPCs, and nonhostile NPCs. A hostile enemy in its trigger radius consumes it and takes the existing 30 damage; nearby hostile enemies also take damage. Existing arming delay, lifetime and mine limits remain in force.

`tests/mine_hacking_module_test.gd` injects an actual viewport pointer click on the armory purchase button and checks purchase, mount, E mapping, simulated held input, timing, all interruption cases, EN/RU prompts, green presentation state and hostile-only triggering. It uses headless Godot; it does not establish rendered appearance or physical keyboard handling in a graphical session.

The native module definition/build profile also live in `scripts/godot_module_additions.json`. The TypeScript catalog exporter merges these additions, so re-exporting the reference catalog preserves the kit. The original exported constants remain unchanged.

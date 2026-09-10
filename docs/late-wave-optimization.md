# Late-wave performance investigation, 2026-09-10

Removed the top status messages on failed ability use and loot pickup, and the nitro activation banner. Ability activation, pickup rewards, cooldowns, sound and camera feedback remain in their existing owners.

Reduced redundant presentation work:
- Static pooled model parts use their prepared transform directly; animated parts retain SourceAnimation.
- Unchanged MultiMesh visible counts are not assigned again.
- The target/boss label is assembled before assigning text, instead of clearing and rebuilding the visible Label every physics tick.
- Dry jammer interference skips the two rain-droplet shader layers, which contribute zero when rain is zero.

## Evidence and limits

10/10 selected tests passed cleanly through tests/run_all.py: combat_optimization, combat, combat_presentation, hud_layout, source_fx, jammer_feedback, weather_transition, raid_loot, support_feedback, integration. Logs: /tmp/late-wave-final-tests. Architecture guard and git diff --check passed. Full suite and exported build were not run.

Rendered Metal benchmark: seeded final-wave roster repeated up to the requested 80 actors; catalog caps constrain spawning; both sustained runs ended with 75 NPC. Includes boss, jammer/support vehicles and two miniguns. 600 warmup frames and 3600 measured frames. This is a synthetic crowd, not a saved wave 5-7 playthrough: model wave remains 1, world activity physics is disabled, actors have high health, player is stationary, clear weather. Window settings override the requested size: actual window 4112x2514, viewport logical size 1308x800. Vsync unchanged. Not an isolated-machine benchmark.

| Measurement | Before | Retained model/shader changes |
| --- | ---: | ---: |
| Average FPS | 76.54 | 76.59 |
| Average frame ms | 13.065 | 13.057 |
| 1% low FPS | 42.00 | 42.39 |

No meaningful overall FPS improvement was established. The reported severe late-session slowdown remains unreproduced. Need F3 evidence from the affected live run to locate its bottleneck; do not present these changes as a confirmed fix for that incident.

A trial batching physics publications into process frames measured about 69 FPS and was reverted completely. The final HUD label assignment cleanup was applied after the sustained renderer launched; its performance is not included in the comparison above. It is covered by the final headless HUD tests and UI capture.

Benchmark JSON and screenshots: docs/validation/late-wave-optimization/before and final. Final interaction render: ui (nitro success, repeated attempt during cooldown, real salvage pickup). Temporary profiles are isolated under /private/tmp.

Reproduce:
```sh
/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" --scene res://tests/combat_performance_capture.tscn -- --late-waves --sustained --verify-feedback --output=res://docs/validation/late-wave-optimization/recheck
```

Follow-up GPU smoke, obstacle cache and route geometry work: [gpu-fx-optimization.md](gpu-fx-optimization.md). The initial findings above describe the earlier pass.

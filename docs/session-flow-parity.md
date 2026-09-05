# Local countdown, clock and death flow

The offline death cinematic is reachable source behavior even though its helper lives in the original multiplayer module. It is included in the native offline port without networking.

`modules/session/run_clock.gd` retains the order in source `src/client/main.ts:48..130`, `contexts/session/index.ts:updateIntro/updatePendingDeath` and `contexts/multiplayer/index.ts:getSimulationTimeScale`:

- Raw frame delta is capped at0.05. Intro lasts2.65 seconds, with3 above1.92,2 above1.25,1 above0.58 and GO thereafter. The frame that finishes the intro still has zero gameplay delta.
- Resume easing begins at0 and increments by rawDelta×2.8, then uses `t*t*(3-2*t)` for gameplay delta. Manual pause, build close and upgrade resume reset easing.
- Hit stop uses `max(current,min(0.075,0.014+power*0.045))`; it expires in raw time and suppresses the whole gameplay delta for its final expiry frame too.
- Weather uses raw time in active runs, including countdown/resume/hit-stop. Intro ambient environment receives rawDelta×0.25. Paused/dead gameplay and weather are frozen. Camera remains on raw time.
- Local death immediately cancels activities, freezes player/world/combat, emits `death_started`, captures destruction meshes then hides the living model. It delays the result and progression terminal event for2.4 raw seconds.
- Death effects run at0.22 speed, recovering with smoothstep during the final38percent. Source camera follows fixed death position/heading with orbit `heading+2.25+progress*.72`, radius18→14.5, height15.5, zoom1.42 and source damping. After the terminal timer, camera leaves cinematic mode while destruction effects continue fading behind the result, matching the original frame's paused-effects branch.
- Restart cancels prior countdown/death state before asynchronous rebuilding. Pending result is generation-checked and delivered once. New run restores the visible player and full intro.

`session_flow.gd` runs before gameplay physics at priority−1000. It injects cached deltas into vehicle/combat/world adapters. No global Engine.time_scale is used. Standalone module tests can retain their normal supplied delta without the application clock. Presentation world effects have explicit raw/gameplay clocks; shared combat effects use the same cached gameplay delta and an explicit cinematic update while paused.

`app/main.gd` exposes `run_prepared(seed)` after covered resource/world construction and before countdown, and `run_ready(seed)` only once countdown finishes. Awaiting `restart_run()` also waits for actual readiness. At run_ready, gameplay elapsed/fuel are unchanged; weather has legitimately advanced during the visible countdown. Source foundries/initial guards already exist and stay frozen through countdown. Countdown blocks gameplay shortcuts, and programmatic restart safely cancels an in-progress intro/death.

`presentation/ui/progression_feedback.gd` replaces an invented generic menu-click cue with actual contract completion/progress sounds and flat notices. Progress cues have the original700ms throttle. Source countdown GO and repair ability tones are extracted into the offline audio bank by the audio owner.

## Verification

- `tests/export_run_clock.mjs` independently evaluates actual source function bodies and main-loop delta statements. `run_clock_test.gd` compares540 original frames for intro, resume, manual pause, hit-stop, death timing/scaling and effects fading after result, plus cancel/reset.
- `session_flow_test.gd` exercises actual prepared world/foundries, held drive input, countdown3/2/1/GO, pause/build/ability/restart key guards, raw weather, resumed movement, delayed death result/contracts, terminal camera/effects, restart during countdown and death, and stale generation rejection.
- Integration and world-result tests now explicitly advance the real cinematic clock. The full-run scenario advances the actual session clock for every controlled tick; it does not bypass countdown or manipulate global timescale.
- Latest clean gates:run_clock4697 checks,session_flow24 checks,full_run16 checks (`/private/tmp/iron-final-session-review`); all engine logs clean.
- First combined gate passed all five requested tests cleanly: run clock, session flow, integration, world results and controlled full run. Additional offline-session, composed-seed and UI-flow regressions passed cleanly. Latest exact results and logs are recorded in the parent validation report; headless cannot prove rendered cinematic quality or acoustic identity.

Full original destruction mesh/shader/debris fidelity is handled by the presentation owner. This clock document does not claim all destruction visuals merely because the death event is connected.

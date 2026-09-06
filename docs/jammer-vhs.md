# Jammer screen interference

The enemy jammer now draws animated VHS interference across the world: scanlines, grain, horizontal tracking distortion and RGB separation. HUD text and controls draw above it and remain readable.

`jammer_vhs.gd` consumes the same combat snapshot as the existing corner indicator. Inside the real 48-unit jammer radius, the visual strength has a 0.32 minimum so the edge is visible. Proximity strengthens the effect; the actual control-reversal pulse strengthens tracking distortion. Gameplay range, aim and input rules are unchanged. Leaving the radius uses the existing short strength fade. Death, reset and hidden gameplay screens remove the effect.

The screen rectangle is allocated with the HUD, ignores input and is excluded from world-marker occluders. Its shader is in the asset manifest and is drawn beneath the loading screen during covered preparation before gameplay.

Validation: `jammer_feedback_test.gd` checks real jammer rules through the HUD, radius edge, pulse, exit, death, reset, pause and layering. `jammer_vhs_capture.tscn` renders the actual game with a spawned jammer and captures clear, inside, edge and outside states in `/private/tmp/iron-vhs-*.png`. Gameplay physics are frozen for these captures; they are visual checks, not a combat performance benchmark.

Metal render captures: [clear](validation/jammer-vhs-clear.png), [inside radius](validation/jammer-vhs-inside.png), [radius edge](validation/jammer-vhs-edge.png), [outside](validation/jammer-vhs-outside.png). The capture completed all runtime assertions without engine or shader errors. [Focused headless checks](validation/jammer-vhs-headless-report.json).

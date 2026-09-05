# Jammer gameplay

A living hostile jammer affects the player within 48 metres in the XZ plane. Dead, suppressed/staggered, friendly and nonhostile emitters cannot jam. The nearest eligible emitter supplies the field position and ID; ties resolve by ID. Existing 55% weapon/radar range remains compatible.

Proximity strength is full within 24m and smoothly falls to zero at 48m. Entry uses a 0.45s exponential time constant; cosmetic exit uses 0.25s. Outside the field, or when its source dies/is staggered, gameplay effects stop immediately even while the visual strength finishes fading.

Inputs are normally attenuated by at most 10%. After 1.6s exposure, a 0.5s pulse repeats every 3.2s. Its 0.12s smooth edges ramp the throttle/steering multiplier as low as -0.9 at full strength. Weak outer-zone interference never reverses controls. Handbrake remains usable. Only input is affected: velocity, body transforms, scale and suspension are not flipped or shaken.

Player projectile aim receives deterministic horizontal dispersion up to ±6 degrees multiplied by strength. The shot-index/seed hash does not consume the existing combat RNG. Enemy aim is unchanged. Pause, result and restart clear interference; resuming starts a fresh warning interval.

Snapshot fields on player: `jammed`, `jammer_strength`, `jammer_reversed`, `jammer_pulse`, `jammer_source_id`, `jammer_source_position`, `jammer_radius`. Source metadata persists during the short cosmetic exit fade and clears afterward.

`jammer_gameplay_test.gd` passes 120 checks in headless Godot: 30/60/144Hz timing, proximity, all source-disable conditions, real projectile trajectories, real controller input, unchanged rigid transforms, runtime synchronization, pause and reset. Existing enemy AI, advanced combat, vehicle response, combat and session flow suites pass (5/5 strict suites). No graphical rendering or subjective driving-feel claim is made.

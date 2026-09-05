# Weather transitions

Clear (`sunny`), rain, storm and fog already used the source seeded schedule. A fresh run generates a new seed; adjacent phases differ and last 120–180 seconds. That schedule and the lightning, mud and particle source fixtures remain unchanged.

Lighting, precipitation, mist and gameplay visibility now share a 24-second quintic fade based on absolute weather time. Its first and second derivatives are zero at both ends. Fog fades out after the target type changes as well as fading in. Initial weather is applied under loading, so a randomly selected storm does not begin with a clear frame. Pause and the existing raw weather clock remain authoritative.

Fog's source-equivalent density is now 0.0135, converted to native Godot density 0.01184625. The exponential model transmits about 46% of light over 65 units, compared with 95% in clear weather. This is a calculation, not a rendered visibility measurement. At full fog, player acquisition/detection is 68%, upgraded radar 84% and NPC acquisition 72%; all three interpolate continuously. The 12-second source traction curve remains, with phase-boundary catch-up corrected to use elapsed time since the boundary.

`weather_transition_test.gd`: 1207 checks pass in headless Godot. Covers all initial weather types over 64 seeds, no repeated adjacent phases, all 12 transitions at 30/60/144 Hz, phase crossing/catch-up, paused time, entry/exit acquisition, radar integration, actual environment/light/particle state and dry-layer shutdown. Existing world gameplay/presentation, enemy AI, advanced combat, minimap, run clock and loading suites pass (7/7 strict suites). Source fixtures were not regenerated. Logs: `/private/tmp/weather-transition.engine.log`, `/private/tmp/iron-weather-targeted/`.

Headless checks validate state and resource properties; graphical fog readability still requires a normal rendered playthrough.

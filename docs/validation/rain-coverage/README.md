# Full camera rain coverage

Validated with Godot 4.7.2, Metal on Apple M4 Pro.

- `rain_coverage_capture.gd`: 38 checks, 0 failures. Rain appears in all nine screen sectors at 1280x720, 1920x720, and 1920x720 with camera size 120 and a shifted focus. Paused captures match byte for byte. An opaque surface ahead of all particles removes every visible rain pixel.
- Visible rain pixels per sector (sample every two pixels): normal 134-196; ultrawide storm 326-482; zoom/drag rain 77-120.
- `rain_world_capture.tscn`: actual world captured in rain and storm; images inspected. Lens droplets disabled for these captures to isolate the world rain coverage.
- `world_presentation_test.gd` and `weather_transition_test.gd`: 2/2 clean. Existing seeds, particle count, wind, lightning, fades and warmup reset preserved.

The graphical capture scripts require a rendered Godot launch; do not add them to the headless test manifest. These checks do not establish long-session performance or every camera configuration.

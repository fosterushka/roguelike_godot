# World and combat update

Implemented in the offline Godot project, September 2026.

| Request | Runtime change |
| --- | --- |
| Motorcycle rider | Rider geometry baked into the existing bike body mesh; Blender source retained. |
| NPC red splash | Short red droplets on infantry/rider death, using the existing bounded effect pool. |
| Different launchers | Bazooka tube and twin-barrel anti-air station with radar; attachment dimensions checked. |
| Metal impact sparks | Short emissive streaks at projectile impact positions on player/enemy vehicles. |
| Tornado tree landing | Uprooted trees remain destroyed; pooled debris uses gravity, angular momentum, bounce and friction. |
| Airdrop | Military crate with straps, corner guards, latches and red flare smoke; corrected model origin. |
| Wider roads | Width multiplier shared by generated layout, road rendering and surface sampling. |
| Larger trees | Generated/reference tree presentation enlarged consistently with collision footprints. |
| Small rocks | Local-space rock detail shader with matched material and instanced tint. |
| Enemy bases | Bunker, barracks and factory silhouettes; damage-triggered defenders, fixed gate, shared oriented box hitboxes for vehicle/projectile collision, no hit bounce. |
| Day/night | Eight-minute cycle with sun/moon lighting, ambient light and weather-aware fog. |
| Rain inertia | Surface grip and mass affect braking distance and lateral grip. |
| A/D smoothing | Exponential steering/yaw damping and reduced steering angle at higher speed. |
| Terrain bumps | Geometric rolling hills and hummocks shared by rendering, heightfield and wheel sampling; roads/props flattened. |
| Biomes | Meadow, dry badlands and snowy tundra; blended terrain colors, vegetation tint and density/species changes. |
| Animals | Bounded sheep flocks flee threats; vehicle sweep collision drops scrap once per animal; reset restores flock. |

Tuning lives in `handling_rules.gd`, `wildlife_rules.gd`, `base_defense_rules.gd`, `biome_rules.gd`, `day_cycle.gd` and the small terrain/debris modules. New effects reuse pools; the world does not add physics bodies for every sheep or thrown tree.

Rendered captures are under `docs/validation/world-upgrade` and `docs/validation/world-expansion`. `wildlife_runtime_capture.gd` starts the real app with a temporary save, rebuilds the world and verifies that running over a sheep produces scrap. Other captures stage the actual runtime models and landscape.

Validation distinguishes headless behavior checks from Metal rendering. Captures do not establish long-session frame time or preferred driving balance. The final automated result is recorded in `docs/validation/world-upgrade/report.json`.

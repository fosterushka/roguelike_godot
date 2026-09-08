# Survivor encounters

- Interaction uses horizontal distance within 5 metres of the pickup or any attached living wagon. Rolling speed and terrain height no longer prevent recruitment.
- Pressing E, clicking the survivor E prompt, or using touch interaction opens the dialogue only inside the interaction radius. Proximity never opens it. The prompt is outlined in range and dimmed farther away. Opening stops the vehicle; Talk later requires another explicit interaction.
- Eight identities, four short backstories and four rotating distress calls are localized in Russian and English. Stranded survivors jump and wave; nearby survivors display speech callouts.
- Recruitment reserves a matching wagon seat, falling back to another free seat for specialists. Untrained passengers require a cargo wagon. Recruits walk to the carrier and climb aboard over 0.85 seconds. Work begins only after boarding.
- Driving away for three seconds while a recruit approaches causes a seeded 5–10 second refusal to board, with a sad face and one of five localized offended replies. Driving away mid-climb cancels the climb, preventing teleport boarding.
- Eight survivors spawn at seeded random positions throughout the circular playable world, at least 180 metres from the player and 120 metres from one another, clear of solid props.
- Refusal is deterministic per survivor: 50% flee, 30% head toward enemies (convert on arrival or after eight seconds), 20% become hostile immediately. Hostiles use the real combat enemy system and do not count toward the wave quota.
- Untrained survivors who return alive can learn a profession at base through Crew. Training costs 30 stash scrap, is unavailable during raids, preserves personal identity and health ratio, and rolls back with the currency if saving fails.
- Existing extraction rules still apply: survivors left outside, dead, or aboard lost wagons are not banked.

## Validation

The full manifest completed 87/88 clean. The only failure was a repeated-run collision in the crew-mission test's temporary save path. Its path now includes the process ID; the repaired test passed in focused reruns. Updated runtime, encounter, seating and real Main input integration checks passed after the final behavior changes.

GPU captures from the dedicated scene cover distress calls, Russian/English dialogue, climbing, and base training at 960x640. These are standalone rendered checks, not a full interactive raid playthrough.

Commands:
- python3 tests/run_all.py
- Godot --path . --script res://tests/crew_encounter_capture.gd

## NPC feedback and base navigation revision

Speech and the E prompt now share one wrapped, padded screen-space bubble. A five-second green smile follows accepted recruits. Refusal speech follows fleeing survivors and the real enemy actor after hostile conversion; these decisions do not emit world notice banners.

Base Garage is embedded beside Armory, Stash and Vault under the same navigation and account header. Crew cards use a compact grid. Manual seat selectors were removed: departure plans profession matches first, reserves cargo seats for untrained passengers, and respects available wage funds. Survivors outside a lost carrier automatically seek a new seat and walk aboard.

Focused runtime, real Main caravan/navigation, persistence, locale, seating and layout checks passed. Dedicated GPU captures show the speech bubble, acceptance, refusal before/after movement and Garage/Vault/Stash at 960x640.

Blocked navigation destinations are rejected before graph search; failed routes retry at most every half-second unless the carrier moves to a new destination.

September 8 revision: crew encounter, runtime and seating checks passed (49/49, 41/41, 43/43). Dedicated Metal captures in `/private/tmp/crew-calling-nearby.png`, `/private/tmp/crew-calling-distant.png`, `/private/tmp/crew-offended-ru.png` and `/private/tmp/crew-offended-en.png` confirm prompt states and sad-face text layout. This is rendered scene validation, not a full raid playthrough.

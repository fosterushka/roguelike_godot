# Survivor encounters

- Interaction uses horizontal distance within 12 metres of the pickup or any attached living wagon. Rolling speed and terrain height no longer prevent recruitment.
- Approaching opens a paused dialogue; E and touch interaction also open it. Opening stops the vehicle. Talk later suppresses automatic reopening until the convoy leaves the area; E can reopen immediately.
- Eight identities, four short backstories and four rotating distress calls are localized in Russian and English. Stranded survivors jump and wave; nearby survivors display speech callouts.
- Recruitment reserves a matching wagon seat, falling back to another free seat for specialists. Untrained passengers require a cargo wagon. Recruits walk to the carrier and climb aboard over 0.85 seconds. Work begins only after boarding.
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

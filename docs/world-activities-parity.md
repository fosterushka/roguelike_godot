# Offline world activities and extraction

## Source scope

The original implements `raiderSupplyConvoy`, `settlementDistress`, `foundryDispatch`, `scavengerRoute` and extraction in `src/client/contexts/world/world-activity.ts` / `extraction.ts`. Foundries are hostile destructible production sites, not capturable bases. The source does not implement a separate minor-cache activity. This port does not invent those mechanics.

## Working runtime

`modules/world/activities/` now contains independent rules, original LCG/hash RNG, activity lifecycle, foundry production and support systems. `world_runtime.gd` composes them and exposes `interact()` for the existing E action. All systems obey the run lifecycle and pause; representative models are built once and reusable view pools survive restarts.

- Full exact source route/anchor data retained in `world_layout.json`: `activityRoutes`, `activityAnchors`, `activityBlockers`, eight `deploymentAnchors` per village, village tribute and original per-prop `village_id`.
- Major cap1, minor cap2, retained history16. First major9–14s/minor5–9s; later gaps24–34s/20–28s; failed placement retries after5s; post-outcome recovery10s. Original activity RNG golden timer match for seed72841:9.410234484588727 and6.388639932498336.
- Convoys reserve an exact three-anchor road section and announce2.5s before spawning a buggy and motorcycle atomically. Vehicles use source spacing5 and route speed6.2; all destroyed completes the contract; reaching destination fails; expiry95s. Stagger pauses convoy progression. AI does not overwrite their source route ownership.
- Distress selects intact source villages, reserves three clear original deployment anchors and commits three riflemen after1.5–2s telegraph. Safety distances76 for village selection/42 for commit; intrusion grace1.25s; destroyed settlement or blocked deployment fails; killing all participants completes. Active expiry62s.
- Scavengers use the original heal-cart model, road speed4.2, activation delay1.5s, meeting radius5 and lifetime82s. Contact completes; leaving the road section expires.
- Foundry network creates10 source garrisons with tier cycle1–3, HP370/480/590, original footprint and aim-height values, initial guards2+tier, minimum player distance170 and network spacing120. Static colliders and dynamic navigation volumes are pooled and removed on destruction. Garrisons/guards do not count toward wave completion.
- Living foundries provide original radius90 sector overclock with movement/cadence×1.2 and pressure capacity1.5. Engaged radius78 foundries produce telegraphed infantry at their radius+1.3 gate, cooldown5; production stops on destruction. Dispatch creates a tracked major objective, expiry60, completion after participant elimination. Source garrison/keep combat definitions and drop counts were implemented in the combat agent's owned modules.
- Activity salvage rewards18 convoy/14 distress/10 dispatch/8 scavenger, XP round(reward×0.6), one activity credit per completion. `reward_claimed` and terminal lifecycle prevent replay. Stable generation/activity event IDs feed `activity_completed` to existing contract progression exactly once.
- E extraction requires2 credits, intact village within22 and speed≤1.5. It spends credits once, selects the nearest clear original deployment anchor, holds within12 for30 seconds, pauses while living hostiles are within28, and allows2 seconds away before abandonment. Destroyed settlement fails extraction. Failed/abandoned requests do not refund spent credits, matching source.
- Extraction ends alive with `status=extracted`, `result.extracted=true`, `reason=extracted`, `won=false`. This matches original `endGame(false, 'extracted')`, so extraction does not grant victory-only contracts.
- Airdrops: first28–40s, gaps46–64s, at most1, original source model, height12, downward velocity−4.4 with gravity2.2/cap−7.2, lifetime90. Landed pickup within4.3 grants24+level×4 salvage, round(salvage×0.85) XP,32+level×3 fuel and one locked projectile weapon unlock. Claimed once.
- Rescue carts: first10s, at most1, original model, speed2.8, lifetime48, radius2.05+3 contact. Heal90+level×5 clamped to missing HP; full-health contact does not consume cart. Source next-spawn ranges42–58s, after healing34–46s, expired retry8s.
- `presentation/world/activity_view.gd` uses reusable original heal-cart/airdrop pools, original activity colors and ring-sized beacons, dashed source route guidance and an extraction zone marker. At most3 heal-cart visuals and1 airdrop; route geometry is reused.

## Integration API

`world.interact()` returns whether extraction started. `get_state()` adds:

- `activity`: `available`, `records` (live), `current`, `credits`.
- `extraction`: `available`, `visible`, `mode`, `active`, `can_request`, `credits`, `required_credits`, `position`, `distance` when inactive, `progress_percent`, `remaining_seconds`, `hostile_count`.
- `support`: airdrop/heal-cart records and next timers.
- `foundries`: living source IDs, positions, tier and health.

Contract events use the combat event stream. User-facing announcements use `world_event`; they do not independently credit contracts.

## Validation

`Godot --headless --log-file /private/tmp/iron-caravan-activities-test.log --path . --script tests/world_activities_test.gd`

71 checks pass: source timers/RNG, slot bounds, rewards/XP/credits/events once, failure/expiry, village invalidation, extraction E gating/charge/contestation/grace/alive result, support landing/heal/claim once, actual paused physics frames, inert warmup, restart cleanup, convoy/distress actor spawning and completion,10 foundries/HP/colliders/rewards, production telegraph→participant→completion, source scavenger contact and pressure rejection without partial spawn. The39 existing world gameplay checks also pass. `tests/world_result_test.gd` adds16 passing checks through actual app composition: boundary/extraction publish immediately, open result UI, freeze input, close contracts once, preserve final position/health semantics, persist isolated profiles, and restart correctly. World termination now calls public `CombatRuntime.finish_run` instead of leaving an undelivered model event behind a stopped simulation. Real rendered gameplay performance/appearance still needs separate validation.

## Remaining parity gaps

- Full original encounter-director pressure/recovery phases, pending boss reservation, threat<84 gating, weighted reinforcement event selection and exact random-call interleaving are not yet ported here. Activity safety uses source numeric budgets/capacity and existing combat phase; foundry dispatch selection is an initial bounded integration rather than an exact whole-director port.
- Garrison placement and support spawns use isolated deterministic source-style RNG streams. Source numerical rules are retained, but exact original shared-RNG positions vary; this avoids coupling presentation warmup to gameplay RNG.
- Full priority-vehicle dispatch/repair/mine/shield lifecycle and crawler mandatory-boss scheduling are outside this activity task. The keep definition/model exists in combat; this task does not silently add invented keep spawning rules.
- Source convoy tornado-offset decay and advanced per-part interruption animation remain pending. Route-following checks are source-style straight-segment traversal; complete roadway collision recovery/path detours need further rendered testing.
- Foundry cannon articulation, gate telegraph source visuals, local sector overlays and rubble/crater collapse presentation need the next visual pass. Foundry actor HP/collision/production/rewards are functional.
- Airdrop canopy collapse, flare/beam/point-light animation, original wheel animations, rescue sound/bursts, proximity full-health notice and ambient NPC behavior remain pending. Original mesh data is present, but grouping metadata for canopy animation needs extending.
- Activity labels are source text. Final localization, polished HUD/offscreen indicators and camera integration belong to the UI agent.
- Standalone village tribute/consumption interaction and original ambient villagers/grazers are not implemented by these contract systems. Per-prop settlement destruction and extraction eligibility are implemented.
- Headless tests do not verify actual renderer appearance, first-use GPU stutter or production frame time.

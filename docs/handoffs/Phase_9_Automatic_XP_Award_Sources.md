# Codex Handoff: Phase 9 Automatic XP Award Sources

**Prepared by:** Claude (project architect)
**Date:** 2026-07-24
**Workflow:** Follows the "SOUL Codex Handoff Instructions" in `docs/spec/Implementation_Specification_Addendum.md`.

---

## 1. Scope

FINAL REQ-013 specifies six XP award sources. Two are already fully implemented: the weekly approved-character award (`plugin/events/soul_xp_cron_handler.rb`) and manual staff awards (`+xp/award`, Phase 6). A third, "approved Inkling XP outcome," is implemented via `SoulInklingsHook` (Phase 7). The remaining three from REQ-013's table are **not implemented as REQ-013 specifies them**:

| Source | REQ-013 default | Current state |
|---|---:|---|
| scene sharer | 2 XP, automatic, once per scene/recipient/award-type | **Manual only** — `+xp/scene` (Phase 6) requires a staff member to type in an amount and run the command; there is no automatic award triggered by sharing a scene |
| each other approved scene participant | 1 XP, automatic, same idempotency | Same gap — `+xp/scene` treats all recipients identically with a staff-chosen amount, not the sharer/participant differential REQ-013 specifies |
| first qualifying forum topic/reply each week | 1 XP, automatic | **Does not exist at all** — no command, no cron, no event handler |

**In scope:**
- An automatic, event-driven scene sharer/participant XP award, triggered by the real `SceneSharedEvent`.
- An automatic forum XP award via an idempotent reconciliation process (REQ-013 explicitly permits this fallback — see §2 below for why an event-driven approach isn't available).
- Config keys already exist for both (`game/config/soul.yml`'s `xp.scene_sharer_award`, `xp.scene_participant_award`, `xp.forum_award` — confirmed present, added in Phase 2 but never consumed). No new config is needed unless you find a genuine gap; if so, flag it rather than inventing a key silently.

**Explicitly out of scope:**
- Changing `+xp/scene`/`+xp/scene/catchup` (the existing manual staff commands) — they remain a legitimate, separate manual-override path per REQ-013's "manual staff award: entered amount" row. Do not remove or repurpose them.
- Any change to `SoulXpApi.award` itself — it already has everything this handoff needs (`idempotency_key:`, `apply_catchup:`, `source:`). Call it; don't modify it.
- A generic "forum post event" — confirmed not to exist in real AresMUSH core (see §2). Do not add one to the Forum plugin; that plugin is not part of this repository.

## 2. Design Decisions Already Resolved (read before implementing)

### 2.1 Scene sharer/participant award: which event, and who is "the sharer"

Verified directly against the real AresMUSH engine checkout: `plugins/scenes/helpers/actions.rb`'s `Scenes.share_scene(enactor, scene)` fires

```ruby
Global.dispatcher.queue_event SceneSharedEvent.new(scene.id)
```

(`plugins/scenes/public/scene_events.rb`). **The event payload is only the scene ID — it does not identify who ran the share command.** This is exactly the situation REQ-013 anticipates: *"If the installed scene event does not identify the sharing character, SOUL SHALL extend the supported scene-sharing action/event payload rather than guess."*

Extending the Scenes plugin's own event class is out of scope (it's not this repository, and it's not SOUL's to modify). Instead, this is resolved without guessing: `Scene#owner` (`plugins/scenes/public/scene.rb`, `reference :owner, "AresMUSH::Character"`) is a real, always-populated field set at scene creation — not something inferred from who happened to run `+scene/share`. **Use `scene.owner` as "the sharer" for the 2 XP award, and `scene.participants` (excluding the owner) for the 1 XP participant award.** This is a deliberate design choice (the scene's owner, not whoever clicked share), not a guess from ambiguous event data — record it as such in your implementation notes.

### 2.2 No forum-post event exists — use idempotent reconciliation instead

Confirmed directly against the real engine: the Forum plugin (`plugins/forum/`) fires no event on post or reply creation (only `role_deleted_event_handler.rb`/`char_connected_event_handler.rb` exist under `plugins/forum/events/`, both unrelated). REQ-013 explicitly anticipates this: *"If AresMUSH exposes no forum-post event, SOUL SHALL use a supported service-boundary adapter or idempotent reconciliation process; it SHALL NOT rely on client-only commands."*

`BbsPost` and `BbsReply` (`plugins/forum/public/bbs_post.rb`/`bbs_reply.rb`) are real Ohm models with a `reference :author, "AresMUSH::Character"` and a real `created_at` timestamp (via `ObjectModel`/`OhmTimestamps`, confirmed in `engine/aresmush/models/ohm_timestamps.rb`). Build the reconciliation as a cron-driven scan: **add this to the existing `SoulXpCronHandler`'s tick** (the real `Dispatcher` supports only one `CronEvent` handler per plugin per event name — this is already true for the weekly-award/roll-expiry logic sharing one handler; do not attempt to register a second cron handler). On each tick, for every `BbsPost`/`BbsReply` with `created_at` in the current ISO week that hasn't been processed, find its `author`; if that author has not yet received a `forum_award` this week (idempotency key below), award it.

### 2.3 Idempotency keys

Reuse `SoulXpApi.award`'s existing `idempotency_key:` parameter — do not add a new dedup mechanism (CP-09):
- Scene sharer: `"scene_sharer:#{scene.id}:#{character.id}"`
- Scene participant: `"scene_participant:#{scene.id}:#{character.id}"`
- Forum (first qualifying post/reply per character per week): `"forum:#{character.id}:#{iso_year}-W#{iso_week}"` — use whatever ISO-week calculation the codebase already has available (check `Time`/`Date` stdlib; do not add a new gem). "First qualifying" per REQ-013 means the first post-or-reply that week counts; later ones that week award 0 — the idempotency key naturally enforces this since `SoulXpApi.award` should already refuse a duplicate `idempotency_key` (verify this is true; if `award` doesn't already dedupe by key, that's a real bug to flag back rather than silently work around).

### 2.4 Eligibility

Only approved characters are eligible for any of these awards (matches the existing `SoulXpApi.get_scene_participants`' `Chargen.approved_chars` filter and `median_earned_xp`'s population). Apply catch-up (`apply_catchup: true`) for all three sources, consistent with "automatic sources default catch-up on" (Phase 2's `SoulXpApi.award` doc comment).

## 3. Relevant Specification Sections

- FINAL §5.6 (REQ-013), the "Canonical configurable awards" table and the two paragraphs immediately after it (scene-repeat/no-cap rule, forum "SHALL use a supported service-boundary adapter" fallback).
- `docs/architecture/Event_Flow.md` for this plugin's existing event-handling conventions.
- `plugin/events/soul_xp_cron_handler.rb` — the cron handler you'll extend.
- `plugin/public/soul_xp_api.rb`'s `award`/`get_scene_participants` — the only APIs this handoff calls into.

## 4. Repository Files Expected to Change

```
plugin/events/soul_scene_shared_event_handler.rb   # new — SceneSharedEvent handler
plugin/events/soul_xp_cron_handler.rb              # extended — forum reconciliation added to the existing tick
plugin/soul.rb                                     # register the new event handler in get_event_handler
plugin/spec/soul_scene_shared_event_handler_spec.rb  # new
plugin/spec/soul_xp_cron_handler_spec.rb           # extended
```

No model changes. No new config keys expected (see §1) — if you find the existing `xp.scene_sharer_award`/`xp.scene_participant_award`/`xp.forum_award` keys insufficient, flag it rather than adding new ones unilaterally.

## 5. Acceptance Criteria

- Sharing a scene automatically awards the configured `scene_sharer_award` to `scene.owner` and `scene_participant_award` to every other approved participant, each with its own idempotency key (no batch short-circuit that would skip a legitimate second recipient).
- Re-sharing (or any other duplicate delivery of the same `SceneSharedEvent`) does not double-award.
- A character's first qualifying forum post or reply in a given ISO week awards `forum_award` XP exactly once; a second post/reply that same week awards nothing.
- All three sources apply catch-up XP and are restricted to approved characters.
- `+xp/scene`/`+xp/scene/catchup` continue to work unchanged as the manual override path.
- Specs cover: the sharer/participant split, duplicate-event idempotency, the forum first-post-per-week rule, and a genuinely stale/already-processed case still being correctly skipped.

# Codex Handoff: Phase 4 Roll Models and Service API

**Prepared by:** Claude (project architect)
**Date:** 2026-07-24
**Workflow:** Follows the "SOUL Codex Handoff Instructions" in `docs/spec/Implementation_Specification_Addendum.md`. Claude has already designed and implemented the mathematically sensitive core (the dice/probability engine) and resolved one genuine spec gap (degrees-of-success boundary). Codex implements the surrounding models and orchestration service against that already-built, already-tested dependency.

---

## 1. Scope

Implement the standard (non-GM-assisted) roll subsystem for Phase 4: the `Roll` and `PendingRoll` Ohm models, the `SoulRollApi` service that orchestrates candidate B&B identification through pending-roll selection through resolution, a cron-driven pending-roll expiry sweep, and the Character collection wiring. This is core service-API work — no MUSH commands or web handlers are in scope (that's Phase 6, following the same precedent set by Phases 1–3).

**Explicitly out of scope:**

- GM-assisted rolls, scene GM policy, mandatory/optional B&B marking by a GM, force-abort by staff (Phase 5). The models include the fields Phase 5 will need (`gm_suggested_entries`, `gm_mandatory_entries`, `gm_assisted`) but Phase 4 never populates or branches on them beyond leaving them at their defaults.
- Any MUSH command (`+roll`, `+roll/gm`, etc.) or web handler. These are Phase 6.
- Any change to `plugin/public/soul_dice_engine.rb` — it is complete, reviewed, and covered by `plugin/spec/soul_dice_engine_spec.rb`. Treat it as a locked dependency. If its interface seems insufficient for something this handoff needs, stop and report rather than modifying it.
- Roll-modifier contribution from other plugins (the previously-flagged `get_hooks` dead end — still unresolved, still not part of this phase; see `docs/architecture/Integration_Guide.md`'s "Providing Roll Modifiers" section).
- Narrative History entries for individual rolls. Per `docs/architecture/Data_Model.md`'s qualifying-events list, rolls are **not** a Narrative History category — the `Roll` record itself is the permanent record (REQ-031, §6.5). Do not call `SoulNarrativeHistoryApi.create` from any roll code path.

## 2. Relevant Specification Sections

- `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` §6.4 (Roll Model, REQ-025 through REQ-031), CI-03 (Conversational Roll Flow), CI-04 (Pending Roll Limits).
- `docs/spec/Implementation_Specification_Addendum.md` §2 (Random Distribution Model — already implemented in `SoulDiceEngine`, read for context on what the engine does), §6 (Pending Roll Expiry Mechanics), §8.1 (Degrees of Success — **read the "Implementation note" added 2026-07-24**, it changes the table from what a first read would suggest), §9 (Extraordinary Luck Messaging).
- `docs/architecture/Data_Model.md`'s "Rolls" section (just updated — read the current version, not memory of an earlier draft) for the exact field lists of both models.
- `game/config/soul.yml`'s `rolls:` block — already complete and validated (`plugin/soul_config_validator.rb`'s `validate_rolls`); do not add new config keys without checking whether an equivalent already exists there first.

## 3. Repository Files Expected to Change

```
plugin/models/roll.rb                    # new
plugin/models/pending_roll.rb            # new
plugin/models/character_soul_fields.rb   # add two collections (see §5)
plugin/public/soul_roll_api.rb           # new
plugin/events/soul_roll_expiry_cron.rb   # new, OR extend soul_xp_cron_handler.rb — see §5
plugin/public/soul_events.rb             # add SoulRollResolvedEvent (shape already documented in API_and_Hooks.md)
plugin/spec/soul_roll_api_spec.rb        # new
plugin/spec/roll_spec.rb                 # new (or fold into soul_roll_api_spec.rb if that's the repo's usual pattern — check how Phase 2/3 specs handled models with no dedicated API-adjacent behavior)
```

Do not create anything under `plugin/commands/` or `plugin/web/` in this pass.

## 4. Existing Services/APIs That Must Be Used

### `SoulDiceEngine` (complete, locked — `plugin/public/soul_dice_engine.rb`)

```ruby
SoulDiceEngine.roll(net_modifier)
  # => { total:, mode: (:normal/:explosion/:implosion), segments: [{d1:, d2:}, ...] }
  # Real RNG. This IS the dice portion of the roll — call it exactly once per resolution.

SoulDiceEngine.success_probability(net_modifier, required_dice_total)
  # => Float, 0.0..1.0. Pure/deterministic, no RNG. required_dice_total is the
  # dice-only threshold — i.e. (difficulty - effective_base), NOT the raw difficulty.
```

Both take `net_modifier` as a plain signed integer — the sum of every accepted B&B's signed modifier (positive for Boons, negative for Banes). Compute that sum yourself; the engine doesn't know about B&Bs.

### Framework / Character / B&B APIs (all complete from Phases 2–3)

```ruby
SoulFrameworkApi.get_skill(skill_key)                      # => hash or nil; use to validate skill_key
SoulCharacterApi.get_effective_base(character, skill_key)   # => skill_rating + aspect contribution (REQ-030's effective_base)
SoulBnbApi.get_character_entries(character)                  # => [CharacterBnbEntry, ...], owner view
SoulBnbApi.level_modifier(catalogue_entry, level_state)       # => positive magnitude Integer (or nil for unconfigured Epic)
Soul.can_play?(enactor)                                       # permission check
```

`BnbCatalogueEntry#modifier_eligible` and `#skill_associations` (Array of skill keys) determine whether a given owned, unresolved `CharacterBnbEntry` is a **candidate** for a roll on a given skill — see §6 for the exact rule.

### Audit

```ruby
SoulAuditApi.create(action:, character:, actor:, reason:, before_state: nil, after_state: nil, error: nil)
```

Use for pending-roll abort and expiry (staff/system actions on a character's state), not for every ordinary roll resolution (a completed `Roll` record already is the audit trail for normal play — REQ-031).

## 5. Constraints and Invariants That May Not Change

1. **Trigger vs. contribution timing is already baked into `SoulDiceEngine`.** Don't second-guess or re-derive explosion/implosion logic anywhere else — `SoulRollApi` only ever calls `.roll` and `.success_probability`, never re-implements dice math.
2. **Compute probability before rolling, in that order, for the same inputs.** Addendum §9 requires the probability to be *pre-roll*. Since `success_probability` is a pure function of `(net_modifier, required_dice_total)` and doesn't consume randomness, calling it before or after `.roll` doesn't change its value — but call it first anyway, so the code reads in the same order the spec describes and the stored `success_probability` field is unambiguously "what we knew going in," not "what we happened to compute after."
3. **Degrees of success use the corrected six-band table**, not the original ambiguous one:
   ```
   margin = final_result - difficulty
   Exceptional Success:   margin >= 10
   Success:               margin >= 0  and margin < 10
   Complicated Success:   margin >= -5  and margin < 0
   Lucky Failure:         margin >= -10 and margin < -5
   Failure:               margin >= -20 and margin < -10
   Catastrophic Failure:  margin < -20
   ```
   Read every threshold from `Global.read_config("soul", "rolls", "degrees_of_success")` (keys: `exceptional_success_min`, `success_min`, `complicated_success_min`, `lucky_failure_min`, `failure_min`, `catastrophic_failure_min`) — do not hardcode the numbers, even though the defaults above match the shipped config.
4. **Extraordinary flag uses the probability of the outcome that actually happened, not always P(success).** If the roll succeeded, compare `success_probability` (as returned by the engine) to the threshold. If the roll failed, compare `1.0 - success_probability` (the failure probability) to the threshold. Read the threshold from `rolls.extraordinary_result_threshold` (default `0.0001`).
5. **Candidate B&B identification rule:** an owned `CharacterBnbEntry` is a roll candidate for `skill_key` when all of: `entry.resolved != "true"`, `entry.catalogue_entry.modifier_eligible == "true"`, and `entry.catalogue_entry.skill_associations.include?(skill_key.to_s)`. No entry is a candidate by default/omission — an empty `skill_associations` array means "not associated with any skill," not "applies universally."
6. **Signed modifier per accepted entry** = `SoulBnbApi.level_modifier(entry.catalogue_entry, entry.level_state) * (entry.boon? ? 1 : -1)`. Sum across every *accepted* entry (system-suggested-and-selected, or manually-identified-and-selected) to get `net_modifier`. A `nil` `level_modifier` (unconfigured Epic — see `bnb_catalogue_entry.rb`'s comment) is an error state; return `{ error: ... }` rather than treating it as 0.
7. **`+roll suggested` accepts every system-suggested entry; `+roll <tag>` selects specific owned entries (candidate or manually-identified); `+roll none` accepts zero optional entries.** These are REQ-026's semantics — build `SoulRollApi`'s selection method to support all three without assuming a MUSH command layer exists yet (Phase 6 will call whatever you build here).
8. **"No candidates found" is not a distinct pending-roll status.** Per the corrected Data_Model.md, `system_suggested_entries: []` on an otherwise-normal `awaiting_selection` pending roll *is* the no-candidates case (REQ-028's manual-identification opportunity is always available via `manually_identified_entries`, regardless of whether the system found anything). Do not invent a `no_candidates` status.
9. **Pending-roll limit (Phase 4 scope):** before creating a new pending roll, count the character's open (`awaiting_selection`) pending rolls and reject if `>= Global.read_config("soul", "rolls", "max_pending_rolls_per_player")`. The GM-assisted limit (`max_pending_rolls_per_player_gm`) is Phase 5 territory — don't wire it up, since nothing in Phase 4 sets `gm_assisted: true`.
10. **Expiry is lazy-plus-swept, not silently correct-on-read only.** `expires_at` is set at creation (`Time.now + pending_roll_timeout_hours.hours`, using whatever time-arithmetic helper the rest of this codebase already uses — check `SoulResonanceApi`/`SoulXpApi` for the convention). A cron sweep (see below) actively flips `status` to `"expired"` for anything past its `expires_at` that's still `awaiting_selection`, with an audit entry, per Addendum §6 ("no auto-resolve" means no `Roll` record gets created, not that nothing happens — the status transition itself is required so a stale pending roll doesn't count against the pending-roll limit forever).
11. **Cron wiring:** `Soul.get_event_handler("CronEvent")` can only return one handler class per the real `AresMUSH::Dispatcher` (confirmed in earlier phases — see `plugin/soul.rb`). Do not try to register a second handler for the same event name; it won't be called. Instead, add the expiry sweep as an additional call inside the *existing* `plugin/events/soul_xp_cron_handler.rb`'s `on_event`, alongside (not replacing) its current weekly-XP-award logic — call something like `SoulRollApi.expire_stale_pending_rolls(event.time)` unconditionally on every tick (the method itself should be cheap — a query filtered by `expires_at < now` and `status == "awaiting_selection"` — so it doesn't need its own `Cron.is_cron_match?` gate the way the weekly award does).
12. **Boolean-like model attributes are plain `"true"`/`"false"` strings**, matching every existing model in this codebase — not `DataType::Boolean`. Apply this to any new boolean-shaped field (e.g. `gm_assisted`, `extraordinary`).
13. **Events fire via `Global.dispatcher.queue_event`, classes flat under `module AresMUSH`** (not nested under `Soul::`) — same convention as `plugin/public/soul_events.rb`'s existing `SoulBnbTransitionedEvent`/`SoulCulminationApprovedEvent`. Add `SoulRollResolvedEvent` there, matching the field list already documented in `docs/architecture/API_and_Hooks.md` (`character_id, roll_id, skill_key, final_result, degree_of_success, extraordinary, gm_assisted, resolved_at`).
14. **Never trust client-supplied identifiers or permissions** (REQ-002) — `SoulRollApi` methods that take a `pending_roll_id` must verify the pending roll actually belongs to the character/player making the call before mutating it. This matters even though no command layer exists yet, because Phase 6's commands will call these methods directly with user-supplied IDs.

## 6. Method Signatures to Implement

```ruby
SoulRollApi.get_candidate_bnbs(character, skill_key)
  # => [CharacterBnbEntry, ...] per the rule in §5.5

SoulRollApi.get_open_pending_count(character)
  # => Integer, count of this character's "awaiting_selection" pending rolls

SoulRollApi.start_roll(character, skill_key, context: {})
  # Validates: character present, skill_key resolves via SoulFrameworkApi.get_skill,
  # Soul.can_play?(character) [player is rolling for their own character],
  # pending-roll limit not exceeded (§5.9).
  # Creates a PendingRoll: system_suggested_entries = get_candidate_bnbs ids,
  # status: "awaiting_selection", expires_at per §5.10, context stored as given
  # (expected to carry at least a difficulty key/tier - validate it resolves via
  # rolls.difficulties, and optionally a scene_id).
  # => { error: "..." } or { success: true, pending_roll: <PendingRoll> }

SoulRollApi.select_entries(pending_roll_id, character, tags: [], suggested: false, none: false)
  # Exactly one of tags/suggested/none is meaningful per call (REQ-026's three
  # forms) - validate the caller didn't pass a nonsensical combination.
  # "suggested": accepts every entry in system_suggested_entries.
  # tags: resolves each tag to an owned, unresolved CharacterBnbEntry (candidate
  # OR not - an owned entry named explicitly by tag that ISN'T in
  # system_suggested_entries becomes a manually_identified_entry, never
  # misreported as system-suggested, per REQ-027).
  # "none": accepts zero optional entries (pending roll still resolvable with
  # no B&B modifiers).
  # Revalidates ownership/duplicates each call (REQ-028 step 6).
  # => { error: "..." } or { success: true, pending_roll: <PendingRoll> }

SoulRollApi.resolve_pending(pending_roll_id)
  # 1. Load pending roll, verify status == "awaiting_selection".
  # 2. Combine accepted entries (selected system-suggested + manually-identified).
  # 3. net_modifier = sum of signed level_modifier per §5.6.
  # 4. effective_base = SoulCharacterApi.get_effective_base(character, skill_key).
  # 5. difficulty = resolve from context against rolls.difficulties.
  # 6. required_dice_total = difficulty - effective_base.
  # 7. success_probability = SoulDiceEngine.success_probability(net_modifier, required_dice_total).
  # 8. dice = SoulDiceEngine.roll(net_modifier).
  # 9. final_result = dice[:total] + effective_base.
  # 10. margin = final_result - difficulty; degree_of_success per §5.3.
  # 11. extraordinary per §5.4.
  # 12. Create Roll record with every field from Data_Model.md's list.
  # 13. Update pending_roll: status "resolved" (do not delete - keep for audit trail
  #     of what was selected, matching this codebase's non-destructive convention).
  # 14. Global.dispatcher.queue_event SoulRollResolvedEvent.new(...).
  # => { error: "..." } or { success: true, roll: <Roll> }

SoulRollApi.abort_pending(pending_roll_id, actor, reason:)
  # Player aborts their own open pending roll (CI-03: "a player MAY abort until
  # the GM submits selections" - in Phase 4 there's no GM step, so this is
  # simply "abort any awaiting_selection pending roll belonging to actor's
  # character"). status -> "aborted", SoulAuditApi.create with actor + reason,
  # no Roll record created.
  # => { error: "..." } or { success: true }

SoulRollApi.expire_stale_pending_rolls(now = Time.now)
  # Sweep: every PendingRoll with status "awaiting_selection" and
  # expires_at < now -> status "expired", SoulAuditApi.create (actor: nil,
  # system-initiated). No Roll record. Returns the count swept (useful for
  # cron logging/tests), not required to return anything else.

SoulRollApi.get_roll_history(character, limit: 50)
  # => character.rolls, sorted by rolled_at descending, capped at limit
  # (mirror SoulXpApi.get_history's existing pattern exactly)
```

## 7. Acceptance Criteria

- `Roll` and `PendingRoll` models exist with every field listed in the current `docs/architecture/Data_Model.md` "Rolls" section, using the same attribute-typing conventions as every other model in this codebase (plain string booleans, `DataType::Array`/`DataType::Hash` where a structured value is stored, `reference`/`collection` for Character associations).
- `character.rolls` and `character.pending_rolls` collections work (added to `character_soul_fields.rb`).
- `SoulRollApi.resolve_pending` never calls any randomness itself — the only call into `SoulDiceEngine.roll` happens exactly once per resolution, and `success_probability` is computed from the same `net_modifier` and `required_dice_total` that `.roll` effectively resolves against.
- A roll with `net_modifier` derived from an unconfigured Epic-level entry (`level_modifier` returns `nil`) fails cleanly with an error rather than raising or silently treating the modifier as 0.
- The pending-roll limit is enforced before a new pending roll is created; exceeding it returns `{ error: }`, not a silently-truncated success.
- `expire_stale_pending_rolls` never creates a `Roll` record and never touches a pending roll that isn't `awaiting_selection` and past its `expires_at`.
- No code path in this handoff calls `SoulNarrativeHistoryApi.create` (see §1's exclusions).
- No code path calls `Global.dispatcher.dispatch(...)` (doesn't exist on the real Dispatcher) or references `get_hooks` (doesn't exist in real AresMUSH core) — only `Global.dispatcher.queue_event`.
- `Soul.get_event_handler("CronEvent")` still returns exactly one class, and that class now performs both the weekly XP sweep and the pending-roll expiry sweep on every tick.

## 8. Testing Requirements

- `plugin/spec/soul_roll_api_spec.rb`: cover `start_roll` (success, unknown skill, pending-limit exceeded), `select_entries` (all three REQ-026 forms, ownership rejection, duplicate rejection), `resolve_pending` (a full success path asserting the stored `Roll` fields are internally consistent — e.g. `final_result == dice_total + effective_base`, `degree_of_success` matches the margin thresholds, `extraordinary` only set when the relevant probability is below threshold), `abort_pending`, `expire_stale_pending_rolls` (sweeps exactly the expired ones, leaves others untouched), `get_roll_history`.
- At least one spec asserting the "no candidates found" case (`system_suggested_entries` empty) still produces a normal `awaiting_selection` pending roll that `select_entries` with `tags:` can complete via manual identification.
- At least one spec asserting a Boon-only roll (`net_modifier > 0`) and a Bane-only roll (`net_modifier < 0`) both resolve without error and produce plausible `final_result` values (don't need to assert exact numbers given the RNG — assert the modifier direction affected `net_modifier` correctly and that `dice_result`/`segments` round-trip through the stored `Roll`).
- Run `ruby -c` on every new/modified file and confirm `bundle exec rspec plugin/spec/soul_roll_api_spec.rb` (or however this repo's suite is invoked — check `docs/development/Testing.md`) passes before reporting completion, and note in your summary if the suite couldn't actually be run (e.g. missing `spec_helper.rb` harness — a pre-existing gap noted in the Phase 1-3 Implementation Notes; report the same issue again here rather than working around it silently).

## 9. Existing Repository Conventions Relevant to This Task

- Model style: see `plugin/models/character_bnb_entry.rb` and `plugin/models/soul_xp_ledger_entry.rb` for the established comment density and attribute-typing conventions (explain *why* a type choice was made, not what the code does).
- Service API style: see `plugin/public/soul_xp_api.rb`'s `.spend` method (validate → compute → atomic update → ledger/audit) — `resolve_pending` should follow the same shape.
- `Global.read_config("soul", ...)` is always called fresh at point of use, never memoized (CP-06).
- Every public API method returns `{ error: "..." }` on failure or a `{ success: true, ... }` / bare-data hash on success — never raises for an ordinary validation failure.

---

**Known exclusion reminder:** if anything in this handoff turns out to be underspecified once you're inside the code (for example, if `context`'s exact shape for carrying a difficulty tier proves awkward), stop and report it rather than deciding the shape yourself — per the Addendum's Architectural Rule, that's a design question for Claude, not an implementation detail for Codex to resolve unilaterally.

# Codex Handoff: Phase 5 GM-Assisted Rolls and Scene Integration

**Prepared by:** Claude (project architect)
**Date:** 2026-07-24
**Workflow:** Follows the "SOUL Codex Handoff Instructions" in `docs/spec/Implementation_Specification_Addendum.md`.

---

## 1. Scope

Extend Phase 4's standard-roll subsystem (`SoulRollApi`, `PendingRoll`, `Roll`) to support GM-assisted rolls: per-scene GM policy (Required/Optional/Unavailable), GM marking of mandatory/optional B&B entries with privacy-scoped visibility, player abort before GM submission, and staff/GM force-abort. This is a modification of the existing `plugin/public/soul_roll_api.rb`, not a new file — read the current version before starting; every method signature and helper name below refers to what's actually there today, not what an earlier doc described.

**Explicitly out of scope:**
- Any MUSH command (`+roll/gm`, etc.) or web handler — Phase 6, same precedent as every other subsystem.
- Roll-modifier contribution from other plugins — still no confirmed dispatch point (see `docs/architecture/Integration_Guide.md`'s "Providing Roll Modifiers" section).
- A per-scene override of `gm_scene_policy` — this phase treats it as a single global config value (see §5.2). Do not add a per-scene config field to the `Scene` model.
- Any change to `plugin/public/soul_dice_engine.rb` — locked dependency, unchanged since Phase 4.

## 2. Relevant Specification Sections

- `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` §6.4.4 (GM-Assisted Roll, REQ-029), CI-03 (Conversational Roll Flow — GM-assisted flow), CI-04 (Pending Roll Limits — GM-assisted cap of 2), REQ-005 (Scene-GM permission tier), REQ-027 (pending-roll state, already implemented in Phase 4).
- `docs/reference/Permissions.md`'s "Scene-GM Operations" section and "Privacy Model" (`gm_reveal_categories`).
- `game/config/soul.yml`'s `rolls.gm_scene_policy` and `privacy.gm_reveal_categories`/`warn_on_broader_reveal` — already shipped and validated (`plugin/soul_config_validator.rb`); no config changes needed this phase.
- `docs/architecture/Data_Model.md`'s "Rolls" section — read the current version; it already documents `gm_suggested_entries`/`gm_mandatory_entries`/`gm_assisted` as Phase-5-reserved fields.

## 3. Repository Files Expected to Change

```
plugin/public/soul_roll_api.rb    # modify existing methods, add new ones (see §6)
plugin/spec/soul_roll_api_spec.rb # extend existing spec file with Phase 5 coverage
```

No new model files. No new event classes (the existing `SoulRollResolvedEvent` already carries `gm_assisted` — Phase 4 always passed `"false"`; Phase 5 will pass the real value).

## 4. Existing Services/APIs That Must Be Used

```ruby
Soul.can_play?(character)          # existing player-tier check
Soul.can_review_rolls?(character)  # existing GM-tier check (gm_review_permission)
Soul.can_manage_soul?(character)   # existing staff-tier check
SoulAuditApi.create(action:, character:, actor:, reason:, before_state: nil, after_state: nil)
```

**New dependency this phase introduces:** `Login.notify(character, type, message, reference_id, data = "", notify_if_online = true)` — the real AresMUSH notification mechanism (`plugins/login/public/login_api.rb`), confirmed against current core. Use `Login.notify(pending.character, :soul, message, pending.id)` to satisfy REQ-029's "notify affected participants" on force-abort. Do not invent a different notification path.

**Scene model (real AresMUSH core, `plugins/scenes/public/scene.rb`) — confirmed fields/methods:**
```ruby
scene.owner            # reference to a Character (scene organizer)
scene.participants      # Set of Characters
scene.is_participant?(char)   # true for owner OR anyone in participants
```
There is **no** `gms`/`gm` field on the real `Scene` model. Do not invent one or add a custom field to `Scene` — see §5.1 for the scene-GM authorization rule this phase actually uses instead.

## 5. Constraints and Invariants That May Not Change

### 5.1 Scene-GM authorization (Claude's design decision — FINAL doesn't specify a mechanism)

A character has scene-GM authority for a given pending roll when **both**:
```ruby
Soul.can_review_rolls?(character) && scene && scene.is_participant?(character)
```
where `scene = Scene[pending.scene_id]` (nil-safe — if `pending.scene_id` is blank or the scene can't be loaded, authority is false, not an error swallowed silently). This is a real design decision, not documented anywhere else — it's now recorded here and should be treated as settled, not reopened. `Soul.can_manage_soul?(character)` always additionally satisfies any scene-GM-gated action (staff can always do what a scene-GM can, for corrective purposes) — see §5.6's force-abort authorization for exactly how these two checks combine.

### 5.2 GM scene policy is a single global config value

`Global.read_config("soul", "rolls", "gm_scene_policy")` is `"required"`, `"optional"`, or `"unavailable"` (already validated). It applies uniformly to every roll — there is no per-scene override in this phase. `start_roll` resolves the effective `gm_assisted` value from this policy plus a new `gm_requested:` argument (§6):
- `"required"` → always GM-assisted, regardless of `gm_requested`.
- `"optional"` → GM-assisted only if `gm_requested: true`.
- `"unavailable"` → never GM-assisted, regardless of `gm_requested` (silently falls back to standard — REQ-029 says "falls back to standard roll behavior," not an error).

A GM-assisted roll requires a resolvable scene — `context["scene_id"]` must be present and `Scene[scene_id]` must exist, or `start_roll` returns `{ error: }`. A standard (non-GM) roll still doesn't require a scene, unchanged from Phase 4.

### 5.3 New `PendingRoll` status: `"awaiting_gm"`

Phase 4 used `awaiting_selection` / `resolved` / `aborted` / `expired`. Phase 5 adds `awaiting_gm` for GM-assisted rolls only, inserted before `awaiting_selection`:

```
start_roll (gm_assisted) → "awaiting_gm" → gm_submit_selections → "awaiting_selection" → select_entries (optional-only) → resolve_pending → "resolved"
start_roll (standard)    → "awaiting_selection" → select_entries → resolve_pending → "resolved"          (unchanged from Phase 4)
```

Both `"awaiting_gm"` and `"awaiting_selection"` count as "open" for pending-roll-limit purposes (§5.4) and are both subject to expiry (§5.7). `select_entries` and `resolve_pending` still require status to be exactly `"awaiting_selection"` — a roll still `"awaiting_gm"` cannot be selected on or resolved yet.

### 5.4 Pending-roll limits are two independent caps, not a shared pool

CI-04's "standard: 1 open, GM-assisted: 2 open" means a player can have up to 1 open **standard** pending roll AND up to 2 open **GM-assisted** pending rolls at the same time — these are separate counters. `get_open_pending_count(character)` currently counts all `status == "awaiting_selection"` rolls with no `gm_assisted` distinction; change it to accept a `gm_assisted:` argument and count rolls matching both that flag and `status` in `["awaiting_gm", "awaiting_selection"]`. `start_roll` checks the counter and limit (`max_pending_rolls_per_player` vs `max_pending_rolls_per_player_gm`) matching the roll's own resolved `gm_assisted` value from §5.2.

### 5.5 GM candidate visibility is privacy-filtered, never the raw model

`get_gm_candidate_view` (§6) must never return a `CharacterBnbEntry`/`BnbCatalogueEntry` object directly to a caller — only a plain hash containing exactly the fields `Global.read_config("soul", "privacy", "gm_reveal_categories")` allows. The category-to-field mapping:
```
"name"                 -> catalogue_entry.name
"public_description"   -> catalogue_entry.description
"mechanical_effect"    -> the signed modifier (SoulBnbApi.level_modifier(...) * (boon? ? 1 : -1))
"character_explanation" -> entry.character_explanation
"gm_notes"             -> entry.gm_notes
```
Every returned hash always includes `id` and `tag` (needed to reference the entry — these aren't privacy-sensitive) regardless of configured categories. Default config (`name` + `public_description` only) means a GM reviewing candidates by default sees name/tag/id and public description — nothing else, not even the mechanical effect, unless the game has opted in.

### 5.6 GM submission is restricted to the pending roll's own candidate list

`gm_submit_selections` partitions **only** IDs already present in `pending.system_suggested_entries` into mandatory/optional — it does not accept arbitrary entry IDs or tags. Reject any `mandatory_ids`/`optional_ids` value not present in `pending.system_suggested_entries`, and reject any ID appearing in both lists (an entry can't be simultaneously mandatory and optional). A `system_suggested_entries` ID the GM doesn't mention in either list is simply not carried forward — it's dropped from consideration for this roll, not implicitly treated as optional. (The player's own separate right to manually identify additional owned B&Bs via `select_entries`'s `tags:` form is completely unaffected by this — that path never went through GM review to begin with, Phase 4 or 5.)

Authorization for `gm_submit_selections`: `Soul.can_manage_soul?(gm) || (Soul.can_review_rolls?(gm) && scene && scene.is_participant?(gm))` per §5.1. Requires `pending.status == "awaiting_gm"`.

### 5.7 Mandatory entries always apply; `resolve_pending` combines them in

`select_entries` is **unchanged in this phase** — it still governs only the player's optional selection (`player_selected_entries`/`manually_identified_entries`), including `none` (decline all optional entries). REQ-029's "Mandatory selections SHALL survive `+roll none`" is satisfied at resolution time, not selection time: `resolve_pending`'s accepted-entries set becomes `(player_selected_entries + manually_identified_entries + pending.gm_mandatory_entries).uniq` instead of just the first two. Keep the existing "duplicate ID" validation (`all_ids.uniq.length == all_ids.length`) scoped to `player_selected_entries + manually_identified_entries` only — a mandatory entry the player also happened to independently select is not a duplicate-submission error, it's just already covered; dedupe silently when building the final accepted set, don't reject it.

### 5.8 Player abort window narrows once the GM has submitted

`abort_pending`'s ownership/status validation currently requires `status == "awaiting_selection"` (via `validate_owned_open_pending`). Phase 5 changes the allowed-status set per caller:
- `select_entries`/`resolve_pending` still require exactly `"awaiting_selection"` (unchanged).
- The **player's own voluntary** `abort_pending` is allowed when `status == "awaiting_gm"` (before GM submission, any roll) OR when `status == "awaiting_selection" && pending.gm_assisted != "true"` (a standard roll, exactly Phase 4's existing behavior). It is **not** allowed when `status == "awaiting_selection" && pending.gm_assisted == "true"` — that means the GM already submitted, and per REQ-029/CI-03 only force-abort remains available past that point.

Refactor `validate_owned_open_pending(pending, character)` to accept an `allowed_statuses:` keyword (default `["awaiting_selection"]`, preserving every existing caller's behavior unchanged) so `abort_pending` can pass `allowed_statuses: pending && pending.gm_assisted == "true" ? ["awaiting_gm"] : ["awaiting_gm", "awaiting_selection"]` — reject the case described above by rejecting a GM-assisted `"awaiting_selection"` roll to the player's own abort call specifically once the GM has actually submitted, only permitting `"awaiting_gm"` for those.

### 5.9 New: `force_abort_pending`

Staff/scene-GM may force-abort a pending roll **at any open status** (`"awaiting_gm"` or `"awaiting_selection"`, regardless of whether the GM has already submitted), unlike the player's own narrower `abort_pending` window. Authorization: `Soul.can_manage_soul?(actor) || (Soul.can_review_rolls?(actor) && scene && scene.is_participant?(actor))` (§5.1). Requires a non-blank `reason:`. Sets `status: "aborted"`, creates an audit entry (`action: "roll_force_abort"`, `actor:`, `reason:`), and calls `Login.notify(pending.character, :soul, <message mentioning the reason>, pending.id)` to satisfy "notify affected participants" — the player's own voluntary `abort_pending` does not need to self-notify (they already know), but force-abort acts on someone else's roll and must tell them.

### 5.10 Expiry sweep and validators must recognize `"awaiting_gm"` as open

`expire_stale_pending_rolls` currently filters `PendingRoll.find(status: "awaiting_selection")` only — extend it to sweep both `"awaiting_gm"` and `"awaiting_selection"` past their `expires_at`. `get_open_pending_count` (§5.4) already covers both statuses per that section.

### 5.11 Boolean-like fields, events, error-hash contract — unchanged conventions

Same conventions as Phase 4: plain `"true"`/`"false"` strings, every method returns `{ error: }` or `{ success: true, ... }`, `Global.read_config` called fresh at point of use, never memoized.

## 6. Method Signatures to Implement / Modify

```ruby
# MODIFIED - new gm_requested: kwarg, resolves effective gm_assisted per §5.2,
# checks the matching limit per §5.4, creates status "awaiting_gm" instead of
# "awaiting_selection" when gm_assisted resolves true, requires a resolvable
# scene in that case.
SoulRollApi.start_roll(character, skill_key, context: {}, gm_requested: false)

# NEW - privacy-filtered candidate view for GM review (§5.5). Returns
# { error: } or { success: true, candidates: [{ id:, tag:, <configured fields> }, ...] }
SoulRollApi.get_gm_candidate_view(pending_roll_id, gm)

# NEW - GM marks mandatory/optional from the existing candidate list (§5.6).
# => { error: } or { success: true, pending_roll: <PendingRoll> }
SoulRollApi.gm_submit_selections(pending_roll_id, gm, mandatory_ids: [], optional_ids: [])

# UNCHANGED signature; behavior unchanged (§5.7) - still governs only the
# optional bucket.
SoulRollApi.select_entries(pending_roll_id, character, tags: [], suggested: false, none: false)

# MODIFIED - accepted-entries set now includes pending.gm_mandatory_entries (§5.7).
SoulRollApi.resolve_pending(pending_roll_id, character)

# MODIFIED - narrower allowed-status window for GM-assisted rolls (§5.8).
SoulRollApi.abort_pending(pending_roll_id, actor, reason:)

# NEW - staff/scene-GM only, any open status, notifies the roller (§5.9).
# => { error: } or { success: true }
SoulRollApi.force_abort_pending(pending_roll_id, actor, reason:)

# MODIFIED - now takes gm_assisted: to check the correct independent cap (§5.4).
SoulRollApi.get_open_pending_count(character, gm_assisted: false)

# MODIFIED - sweeps both "awaiting_gm" and "awaiting_selection" (§5.10).
SoulRollApi.expire_stale_pending_rolls(now = Time.now)
```

## 7. Acceptance Criteria

- `start_roll` with `gm_scene_policy: "required"` always produces a `gm_assisted: "true"`, `status: "awaiting_gm"` pending roll regardless of `gm_requested`, and rejects a missing/unresolvable scene.
- `start_roll` with `gm_scene_policy: "optional"` produces a standard roll unless `gm_requested: true` is passed.
- `start_roll` with `gm_scene_policy: "unavailable"` never produces a GM-assisted roll even if `gm_requested: true` is passed, and does not error — it silently falls back.
- A player with 1 open standard roll can still start a GM-assisted roll (and vice versa) — the two caps don't share a counter.
- `get_gm_candidate_view` never includes `character_explanation` or `gm_notes` under the default config, and a character without scene-GM authority for that pending roll gets `{ error: }`, not a filtered-but-present view.
- `gm_submit_selections` rejects an ID not in `pending.system_suggested_entries`, rejects overlap between mandatory and optional, and rejects a caller without scene-GM authority.
- A roll with `gm_mandatory_entries` set still applies those modifiers after the player calls `select_entries(..., none: true)` — verified by asserting `net_modifier` on the resulting `Roll` reflects the mandatory entry even though `player_selected_entries` is empty.
- The player's own `abort_pending` succeeds while `status == "awaiting_gm"` and fails once `status == "awaiting_selection" && gm_assisted == "true"` (GM already submitted) — but still succeeds for a standard (`gm_assisted == "false"`) roll in `"awaiting_selection"`, unchanged from Phase 4.
- `force_abort_pending` succeeds regardless of which of the two open statuses the roll is in, requires a reason, and results in exactly one `Login.notify` call to the roller.
- `expire_stale_pending_rolls` now also expires stale `"awaiting_gm"` rolls, not just `"awaiting_selection"` ones.
- No existing Phase 4 test's expected behavior changes for a **standard** (non-GM) roll — every modification above is additive/branching on `gm_assisted`, not a change to the non-GM path.

## 8. Testing Requirements

Extend `plugin/spec/soul_roll_api_spec.rb` (same file, same Fabrication/RSpec conventions as the existing Phase 4 coverage) with:
- `.start_roll` under each of the three `gm_scene_policy` values, with and without `gm_requested:`, including the missing-scene rejection case for a GM-assisted attempt.
- Independent-cap test: a character at the standard limit can still start a GM-assisted roll.
- `.get_gm_candidate_view`: default-config filtering (asserts absence of `character_explanation`/`gm_notes` keys entirely, not just blank values), authorization rejection for a non-participant with `can_review_rolls?`, authorization rejection for a participant without `can_review_rolls?`.
- `.gm_submit_selections`: success partitioning a known candidate set, rejection for an ID outside `system_suggested_entries`, rejection for overlapping mandatory/optional, rejection for missing scene-GM authority, status transition to `"awaiting_selection"`.
- `.resolve_pending`: a roll with only `gm_mandatory_entries` set (no player selection at all) still applies that modifier.
- `.abort_pending`: success in `"awaiting_gm"`, rejection once `"awaiting_selection"` with `gm_assisted: "true"`, continued success for a standard roll in `"awaiting_selection"` (regression check against Phase 4 behavior).
- `.force_abort_pending`: success from both open statuses, reason requirement, exactly one `Login.notify` call (stub it — don't assume a real `LoginNotice` model is fabricatable in this harness), authorization rejection for a non-staff non-scene-GM caller.
- `.expire_stale_pending_rolls`: a stale `"awaiting_gm"` roll is swept alongside a stale `"awaiting_selection"` one.
- Run `ruby -c` on the modified file and note (as Phase 4's implementation notes already did) whether the suite could actually execute given the still-missing `plugin/spec/spec_helper.rb` harness — don't attempt to fix that gap yourself, just report it again if still present.

## 9. Existing Repository Conventions Relevant to This Task

- Reuse `validate_owned_open_pending`, `resolve_owned_tags`, `load_accepted_entries`, `build_applied_modifiers`, `expire_pending`, `serialize_dice`, `normalize_context`, `resolve_difficulty` exactly as they already exist — extend their parameters where §5 calls for it (e.g. `validate_owned_open_pending`'s new `allowed_statuses:` keyword), don't duplicate their logic in a new method.
- `SoulAuditApi.create`'s `before_state`/`after_state` convention from `expire_pending`/Phase 3's audit calls — follow the same shape for `force_abort_pending`'s audit entry.
- Every `Global.read_config("soul", ...)` call is fresh, never memoized (CP-06) — matches every existing method in this file.

---

**Known exclusion reminder:** if anything here proves awkward once you're inside the code — for example if `validate_owned_open_pending`'s new keyword interacts strangely with an existing caller — stop and report it rather than redesigning the authorization/status-machine rules yourself. §5.1's scene-GM rule and §5.2's policy-resolution rule are Claude's explicit design decisions for gaps FINAL left open; they are settled for this phase, not something to reinterpret.

# Codex Handoff: Phase 7 Inklings Integration Hook

**Prepared by:** Claude (project architect)
**Date:** 2026-07-24
**Workflow:** Follows the "SOUL Codex Handoff Instructions" in `docs/spec/Implementation_Specification_Addendum.md`.

---

## 1. Scope

Implement `SoulInklingsHook`, the two-step validate/apply integration point already documented in `docs/architecture/Integration_Guide.md` (Pattern: Inklings Outcome Validation and Application) and `docs/architecture/API_and_Hooks.md`. This is the only piece of Phase 7 that requires new business logic — the Grimoire side of Phase 7 (read-only Skill/Aspect/Resonance access, branch-to-Skill mapping) is already done: `SoulCharacterApi.get_skill_rating`/`get_aspect_rating`, `SoulResonanceApi.get_resonance`, and the new `SoulFrameworkApi.get_skill_for_grimoire_branch` (plus its `game/config/soul.yml` `integrations.grimoire.branch_skill_map` config and validator check) were added directly by Claude — read-only lookups over an existing config-driven catalogue, not something requiring a handoff.

**In scope:**
- `SoulInklingsHook.validate_outcome` / `.apply_outcome` for four outcome types: `:xp`, `:boon_progression`, `:bane_progression`, `:culmination`.
- The idempotency design in §5 — this is the one genuinely tricky part, because two of the four outcome types (`boon_progression`/`bane_progression`) call into `SoulBnbApi.grant`/`.progress`, **neither of which has any built-in duplicate-delivery protection today**. Read §5 carefully before writing any code.

**Explicitly out of scope:**
- Any change to `SoulBnbApi.grant`/`.progress`, `SoulXpApi.award`, `SoulCulminationApi.propose`, or any other existing service API — the hook works around the one real gap (§5) using data these methods already store, not by modifying them.
- Grimoire's own casting/spell logic — Grimoire is a separate plugin (not part of this repository) that will call SOUL's already-existing read APIs when it's built; nothing here changes based on Grimoire's own implementation.
- Inklings' own code — Inklings is a separate plugin/repository. This handoff only builds SOUL's side of the contract; Inklings will need its own future update to actually call `SoulInklingsHook`, which is out of scope for this repository.
- MUSH/web commands for anything in this handoff — there is no direct player-facing command for `SoulInklingsHook`; it's called programmatically by Inklings' own approval workflow, not a command a person types.

## 2. Relevant Specification Sections

- `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` §8.1 (REQ-038, Common Integration Rules), §8.2 (REQ-039, Inklings).
- `docs/architecture/Integration_Guide.md`'s "Pattern: Inklings Outcome Validation and Application" — **the exact `proposed_transition` shape shown there (`{ catalogue_id: 22, from: "Minor", to: "Major" }`) is the established public contract; match it exactly, don't invent a different shape.**
- `docs/architecture/API_and_Hooks.md`'s "Integration Contracts" section for the method signatures already documented.
- `docs/architecture/Data_Model.md`'s B&B section (`CharacterBnbEntry#source`/`#progression_history`) and Culmination section (`Culmination#source`) for the fields this handoff's idempotency design reuses.

## 3. Repository Files Expected to Change

```
plugin/public/soul_inklings_hook.rb       # new
plugin/spec/soul_inklings_hook_spec.rb    # new
```

No model changes. No config changes (this handoff doesn't need any new config beyond what already exists).

## 4. Existing Services/APIs That Must Be Used

```ruby
SoulXpApi.award(character, amount, source:, idempotency_key: nil, apply_catchup: true)
  # Already idempotent via idempotency_key - SoulXpLedgerEntry.find_one(idempotency_key:) short-circuits a repeat call.

SoulBnbApi.get_catalogue_entry(id_or_tag)
SoulBnbApi.grant(character, catalogue_ref, level_state:, source:, explanation: nil, enactor: nil)
  # NOT idempotent on its own - calling twice with the same source creates two entries. See §5.
SoulBnbApi.progress(entry_id, new_level_state, source:, explanation: nil, enactor: nil)
  # NOT idempotent on its own - calling twice with the same source double-progresses. See §5.
SoulBnbApi.ratio_satisfied_after_boon?(character)
  # Same 2:1 check .grant already runs internally for a Boon - re-run it yourself during validate_outcome
  # (before staff approval) so Inklings gets an actionable error early, even though .grant will also
  # re-check it at apply time regardless.

SoulCulminationApi.propose(character, title:, description:, source:, enactor: nil)
  # Already idempotent by source - a repeat call with the same source returns
  # { success: true, culmination: existing, duplicate: true } rather than creating a second record.

SoulCharacterApi.get_skill_rating(character, skill_key)
SoulFrameworkApi.get_skill(skill_key)
```

```ruby
Character[id]   # standard Ohm lookup, for re-deriving character from a stored payload's character_id
```

## 5. Constraints and Invariants That May Not Change

### 5.1 The two-step contract's state boundary

`validate_outcome` **never mutates anything** — it only checks shape/state and returns a normalized payload or an error. `apply_outcome` is the only method that changes SOUL state, and it **must re-run every check `validate_outcome` ran**, not trust the stored payload blindly — real time passes between Inklings' initial submission and staff approval, during which the character's B&B ratio, Resonance, or the target entry's level could have changed. Implement the actual validation logic once, in a shared private method both public methods call, so there's exactly one place these rules live (CP-09).

### 5.2 Idempotency design — reuse existing stored fields, don't add a new marker mechanism

Per REQ-038 ("consumers SHALL be idempotent where duplicate delivery is possible") and REQ-039 ("revalidate current state and idempotency"), `apply_outcome` must be safe to call more than once with the same `source` (e.g. a retried "inkling:234" delivery) without double-applying. The four outcome types need different treatment because their underlying APIs differ in what they already provide:

- **`:xp`** — already solved. Pass `idempotency_key: source` straight through to `SoulXpApi.award`; it already short-circuits a repeat call via `SoulXpLedgerEntry.find_one(idempotency_key:)`. Do nothing extra.
- **`:culmination`** — already solved. `SoulCulminationApi.propose`'s own source-based dedup (`character.culminations.to_a.find { |c| c.source == source.to_s && c.status != "denied" }`) already returns the existing record rather than creating a second one. Do nothing extra.
- **`:boon_progression` / `:bane_progression` — NOT already solved, this is the real gap.** Neither `grant` nor `progress` checks whether this exact `source` was already applied. Before calling either:
  - **For a fresh grant** (no existing character entry for this catalogue reference — see §5.3 for how to tell): check `character.character_bnb_entries.to_a.any? { |e| e.catalogue_entry && e.catalogue_entry.id.to_s == catalogue_id.to_s && e.source == source.to_s }`. If true, this exact grant was already applied by a previous call with this `source` — return the existing entry's info as `soul_references` with `duplicate: true`, and do **not** call `.grant` again.
  - **For a progression of an existing entry:** check whether `entry.progression_history` already contains a hash with `"source" => source.to_s` (any entry in the array, not just the most recent one — a retry could arrive after further legitimate progressions). If true, already applied — return `{ success: true, soul_references: { character_bnb_entry_id: entry.id }, duplicate: true }` without calling `.progress` again.

This reuses data these models already store (`source` on the entry itself, `source` inside each `progression_history` row) rather than inventing a parallel audit-marker table — the B&B record remains the single source of truth for "did source X already affect this entry," consistent with CP-09.

### 5.3 Grant vs. progression is determined by whether `proposed_transition["from"]` is present

Matching the documented example (`{ catalogue_id: 22, from: "Minor", to: "Major" }`):
- If `from` is present and non-blank: this is a **progression** of an existing character entry. Locate it via `character.character_bnb_entries.to_a.find { |e| e.catalogue_entry && e.catalogue_entry.id.to_s == catalogue_id.to_s && e.resolved != "true" }`. If not found, or its current `level_state` doesn't case-insensitively match `from`, this is a validation failure — `{ error: "..." }` (this is exactly the "state changed since submission" case REQ-039 requires re-checking for; do not silently proceed with a mismatched `from`).
- If `from` is absent/blank: this is a **fresh grant** at the level given by `to`. If the character already owns an unresolved entry for this catalogue reference, this is also a validation failure (`{ error: "Character already owns this Boon/Bane." }`) — a fresh grant should never target a catalogue entry the character already has, regardless of idempotency (idempotency handles "the same request arrived twice," not "grant something already owned via a different source").

### 5.4 `proposed_transition` shape per outcome type

```ruby
:xp
  { "amount" => Integer }   # positive; validate_outcome rejects <= 0

:boon_progression / :bane_progression
  { "catalogue_id" => <id or tag>, "from" => <level_state or nil/blank>, "to" => <level_state> }
  # "to" must be a key in rolls... no - in bnb.level_definitions (game/config/soul.yml).
  # The catalogue entry resolved via catalogue_id must have kind matching the outcome_type
  # ("boon_progression" -> catalogue_entry.boon?, "bane_progression" -> catalogue_entry.bane?) -
  # reject a mismatch (e.g. outcome_type: :boon_progression naming a Bane's catalogue_id) as a
  # validation error rather than silently granting/progressing the wrong kind.

:culmination
  { "title" => String, "description" => String }   # both required, non-blank
```

Reject an unrecognized `outcome_type` in `validate_outcome` with a clear error — don't let it fall through silently.

### 5.5 Normalized payload shape (what `validate_outcome` returns, what `apply_outcome` consumes)

The payload is what Inklings stores until staff approval — it must be plain, JSON-safe data (string keys, no live model references), since Inklings may serialize it to its own DB field for however long approval takes:

```ruby
{
  "outcome_type" => "boon_progression",   # string, not symbol
  "character_id" => character.id,
  "proposed_transition" => { "catalogue_id" => "22", "from" => "Minor", "to" => "Major" },
  "requester_id" => requester && requester.id,
  "inkling_reference" => inkling_reference
}
```

`apply_outcome(payload, source:)` re-derives `character = Character[payload["character_id"]]` (error if not found — the character could have been deleted between submission and approval) and re-runs the full validation (§5.1) against current state before doing anything else.

### 5.6 `soul_references` returned by a successful `apply_outcome`

```ruby
:xp                => { awarded:, base_award:, catchup_portion: }   # SoulXpApi.award's own result, passed through
:boon_progression /
:bane_progression   => { character_bnb_entry_id: }
:culmination        => { culmination_id: }
```

### 5.7 XP outcomes always apply catch-up; this is not a manual grant

Per `Implementation_Specification_Addendum.md` §8's catch-up sourcing list ("Scene participation, Inklings completion, Boon/Bane awards... Excludes: Manual XP grants by admins"), an Inklings-sourced XP outcome is an **automatic** source, not a manual staff grant — call `SoulXpApi.award(character, amount, source: source, idempotency_key: source, apply_catchup: true)`. Do not default `apply_catchup` to `false` the way the manual `+xp/award` command does.

### 5.8 No SOUL-side permission check on `requester`

Unlike a player-facing command, this hook is called by Inklings' own already-authorized approval workflow (Inklings validates permissions on its own side per REQ-038's "validate permissions in both plugins where applicable" — that's Inklings' half, already outside this repository). Don't add a `Soul.can_play?`/`Soul.can_manage_soul?` check on `requester` here — this matches the existing precedent that `SoulBnbApi.grant`/`.progress`/`SoulCulminationApi.propose` all accept `enactor: nil` for system/integration-initiated changes without requiring a permission check on that value.

### 5.9 Narrative History / Audit

Every successful `apply_outcome` outcome type already creates its own Narrative History and/or audit entry through the underlying API it calls (`grant`/`progress` create `SoulNarrativeHistoryApi` entries and fire `SoulBnbTransitionedEvent`; `propose` creates its own Culmination record which is itself the narrative trail; `award` creates a `SoulXpLedgerEntry`). The hook does **not** need to create any additional Narrative History or audit entry of its own — doing so would duplicate what the underlying API already records for the same `source`.

## 6. Method Signatures to Implement

```ruby
SoulInklingsHook.validate_outcome(outcome_type:, character:, proposed_transition:, requester: nil, inkling_reference:)
  # => { error: "..." } or the normalized payload hash from §5.5 (no "error" key present on success)

SoulInklingsHook.apply_outcome(payload, source:)
  # => { error: "..." } or { success: true, soul_references: <shape from §5.6> } (+ duplicate: true
  #    per §5.2 when idempotency short-circuited an already-applied outcome)
```

## 7. Acceptance Criteria

- `validate_outcome` never creates, updates, or deletes any record, regardless of input.
- `apply_outcome` called twice in a row with the identical `payload`/`source` for a `:boon_progression`/`:bane_progression` outcome results in exactly one `CharacterBnbEntry` (or exactly one progression step) — not two.
- `apply_outcome` for `:xp`/`:culmination` relies entirely on the underlying API's own idempotency — no redundant duplicate-check logic added for those two types.
- A `:boon_progression` naming a catalogue entry that's actually a Bane (kind mismatch) is rejected as a validation error, not silently granted/progressed.
- A progression whose stored `from` no longer matches the entry's actual current `level_state` (state changed since submission) is rejected by `apply_outcome`, even if `validate_outcome` accepted it earlier.
- No new Narrative History or audit entries are created directly by `SoulInklingsHook` itself — only via the underlying APIs it calls.
- No permission check is added on `requester`.

## 8. Testing Requirements

- `plugin/spec/soul_inklings_hook_spec.rb`: cover all four outcome types for both `validate_outcome` (success, each documented validation failure) and `apply_outcome` (success, idempotent re-delivery for boon/bane specifically, the kind-mismatch rejection, the stale-`from` rejection, character-not-found on a stale `character_id`).
- At least one test asserting a repeated `apply_outcome` call for the same `:boon_progression` payload/source results in `CharacterBnbEntry.all.to_a.length` (scoped to the test's own character) staying at 1, not 2.
- Run `ruby -c` on the new file; note whether `plugin/spec/spec_helper.rb`'s continued absence still prevents actually executing the suite (same standing note as every prior phase).

## 9. Existing Repository Conventions Relevant to This Task

- `plugin/public/soul_bnb_api.rb`'s `.grant`/`.progress` for the exact field names/shapes this hook reads and writes through.
- `plugin/public/soul_culmination_api.rb`'s `.propose` for the source-based dedup pattern already established.
- Every public API method returns `{ error: "..." }` or `{ success: true, ... }` — match this exactly, no exceptions raised for ordinary validation failures.
- File/module convention: flat `module AresMUSH; class SoulInklingsHook`, matching every other `*_api.rb`/`*_hook.rb` file in `plugin/public/` (not nested under `module Soul`).

---

**Known exclusion reminder:** the idempotency design in §5.2 and the grant-vs-progression rule in §5.3 are Claude's explicit resolutions of a real gap (`grant`/`progress` have no built-in duplicate protection) — not implementation details open to reinterpretation. If a case arises that doesn't fit cleanly (e.g. a progression where the target catalogue entry has been deactivated between submission and approval), stop and report it rather than deciding new behavior unilaterally.

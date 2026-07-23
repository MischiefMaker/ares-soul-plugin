# SOUL Data Model

Database schema and data structures for SOUL, derived from `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") §4.3 (REQ-003), §5 (Character Model), §6 (Mechanics), and `docs/spec/Implementation_Specification_Addendum.md` ("Addendum") for resolved mechanical values. REQ-* references point to FINAL's Requirements Index.

## Character Framework

### Aspects and Skills Are Configured Catalogues, Not Database Models

Aspects and Skills are **not** separate Ohm::Model classes. They are read directly from `game/config/soul.yml`'s `framework.aspects` and `framework.skills` (via `SoulFrameworkApi`), matching the verified real convention from AresMUSH's own bundled FS3Skills plugin — ability/attribute/skill *definitions* live entirely in config (`plugins/fs3skills/helpers/utils.rb`: `Global.read_config("fs3skills", "action_skills")`, etc.); only the per-character *rating* gets a DB-backed model (`FS3ActionSkill`). SOUL follows the same split. This also matches CP-06 (Configuration over Hard-Coding) more directly than a DB catalogue would.

### Aspect (configured, `SoulFrameworkApi.get_aspects` / `get_aspect(key)`)

A broad configured category representing innate or foundational capability, organizing related Skills (GL-04, REQ-009).

**Config shape** (`framework.aspects.<key>`):
- `key` — Stable identifier used by core logic (never the display name); the config hash key itself
- `name` — Configurable display name
- `description` — What this Aspect represents
- `order` — Display order

**Defaults:** Body, Mind, Spirit (REQ-008). Names, stable keys, descriptions, ordering, and displayed terminology are all configurable.

**Contribution to rolls (REQ-009, Addendum §7 — `SoulCharacterApi.aspect_contribution`/`get_effective_base`):**
```
Aspect Contribution = round_nearest(Aspect Rating × aspect.weight)
Effective Base = Skill Rating + Aspect Contribution
```
`aspect.weight` defaults to `0.20` (DD-06). Per CP-03, equivalent Skill investment SHALL matter substantially more than Aspect investment — Aspects remain secondary to Skills.

### Skill (configured, `SoulFrameworkApi.get_skills` / `get_skill(key)`)

A learned capability belonging to exactly one Aspect (GL-05, REQ-010).

**Config shape** (`framework.skills.<key>`):
- `key` — Stable identifier; the config hash key itself
- `name` — Display name
- `aspect` — Parent Aspect's stable key (config field name `aspect`, exposed as `aspect_key` from `SoulFrameworkApi.get_skill`)
- `order` — Display order

**Defaults:** Rating range `0–10` (`framework.skill_min_rating`/`skill_max_rating`). Labels: `0` Untrained; `1–3` Trained; `4–6` Experienced; `7–9` Expert; `10` Exceptional/Master. All Skills begin at `0` unless configured otherwise.

### CharacterAspect (`AresMUSH::CharacterAspect`, `plugin/models/character_aspect.rb`)

A character's rating in a specific configured Aspect — the DB-backed half of the Aspect split described above.

**Key Attributes:**
- `character` — `reference` to `AresMUSH::Character`
- `aspect_key` — Stable key into `framework.aspects`
- `rating` — Current rating, default `0`

### CharacterSkill (`AresMUSH::CharacterSkill`, `plugin/models/character_skill.rb`)

A character's rating in a specific configured Skill — the DB-backed half of the Skill split described above. Shaped identically to FS3Skills' own `FS3ActionSkill` (`reference :character`, a stable key, a `rating`).

**Key Attributes:**
- `character` — `reference` to `AresMUSH::Character`
- `skill_key` — Stable key into `framework.skills`
- `rating` — Current rating (0–10, ultimate cap regardless of Resonance tier), default `0`
- `last_advanced_at`

## Resonance (GL-06, REQ-012, `SoulResonanceApi`)

Optional, configurable, chargen-only measure of setting-relative starting position. R0 is the normal protagonist baseline. Resonance affects starting resources and chargen ceilings, not ultimate potential.

**Key Attributes (Character custom fields, `plugin/models/character_soul_fields.rb`):**
- `resonance` — Plain (untyped) attribute, not `DataType::Integer`. Ohm's Integer cast (`x.to_i`) turns a genuinely unset value into `0`, which would be indistinguishable from an explicit R0 choice — read via `SoulResonanceApi.get_resonance`, which parses manually and preserves the nil-vs-R0 distinction.
- `resonance_locked_at` — `DataType::Time` (nil-safe); set once by `SoulResonanceApi.lock_at_approval`, called from the game's own `plugins/chargen/custom_approval.rb` (manual-paste snippet — see `custom-install/custom_approval.snippet.rb` — **not** a plugin-defined `hooks/` class; there is no framework-level chargen-approval hook dispatch, only `get_cmd_handler`/`get_event_handler`/`get_web_request_handler`)
- `resonance_correction_log` — `DataType::Array`; append-only `{old_value, new_value, actor, reason, corrected_at}` entries from `SoulResonanceApi.correct`, standing in for the real Narrative History/Audit models until Phase 3 builds them

**Canonical symmetric table (REQ-012):**

| Resonance | Skill points | Chargen cap |
|---:|---:|---:|
| R-3 | 9 | 4 |
| R-2 | 11 | 5 |
| R-1 | 13 | 6 |
| R0 | 15 | 7 |
| R1 | 17 | 8 |
| R2 | 19 | 9 |
| R3 | 21 | 10 |

Resonance normally locks at approval and does not advance later. Positive Resonance MAY require at least one Bane whose catalogue definition has `modifier_eligible: true` (staff MAY override with recorded reason) — enforced once Phase 3's B&B catalogue exists.

## XP and Advancement (GL-11, REQ-013, `SoulXpApi`)

**Key Attributes (Character custom fields, `plugin/models/character_soul_fields.rb`):**
- `soul_xp_available` — Current spendable XP (`DataType::Integer`, default `0`)
- `soul_xp_earned` — Lifetime Earned XP (base awards only, never includes catch-up bonus)
- `soul_xp_spent` — Lifetime Spent XP
- `soul_catchup_xp_earned` — Catch-Up XP Earned (bonus portion only, tracked separately per GL-12)

Unlike Resonance, these safely use `DataType::Integer, :default => 0` — every character has them from creation (matching FS3Skills' own `attribute :fs3_xp, :type => DataType::Integer, :default => 0`), so the nil-casts-to-zero behavior never distinguishes a meaningfully different "unset" state.

### SoulXpLedgerEntry (`AresMUSH::SoulXpLedgerEntry`, `plugin/models/soul_xp_ledger_entry.rb`)

One award or spend event — the "source ledger/idempotency records" domain from REQ-003.

**Key Attributes:**
- `character` — `reference`
- `direction` — `"award"` or `"spend"`
- `source` — e.g. `"weekly"`, `"scene:42"`, `"admin"`, or a Skill key for spends
- `idempotency_key` — Indexed; a repeated delivery of the same logical event (a re-fired cron tick) is detected via this and made a no-op rather than double-awarding (REQ-013)
- `base_amount` — Base award amount, or XP cost for a spend
- `catchup_amount` — Catch-up bonus portion (awards only)
- `created_at`

XP SHALL NOT directly buy Boons or remove Banes (GL-11).

### XP Cost Formula (Addendum §3 — resolves REQ-045's open cost-table decision)

```
base_cost = ceil(new_rating² / 2)
development_modifier = 1 + (xp_spent / 250)^1.25
resonance_modifier = (char_resonance > 0) ?
                      (1 + 0.22 × char_resonance + 1 × char_resonance) :
                      (1 + 0.12 × char_resonance)
final_cost = ceil(base_cost × development_modifier × resonance_modifier)
```

Costs are non-decreasing as ratings rise (REQ-015 invariant). Implemented in `SoulXpApi.calculate_cost` (`xp_spent` is read live via `SoulXpApi.get_lifetime_spent_xp`, `char_resonance` via `SoulResonanceApi.get_resonance`).

### Catch-Up XP (GL-12, REQ-014, Addendum §8)

- Eligibility: median `xp_earned` across approved, active characters (`Chargen.approved_chars`, not `Character.all` — excludes NPCs/rosters/inactive, per the real convention `plugins/chargen/public/chargen_api.rb` establishes). New characters are included immediately (no grace period).
- The median is computed live on every award (`SoulXpApi.median_earned_xp`) rather than cached and periodically recalculated — this naturally satisfies "weekly recalculation" (Addendum §8) since the weekly award cron (`xp.weekly_award_cron`) is the main point awards happen, without a separate recalculation job to keep in sync.
- Progress metric: `xp_earned + catchup_xp_earned`.
- Multiplier: `2.0×` (configurable) applied only when `apply_catchup: true` is passed to `SoulXpApi.award` — the manual-grant staff command (`+xp/award`) omits it by default; `+xp/award/catchup` passes it explicitly.
- Bonus SHALL be capped at the current median gap.

```
catchup_portion = award_after_multiplier - base_award
current_xp += award_after_multiplier
lifetime_earned_xp += base_award
catchup_xp_earned += catchup_portion
```

## Boons & Banes (CI-01, GL-07/08/09/10, REQ-016 through REQ-022, `SoulBnbApi`)

B&Bs use **two layers**: a site-wide catalogue and character-owned entries referencing it. This is a deliberate architectural split — do not collapse them into one table. Unlike Aspects/Skills, the catalogue **is** a real Ohm::Model (not config-driven) — FINAL REQ-017 requires "a unique numeric ID" (satisfied by Ohm's own auto-incrementing `.id`, no custom generator needed) and `SOUL_Design_Decisions.md` DD-02 confirms entries are created via in-game commands, not seeded from config.

### BnbCatalogueEntry (`AresMUSH::BnbCatalogueEntry`, `plugin/models/bnb_catalogue_entry.rb`)

**Key Attributes (REQ-017):**
- `tag` / `tag_upcase` — Stable unique short key (GL-10); uniqueness enforced at `SoulBnbApi.create_catalogue_entry` (check-then-create), matching the real convention used for `AresMUSH::Role` names — Ohm has no native unique-constraint mechanism
- `name`, `description` — Display name and public description
- `kind` — `"boon"` or `"bane"` (GL-07/GL-08). Not explicitly itemized in REQ-017's field list, but required by every mechanic that depends on distinguishing the two: the 2:1 chargen ratio, the separate Boon/Bane chargen limit tables, and GL-07/GL-08's own definitions
- `category` — Configurable grouping, independent of `kind`; defaults are **Arcane** and **Mundane** (CI-01, `game/config/soul.yml`'s `bnb.categories`). A Boon and a Bane can share a category
- `chargen_available` / `flag_for_review` / `modifier_eligible` — Plain `"true"`/`"false"` string attributes, not `DataType::Boolean` (its cast `!!x` turns even the stored string `"false"` into `true` — the same footgun documented for Resonance, matching the verified convention from Inklings' own `Inkling#locked`)
- `epic_modifier` — Only meaningful for the Epic level/state (see below); `nil` means "not configured"
- `skill_associations` — Array of Skill keys

**Level/state modifiers** come from global config (`game/config/soul.yml`'s `bnb.level_definitions`) and apply uniformly to every catalogue entry: Minor `+1`, Major `+2`, Legendary `+3`, Negated no active modifier. Epic is the one level FINAL requires an "explicitly configured" **per-entry** effect for (REQ-017: "the label alone SHALL NOT imply an uncapped modifier") — hence `epic_modifier` living on the catalogue entry itself rather than in global config. `SoulBnbApi.level_modifier(catalogue_entry, level_state)` resolves either source correctly.

Example: `22. Cursed — Your character carries some sort of curse.` (catalogue entry, kind Bane, category Mundane).

### CharacterBnbEntry (`AresMUSH::CharacterBnbEntry`, `plugin/models/character_bnb_entry.rb`)

**Key Attributes (REQ-018):**
- Its own auto-incrementing `.id` is a separate sequence from the catalogue's — e.g. catalogue **Cursed** might be `#27`, while Sarah's and Morgan's instances are `#123` and `#146`, both referencing catalogue `#27` (FINAL's own worked example)
- `character`, `catalogue_entry` — References
- `level_state` — Current level/state (`"minor"`/`"major"`/`"legendary"`/`"negated"`/`"epic"`, or configured equivalents)
- `character_explanation` — Private; owner + authorized staff only
- `associated_skills`, `source` (e.g. `"[Chargen]"`, `"[Inkling 234]"`), `progression_history` (array, appended to per attained level), `gm_notes` (staff-only)
- `resolved` — `"true"`/`"false"`; non-destructive (never hard-deleted; FINAL REQ-021)
- `preserved_level_state` — The level held immediately before resolution/negation, restored by `SoulBnbApi.restore` (REQ-020)

Example: `22. Minor | Cursed [cursed] — A small curse causes clumsiness and weakness. Skills: Strength, Reflexes.`

Public presentation (`SoulBnbApi.get_character_entry_public`) shows `Level | Name [tag]`, numeric ID, and mechanical modifier only — never the private explanation or GM notes (REQ-018).

### States (REQ-020)

- **Resolved** (Banes) / **Negated** (Boons) — same underlying mechanic (`resolved: "true"`), different label by convention. Removes ordinary cost/modifier/suggestion behavior while preserving the narrative record and prior level (`preserved_level_state`). Restoring (`SoulBnbApi.restore`) returns the entry to that preserved level.
- **Epic** — growth beyond the normal catalogue scale; requires a documented source and the catalogue entry's explicit `epic_modifier`. Chargen availability defaults to `false`.

### Ratio and Chargen Limit Enforcement (Addendum §5)

`SoulBnbApi.ratio_satisfied_after_boon?` enforces the 2:1 Boon-to-Bane ratio **continuously** — checked on every Boon grant regardless of source (chargen or post-chargen approved workflow), per the Addendum's own "continuous enforcement" design rationale. `SoulBnbApi.validate_chargen_limits` enforces the per-Resonance-level count/level tables (`game/config/soul.yml`'s `bnb.resonance_levels`) — checked **only** when `source: "chargen"`, since those tables are explicitly framed as chargen-time limits, not lifetime caps.

## Culminations (GL-15, REQ-023, `SoulCulminationApi`)

A permanent SOUL record of a significant story milestone or accomplishment (`AresMUSH::Culmination`, `plugin/models/culmination.rb`) — **not** an XP purchase. Unlike B&Bs, Culminations have no shared catalogue: each is a bespoke, staff-authored (or approved-Inkling-sourced) record, closer in shape to the real AresMUSH Achievements plugin's per-grant record (`plugins/achievements/public/achievement.rb`) than to the two-layer B&B model.

**Key Attributes:**
- `character`, `title`, `description`
- `source` — e.g. `"staff"`, `"inkling:234"`; also used for deterministic duplicate detection (`SoulCulminationApi.propose` is a no-op if an active Culmination with the same source already exists)
- `status` — `"proposed"` / `"approved"` / `"denied"` / `"revoked"`
- `visibility`, `source_link`
- `approved_by`, `approved_at`
- `correction_log` — Append-only `{action, actor, reason, at}` entries for corrections/revocations; the original record is never deleted or overwritten

Staff approval is required by default (`culminations.approval_required`) unless automation is explicitly enabled. Another plugin MAY propose a Culmination but SHALL NOT create it directly — SOUL owns the record.

## Narrative History (GL-16, REQ-024, `SoulNarrativeHistoryApi`)

The character-facing record of meaningful SOUL-owned events (`AresMUSH::NarrativeHistoryEntry`, `plugin/models/narrative_history_entry.rb`) — distinct from the technical Audit log (CP-07). Other SOUL APIs call `SoulNarrativeHistoryApi.create` when they perform a qualifying transition; it isn't meant to be created directly by commands or web handlers.

**Key Attributes:**
- `character`, `event_type`, `narrative` (concise, character-facing), `visibility`
- `soul_record_type` / `soul_record_id` — Two plain attributes standing in for a polymorphic reference (Ohm has no native polymorphic association) — e.g. `soul_record_type: "CharacterBnbEntry"`
- `external_reference` — e.g. an Inkling ID; SOUL never copies the external record's own history alongside this
- `correction_of_id` — Set when this entry is itself a correction/reversal of an earlier one; the original is never overwritten (CP-07)
- `audit_entry_id` — Links back to the `SoulAuditEntry` created alongside this one, if any

Qualifying events: approved starting Resonance, B&B acquisition/progression/resolution/negation, significant configured advancement, Culminations, and authorized corrections/reversals. Ordinary reads, failed validation, retries, and diagnostics SHALL NOT create Narrative History entries — those belong only in the Audit log. `SoulNarrativeHistoryApi.get_history(character, viewer)` returns entries only to the owner or authorized staff (`Soul.can_manage_soul?`).

## Audit Log (GL-17, `SoulAuditApi`)

The technical, staff-only operational record (`AresMUSH::SoulAuditEntry`, `plugin/models/soul_audit_entry.rb`): `character` (subject, if any), `actor` (who performed the action, nil for system/cron-initiated entries), `action`, `reason`, `source`, `before_state`/`after_state` (Hashes), `error` (set only for a recorded failure). MAY contain technical detail unsuitable for Narrative History. Corrections and reversals append linked records; originals are always preserved (never overwritten or deleted). `SoulAuditApi.get_audit(character, viewer)` is staff-only — unlike Narrative History, the character it concerns cannot read their own Audit entries.

## Rolls (GL-18/19, REQ-025 through REQ-031)

### Roll (completed, `AresMUSH::Roll`)

**Key Attributes (REQ-031, Addendum §2/§8.1/§9):**
- `character_id`
- `skill_key`, `aspect_key`
- `scene_id` / context
- `difficulty` — the numeric target (from `rolls.difficulties`)
- `dice_result` — Raw 2d20 open-ended result including any explosion/implosion chain (Addendum §2); stores the segment-by-segment detail `SoulDiceEngine.roll` returns, not just the summed total
- `net_modifier` — the summed Boon/Bane modifier that drove the dice engine's reroll band (positive/negative/zero)
- `applied_modifiers` — Array with source categories (system-suggested, GM-mandatory, player-selected, manually-identified); each entry records the B&B entry id, catalogue tag/name, level_state, and signed modifier value
- `final_result` — dice total + effective base (Skill + Aspect contribution) per REQ-030
- `success_probability` — the pre-roll probability calculated by `SoulDiceEngine.success_probability` (Addendum §9: "store calculated probability alongside roll record for audit/transparency"); this is the probability of the outcome that actually occurred (success chance if the roll succeeded, failure chance if it failed), not always "chance of success"
- `degree_of_success` — One of six degrees (Addendum §8.1)
- `extraordinary` — Boolean flag, set when the relevant probability above was ≤ `extraordinary_result_threshold` (default 0.01%, Addendum §9)
- `gm_assisted` — Boolean; always `false` in Phase 4 (no GM-assisted rolls exist yet), reserved for Phase 5
- `rolled_at`

### PendingRoll (REQ-027, `AresMUSH::PendingRoll`)

**Key Attributes:**
- `player_id`, `character_id`
- `skill_key`, `aspect_key`
- `scene_id` / context
- `difficulty` and other validated inputs
- `system_suggested_entries` — candidate B&B entry ids identified automatically (may be empty; REQ-028's "no candidates found" case is simply an empty list, not a distinct status)
- `gm_suggested_entries`, `gm_mandatory_entries` — present in the schema per REQ-027's full field list, but unused/always empty until Phase 5 implements GM-assisted rolls
- `player_selected_entries`
- `manually_identified_entries` — distinct from system suggestions; a player may identify and add a relevant owned B&B the system did not suggest, marked as identified/override, never misreported as a system suggestion
- `status` — Phase 4 uses `awaiting_selection` / `resolved` / `aborted` / `expired` only; Phase 5 adds GM-assisted statuses (e.g. `gm_input`)
- `gm_assisted` — Boolean; always `false` in Phase 4, reserved for Phase 5
- `expires_at`

Expiry (Addendum §6): 720 hours (~30 days) wall-clock. Expired rolls are marked inactive; no auto-resolution occurs. Pending-roll limits (CI-04 canonical defaults): standard player rolls `1` open, GM-assisted rolls `2` open (configurable) — only the standard limit is enforced until Phase 5.

## Character Integration

SOUL attaches to Ares Characters by reopening `AresMUSH::Character` and declaring plain attributes directly (`plugin/models/character_soul_fields.rb`) — there is no `char.custom.soul_*` or `char.custom['...']` accessor on Character; that pattern doesn't exist in real AresMUSH source. A custom field is a normal Ohm attribute (`char.resonance`, `char.soul_xp_available`, etc.) that has to be declared before anything can read or write it — skipping the declaration produces a runtime `undefined method` error on every page that touches it. `custom_char_fields.rb` (a separate, game-owned file covered by its own manual-paste snippet) is only involved when a field needs to surface on the profile/chargen web forms — it does not create the underlying storage. See `docs/architecture/Plugin_Architecture.md`.

## Relationship Diagram

```
Character (resonance, resonance_locked_at, soul_xp_* attributes)
  ├─→ CharacterAspect (aspect_key → configured Aspect)
  ├─→ CharacterSkill (skill_key → configured Skill, which has an aspect_key)
  ├─→ SoulXpLedgerEntry (award/spend history)
  ├─→ CharacterBnbEntry → BnbCatalogueEntry
  ├─→ Culmination
  ├─→ NarrativeHistoryEntry (soul_record_type/id → any of the above)
  ├─→ SoulAuditEntry (as subject; actor may be a different Character)
  ├─→ Roll / PendingRoll
```

## Data Integrity (CP-07)

- Aspects and Skills are configuration, not database rows — "marking inactive" means removing or editing the config entry; existing `CharacterAspect`/`CharacterSkill` records referencing a since-removed key simply become orphaned data (harmless, but `SoulFrameworkApi.get_aspect`/`get_skill` will return `nil` for it).
- `BnbCatalogueEntry`s can be marked inactive (`active: "false"`) but not deleted (preserve history for characters who already hold an entry referencing it).
- `CharacterBnbEntry`s are never hard-deleted by ordinary play — resolution/negation (`SoulBnbApi.resolve`/`restore`) preserves the record (REQ-021). Actual deletion (`SoulBnbApi.delete`) requires two explicit confirmations, an audit snapshot, and a linked Narrative History correction.
- `Culmination` corrections/revocations append to `correction_log` rather than modifying the original `title`/`description`/`status` destructively — `SoulCulminationApi.revoke`/`.correct` never delete a record.
- Corrections and reversals append linked `NarrativeHistoryEntry`/`SoulAuditEntry` records; originals are always preserved.
- Rolls are append-only; pending rolls that expire or are aborted never produce a completed result.

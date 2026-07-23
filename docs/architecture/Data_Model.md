# SOUL Data Model

Database schema and data structures for SOUL, derived from `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") §4.3 (REQ-003), §5 (Character Model), §6 (Mechanics), and `docs/spec/Implementation_Specification_Addendum.md` ("Addendum") for resolved mechanical values. REQ-* references point to FINAL's Requirements Index.

## Character Framework

### Aspect

A broad configured category representing innate or foundational capability, organizing related Skills (GL-04, REQ-009).

**Key Attributes:**
- `key` — Stable identifier used by core logic (never the display name)
- `name` — Configurable display name
- `description` — What this Aspect represents
- `order` — Display order

**Defaults:** Body, Mind, Spirit (REQ-008). Names, stable keys, descriptions, ordering, and displayed terminology are all configurable.

**Relationships:** Has many Skills.

**Contribution to rolls (REQ-009, Addendum §7):**
```
Aspect Contribution = round_nearest(Aspect Rating × aspect.weight)
Effective Base = Skill Rating + Aspect Contribution
```
`aspect.weight` defaults to `0.20` (DD-06). Per CP-03, equivalent Skill investment SHALL matter substantially more than Aspect investment — Aspects remain secondary to Skills.

### Skill

A learned capability belonging to exactly one Aspect (GL-05, REQ-010).

**Key Attributes:**
- `key` — Stable identifier
- `name` — Display name
- `description` — What the skill represents
- `aspect_key` — Parent Aspect (stable key, not display name)
- `order` — Display order

**Defaults:** Rating range `0–10`. Labels: `0` Untrained; `1–3` Trained; `4–6` Experienced; `7–9` Expert; `10` Exceptional/Master. All Skills begin at `0` unless configured otherwise.

**Relationships:** Belongs to Aspect; has many CharacterSkill ratings.

### CharacterSkill

A character's rating in a specific Skill.

**Key Attributes:**
- `character_id`
- `skill_key`
- `rating` — Current rating (0–10, ultimate cap regardless of Resonance tier)
- `last_advanced_at`

## Resonance (GL-06, REQ-012)

Optional, configurable, chargen-only measure of setting-relative starting position. R0 is the normal protagonist baseline. Resonance affects starting resources and chargen ceilings, not ultimate potential.

**Key Attributes (stored on character SOUL state):**
- `resonance` — Approved value, range `R-3` through `R3`
- `locked_at` — Timestamp of chargen-approval lock
- `correction_history` — Original value, new value, actor, reason, source (for administrative correction only)

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

Resonance normally locks at approval and does not advance later. Positive Resonance MAY require at least one Bane whose catalogue definition has `modifier_eligible: true` (staff MAY override with recorded reason).

## XP and Advancement (GL-11, REQ-013)

**Key Attributes (character SOUL state + ledger):**
- `xp_available` — Current spendable XP
- `xp_earned` — Lifetime Earned XP (base awards only, never includes catch-up bonus)
- `xp_spent` — Lifetime Spent XP
- `catchup_xp_earned` — Catch-Up XP Earned (bonus portion only, tracked separately per GL-12)
- `source ledger` — One entry per award/spend with idempotency key, source, actor, timestamp

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

Costs are non-decreasing as ratings rise (REQ-015 invariant).

### Catch-Up XP (GL-12, REQ-014, Addendum §8)

- Eligibility: weekly recalculation against median `xp_earned` across approved characters (new characters included immediately, no grace period).
- Progress metric: `xp_earned + catchup_xp_earned`.
- Multiplier: `2.0×` (configurable) applied to all automatic sources except manual admin grants.
- Bonus SHALL be capped at the current median gap.

```
catchup_portion = award_after_multiplier - base_award
current_xp += award_after_multiplier
lifetime_earned_xp += base_award
catchup_xp_earned += catchup_portion
```

## Boons & Banes (CI-01, GL-07/08/09/10, REQ-016 through REQ-022)

B&Bs use **two layers**: a site-wide catalogue and character-owned entries referencing it. This is a deliberate architectural split — do not collapse them into one table.

### Boon/Bane Catalogue (site-wide, public)

**Key Attributes (REQ-017):**
- `id` — Unique numeric ID (catalogue-wide)
- `tag` — Stable unique short key (GL-10), used to reference the B&B without quoting its full name
- `name` — Display name
- `description` — Public description
- `category` — Configurable; defaults are **Arcane** and **Mundane** (CI-01)
- `level_definitions` — Configurable level/state definitions: name, mechanical effect, ordering, `chargen.available`
- `chargen.available` — default `true`
- `chargen.flag_for_review` — default `false`
- `chargen.modifier_eligible` — default `false`
- `skill_associations` — optional Skill tags/matching metadata

**Default level modifiers:** Minor `+1`, Major `+2`, Legendary `+3`. Negated has no active modifier by default. Epic has no implied modifier and SHALL use its explicitly configured effect — the label alone never implies an uncapped modifier. All level/state effects and chargen availability are configurable, but modifier effects SHALL be globally bounded so Skills remain meaningful (REQ-017, REQ-020).

Example: `22. Cursed — Your character carries some sort of curse.` (catalogue entry, category Mundane).

### Character B&B Entry (owner + authorized staff only)

**Key Attributes (REQ-018):**
- `id` — Unique numeric ID (this specific character-owned instance; distinct from the catalogue ID it references — e.g. catalogue **Cursed** is `#27`, Sarah's instance is `#123`, Morgan's is `#146`, both referencing `#27`)
- `character_id`
- `catalogue_id` — Reference to the Boon/Bane catalogue entry
- `level_state` — Current level/state (Minor/Major/Legendary/Negated/Epic, or configured equivalents)
- `character_explanation` — Private, character-specific explanation (owner + authorized staff only)
- `associated_skills` — Skills this entry modifies
- `source` — e.g. `[Chargen]`, `[Inkling 234]`
- `progression_history` — One entry per attained level/state, each with its own explanation and source marker
- `gm_notes` — Optional, staff-only
- `resolved` — Non-destructive resolved/negated flag (never hard-deleted; see FINAL REQ-021)

Example: `22. Minor | Cursed [cursed] — A small curse causes clumsiness and weakness. Skills: Strength, Reflexes.`

Public presentation shows `Level | Name [tag]`, numeric ID where useful, and mechanical modifier only — never the private explanation or GM notes (REQ-018).

### States (REQ-020)

- **Resolved** (Banes) / **Negated** (Boons) — same underlying mechanic, different label by convention. Default numeric value `0`; removes ordinary cost/modifier/suggestion behavior while preserving the narrative record and prior level. Restoring returns the entry to its preserved level. Chargen availability defaults to `false`.
- **Epic** — growth beyond the normal catalogue scale; requires a documented source and explicit configured mechanical effect. Chargen availability defaults to `false`.

## Culminations (GL-15, REQ-023)

A permanent SOUL record of a significant story milestone or accomplishment — **not** an XP purchase.

**Key Attributes:**
- `id` — Stable identifier
- `title` / `name`
- `narrative_description`
- `timestamp`
- `awarding_actor` / `source` (staff review, approved Inkling, standalone workflow, or proposal from another plugin)
- `visibility`
- `source_link` — External reference where applicable
- `status`
- `correction_links` / `revocation_links` — appended, never destructive

Staff approval is required by default unless automation is explicitly enabled. Another plugin MAY propose a Culmination but SHALL NOT create it directly — SOUL owns the record.

## Narrative History (GL-16, REQ-024)

The character-facing record of meaningful SOUL-owned events — distinct from the technical audit log (CP-07).

**Key Attributes:**
- `event_type`
- `timestamp`
- `actor` / `source`
- `narrative` — Concise, character-facing
- `visibility`
- `soul_record_reference`
- `external_reference` — optional (e.g. an Inkling ID; SOUL SHALL NOT copy Grimoire spell history)
- `correction_reversal_relationship`
- `linked_audit_id`

Qualifying events: approved starting Resonance, B&B acquisition/progression/resolution/negation, significant configured advancement, Culminations, and authorized corrections/reversals. Ordinary reads, failed validation, retries, and diagnostics SHALL NOT create Narrative History entries — those belong only in the audit log.

## Audit Log (GL-17)

Operational record of actors, timestamps, sources, reasons, before/after values, errors, and administrative actions. MAY contain technical detail unsuitable for Narrative History. Corrections and reversals append linked records; originals are always preserved (never overwritten or deleted).

## Rolls (GL-18/19, REQ-025 through REQ-031)

### Roll (completed)

**Key Attributes (REQ-031):**
- `character_id`
- `skill_key`, `aspect_key`
- `scene_id` / context
- `difficulty`
- `dice_result` — Raw 2d20 open-ended result including any explosion/implosion chain (Addendum §2)
- `applied_modifiers` — Array with source categories (system-suggested, GM-mandatory, player-selected, manually-identified)
- `final_result`
- `degree_of_success` — One of six degrees (Addendum §8.1)
- `extraordinary` — Boolean flag, set when pre-roll probability was ≤ 0.01% (Addendum §9)
- `rolled_at`

### PendingRoll (REQ-027)

**Key Attributes:**
- `player_id`, `character_id`
- `skill_key`, `aspect_key`
- `scene_id` / context
- `difficulty` and other validated inputs
- `system_suggested_entries`
- `gm_suggested_entries`
- `gm_mandatory_entries`
- `player_selected_entries`
- `manually_identified_entries` — distinct from system suggestions; a player may identify and add a relevant owned B&B the system did not suggest, marked as identified/override, never misreported as a system suggestion
- `status` — waiting / GM-input / player-choice / resolved / aborted / expired
- `expires_at`

Expiry (Addendum §6): 720 hours (~30 days) wall-clock. Expired rolls are marked inactive; no auto-resolution occurs. Pending-roll limits (REQ-044 canonical defaults): standard player rolls `1` open, GM-assisted rolls `2` open (configurable per Addendum §6).

## Character Integration

SOUL attaches to Ares Characters via custom fields (`char.custom.soul_*`) per the AresMUSH `custom_char_fields.rb` convention — not a separate SOUL-owned Character subclass. See `docs/architecture/Plugin_Architecture.md`.

## Relationship Diagram

```
Character
  ├─→ CharacterSkill → Skill → Aspect
  ├─→ Resonance (chargen-locked)
  ├─→ XP ledger (xp_available, xp_earned, xp_spent, catchup_xp_earned)
  ├─→ Character B&B Entry → Boon/Bane Catalogue Entry
  ├─→ Culmination
  ├─→ Narrative History entry
  ├─→ Roll / PendingRoll
  └─→ Audit Log entry
```

## Data Integrity (CP-07)

- Skills, Aspects, and Boon/Bane catalogue entries can be marked inactive but not deleted (preserve history).
- Character B&B entries are never hard-deleted by ordinary play — resolution/negation preserves the record (REQ-021). Actual deletion requires two-step confirmation, an audit snapshot, and a linked Narrative History correction.
- Corrections and reversals append linked records; originals are always preserved.
- Rolls are append-only; pending rolls that expire or are aborted never produce a completed result.

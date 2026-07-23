> **DO NOT DELETE OR EDIT THIS FILE WITHOUT EXPLICIT INSTRUCTION FROM THE PROJECT OWNER.**
> This document is creator-built. Claude may read and cite it, but SHALL NOT modify,
> delete, or rewrite any part of it absent explicit owner permission for that specific change.

# SOUL LLM Implementation Specification

**Version:** 2.0 canonical working draft  
**Purpose:** Implementation-facing requirements for SOUL.  
**Audience:** Claude and human implementers.  
**Authority:** The latest project-owner-approved version of this document governs SOUL-specific behavior.

# 0. Document Framework

## 0.1 Normative Language

- **SHALL / SHALL NOT**: required or prohibited.
- **SHOULD / SHOULD NOT**: strongly recommended; deviations require a documented implementation reason.
- **MAY**: optional.
- **Default**: required initial behavior unless valid configuration overrides it.
- **Invariant**: never configurable unless this specification is amended.

## 0.2 Informative Content

Only text labelled **Implementation Note**, **Example**, **Rationale**, or **Deferred** is informative. Unlabelled prose inside a requirement block is normative when it uses SHALL, SHOULD, MAY, or defines a canonical default, formula, state, field, permission, command, workflow, or interface behavior.

## 0.3 Document Style

- Each concept has one canonical home under **CP**, **CI**, **GL**, or a **REQ** block.
- Later sections SHALL reference canonical IDs rather than repeat their content.
- Requirement blocks use stable `REQ-*` identifiers and appear in the Requirements Index.
- Commands use tables with syntax, actor, purpose, and constraints.
- Configuration uses tables with key/area, type, default, and rule.
- Workflows use ordered state transitions.
- Examples illustrate requirements but SHALL NOT redefine them.
- Historical rationale and rejected alternatives belong in `SOUL_Design_Decisions.md`.

## 0.4 Authority and Conflict Resolution

Authority order:

1. this specification;
2. newer project-owner-approved ADRs awaiting incorporation;
3. `Claude.md` and repository development guidance;
4. current official AresMUSH conventions;
5. community examples.

Valid configuration overrides a configurable default but SHALL NOT override an invariant. Claude SHALL surface unresolved ambiguity or conflict to the project owner rather than inventing a rule.

# 1. Core Principles

## CP-01 — Story First

Mechanics SHALL support collaborative storytelling rather than replace it. Where several safe, maintainable implementations satisfy a requirement, prefer the one that produces clearer, more meaningful play.

## CP-02 — Distinct Growth Paths

Mechanical and narrative growth SHALL remain distinct. XP, Resonance, Boons, Banes, and Culminations serve different purposes and SHALL NOT be collapsed into one advancement currency.

## CP-03 — Training Outweighs Talent

Skills are the primary measure of competence. Aspects represent broader innate potential and SHALL contribute less to a roll than equivalent Skill investment.

## CP-04 — Plugin Ownership

A plugin owns its own data, workflow, validation, business rules, and history. Integrations SHALL use published hooks, APIs, services, or events and SHALL NOT duplicate or directly mutate another plugin's domain.

## CP-05 — Equal Interfaces

MUSH and web are equal, first-class interfaces. No supported workflow SHALL require switching interfaces. Both SHALL enforce the same permissions and service-layer rules and produce equivalent persistent state.

## CP-06 — Configuration over Hard-Coding

Anything a game is reasonably likely to rename, tune, limit, enable, or disable SHOULD be configurable. Safe defaults SHALL keep configuration comprehensible.

## CP-07 — Preserve History

Meaningful character changes and staff interventions SHALL remain traceable. Prefer state transitions, corrections, reversals, and audit snapshots over silent deletion.

## CP-08 — AresMUSH First

SOUL SHALL use established AresMUSH helpers, APIs, plugin layout, permissions, Jobs, scenes, chargen, localization, and UI patterns where suitable. New infrastructure SHOULD be introduced only when existing mechanisms cannot satisfy the requirement cleanly.

## CP-09 — One Rule, One Home

Each concept SHALL have one canonical definition. Other sections MAY link to or demonstrate that rule but SHALL NOT restate it merely for emphasis.

# 2. Creator's Intent

This section is authoritative product and implementation guidance. If it conflicts with a later section, this section governs until the conflict is corrected.

## CI-01 — Catalogue and Character B&Bs

Boons and Banes (B&Bs or `bnb`) use two layers:

| Layer | Required data | Visibility |
|---|---|---|
| Site-wide catalogue | unique numeric ID, stable key/tag, name, category, public description, level defaults, chargen flags | public |
| Character B&B | catalogue reference, level/state, character-specific explanation, associated Skills, source/history, optional GM notes | owner and authorized staff, subject to privacy rules |

Default configurable categories are **Arcane** and **Mundane**.

Example catalogue entry: `22. Cursed — Your character carries some sort of curse.`  
Example character entry: `22. Minor | Cursed [cursed] — A small curse causes clumsiness and weakness. Skills: Strength, Reflexes.`

## CI-02 — Concise Sheet

The primary `+soul` command and web view SHALL display the SOUL Sheet.

The default Sheet SHALL:

- list each Aspect with its Skills beneath it;
- show numeric Aspect and Skill values;
- show condensed B&B summaries with ID, level/state, modifier, and affected Skills;
- include the information needed for ordinary play;
- fit within approximately one MUSH screen (roughly 40–50 lines) where practical;
- move long descriptions and history to drill-down commands or web disclosure controls.

`+bnb <id>` SHALL show the catalogue description. For an owned entry, it SHALL also show the character-specific explanation. Authorized staff SHALL have an equivalent view for other characters. Both interfaces SHALL provide the full catalogue.

## CI-03 — Conversational Roll Flow

A roll SHALL pause only when a player or GM must make a meaningful choice. Every pause SHALL explain what is needed and how to continue.

**Player roll:** start roll → identify matching B&Bs → present concise suggestions or state that none matched → player selects optional entries or none → resolve.

**GM-assisted roll:** start roll → identify matching B&Bs → GM marks entries as optional suggestions or mandatory selections → player chooses optional entries → resolve with all mandatory and chosen optional entries.

The player remains the roller. A player MAY abort until the GM submits selections; an affected GM SHALL be notified.

## CI-04 — Pending Roll Limits

Configurable defaults:

- standard player rolls: `1` open;
- GM-assisted rolls: `2` open.

When an additional open roll remains within the limit, SOUL SHOULD remind the player. Roll messages SHOULD include the relevant Scene ID when one exists.

## CI-05 — Short, Guessable Commands

Commands SHOULD be short, memorable, and easy to guess. Prefer one-word verbs, shallow command families, concise routes, and concise identifiers where clarity is preserved. Avoid names approaching patterns such as `inkling/needschanges` unless the distinction is necessary.

## CI-06 — Progressive Disclosure

Present immediately what a user needs to decide or act. Put explanations, histories, GM-only information, and large catalogues behind drill-down views, modals, or subcommands.

## CI-07 — Actionable Errors

Errors SHALL say what failed and how to correct it. Include useful identifiers such as B&B ID, Inkling ID, Job ID, character, or Scene ID when applicable. Avoid generic failure messages.

## CI-08 — User-Facing Documentation

Player, admin, installation, and configuration documentation SHALL focus on what the feature does, how to install/configure it, and how to use it. Internal architecture and code rationale belong in developer documentation or Design Decisions, not ordinary help files. The admin help topic SHALL be named `manage soul`.

## CI-09 — Responsive by Default

Frequently used commands and handlers SHOULD avoid unnecessary queries and loading large collections. Static catalogue/configuration lookups MAY be cached with safe invalidation.

## CI-10 — Cross-Interface Text Safety

Text crossing between MUSH and web SHALL use the appropriate AresMUSH formatting helpers, including `format_input_for_html` and `format_input_for_mush`, for colour codes, line breaks, descriptions, B&B text, Inkling text, GM notes, and similar rich input.

# 3. Glossary

## GL-01 — SOUL

The plugin and system defined by this specification: a configurable Character Framework, advancement, narrative-trait, roll, history, and integration system for AresMUSH.

## GL-02 — Sheet

The complete representation of a character's SOUL state, independent of presentation. “Sheet” may refer to the underlying state or its MUSH/web display. It does not imply that SOUL represents the character's entire identity.

## GL-03 — Character Framework

The configured arrangement of Aspects and Skills used by every SOUL character.

## GL-04 — Aspect

A broad configured category representing innate or foundational capability and organizing related Skills. Default Aspects are Body, Mind, and Spirit.

## GL-05 — Skill

A learned capability belonging to exactly one Aspect. Skills are the primary input to competence and advancement.

## GL-06 — Resonance

An optional, configurable chargen-only measure of setting-relative starting position. R0 is the normal protagonist baseline. Resonance affects starting resources and ceilings, not ultimate potential.

## GL-07 — Boon

A story-earned advantage, strength, relationship, reputation, resource, quality, or other beneficial narrative trait.

## GL-08 — Bane

A narrative weakness, complication, limitation, vulnerability, or cost. Banes are resolved through play rather than removed with XP.

## GL-09 — B&B Level and State

B&B levels and states are configurable definitions. Defaults are Minor, Major, Legendary, Negated, and Epic. Each definition SHALL specify its mechanical effect and whether it is available during chargen. Negated and Epic default to unavailable during chargen.

## GL-10 — Tag

A unique, short identifier used to reference a B&B without quoting its full name. Full names MAY be accepted; collisions SHALL produce a disambiguation list using tags and IDs.

## GL-11 — XP

The primary resource for mechanical advancement, including Skills and other configured mechanical traits. XP SHALL NOT directly buy Boons or remove Banes.

## GL-12 — Catch-Up XP

A temporary modifier to future eligible XP gains. It is not a retroactive lump sum and is tracked separately from Lifetime Earned XP.

## GL-13 — Inkling

A private narrative prompt, discovery, vision, suspicion, opportunity, or hook owned by the optional Inklings plugin.

## GL-14 — System Outcome

A structured result of narrative resolution, such as XP, Boon progression, Bane progression/resolution, or a Culmination.

## GL-15 — Culmination

A permanent SOUL record of a significant story milestone or accomplishment. It is not an XP purchase.

## GL-16 — Narrative History

The character-facing record of meaningful SOUL-owned events and state changes. It is distinct from the technical audit log.

## GL-17 — Audit Log

The operational record of actors, timestamps, sources, reasons, before/after values, errors, and administrative actions. It MAY contain technical detail unsuitable for Narrative History.

## GL-18 — Pending Roll

A stored, unresolved roll awaiting player or GM choices. Pending rolls SHALL expire, resolve, or be explicitly aborted without creating a completed roll result.

## GL-19 — GM-Assisted Roll

A pending roll in which an authorized scene GM may suggest optional B&Bs or select mandatory B&Bs before the player completes the roll.

# 4. Architecture

## 4.1 Scope and Boundaries

**REQ-001**

**Additional Requirement:** SOUL SHALL replace the FS3 system entirely. It is intended to serve as the game's complete character advancement, resolution, and progression framework rather than operating alongside FS3. Integrations with existing AresMUSH systems SHOULD be used where appropriate, but FS3 mechanics are not a dependency of SOUL.


SOUL SHALL provide:

- the Character Framework;
- optional Resonance;
- XP and advancement;
- Boons and Banes;
- Culminations;
- Narrative History;
- standard and GM-assisted rolls;
- equivalent MUSH and web workflows;
- permissions, privacy, validation, configuration, notifications, and audit;
- optional first-party integrations.

SOUL SHALL complement, not replace, AresMUSH authentication, channels, mail, Jobs, scenes, chargen/approval, and other suitable core systems.

SOUL SHALL load and support its core features without Inklings or Grimoire.

## 4.2 Plugin Architecture

**REQ-002**

SOUL SHALL follow CP-04 and CP-08.

- Commands and request handlers SHALL be thin adapters.
- Shared services SHALL own validation, permissions, calculations, state transitions, history effects, audit, and notifications.
- MUSH and web SHALL call the same services.
- Serializers SHALL enforce the same privacy rules as commands and handlers.
- Handlers SHALL NOT trust client-supplied character IDs, scene roles, permissions, modifiers, or costs.
- Events and hooks SHALL be idempotent where duplicate delivery is possible.
- Direct cross-plugin model access, monkey-patching, brittle polling, and duplicated business rules are prohibited.

## 4.3 Data Domains

**REQ-003**

SOUL-owned persistent domains SHOULD include, as implementation requires:

- character SOUL state;
- configured Aspect/Skill references and ratings;
- approved Resonance and chargen lock state;
- XP balances, lifetime counters, catch-up counters, and award/spend ledger;
- character B&B entries and level/state history;
- Culminations;
- Narrative History;
- pending and completed roll records;
- SOUL audit records and idempotency keys.

Character-specific explanations and GM notes SHALL NOT be stored in public catalogue definitions.

External plugin references MAY be stored by stable external identifier, but external history SHALL NOT be copied.

## 4.4 Services

**REQ-004**

At minimum, business logic SHOULD be centralized into cohesive services for:

- framework/configuration validation;
- character/chargen validation;
- Resonance calculation and locking;
- XP awards, catch-up, spending, reversal, and correction;
- B&B catalogue and character state transitions;
- Culminations;
- Narrative History and audit;
- roll suggestion, pending-roll state, GM input, resolution, and abort;
- privacy/authorization;
- integrations and capability detection.

Exact class names are implementation decisions; service boundaries SHALL prevent rule duplication.

## 4.5 Permissions and Privacy

**REQ-005**

The final permission matrix SHALL enumerate player, scene-GM, staff, and administrator capabilities, commands/handlers, private data exposure, scene authority, and audit requirements.

- Players MAY perform supported actions for their own characters.
- Scene-GM authority SHALL be limited to the active scene and configured reveal policy.
- Staff administration SHALL require explicit permissions.
- Privacy-sensitive fields SHALL require explicit authorization.
- No permission SHALL expose broader private data than its documented purpose requires.
- Overrides SHALL record actor and reason.
- Destructive actions SHALL require two-step confirmation and an audit snapshot.

Configurable GM reveal categories MAY include B&B name, public description, mechanical effects, character explanation, and GM notes. Defaults SHALL be conservative; enabling broader reveal SHOULD produce an operator warning.

## 4.6 History versus Audit

**REQ-006**

Follow GL-16 and GL-17.

Narrative History SHALL contain meaningful SOUL-owned character events. Routine reads, validation failures, retries, diagnostics, and integration errors belong only in audit/logging.

Corrections and reversals SHALL append linked records and preserve originals. A technical audit record SHOULD include actor, timestamp, source, reason, before/after state where applicable, and a batch or external reference when relevant.

## 4.7 Reliability and Compatibility

**REQ-007**

- State-changing services SHALL be atomic.
- Failed validation SHALL leave persistent state unchanged.
- Repeated external events and scheduled awards SHALL use deterministic idempotency keys.
- Missing optional plugins SHALL disable only dependent paths and produce actionable warnings.
- New configuration keys SHALL have safe defaults.
- Deprecated keys SHOULD remain temporarily recognized where safe and SHALL warn.
- Removed, unsafe, destructive, or ambiguous configuration SHALL fail safely.
- Valid existing data SHOULD remain compatible across upgrades where practical; feature-specific migration MAY be required for approved schema changes.

# 5. Character Model

## 5.1 Character Framework

**REQ-008**

Every SOUL character SHALL use the configured Aspect and Skill framework.

- Default Aspects: Body, Mind, Spirit.
- Aspect names, stable keys, descriptions, ordering, and displayed terminology SHALL be configurable.
- Each Skill SHALL resolve to exactly one Aspect by stable key.
- Core logic SHALL use stable keys, not display names.
- Grimoire branches MAY map to Spirit Skills; SOUL SHALL NOT require a separate Arcana Skill.
- MUSH and web presentation MAY differ but SHALL show equivalent state.

## 5.2 Aspects

**REQ-009**

Aspects SHALL:

- organize Skills;
- have stable keys and configurable display names;
- support numeric values where enabled;
- remain secondary to Skills under CP-03;
- be exposed through documented read APIs for integrations;
- be changed only through SOUL services.

Default Aspect contribution to rolls:

```text
Aspect Contribution = Aspect Rating × 0.20
Effective Base = Skill Rating + Aspect Contribution
```

`aspect.weight` defaults to `0.20` and is configurable for playtesting. Any implementation SHALL preserve CP-03: equivalent Skill investment must matter substantially more than Aspect investment. Fractional behavior SHALL be deterministic and identical across interfaces.

## 5.3 Skills

**REQ-010**

- Default rating range: `0–10`.
- Default labels: `0` Untrained; `1–3` Trained; `4–6` Experienced; `7–9` Expert; `10` Exceptional/Master.
- All Skills begin at `0` unless configured otherwise.
- Each chargen rank costs one point by default.
- Skill maximum after chargen defaults to `10` for all Resonance tiers.
- Skills SHALL be used by rolls, XP advancement, B&B associations, chargen, Sheet display, and configured integrations through shared services.
- Staff corrections SHALL require permission, reason, history where character-facing, and audit.

## 5.4 Character Generation

**REQ-011**

SOUL SHALL integrate with AresMUSH's existing chargen and approval lifecycle.

Canonical flow:

1. Load configured framework and terminology.
2. Select Resonance when enabled.
3. Allocate Skills within the allowance and starting cap.
4. Select chargen-available B&Bs and provide required explanations.
5. Validate limits, prerequisites, ratios, Resonance gates, unique tags, and required fields.
6. Permit correction without losing editable work.
7. Submit through the normal approval workflow.
8. On approval, lock chargen-only state and create only the feature-specific starting history entries required below.

Rules:

- R0 default Skill allowance: `15`.
- R0 default starting Skill cap: `7`.
- Unused Skill points MAY remain unspent during chargen, but any unspent Skill points SHALL be forfeited when chargen is approved. Skill point banking is not supported.
- Players SHALL be able to review public data and their own private explanations before submission.
- Incomplete or rejected chargen SHALL NOT create Narrative History.
- Staff overrides SHALL be permission-controlled and require a reason.
- Character generation SHALL NOT depend on Inklings.

## 5.5 Resonance

**REQ-012**

Resonance is optional and follows GL-06.

Configurable defaults:

- range: `R-3` through `R3`;
- R0: `15` Skill points, starting cap `7`;
- positive Skill points per level: `2`;
- negative Skill points per level: `2`;
- positive starting-cap change per level: `1`;
- negative starting-cap change per level: `1`;
- ultimate Skill cap: `10` at every tier;
- R3 and R-3 require strong justification and heightened review.

Calculation:

```text
if r > 0:
  points = 15 + (r × positive_skill_points_per_level)
  chargen_cap = 7 + (r × positive_skill_cap_per_level)
if r < 0:
  points = 15 + (r × negative_skill_points_per_level)
  chargen_cap = 7 + (r × negative_skill_cap_per_level)
if r = 0:
  points = 15
  chargen_cap = 7
ultimate_cap = 10
```

Canonical symmetric table:

| Resonance | Skill points | Chargen cap |
|---:|---:|---:|
| R-3 | 9 | 4 |
| R-2 | 11 | 5 |
| R-1 | 13 | 6 |
| R0 | 15 | 7 |
| R1 | 17 | 8 |
| R2 | 19 | 9 |
| R3 | 21 | 10 |

Positive and negative scaling SHALL be independently configurable. Positive Resonance MAY require at least one Bane whose catalogue definition has `modifier_eligible: true`; validation SHALL use the B&B service and staff MAY override with a recorded reason. Resonance normally locks at approval and SHALL NOT advance later or act as a permanent power ceiling. Administrative correction SHALL preserve the original value, new value, actor, reason, and source.

Approval SHALL create a Narrative History entry for starting Resonance. Players SHOULD be notified when Resonance is approved, overridden, or corrected; notifications SHALL NOT reveal private Bane explanations or GM notes. Optional integrations MAY read Resonance only through documented APIs and SHALL NOT mutate it directly.

## 5.6 XP and Advancement

**REQ-013**

XP follows CP-02 and GL-11.

Required counters SHOULD include:

- available/current XP (`xp_available`);
- Lifetime Earned XP (`xp_earned`);
- Lifetime Spent XP (`xp_spent`);
- Catch-Up XP Earned (`catchup_xp_earned`);
- source ledger/idempotency records.

Canonical configurable awards:

| Source | Default | Eligibility/idempotency |
|---|---:|---|
| weekly approved-character award | 1 XP | once per configured week; login/activity not required |
| scene sharer | 2 XP | once per scene, recipient, award type |
| each other approved scene participant | 1 XP | same idempotency; sharer not double-awarded |
| first qualifying player-authored forum topic or reply each week | 1 XP | later weekly contributions award 0 |
| approved Inkling XP outcome | explicit amount | only through approved integration outcome |
| manual staff award | entered amount | no catch-up unless explicit override |

Scene awards MAY repeat without a daily or weekly cap. Unsharing and resharing SHALL NOT duplicate an award unless authorized staff deliberately reverse and reapply it. Every recipient SHALL receive an individual ledger/audit entry; batch awards SHOULD share a batch ID.

If the installed scene event does not identify the sharing character, SOUL SHALL extend the supported scene-sharing action/event payload rather than guess. If AresMUSH exposes no forum-post event, SOUL SHALL use a supported service-boundary adapter or idempotent reconciliation process; it SHALL NOT rely on client-only commands.

### 5.6.1 Catch-Up XP

**REQ-014**

- Eligibility defaults to weekly recalculation against median `xp_earned`.
- Progress toward the target uses `xp_earned + catchup_xp_earned`.
- Default multiplier: `2.0×`.
- Default new-character grace period: `0` weeks.
- Bonus SHALL be capped at the current median gap.
- Catch-up SHALL apply only to future eligible awards.
- Lifetime Earned XP increases by the base award only.
- Current XP increases by the full post-multiplier award.
- Catch-Up XP Earned increases by the bonus portion.
- All spent XP increases Lifetime Spent XP regardless of source.
- A catch-up calculation failure SHOULD fall back to the valid base award and create an audit error.

```text
catchup_portion = award_after_multiplier - base_award
current_xp += award_after_multiplier
lifetime_earned_xp += base_award
catchup_xp_earned += catchup_portion
```

### 5.6.2 Spending and Corrections

**REQ-015**

Advancement flow: validate prerequisites and target → calculate cost → show cost → atomically deduct XP and apply advancement → increment Lifetime Spent XP → history/audit/notification.

Failed purchases SHALL change neither XP nor the target rating. Costs SHALL be non-decreasing as ratings rise. The exact XP cost table/equation remains an open implementation decision requiring owner approval.

Reversals and corrections SHALL preserve the original ledger/state, add linked corrective records, and require actor/reason. Players SHOULD be notified of awards, successful or failed purchases, corrections, and reversals as appropriate. Inspiration or another optional narrative currency SHALL remain separate from XP; default Inkling submission cost is `0`.

Canonical administrative commands:

| Syntax | Scope | Catch-up | Rule |
|---|---|---:|---|
| `+xp/award <character>=<amount>/<reason>` | one character | no | grants the raw amount |
| `+xp/award/catchup <character>=<amount>/<reason>` | one character | yes | applies configured catch-up calculation |
| `+xp/scene <amount>/<reason>` | current scene | no | targets approved participants |
| `+xp/scene <scene id>=<amount>/<reason>` | named scene | no | targets approved participants |
| `+xp/scene/catchup <amount>/<reason>` | current scene | yes | targets approved participants |
| `+xp/scene/catchup <scene id>=<amount>/<reason>` | named scene | yes | targets approved participants |

Scene operations SHOULD preview recipients and MAY require confirmation.

# 6. Mechanics

## 6.1 Boons and Banes

**REQ-016**

B&Bs follow CI-01 and GL-07 through GL-10.

### 6.1.1 Catalogue

**REQ-017**

Every catalogue definition SHALL include:

- unique numeric ID;
- stable unique tag/key;
- name and public description;
- optional category;
- configurable level/state definitions, including name, mechanical effect, ordering, and `chargen.available`;
- chargen block with defaults:
  - `chargen.available: true`
  - `chargen.flag_for_review: false`
  - `chargen.modifier_eligible: false`
- optional Skill associations or matching metadata.

Default level modifiers are Minor `+1`, Major `+2`, and Legendary `+3`. Negated defaults to no active modifier; Epic has no implied modifier and SHALL use its configured effect. All level/state effects and chargen availability SHALL be configurable. Modifier effects SHALL be bounded globally so Skills remain meaningful.

### 6.1.2 Character Entry

**REQ-018**

A character entry SHALL preserve:

- catalogue ID/reference;
- current level/state;
- character-specific private explanation;
- associated Skills;
- source link(s), such as `[Chargen]` or `[Inkling 234]`;
- progression history by level/state, with a distinct explanation and source marker for every attained level;
- optional GM notes;
- resolved/negated status without destructive deletion.

Public presentation SHALL show `Level | Name [tag]`, numeric ID where useful, and mechanical modifier. It SHALL NOT expose private explanations or GM notes. The owner and authorized staff SHALL see permitted private fields.

### 6.1.3 Acquisition and Progression

**REQ-019**

- Players MAY add/remove chargen B&Bs only while chargen is unfinished.
- Post-chargen Boons SHALL be earned through RP and approved workflow; XP SHALL NOT buy them.
- Banes SHALL be progressed or resolved through RP; XP SHALL NOT remove them.
- Inklings MAY carry requests, but equivalent standalone staff workflows SHALL exist.
- The same SOUL validation and transition services SHALL be used by chargen, Inklings, Jobs, staff commands, MUSH, and web.
- Configurable chargen limits and any Bane-to-Boon ratio remain open defaults requiring project-owner approval.

### 6.1.4 States

**REQ-020**

- **Resolved:** preserves the Bane and its history while marking its story consequence resolved.
- **Negated / Resolved:** These represent the same underlying state with a default numeric value of `0`. For Boons, the state is referred to as **Negated**; for Banes, it is referred to as **Resolved**. The differing names are nomenclature only and do not represent different mechanics. Defaults remove ordinary cost, modifier, and suggestion behavior while preserving the narrative record and prior level. Restoring the entry SHALL return it to that preserved level unless authorized staff explicitly choose another valid state. Its mechanical effect and chargen availability SHALL be configurable; chargen availability defaults to `false`.
- **Epic:** represents growth beyond the normal catalogue scale. It SHALL require a documented source and use an explicitly configured mechanical effect; the label alone SHALL NOT imply an uncapped modifier. Authorization requirements and chargen availability SHALL be configurable; chargen availability defaults to `false`.

### 6.1.5 Deletion and Correction

**REQ-021**

Post-chargen removal SHOULD use resolution or correction. Actual deletion SHALL:

1. warn and recommend a non-destructive alternative;
2. require two explicit confirmations;
3. capture an audit snapshot;
4. preserve a linked Narrative History correction when character-facing;
5. require authorized staff and a reason.

### 6.1.6 Search

**REQ-022**

- `+bnb <id>` and web equivalent SHALL show catalogue detail and owned private detail as authorized.
- `+bnb/here <tag>` (or the configured concise alias) SHOULD provide a minimal scene lookup limited to involved players and permitted data.
- `+bnb/search <tag>` (or the configured concise alias) SHALL be staff/admin global search and MAY support detail/full modes.
- Name collisions SHALL return matching names, IDs, and tags.

## 6.2 Culminations

**REQ-023**

Culminations follow GL-15.

- They SHALL be story milestones, not XP purchases.
- Sources MAY include staff review, approved Inkling, standalone workflow, or proposal from another plugin.
- Staff approval is required by default unless automation is explicitly enabled.
- The service SHALL validate eligibility, duplicates, source, permission, and configured requirements.
- Staff MAY approve, modify, deny, correct, revoke, or reverse with reason and audit.
- Approved Culminations SHALL create Narrative History and notify the player.
- Duplicate handling SHALL be deterministic and SHALL NOT silently create multiple equivalent records.
- Each record SHALL contain a stable identifier, title/name, narrative description, timestamp, awarding actor/source, visibility, source link, status, and correction/revocation links as applicable.
- Another plugin MAY propose a Culmination but SHALL NOT create it directly unless explicitly authorized; SOUL owns the record.
- Revocation and correction SHALL preserve the original record and append a linked revocation/correction rather than delete or overwrite it.

## 6.3 Narrative History

**REQ-024**

Narrative History follows CP-07 and GL-16.

Required entry data SHOULD include:

- event type;
- timestamp;
- actor/source;
- concise character-facing narrative;
- visibility;
- relevant SOUL record reference;
- optional external reference;
- correction/reversal relationship;
- linked audit identifier.

Qualifying events include approved starting Resonance, B&B acquisition/progression/resolution/negation, significant configured advancement, Culminations, and authorized corrections/reversals. Ordinary reads, failed validation, retries, and diagnostics SHALL NOT create Narrative History.

SOUL MAY reference an Inkling or Grimoire record, but SHALL NOT copy external history. In particular, SOUL SHALL never store Grimoire spell history.

Exports SHALL respect visibility and privacy and SHOULD preserve timestamps, actors, source references, correction links, and reversal links. Corrections and reversals SHALL append, never overwrite or delete, the original entry.

## 6.4 Roll Model

**REQ-025**

Rolls follow CI-03, CP-03, and GL-18/19.

### 6.4.1 Canonical Commands

**REQ-026**

| Syntax | Actor | Purpose | Constraints |
|---|---|---|---|
| `+roll <skill>` | player | start a standard roll | scene policy MAY convert it to GM-assisted |
| `+roll/gm <skill>` | player | request GM assistance | only when scene policy permits |
| `+roll suggested` | player | accept all system-suggested optional B&Bs | SHALL NOT remove GM-mandatory entries |
| `+roll <tag> [<tag> ...]` | player | select owned B&Bs | full names MAY be accepted; collisions SHALL disambiguate |
| `+roll none` | player | decline optional entries | SHALL NOT remove GM-mandatory entries |
| concise abort command | player | abort an eligible pending roll | exact syntax requires owner approval |
| concise force-abort command | authorized staff | clear an erroneous pending roll | reason and audit required |

### 6.4.2 Pending-Roll State

**REQ-027**

A pending roll SHALL record:

- player and character;
- Skill and Aspect;
- scene/context;
- difficulty and other validated inputs;
- system-suggested entries;
- GM-suggested entries;
- GM-selected mandatory entries;
- player-selected entries;
- user-identified entries outside suggestions;
- timestamps, expiry, and status.

The categories above SHALL remain distinguishable in audit/output. A player MAY identify and add a relevant owned B&B not suggested by the system; it SHALL be marked as identified/override rather than misreported as a system suggestion. Pending rolls SHALL expire according to configuration; expiry clears unresolved state, records audit, and SHALL NOT create a completed result.

### 6.4.3 Standard Roll

**REQ-028**

1. Validate character, Skill, context, permissions, and pending-roll limit.
2. Identify candidate active B&Bs.
3. Store pending state.
4. Present concise suggestions or state that none matched.
5. Accept tags, `suggested`, or `none`.
6. Revalidate ownership, state, context, duplicates, and bounds.
7. Resolve using the shared roll service.
8. Display result and modifier sources.
9. Create roll audit/history as configured and clear pending state.

If no candidates exist, SOUL SHALL pause the roll, inform the player that no matching B&Bs were found, and provide an opportunity to manually identify applicable B&Bs before the roll resolves. The player MAY continue without modifiers or select one or more B&Bs manually. This interaction SHALL be consistent and its presentation MAY be configurable, but the opportunity for manual selection SHALL always be provided.

### 6.4.4 GM-Assisted Roll

**REQ-029**

Scene policy SHALL be configurable as **Required**, **Optional**, or **Unavailable**.

- Required converts a normal roll to GM-assisted.
- Optional permits `+roll/gm`.
- Unavailable falls back to standard roll behavior.

The GM SHALL see only fields allowed by scene authority and reveal configuration. The GM MAY mark entries optional or mandatory. Mandatory selections SHALL survive `+roll none`; the player remains responsible for completing the roll. Blind/privacy-safe wording SHALL avoid revealing a private B&B's existence when reveal policy forbids it.

The player MAY abort before GM submission. Authorized staff MAY force-abort genuine errors before or after GM input. Abort SHALL clear pending state, create audit with actor/reason, notify affected participants, and SHALL NOT create a completed roll result.

### 6.4.5 Resolution Mathematics

**REQ-030**

```text
effective_base = skill_rating + (aspect_rating × aspect_weight)
validated_modifier = clamp(sum(active accepted B&B modifiers), min_modifier, max_modifier)
effective_rating = effective_base + validated_modifier
result = resolve(random_model, effective_rating, difficulty)
```

Order SHALL be:

1. validate context;
2. determine Skill and Aspect;
3. collect system, GM, and player selections separately;
4. discard inactive, invalid, duplicate, or unauthorized entries;
5. combine accepted modifiers;
6. apply global bounds;
7. apply difficulty;
8. resolve the random model.

Invariants:

- higher Skill SHALL never reduce expected effectiveness under equivalent conditions;
- greater difficulty SHALL not increase success probability under equivalent conditions;
- XP costs SHALL not decrease with higher ratings;
- modifiers SHALL be bounded so Skill remains meaningful;
- rounding SHALL be deterministic and identical in MUSH, web, tests, manual paths, and integrations.

Open decisions requiring project-owner approval: exact random distribution, success equation, difficulty scale, modifier bounds, and rounding rule for fractional values.

## 6.5 Notifications and Roll History

**REQ-031**

Meaningful state changes SHOULD notify affected players. Notifications SHALL not reveal private explanations, GM notes, or another character's information.

Completed roll records SHOULD include roller, Skill/Aspect, difficulty, final result, applied modifiers and source categories, scene/context, and timestamp. Pending or aborted rolls SHALL remain audit-only unless a user-facing pending-roll list is useful.

# 7. Commands and UI

## 7.1 Interface Parity

**REQ-032**

Follow CP-05. A feature is incomplete until its MUSH and web paths are implemented, documented, permission-checked, and tested for equivalent results. Presentation MAY differ by medium.

## 7.2 Sheet and Browsing

**REQ-033**

Both interfaces SHALL support:

- the concise SOUL Sheet described in CI-02;
- drill-down Aspect and Skill details;
- XP balances, advancement costs, and history;
- Resonance;
- B&B catalogue and character details;
- Culminations;
- Narrative History;
- roll history and pending rolls.

Public and private information SHALL be visibly distinguishable. Web controls SHALL be keyboard-accessible, use understandable labels, and not depend solely on colour or icons.

## 7.3 Character Generation and Advancement UI

**REQ-034**

Both interfaces SHALL support the complete flow in §5.4 and §5.6. They SHALL:

- show limits, prerequisites, costs, and explanations before commitment;
- preserve unfinished work where practical;
- prevent irreversible actions without warning;
- provide actionable validation and confirmation;
- use configured terminology consistently.

The web MAY use guided forms/modals; MUSH MAY use concise commands and staged prompts. Neither may omit capabilities.

## 7.4 B&B and Roll UI

**REQ-035**

Both interfaces SHALL support the workflows in §6.1 and §6.4, including:

- catalogue browsing;
- owner/staff detail views;
- searching and disambiguation;
- suggestion review;
- GM optional/mandatory selection;
- player completion and abort;
- pending-roll status and reminders.

Roll displays SHALL show success/result, effective inputs, applied modifiers, and concise source names/levels without exposing private explanations by default.

## 7.5 Staff UI

**REQ-036**

Authorized staff SHALL be able to:

- review and correct Character Framework state;
- manage B&B catalogue and character entries;
- award/correct XP and apply explicit catch-up overrides;
- manage Culminations;
- inspect permitted Narrative History and audit;
- adjudicate, repair, and force-abort pending rolls;
- perform equivalent standalone workflows when optional integrations are absent;
- preview multi-character/batch actions before confirmation.

Staff tools SHALL not require direct database manipulation.

## 7.6 Command Families

**REQ-037**

Exact non-canonical syntax SHALL be finalized in implementation and help files with project-owner approval. The command surface SHALL remain concise under CI-05 and include, at minimum:

| Area | Required command capability |
|---|---|
| Sheet | view own/authorized character SOUL state |
| B&B | browse catalogue, view ID/tag, own details, `+bnb/here`, staff `+bnb/search` and management |
| Rolls | start, GM-start, select suggested/tags/none, list pending, abort/force-abort |
| XP | view, spend, staff award, explicit catch-up award, scene/batch award, correct/reverse |
| History | view authorized Narrative History and roll history |
| Staff | manage framework, Resonance, B&Bs, Culminations, advancement, corrections |

Administrative documentation SHALL use `manage soul`, not “managing soul.”

# 8. Integration

## 8.1 Common Rules

**REQ-038**

All integrations SHALL follow CP-04.

- Detect optional plugins by capability, not assumption.
- Call documented public hooks/APIs/services.
- Validate permissions in both plugins where applicable.
- Isolate and audit integration failures.
- Events SHALL carry stable identifiers and only the context required by authorized consumers.
- Consumers SHALL be idempotent where duplicate delivery is possible.
- Never permit an integration failure to partially mutate SOUL state.
- Provide MUSH/web parity for supported integrated workflows.
- Provide an equivalent standalone staff path for every integration-triggered SOUL transition.

## 8.2 Inklings

**REQ-039**

Inklings owns the request, narrative content, approval workflow, status, and complete Inkling audit/history. SOUL owns validation and application of SOUL state.

### Submission/Validation Hook

When an Inkling includes a proposed SOUL outcome, Inklings SHALL call a SOUL validation hook. The request SHALL identify outcome type, target character, proposed transition/value, requester/source, and stable Inkling reference as applicable. SOUL SHALL return a normalized, validated payload or actionable errors without mutating state. The payload remains stored entirely with the Inkling; SOUL SHALL NOT create duplicate pending progression.

### Approval/Application Hook

After approval, Inklings SHALL call a SOUL application hook with the approved payload and source identifiers. SOUL SHALL:

1. revalidate current state and idempotency;
2. atomically apply the SOUL transition;
3. create SOUL Narrative History/audit as required;
4. return success/failure and created SOUL references.

Supported System Outcomes include XP, Boon, Bane, Culmination, and documented optional plugin outcomes. Inkling XP applies only through an explicit approved outcome. Inklings remains optional, and every supported outcome SHALL have an equivalent manual staff path.

## 8.3 Grimoire

**REQ-040**

Grimoire owns:

- spell catalogue and metadata;
- branch definitions;
- spell learning, costs, prerequisites, and casting lifecycle;
- spell proposals/jobs;
- all spell history.

SOUL MAY:

- expose Skills/Aspects/Resonance through documented read APIs;
- map configured Grimoire branches to Spirit Skills;
- call or receive documented hooks;
- record a resulting SOUL-owned change and stable external reference.

SOUL SHALL NOT copy spell data/history or reimplement Grimoire rules. Missing Grimoire SHALL not affect non-magical SOUL functionality.

## 8.4 AresMUSH

**REQ-041**

SOUL SHALL use normal AresMUSH chargen/approval, scenes, Jobs where suitable, permissions, localization, routing, events, and formatting. It SHALL not create parallel ownership of core AresMUSH systems.

# 9. Configuration

## 9.1 Precedence and Validation

**REQ-042**

Precedence:

1. valid game configuration;
2. canonical defaults in this section;
3. safe implementation fallback matching those defaults.

At startup, SOUL SHALL validate YAML structure, required keys, supported values, references, duplicate keys/tags/IDs, Aspect–Skill mappings, ranges, dependency consistency, negative award/cap values, and unsafe combinations. `null` MAY represent no configured cap only where documented.

- Invalid but recoverable values SHALL warn and use the documented safe default only when interpretation is unambiguous.
- Unsafe, destructive, or ambiguous configuration SHALL fail the affected feature safely.
- Fatal plugin load failure SHALL be limited to conditions preventing safe core operation.

## 9.2 Configurable Areas

**REQ-043**

| Area | Type | Required configurable content |
|---|---|---|
| terminology/UI | strings, ordering, booleans | labels, display names, optional presentation |
| framework | definitions, integers | Aspects, Skills, mappings, descriptions, ranges, order |
| roll contribution | decimal | `aspect.weight` |
| Resonance | booleans, ranges, integers | enablement, tiers, allowances, caps, Bane gate, review flags |
| XP | integers, decimals, schedules, booleans | awards, cadence, eligibility, costs, catch-up, caps, optional currency |
| B&B | catalogue records, limits, modifiers | categories, level/state definitions and ordering, per-level mechanical effects, per-level chargen availability, chargen flags/limits/ratios, tags, matching |


**B&B Identifiers:**
- Every global B&B definition SHALL have a unique numeric identifier in addition to its unique tag.
- Every character-owned B&B instance SHALL also receive its own unique numeric identifier.
- The global identifier identifies the catalogue entry; the instance identifier identifies the specific occurrence on a character.
- Example: the global B&B **Cursed** may be catalogue `#27`. Sarah's instance may be `#123` while Morgan's instance may be `#146`, with both referencing catalogue `#27`.
- Commands and audit logs MAY accept or display either the instance ID or the tag where appropriate, but instance IDs SHALL uniquely identify a specific character-owned B&B.
| rolls | enums, integers, decimals | random model, difficulty, modifier bounds, pending limits/expiry, GM policy |
| privacy | booleans/enums | scene-GM reveal categories and staff visibility |
| history/notifications | booleans, thresholds | qualifying events and delivery behavior |
| integrations | booleans, capability settings | optional-plugin behavior and adapters |

## 9.3 Canonical Defaults

**REQ-044**

| Area | Default |
|---|---|
| Aspects | Body, Mind, Spirit |
| Skill range | 0–10 |
| R0 chargen points/cap | 15 / 7 |
| Resonance range | R-3…R3 |
| Resonance points per level | +2 positive / -2 negative |
| Resonance cap per level | +1 positive / -1 negative |
| Ultimate Skill cap | 10 |
| Aspect weight | 0.20 |
| B&B level/state effects | Minor +1; Major +2; Legendary +3; Negated no active modifier; Epic explicitly configured |
| B&B level/state chargen availability | Minor/Major/Legendary configurable; Negated false; Epic false |
| B&B definition chargen flags | available true; flag_for_review false; modifier_eligible false |
| weekly XP | 1 per approved character |
| scene XP | sharer 2; each other approved participant 1 |
| forum XP | first qualifying weekly contribution 1 |
| catch-up target | median `xp_earned` |
| catch-up progress | `xp_earned + catchup_xp_earned` |
| catch-up multiplier | 2.0× |
| catch-up grace | 0 weeks |
| standard pending-roll limit | 1 |
| GM pending-roll limit | 2 |
| Inkling inspiration cost | 0 |
| Culmination approval | staff required |
| successful character-facing notification | enabled |

Changing interconnected defaults MAY affect pacing, probability, staff workload, or balance and SHOULD generate operator-facing guidance.

## 9.4 Open Configuration Decisions

**REQ-045**

The following remain unresolved and SHALL NOT be implemented without project-owner approval:

- exact XP advancement cost table/equation and any global XP balance cap;
- chargen Boon/Bane limits and required Bane-to-Boon ratio;
- exact random distribution and success equation;
- difficulty scale;
- global roll modifier bounds;
- deterministic rounding rule for fractional calculations;
- any final command syntax not already canonical above.

# 10. Extension Points

## 10.1 Public Service APIs

**REQ-046**

SOUL SHALL expose documented service-level entry points for authorized reads and transitions without permitting direct model mutation. Public APIs SHOULD cover framework lookup, character ratings, Resonance reads, XP awards/spends, B&B validation/transitions, Culmination proposals, roll initiation/completion, and authorized history queries.

## 10.2 Hooks and Events

**REQ-047**

Hooks/events SHALL:

- use stable names and versioned payload contracts;
- carry stable source and idempotency identifiers for state-changing requests;
- return normalized success or actionable error results;
- expose only authorized data;
- document whether they are synchronous requests, asynchronous notifications, or proposals requiring approval;
- remain safe under duplicate delivery where applicable.

Required integration contracts include Inklings outcome validation/application and documented read-only Grimoire/SOUL capability exchange.

## 10.3 Extension Ownership

**REQ-048**

Extensions SHALL follow CP-04. An extension MAY propose or request a SOUL-owned transition, but SOUL SHALL validate and apply it. SOUL MAY reference external records by stable identifier but SHALL NOT copy external domain history or implement another plugin's rules.

## 10.4 Compatibility Contract

**REQ-049**

Public APIs, hooks, event payloads, configuration keys, and stored stable identifiers SHALL be documented. Breaking changes SHALL require migration guidance, compatibility handling where practical, and an explicit version change.

# 11. Appendices

## Appendix A — Canonical Workflows

### A.1 Character Approval

Validate complete chargen → staff review → approve → lock chargen-only state → create required starting history → notify. Failure returns editable state without partial approval.

### A.2 XP Award

Determine source and idempotency → apply catch-up only when eligible/explicitly overridden → cap at target gap → atomically update counters → ledger/audit → notify. Failure changes no counters.

### A.3 XP Spend

Validate target/prerequisites → calculate/show cost → atomic deduction and advancement → Lifetime Spent XP → history/audit → notify. Failure changes neither side.

### A.4 B&B Transition

Validate definition, owner, level/state, source, permissions, limits, and explanation → apply transition → history/audit → notify. Integrated and standalone paths SHALL be equivalent.

### A.5 Culmination

Receive request/proposal → validate eligibility and duplicate → staff approve/modify/deny unless automation enabled → create/reject → history/audit → notify.

### A.6 Narrative Correction

Authorize and require reason → capture before state → append linked correction/reversal → preserve original → audit → notify.

### A.7 Standard Roll

Start → validate → identify candidates → store pending → player chooses suggested/tags/none → revalidate and bound → resolve → output/audit → clear pending.

### A.8 GM-Assisted Roll

Start or scene-policy conversion → validate scene GM/reveal → pending state → GM optional/mandatory selections → player optional selections → resolve with mandatory entries → output/audit → clear pending.

### A.9 Optional Plugin Missing

Capability check fails → disable dependent path only → expose standalone equivalent → log actionable warning → preserve core SOUL operation.

### A.10 Destructive Deletion

Request → warn and recommend resolution/correction → confirmation 1 → confirmation 2 → audit snapshot → permitted deletion → linked history correction/notification where applicable.

## Appendix B — Concrete Examples

### B.1 Sheet

```text
SOUL — Morgan
Body: 4
  Strength: 7
  Stamina: 4
  Reflexes: 2
Mind: 3
  Investigation: 6
  Empathy: 3
Spirit: 2
  Ceremonial Magic: 4

Boons
22. Minor | Keen Observer [observer]  +1 Investigation

Banes
31. Major | Cursed [cursed]          -2 Strength, Reflexes
```

### B.2 B&B Detail

```text
bnb 22
22. Keen Observer
Public: You notice details others miss.
Level: Minor (+1)
Skills: Investigation
Your explanation: Morgan studies rooms before speaking and remembers small inconsistencies.
Source: [Chargen]
```

Unauthorized viewers SHALL not receive “Your explanation,” private progression notes, or GM notes.

### B.3 Resonance

An R2 character using canonical defaults receives `19` chargen Skill points and a starting Skill cap of `9`. The character may still advance only to the universal post-chargen cap of `10`.

### B.4 Catch-Up Award

A qualifying base award of `2` XP under a `2.0×` multiplier grants `4` current XP: `2` increases Lifetime Earned XP and `2` increases Catch-Up XP Earned. If the median gap is `1`, the award is capped to `3` total XP (`2` base + `1` catch-up).

### B.5 GM Roll

```text
Player: +roll/gm investigation
SOUL: Suggested: Keen Observer [observer]. Waiting for the scene GM.
GM: marks Distracted [distracted] mandatory and Keen Observer optional.
Player: +roll observer
SOUL: resolves with mandatory Distracted plus player-selected Keen Observer.
```

### B.6 Inklings Ownership

```text
Inkling 234 stores proposed outcome:
  type: boon_progression
  bnb_id: 22
  from: Minor
  to: Major

Inklings calls SOUL.validate_outcome.
After approval, Inklings calls SOUL.apply_outcome with Inkling 234 as source.
SOUL applies the B&B transition and stores only the external Inkling reference.
```

## Appendix C — Testing and Acceptance

Tests SHALL verify:

- service-level authorization and privacy;
- MUSH/web equivalence;
- chargen validation and approval locking;
- stable Aspect–Skill mapping;
- Resonance calculations including asymmetric configuration;
- XP idempotency, catch-up counters, caps, spending, and correction;
- B&B visibility, tags, level/state transitions, deletion safeguards, and equivalent integrated/manual paths;
- Narrative History versus audit separation;
- pending-roll limits, suggestions, GM mandatory selections, abort, expiry, and privacy-safe output;
- monotonic Skill effectiveness, non-decreasing XP cost, bounded modifiers, deterministic rounding, and identical math across interfaces;
- optional plugin absence and integration failure isolation;
- startup configuration validation and backward-compatible defaults;
- actionable errors and relevant identifiers;
- help/documentation parity, including `manage soul`.

## Appendix D — Implementation Workflow

Before implementation, Claude SHALL read the current AresMUSH Plugin Development Guide and inspect the closest official plugins. Community plugins MAY inform design but SHALL NOT override official conventions or this specification.

Recommended implementation order:

1. plugin skeleton, configuration, localization, permissions;
2. Character Framework, Skills, Aspects, Resonance, XP ledger;
3. B&Bs, Culminations, Narrative History/audit;
4. standard rolls and pending-roll flow;
5. GM-assisted rolls and scene integration;
6. complete MUSH/web UI parity;
7. Inklings and Grimoire integrations;
8. migration, documentation, tests, and release review.

Each phase SHOULD include tests and documentation. AI-generated code SHALL be reviewed for specification compliance, AresMUSH conventions, correctness, authorization/privacy, rule duplication, configuration/localization, interface parity, and maintainability before acceptance.

Required user-facing documentation SHALL include installation, configuration, player help, `manage soul` admin help, command/web workflow parity, permissions, and integration setup. Developer-facing material SHOULD separately document service boundaries, hooks/events, schema/migrations, tests, and material deviations from official AresMUSH patterns.

## Appendix E — Deferred Enhancements

Deferred possibilities include additional roll types, conflict/challenge frameworks, richer suggestion analysis, expanded history visualization, narrative currencies, relationship mechanics, setting-specific modules, and additional integration outcomes. They require owner approval/ADR and SHALL preserve the named principles in this specification.

## Appendix F — Requirements Index

| ID | Canonical requirement block |
|---|---|
| REQ-001 | 4.1 Scope and Boundaries |
| REQ-002 | 4.2 Plugin Architecture |
| REQ-003 | 4.3 Data Domains |
| REQ-004 | 4.4 Services |
| REQ-005 | 4.5 Permissions and Privacy |
| REQ-006 | 4.6 History versus Audit |
| REQ-007 | 4.7 Reliability and Compatibility |
| REQ-008 | 5.1 Character Framework |
| REQ-009 | 5.2 Aspects |
| REQ-010 | 5.3 Skills |
| REQ-011 | 5.4 Character Generation |
| REQ-012 | 5.5 Resonance |
| REQ-013 | 5.6 XP and Advancement |
| REQ-014 | 5.6.1 Catch-Up XP |
| REQ-015 | 5.6.2 Spending and Corrections |
| REQ-016 | 6.1 Boons and Banes |
| REQ-017 | 6.1.1 Catalogue |
| REQ-018 | 6.1.2 Character Entry |
| REQ-019 | 6.1.3 Acquisition and Progression |
| REQ-020 | 6.1.4 States |
| REQ-021 | 6.1.5 Deletion and Correction |
| REQ-022 | 6.1.6 Search |
| REQ-023 | 6.2 Culminations |
| REQ-024 | 6.3 Narrative History |
| REQ-025 | 6.4 Roll Model |
| REQ-026 | 6.4.1 Canonical Commands |
| REQ-027 | 6.4.2 Pending-Roll State |
| REQ-028 | 6.4.3 Standard Roll |
| REQ-029 | 6.4.4 GM-Assisted Roll |
| REQ-030 | 6.4.5 Resolution Mathematics |
| REQ-031 | 6.5 Notifications and Roll History |
| REQ-032 | 7.1 Interface Parity |
| REQ-033 | 7.2 Sheet and Browsing |
| REQ-034 | 7.3 Character Generation and Advancement UI |
| REQ-035 | 7.4 B&B and Roll UI |
| REQ-036 | 7.5 Staff UI |
| REQ-037 | 7.6 Command Families |
| REQ-038 | 8.1 Common Rules |
| REQ-039 | 8.2 Inklings |
| REQ-040 | 8.3 Grimoire |
| REQ-041 | 8.4 AresMUSH |
| REQ-042 | 9.1 Precedence and Validation |
| REQ-043 | 9.2 Configurable Areas |
| REQ-044 | 9.3 Canonical Defaults |
| REQ-045 | 9.4 Open Configuration Decisions |
| REQ-046 | 10.1 Public Service APIs |
| REQ-047 | 10.2 Hooks and Events |
| REQ-048 | 10.3 Extension Ownership |
| REQ-049 | 10.4 Compatibility Contract |

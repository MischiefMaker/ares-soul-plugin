# SOUL Commands Reference

Command surface for SOUL, derived from `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") §6.4.1 (REQ-026), §5.6.2 (REQ-015), §6.1.6 (REQ-022), and §7.6 (REQ-037).

**Canonical vs. proposed syntax:** Commands marked **Canonical** appear with this exact syntax in FINAL and SHALL NOT be renamed without an owner-approved spec change. Commands marked **Proposed** fill a required capability (REQ-037) whose exact syntax FINAL explicitly leaves open pending owner approval (REQ-026 abort commands; REQ-045 "any final command syntax not already canonical"). Follow CI-05 (short, guessable commands) when finalizing these.

## Sheet

| Command | Status | Purpose | Permission |
|---|---|---|---|
| `+soul` | Canonical (CI-02) | Display your SOUL Sheet: Aspects/Skills, condensed B&B summaries, XP, Resonance | play |
| `+soul <character>` | Proposed | View another character's authorized SOUL Sheet (staff, or scene-GM per reveal policy) | staff/gm |

The default Sheet fits roughly one MUSH screen (CI-02); drill-down commands below cover full detail.

## Boons & Banes

| Command | Status | Purpose | Permission |
|---|---|---|---|
| `+bnb <id>` | Canonical (REQ-022) | Show catalogue description; if owned, also show the character-specific explanation | play |
| `+bnb/here <tag>` | Canonical (REQ-022, concise alias configurable) | Minimal scene-scoped lookup limited to involved players and permitted data | play |
| `+bnb/search <tag>` | Canonical (REQ-022, concise alias configurable) | Staff/admin global search; may support detail/full modes | manage_soul |
| `+bnb/catalogue` | Proposed | Browse the full public catalogue | play |
| `+bnb/create <name>=<description>` | Proposed | Create a new catalogue entry (category, level defaults, chargen flags via follow-up prompts) | manage_soul |
| `+bnb/grant <character>/<catalogue id or tag>=<explanation>` | Proposed | Grant a character entry (post-chargen, non-XP) | manage_soul |
| `+bnb/progress <character>/<entry id>=<new level>` | Proposed | Progress or resolve/negate an existing character entry | manage_soul |
| `+bnb/delete <entry id>` | Proposed | Two-confirmation destructive delete (REQ-021); resolution/negation is preferred | manage_soul |

Name collisions return matching names, IDs, and tags for disambiguation (GL-10).

## Rolls

| Command | Status | Purpose | Constraints |
|---|---|---|---|
| `+roll <skill>` | Canonical (REQ-026) | Start a standard roll at Standard difficulty | Scene policy MAY convert it to GM-assisted |
| `+roll <skill>=<difficulty>` | Proposed (extends REQ-026) | Start a roll at an explicit difficulty tier | `<difficulty>` must be a configured `rolls.difficulties` key |
| `+roll/gm <skill>` | Canonical (REQ-026) | Request GM assistance | Only when scene policy permits; requires an active scene |
| `+roll/gm <skill>=<difficulty>` | Proposed (extends REQ-026) | Request GM assistance at an explicit difficulty | Same as above |
| `+roll suggested` | Canonical (REQ-026) | Accept all system-suggested (or, on a GM-assisted roll, GM-approved) optional B&Bs | Applies to your own open pending roll awaiting selection; SHALL NOT remove GM-mandatory entries |
| `+roll <tag> [<tag> ...]` | Canonical (REQ-026) | Select owned B&Bs for this roll | Full names accepted; collisions disambiguate; on a GM-assisted roll, a candidate the GM reviewed and did not approve is rejected, not silently reclassified |
| `+roll none` | Canonical (REQ-026) | Decline optional entries | Applies to your own open pending roll awaiting selection; SHALL NOT remove GM-mandatory entries |
| `+roll/abort <roll id>=<reason>` | Proposed (REQ-026 — exact syntax open) | Abort your own eligible pending roll | Only before GM submission (GM-assisted); reason required |
| `+roll/forceabort <roll id>=<reason>` | Proposed (REQ-026 — exact syntax open) | Staff/scene-GM clears an erroneous pending roll at any open status | Reason and audit required |
| `+roll/pending` | Proposed | List your open pending rolls | Standard limit 1 open, GM-assisted limit 2 open (CI-04) — two independent caps |
| `+roll/history` | Proposed | View your own completed roll history | play |
| `+roll/review` | Proposed | Scene-GM: list pending rolls awaiting your review in the current scene | Requires scene-GM authority (§ below) |
| `+roll/review <roll id>` | Proposed | Scene-GM: view privacy-filtered candidate B&Bs for a specific pending roll | Only fields configured in `privacy.gm_reveal_categories` are shown |
| `+roll/mark <roll id>=<mandatory tags>/<optional tags>` | Proposed | Scene-GM: partition reviewed candidates into mandatory and optional | Both tag lists may be empty (e.g. `+roll/mark 12=/tag1 tag2`); an entry not named in either list is dropped from the roll, not implicitly optional |

Rolling mechanics (dice model, difficulty scale, degrees of success, extraordinary luck) are specified in `docs/spec/Implementation_Specification_Addendum.md` §1–§2, §8.1, §9.

**Scene-GM authority for `+roll/review`/`+roll/mark`/`+roll/forceabort`:** `Soul.can_review_rolls?(enactor) && scene.is_participant?(enactor)`, or `Soul.can_manage_soul?(enactor)` unconditionally — see `docs/handoffs/Phase_5_GM_Assisted_Rolls.md` §5.1 for why this is the authorization rule rather than a dedicated Scene GM field (none exists on the real AresMUSH `Scene` model).

**Difficulty default:** FINAL's canonical `+roll <skill>` syntax has no difficulty argument. Standard difficulty is the default when none is given — a reasonable, low-stakes assumption for an unassisted roll — with the `=<difficulty>` extension above as a Proposed way to choose a harder or easier tier explicitly.

## XP

| Command | Status | Purpose | Permission |
|---|---|---|---|
| `+xp` | Proposed | View your `xp_available`, `xp_earned`, `xp_spent`, `catchup_xp_earned` | play |
| `+xp/spend <skill>=<amount>` | Proposed | Spend XP to advance a Skill (cost shown before commitment, REQ-015) | play |
| `+xp/history` | Proposed | View your XP ledger | play |
| `+xp/award <character>=<amount>/<reason>` | Canonical (REQ-015) | Grant the raw amount to one character; no catch-up | manage_soul |
| `+xp/award/catchup <character>=<amount>/<reason>` | Canonical (REQ-015) | Grant to one character, applying the configured catch-up calculation | manage_soul |
| `+xp/scene <amount>/<reason>` | Canonical (REQ-015) | Award to approved participants of the current scene; no catch-up | manage_soul |
| `+xp/scene <scene id>=<amount>/<reason>` | Canonical (REQ-015) | Award to approved participants of a named scene; no catch-up | manage_soul |
| `+xp/scene/catchup <amount>/<reason>` | Canonical (REQ-015) | Scene award (current scene) with catch-up applied | manage_soul |
| `+xp/scene/catchup <scene id>=<amount>/<reason>` | Canonical (REQ-015) | Scene award (named scene) with catch-up applied | manage_soul |
| `+xp/correct <character>=<amount>/<reason>` | Proposed | Correct/reverse a prior award or spend, preserving the original ledger entry | manage_soul |

Scene-targeted awards SHOULD preview recipients and MAY require confirmation before applying.

## Culminations

| Command | Status | Purpose | Permission |
|---|---|---|---|
| `+culmination <character>` | Proposed | View a character's Culminations | play (own) / staff (others) |
| `+culmination/propose <character>=<title>/<description>` | Proposed | Propose a Culmination for staff review | manage_soul (or approved Inkling outcome) |
| `+culmination/approve <id>` | Proposed | Approve a proposed Culmination | manage_soul |

## History

| Command | Status | Purpose | Permission |
|---|---|---|---|
| `+soul/history` | Proposed | View your own Narrative History | play |
| `+soul/history <character>` | Proposed | View an authorized character's Narrative History | staff |

`+roll/history` (view your own completed roll history) is listed under Rolls above, alongside the rest of the roll command family.

## Staff (`manage soul`)

Per CI-08, the admin help topic for these commands SHALL be named `manage soul` (not "managing soul").

| Command | Status | Purpose | Permission |
|---|---|---|---|
| `+soul/framework` | Proposed | Review/correct Character Framework state (Aspects, Skills) | manage_soul |
| `+soul/resonance <character>=<value>/<reason>` | Proposed | Correct a character's locked Resonance | manage_soul |
| `+soul/reload` | Proposed | Reload live configuration from `game/config/soul.yml` | manage_soul |
| `+soul/audit <character>` | Proposed | View a character's staff-only technical audit log (`SoulAuditApi`) | manage_soul |

Staff tools SHALL NOT require direct database manipulation (REQ-036). `+soul/audit` closes a gap noted since the Phase 1-3 command handoff: Permissions.md documents audit review as a staff capability, but no command surface existed for it until now — unlike Narrative History, the audit log is staff-only even for the character it concerns (`SoulAuditApi.get_audit`'s existing contract, unchanged).

## Help Files

- `help soul` — Overview of SOUL
- `help soul_commands` — This reference
- `help soul_rolls` — Roll mechanics and GM-assisted workflow
- `help soul_bnb` — Boons and Banes
- `help manage soul` — Staff/admin help topic (CI-08 exact naming)

## Notes

- All player commands are permission-gated via `game/config/soul.yml` (see `docs/reference/Permissions.md`).
- Rolls automatically surface matching B&Bs — no manual +/- modifier entry (CI-03 conversational roll flow).
- Web portal SHALL provide equivalent capability for every command family above (REQ-032, CP-05) — MUSH is the authoritative feature list, but no workflow requires switching interfaces.

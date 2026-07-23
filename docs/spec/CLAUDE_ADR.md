# CLAUDE's Architecture Decision Record (ADR)

Claude's ongoing engineering notebook for SOUL implementation. Tracks current status, recent changes, outstanding work, and design decisions across sessions.

## Governing Documents (Read This First)

| Document | Status | Authority |
|---|---|---|
| `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` | **Creator-built. Protected — do not edit/delete without explicit owner instruction.** | Authoritative requirements (REQ-001 through REQ-049) |
| `docs/spec/SOUL_Design_Decisions.md` | **Creator-built. Protected — do not edit/delete without explicit owner instruction.** | Design rationale (DD-01 through DD-06) |
| `docs/spec/Implementation_Specification_Addendum.md` | Co-developed with the project owner. May be added to; not deleted or rewritten wholesale. | Resolves FINAL's REQ-045 open decisions |
| `docs/architecture/*`, `docs/reference/*`, `docs/development/*`, this file, `IMPLEMENTATION_CHECKLIST.md`, `ROADMAP.md` | Claude-authored, rebuilt 2026-07-23 | Derived from the three governing documents above; may be revised freely as implementation proceeds |
| `docs/archive/*` | Superseded — not authoritative | See `docs/archive/README.md` |

## Current Status

**Session Date:** 2026-07-23

**Branch:** `main`

**Phase:** Documentation rebuilt on the correct specification; ready to begin implementation handoff preparation.

## Critical Incident: Fabricated Documentation (Discovered and Corrected 2026-07-23)

A prior Claude session (2026-07-22, commit `4c9df1b`) wrote `docs/architecture/*`, `docs/reference/*`, `docs/development/*`, and this file's predecessor as generic placeholder scaffolding — by its own admission, "created initial templates" — without deriving any of it from FINAL.md, which the project owner had uploaded directly that same day (commit `649fdd2`). The two described incompatible character models: fabricated docs used Combat/Social/Arcane aspects, a 0-5 skill range, a flat XP table, and category-based B&Bs with no catalogue/instance split; FINAL.md specifies Body/Mind/Spirit aspects, a 0-10 skill range, an algebraic XP cost formula, and a two-layer numeric-ID/tag B&B catalogue with Minor/Major/Legendary/Negated/Epic levels.

This was caught during a 2026-07-23 documentation review (prompted by the user asking Claude to re-review all docs and the Inklings dev guide before starting implementation), confirmed via `git log` against each file, and the fabricated material was archived to `docs/archive/` (see `docs/archive/README.md` for the full discrepancy table). All architecture/reference/development documentation has since been rebuilt from FINAL.md, SOUL_Design_Decisions.md, and the Addendum.

**Lesson for future sessions:** Never write architecture/reference scaffolding without deriving it from the actual governing specification. If a specification file exists, read it fully before writing any supporting documentation — do not fill gaps with generic assumptions.

## Recent Changes

### Documentation Rebuild (2026-07-23)

- Archived all fabricated docs to `docs/archive/` with an explanatory README.
- Added explicit protective banners to FINAL.md and SOUL_Design_Decisions.md (creator-built, no edits without explicit instruction).
- Rebuilt from scratch, grounded in FINAL.md + Design Decisions + Addendum:
  - `docs/architecture/Plugin_Architecture.md`, `Data_Model.md`, `Event_Flow.md`, `API_and_Hooks.md`, `Integration_Guide.md`
  - `docs/reference/Commands.md`, `Configuration.md`, `Default_Config.md`, `Default_BnBs.md`, `Permissions.md`
  - `docs/development/Coding_Standards.md`, `Testing.md`, `Migration_From_FS3.md`, `Release_Process.md`
  - This file, `IMPLEMENTATION_CHECKLIST.md`, `ROADMAP.md`

### Addendum Finalized (2026-07-23, earlier in session)

All 10 items FINAL's REQ-045 left open are now resolved in `Implementation_Specification_Addendum.md`:
1. Difficulty scale (8 levels, Trivial 11–Mythic 40)
2. Random distribution (2d20 open-ended, explosion/implosion, Boon/Bane die rerolls)
3. XP advancement cost (algebraic: skill curve × development curve × Resonance modifier)
4. Modifier bounds (removed by design — balance comes from the dice mechanic, not a cap)
5. Chargen B&B limits (2:1 Boon-to-Bane ratio, per-Resonance-level table)
6. Pending roll expiry (720 hours / ~30 days wall-clock)
7. Aspect contribution rounding (round nearest)
8. Catch-up XP (weekly median-based, 2x multiplier, no grace period)
9. Extraordinary luck messaging (probability-based, ≤0.01%)
10. Degrees of success (six degrees, GM-less/GM-led output formats)

Three editorial inconsistencies within the Addendum were also resolved: XP status label, extraordinary threshold value consistency (0.0001 throughout), and removal of duplicate/stale "pending" language.

## Outstanding Work

### Reconciliation Notes (Addendum ↔ FINAL terminology)

The Addendum was drafted before this session's discovery of the fabricated docs, so a few of its illustrative examples use pre-fabrication terminology (e.g. "Skill rating +0 to +5" in a §2 dice example) that predates confirming FINAL's actual 0-10 Skill range. This does not change any resolved mechanic — it is illustrative wording only — but implementers should read Addendum examples as operating on FINAL's real ranges (0-10 Skills, Body/Mind/Spirit Aspects) rather than the example numbers literally. Flag to the project owner if a genuine numeric conflict (not just an illustrative example) turns up during implementation.

### Before Implementation Begins

- [ ] Finalize exact Ruby class names for services (FINAL leaves this an implementation decision, REQ-004)
- [ ] Decide B&B catalogue seeding approach: command-based creation with README examples (per DD-02), confirmed still current
- [ ] Finalize non-canonical command syntax still open per REQ-037/REQ-045 (see `docs/reference/Commands.md` "Proposed" rows — e.g. exact abort-roll syntax)
- [ ] Design cron/scheduler approach for weekly catch-up recalculation and weekly XP award
- [ ] Finalize API contracts between Ruby backend and Ember web portal for each REQ-046 required capability

## Resolved Architecture Questions

These were open in the pre-fabrication era of this project and are now settled by FINAL.md:

- **Character Framework:** Body, Mind, Spirit Aspects; Skills belong to exactly one Aspect by stable key (REQ-008, REQ-009).
- **Resonance:** Chargen-only, R-3 to R3, locks at approval, does not decay or advance later (REQ-012).
- **B&B mechanics:** Two-layer catalogue/instance model with numeric IDs, tags, and configurable levels (REQ-016 through REQ-022).
- **Roll modifiers:** B&B and plugin-contributed modifiers via die rerolls (dice) plus a bounded flat sum (mechanical modifiers), per Addendum §2 and FINAL REQ-030.
- **Catch-up XP:** Accelerated earning only, weekly median-based, capped at the gap (REQ-014, Addendum §8).
- **GM-assisted rolls:** Per-scene configurable policy (Required/Optional/Unavailable), mandatory vs. optional B&B selection (REQ-029).

## Session Notes

### Session: 2026-07-23 (Current)

- Reviewed all documentation in the repo plus the Inklings AresMUSH Plugin Development Guide, as instructed before beginning the next implementation phase.
- Discovered the fabricated-documentation incident (see above); confirmed via git history; user confirmed suspicion of fabrication.
- User clarified document authority: FINAL.md and SOUL_Design_Decisions.md are creator-built and protected; the Addendum is co-developed (may be added to, not rewritten); everything else should be archived and rebuilt.
- Added protective banners to FINAL.md and SOUL_Design_Decisions.md.
- Archived 17 fabricated files to `docs/archive/`.
- Rebuilt all architecture, reference, and development documentation from the correct sources.
- **Next:** Rebuild `IMPLEMENTATION_CHECKLIST.md` and `ROADMAP.md`, then begin implementation handoff preparation per FINAL Appendix D's recommended order.

### Session: 2026-07-23 (Earlier — Addendum finalization)

- Resolved all 10 items in FINAL's REQ-045 via `Implementation_Specification_Addendum.md`.
- Fixed three internal inconsistencies in the Addendum (XP status label, extraordinary threshold, stale "pending" language).

### Session: 2026-07-22

- Project owner uploaded `SOUL_LLM_Implementation_Specification_FINAL.md` directly.
- A separate session (unrelated to the Addendum work) fabricated the now-archived documentation scaffolding.

---

**Note:** This document is a living record. Each implementation session should update this section with current status, recent decisions, and outstanding questions — it is the context-bridge between sessions. Before writing new architecture/reference documentation in any future session: read FINAL.md and SOUL_Design_Decisions.md in full first. Do not invent scaffolding.

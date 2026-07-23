# SOUL Development Roadmap

High-level milestones for SOUL implementation, following the recommended order in `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") Appendix D. Timelines and scope may adjust as development progresses.

## Completed Milestone: Specification and Documentation

**Status:** ✅ Complete (2026-07-23)

- FINAL.md (creator-built, authoritative requirements) and `SOUL_Design_Decisions.md` (creator-built design rationale) established the governing specification.
- `Implementation_Specification_Addendum.md` (co-developed) resolved all 10 items FINAL's REQ-045 left open: difficulty scale, 2d20 dice model, XP cost formula, chargen B&B ratio, pending roll expiry, aspect rounding, catch-up XP, degrees of success, extraordinary luck messaging, and the removal of global modifier bounds.
- A documentation-fabrication incident was discovered, corrected, and archived (see `docs/spec/CLAUDE_ADR.md` and `docs/archive/README.md`); all architecture/reference/development documentation was rebuilt from the correct governing sources.

## Current Milestone: Implementation, Phase 1

**Status:** Ready to begin

Per FINAL Appendix D's recommended order:

### Phase 1 — Plugin Skeleton, Configuration, Localization, Permissions

Foundation work: no gameplay logic yet, but everything downstream depends on it.

### Phase 2 — Character Framework, Skills, Aspects, Resonance, XP Ledger

The core character model: Body/Mind/Spirit Aspects, 0-10 Skills, chargen-locked Resonance, and the full XP ledger with the algebraic cost formula and catch-up mechanics.

### Phase 3 — Boons & Banes, Culminations, Narrative History/Audit

The two-layer B&B catalogue/instance model, Culminations as story milestones, and the Narrative History vs. audit-log split.

**Estimated scope for Phases 1-3:** 2-3 implementation cycles.

## Future Phases

### Phase 4 — Standard Rolls and Pending-Roll Flow

The 2d20 open-ended dice engine, Boon/Bane die rerolls, degrees of success, extraordinary luck detection, and the standard (non-GM) pending-roll workflow.

### Phase 5 — GM-Assisted Rolls and Scene Integration

Per-scene GM policy (Required/Optional/Unavailable), mandatory/optional B&B selection, abort/force-abort.

### Phase 6 — Complete MUSH/Web UI Parity

Every command family from `docs/reference/Commands.md` implemented equivalently on both interfaces (CP-05) — Sheet, B&B, Rolls, XP, History, and Staff UI.

### Phase 7 — Inklings and Grimoire Integrations

The Inklings validate/apply hook handoff, and Grimoire's read-only Skill/Aspect/Resonance access. Both remain fully optional — SOUL's core functionality never depends on either.

### Phase 8 — Migration, Documentation, Tests, and Release Review

FS3 migration validation, full documentation currency pass, coverage targets, FINAL Appendix C acceptance criteria, and the release checklist.

**Estimated scope for Phases 4-8:** 4-6 implementation cycles, with LlamaCoder handling repetitive scaffolding under Claude's architectural review (see the LlamaCoder Handoff Instructions in `Implementation_Specification_Addendum.md`).

## Stretch Goals (Deferred — FINAL Appendix E)

FINAL explicitly defers these; they require owner approval/an ADR before any implementation work begins, and must preserve every named Core Principle (CP-01 through CP-09):

- Additional roll types beyond the standard/GM-assisted model
- Conflict/challenge frameworks
- Richer B&B suggestion analysis
- Expanded Narrative History visualization
- Narrative currencies beyond Inspiration
- Relationship mechanics
- Setting-specific modules
- Additional integration outcome types

## Stretch Goals (Project-Level)

- Gather feedback from pilot games; iterate based on live-play experience
- Publish case studies of system usage
- Reference implementation guidance for third-party plugin developers

---

**Last Updated:** 2026-07-23

**Next Review:** After completing Phase 1 (plugin skeleton, configuration, localization, permissions)

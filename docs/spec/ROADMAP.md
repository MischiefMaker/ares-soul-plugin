# SOUL Development Roadmap

High-level milestones for SOUL implementation, following the recommended order in `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") Appendix D. Timelines and scope may adjust as development progresses.

## Completed Milestone: Specification and Documentation

**Status:** ✅ Complete (2026-07-23)

- FINAL.md (creator-built, authoritative requirements) and `SOUL_Design_Decisions.md` (creator-built design rationale) established the governing specification.
- `Implementation_Specification_Addendum.md` (co-developed) resolved all 10 items FINAL's REQ-045 left open: difficulty scale, 2d20 dice model, XP cost formula, chargen B&B ratio, pending roll expiry, aspect rounding, catch-up XP, degrees of success, extraordinary luck messaging, and the removal of global modifier bounds.
- A documentation-fabrication incident was discovered, corrected, and archived (see `docs/spec/CLAUDE_ADR.md` and `docs/archive/README.md`); all architecture/reference/development documentation was rebuilt from the correct governing sources.

## Completed Milestone: Implementation, Phases 1-3

**Status:** ✅ Complete, including the command/web-handler layer (2026-07-24). Core models/service APIs were Claude-implemented (2026-07-23); the command/web-handler/locale/help/Ember layer was implemented by Codex against a written handoff and reviewed/merged by Claude (`docs/handoffs/Phase_1-3_Commands_and_Web_Handlers.md`).

### Phase 1 — Plugin Skeleton, Configuration, Localization, Permissions ✅

Foundation work: no gameplay logic yet, but everything downstream depends on it.

### Phase 2 — Character Framework, Skills, Aspects, Resonance, XP Ledger ✅

The core character model: Body/Mind/Spirit Aspects, 0-10 Skills, chargen-locked Resonance, and the full XP ledger with the algebraic cost formula and catch-up mechanics.

### Phase 3 — Boons & Banes, Culminations, Narrative History/Audit ✅

The two-layer B&B catalogue/instance model, Culminations as story milestones, and the Narrative History vs. audit-log split.

Each phase was implemented only after verifying its design against real, current AresMUSH core source (FS3Skills for Phase 2, Achievements/Roles for Phase 3) rather than relying solely on the earlier documentation rebuild — see `docs/spec/CLAUDE_ADR.md`'s "Recent Changes" for the specific corrections each verification pass produced.

## Current Milestone: Implementation, Phase 4

**Status:** 🔶 In progress. Dice/probability engine complete (`plugin/public/soul_dice_engine.rb`, Claude-implemented directly and validated against Monte Carlo simulation). Roll models and service API handed to Codex (`docs/handoffs/Phase_4_Roll_Service_and_Models.md`) under the project's broadened Codex delegation model — pending implementation and Claude's review before this phase is complete.

### Phase 4 — Standard Rolls and Pending-Roll Flow

The 2d20 open-ended dice engine, Boon/Bane die rerolls, degrees of success, extraordinary luck detection, and the standard (non-GM) pending-roll workflow. Roll-modifier contribution from other plugins remains out of scope, still pending a design against a confirmed dispatch point — the previously-assumed `get_hooks` mechanism was found to have no basis in real core (see Phase 3 notes in `CLAUDE_ADR.md`); B&B modifiers are the only modifier source this phase implements.

## Future Phases

### Phase 5 — GM-Assisted Rolls and Scene Integration

Per-scene GM policy (Required/Optional/Unavailable), mandatory/optional B&B selection, abort/force-abort.

### Phase 6 — Complete MUSH/Web UI Parity

Every command family from `docs/reference/Commands.md` implemented equivalently on both interfaces (CP-05) — Sheet, B&B, Rolls, XP, History, and Staff UI.

### Phase 7 — Inklings and Grimoire Integrations

The Inklings validate/apply hook handoff, and Grimoire's read-only Skill/Aspect/Resonance access. Both remain fully optional — SOUL's core functionality never depends on either.

### Phase 8 — Migration, Documentation, Tests, and Release Review

FS3 migration validation, full documentation currency pass, coverage targets, FINAL Appendix C acceptance criteria, and the release checklist.

**Estimated scope for Phases 4-8:** 3-5 remaining implementation cycles, with LlamaCoder handling repetitive scaffolding under Claude's architectural review (see the LlamaCoder Handoff Instructions in `Implementation_Specification_Addendum.md`).

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

**Next Review:** After completing Phase 4 (standard rolls and pending-roll flow)

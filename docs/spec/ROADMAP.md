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

## Completed Milestone: Implementation, Phase 4

**Status:** ✅ Complete (2026-07-24). Dice/probability engine Claude-implemented directly (`plugin/public/soul_dice_engine.rb`, validated against Monte Carlo simulation); `Roll`/`PendingRoll` models and `SoulRollApi` implemented by Codex against a written handoff (`docs/handoffs/Phase_4_Roll_Service_and_Models.md`) and reviewed/merged by Claude — one signature gap (missing caller-identity argument on `resolve_pending`) caught and fixed during review.

### Phase 4 — Standard Rolls and Pending-Roll Flow

The 2d20 open-ended dice engine, Boon/Bane die rerolls, degrees of success, extraordinary luck detection, and the standard (non-GM) pending-roll workflow. Roll-modifier contribution from other plugins remains out of scope, still pending a design against a confirmed dispatch point — the previously-assumed `get_hooks` mechanism was found to have no basis in real core (see Phase 3 notes in `CLAUDE_ADR.md`); B&B modifiers are the only modifier source this phase implements.

## Completed Milestone: Implementation, Phase 5

**Status:** ✅ Complete (2026-07-24). Implemented by Codex against `docs/handoffs/Phase_5_GM_Assisted_Rolls.md` (extending the existing `SoulRollApi`, no new files) and reviewed/merged by Claude — one gap in the GM-exclusion enforcement for tag-based selection found and fixed during review.

### Phase 5 — GM-Assisted Rolls and Scene Integration

Per-scene GM policy (Required/Optional/Unavailable), mandatory/optional B&B selection, abort/force-abort. Builds on Phase 4's `PendingRoll` model, which already reserved the `gm_suggested_entries`/`gm_mandatory_entries`/`gm_assisted` fields for this phase. Scene-GM authorization (no dedicated GM field exists on the real `Scene` model) is resolved as global `gm_review_permission` scoped to actual scene participation — see the handoff §5.1.

## Completed Milestone: Implementation, Phase 6

**Status:** ✅ Complete (2026-07-24). Full command/web-handler layer across every subsystem — Sheet, B&B, XP, Culmination, History, Staff (Framework/Resonance/Reload/Audit), and Rolls (start, GM-assist, selection, abort/force-abort, pending, history, GM review/mark) — implemented by Codex and reviewed/merged by Claude. Chargen UI remains deferred to a later phase (underlying APIs exist; chargen integration is separate work).

### Phase 6 — Complete MUSH/Web UI Parity

Every command family from `docs/reference/Commands.md` implemented equivalently on both interfaces (CP-05) — Sheet, B&B, Rolls, XP, History, and Staff UI. Rolls (`+roll`, `+roll/gm`, `+roll suggested`, `+roll <tag>`, `+roll none`, abort/force-abort) join the command surface already deferred from Phases 1-4.

## Completed Milestone: Implementation, Phase 7

**Status:** ✅ Complete (2026-07-24). Grimoire side implemented directly (Claude — read-only lookups already existed from Phase 2; only a branch-to-Skill config mapping was added). `SoulInklingsHook` implemented by Codex against the handoff and reviewed/merged by Claude, including verifying the trickiest part (retry-safe idempotency ordering for Boon/Bane progressions) by reading the code directly rather than trusting the summary.

### Phase 7 — Inklings and Grimoire Integrations

The Inklings validate/apply hook, and Grimoire's read-only Skill/Aspect/Resonance access. Both remain fully optional — SOUL's core functionality never depends on either. A real idempotency gap in `SoulBnbApi.grant`/`.progress` (no protection against duplicate delivery) was found and resolved at the hook layer before the handoff was written, and Codex independently surfaced and correctly resolved a second, subtler ordering issue: the idempotency check must run before the state-matches-current revalidation, or a successful retry looks like stale state.

## Current Milestone: Implementation, Phase 8

**Status:** Ready to begin

### Phase 8 — Migration, Documentation, Tests, and Release Review

FS3 migration validation, full documentation currency pass, coverage targets, FINAL Appendix C acceptance criteria, and the release checklist.

**Estimated scope for the remaining phase:** 1 remaining implementation cycle, with Codex handling well-specified implementation work under Claude's architectural review (see the Codex Handoff Instructions in `Implementation_Specification_Addendum.md`).

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

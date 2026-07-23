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

## Completed Milestone: Implementation, Phase 8

**Status:** ✅ Complete (2026-07-24). This was a review/documentation-currency pass, not new implementation, so it was done directly rather than handed to Codex. Found and fixed real issues: `docs/development/Testing.md` and `Migration_From_FS3.md` contained fictional API examples that never matched any real shipped method (rewritten to quote actual signatures); 3 spec files had a genuine namespace bug that would have raised `NameError` on execution; `Commands.md` had 3 stale rows still showing pre-implementation placeholder syntax; and the long-repeated "`spec_helper.rb` is missing" note across every phase's implementation notes was corrected after checking the real AresMUSH engine and Inklings plugin directly — a standalone plugin repository never runs its own specs independently, by design, so nothing was actually missing.

### Phase 8 — Migration, Documentation, Tests, and Release Review

FS3 migration validation, full documentation currency pass, coverage targets, FINAL Appendix C acceptance criteria, and the release checklist. All eight planned implementation phases (FINAL Appendix D) are now complete.

## Milestone: Phase 9 — Checklist Review Follow-Up

**Status:** ✅ Mostly closed (2026-07-24) — its two remaining open items are carried forward into Phase 10 below rather than tracked twice. A full review of `IMPLEMENTATION_CHECKLIST.md`'s accumulated "deferred/incomplete" items, cross-checked directly against shipped code rather than each phase's own self-reported status. Several previously-flagged items turned out to be stale (already done in a later phase but never checked off); two genuinely real command-surface bugs were found and fixed directly.

### Fixed directly (small, mechanical, exact precedent already established elsewhere in the codebase)

- `SoulBnbApi.resolve`/`.restore` (REQ-020, built in Phase 3) had no command or web surface at all. Added `+bnb/resolve`/`+bnb/restore` and matching web operations.
- `SoulCulminationApi.deny`/`.revoke`/`.correct` (REQ-023, built in Phase 3) had no command or web surface at all — only `propose`/`approve` were ever wired. Added `+culmination/deny`/`/revoke`/`/correct` and matching web operations.

### Handed to Codex, implemented and merged (`60721d1`)

- `docs/handoffs/Phase_9_Profile_Tab_and_XP_Spend_UI.md` — found in response to a direct user question about web parity: the SOUL Ember components (Sheet/XP/B&B/Culmination/History) and their backend web operations were all correct, but none were ever mounted into the character profile page, and the web XP-spend form had no template UI. Codex's implementation matched Inklings' established profile-tab-mounting pattern correctly, including the `isSelf`-gated XP fix; one small gap found in review (no error feedback on a failed spend attempt) was fixed directly.
- `docs/handoffs/Phase_9_Scene_Page_Roll_Widget.md` — found in response to a direct user question comparing to Grimoire's scene-page `cast` component. Codex's review of the *original* handoff caught three real backend gaps the "no backend changes needed" claim had missed (missing player-facing candidate display — a genuine REQ-028 violation; missing difficulty lookup; `soulRollReview` omitting the rolling character) plus a real UX problem with the proposed authorization approach; all four were resolved (three backend fixes plus a `custom_scene_data.rb` snippet) before Codex implemented the actual widget against the corrected contract, confirmed correct by reading the diff directly.

### Confirmed stale, not real gaps (checkboxes corrected in `IMPLEMENTATION_CHECKLIST.md`)

- Resonance's approval Narrative History entry, Phase 6's staff XP commands, Phase 6's B&B search commands, and Phase 6's `+roll` GM-review family were all already implemented; their checklist entries just never got flipped from earlier phases' "deferred" notes.
- The roll-modifier contribution hook and `SoulXpAwardedEvent`/`SoulSkillAdvancedEvent` are resolved as intentionally out of scope (no real core dispatch mechanism exists for the former; no concrete consumer exists for either) rather than left as open TODOs — see `IMPLEMENTATION_CHECKLIST.md`'s Phase 3 section for the full reasoning.

## Milestone: Phase 10 — Web Command Parity Completion

**Status:** ✅ Complete (2026-07-24). Codex's own review of the merged Phase 9 web work audited MUSH/web parity across the whole plugin rather than stopping at the handoffs it was implementing — every finding was independently verified against the source before this phase was opened. Confirmed `docs/reference/Commands.md`'s prior claim that "no workflow requires switching interfaces" was false. All three resulting handoffs (this phase's own, plus Phase 9's two carried-forward items) are implemented and merged (`469995b`).

### Fixed directly (small, mechanical, no design ambiguity)

- `+soul/reload`/`soulReload` were pure no-ops that always reported success. Both now call the real, pre-existing `Soul.check_config` and report actual validation errors.
- `+bnb/here <tag>` had no web operation at all (not just no UI). Added `soulBnbHere`, mirroring the MUSH command's scene-participant-gated, public-safe lookup exactly.
- Corrected `Commands.md`'s inaccurate parity claim.

### Character Generation UI: Codex paused on three real gaps, all resolved

- `docs/handoffs/Phase_9_Character_Generation_UI.md` — no chargen B&B removal API existed (fixed directly, along with a deeper Narrative-History-timing bug it exposed in `SoulBnbApi.grant`); no canonical MUSH syntax was specified (resolved: new `+chargen` command family; also removed Aspect allocation from scope, since FINAL's canonical chargen flow never actually calls for it); the web mounting mechanism wasn't identified (resolved: real `chargen-custom-tabs.hbs`/`chargen-custom.hbs` snippet pair for the tab, dedicated `soulChargen*` operations for the data).

### All three handoffs implemented by Codex and merged (`469995b`)

- `docs/handoffs/Phase_9_Automatic_XP_Award_Sources.md`, `docs/handoffs/Phase_9_Character_Generation_UI.md`, `docs/handoffs/Phase_10_Web_Command_Parity_Completion.md` — reviewed the full diff (28 files) before merging. **Found and fixed one critical bug**: the scene-share event handler read a `.scene_id` attribute that doesn't exist on the real `SceneSharedEvent` (only `.id` does) — every real scene share would have raised an exception and the automatic XP award feature would never have worked, but the handler's own spec used a loose test double that didn't catch the mismatch. Also found and fixed a pervasive UX gap in the two brand-new web components (`soul/chargen`, `soul/staff`): both silently swallowed every API error with no visible feedback; both now surface real error messages. See `docs/spec/IMPLEMENTATION_CHECKLIST.md`'s Phase 10 section for full review detail.

## Milestone In Progress: Phase 11 — Command Parity Fixes and Repeat Audit

**Status:** 🔶 In progress (started 2026-07-24). Codex ran its own full MUSH/web command-parity audit after the Phase 9/10 merge instead of treating that merge as parity-complete, and found four substantive issues plus one secondary gating gap. All independently verified directly against the source before writing `docs/handoffs/Phase_11_Command_Parity_Fixes_and_Repeat_Audit.md`.

- B&B web search (`soulBnbCatalogue`'s `query` path) is reachable by any player and exposes inactive catalogue entries `+bnb/search` (correctly staff-only on the MUSH) would never show.
- Web force-abort only reaches rolls in the narrower `awaiting_gm` list, unlike `+roll/forceabort`, which can target any authorized open roll by id.
- The staff Framework view renders `<pre>{{framework}}</pre>` — Ember stringifies the object rather than displaying its actual Aspect/Skill data.
- Staff action feedback: partially already fixed directly (a generic error/success banner exists as of `89ea8ab`) — what remains is action-specific success messages and auto-refreshing affected read views.
- Secondary: the scene participant-sheet control's visibility doesn't check scene participation the way the roll widget's own gating does (not a security issue; server-side authorization is unaffected).

This handoff also requires Codex to re-run the full bidirectional parity audit after fixing these and repeat until a pass finds nothing, rather than a one-shot fix.

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

**Last Updated:** 2026-07-24

**Next Review:** Phase 11 (command parity fixes and repeat audit) is in progress, with one handoff awaiting Codex implementation and a required repeat audit before it can close. Once Phase 11 closes, future work is project-owner-directed: Stretch Goals above (each requires owner approval/an ADR per FINAL Appendix E), the separately-flagged `soul.yml` `enabled`-key decision (see `IMPLEMENTATION_CHECKLIST.md` Phase 9), or live deployment/pilot feedback.

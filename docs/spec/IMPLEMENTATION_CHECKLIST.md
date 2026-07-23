# SOUL Implementation Checklist

Progress tracking for SOUL subsystem implementation, structured around `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") Appendix D's recommended implementation order. REQ-* references point to FINAL's Requirements Index; Addendum §* references point to `docs/spec/Implementation_Specification_Addendum.md`.

## Phase 1: Plugin Skeleton, Configuration, Localization, Permissions

- [ ] Plugin module structure and initialization (`docs/architecture/Plugin_Architecture.md`)
- [ ] Plugin hooks registration (commands, events, web handlers)
- [ ] Configuration loading with live-reload support, no memoization (CP-06)
- [ ] Startup configuration validation: structure, required keys, duplicate tags/IDs, Aspect–Skill mappings, ranges (REQ-042)
- [ ] Localization setup (`plugin/locales/locale_en.yml`)
- [ ] Permission structure and default mappings (REQ-005, `docs/reference/Permissions.md`)
- [ ] `manage soul` admin help topic scaffolding (CI-08)

## Phase 2: Character Framework, Skills, Aspects, Resonance, XP Ledger

- [ ] Aspect model and configuration (default: Body, Mind, Spirit) (REQ-008, REQ-009)
- [ ] Skill model, Aspect relationship by stable key, 0-10 rating range (REQ-010)
- [ ] Aspect roll contribution (`round_nearest(rating × aspect.weight)`, default weight 0.20) (Addendum §7)
- [ ] Character Generation flow: framework load, Resonance selection, Skill allocation, chargen B&B selection, validation, correction, submission (REQ-011)
- [ ] Chargen approval locking via `Chargen.custom_approval` hook (REQ-011)
- [ ] Resonance model: R-3 to R3, chargen point/cap table, locking, staff correction with audit (REQ-012)
- [ ] XP ledger: `xp_available`, `xp_earned`, `xp_spent`, `catchup_xp_earned` (REQ-013)
- [ ] XP award sources: weekly, scene sharer/participant, forum, Inkling outcome, manual grant (REQ-013)
- [ ] XP cost formula implementation and unit tests against Addendum §3 worked examples
- [ ] Catch-up XP: weekly median recalculation, 2x multiplier, gap cap, exclusion of manual grants (REQ-014, Addendum §8)
- [ ] XP spend/advancement flow: validate → cost → show → atomic deduct+advance → history/audit (REQ-015)
- [ ] Staff XP commands: `+xp/award`, `+xp/award/catchup`, `+xp/scene`, `+xp/scene/catchup`, correction (REQ-015)

## Phase 3: Boons & Banes, Culminations, Narrative History/Audit

- [ ] B&B catalogue model: numeric ID, tag, category, level definitions, chargen flags (REQ-017)
- [ ] Character B&B entry model: instance ID, level/state, private explanation, associated Skills, source, progression history, GM notes (REQ-018)
- [ ] Chargen B&B acquisition with per-Resonance-level limits and 2:1 ratio validation (REQ-019, Addendum §5)
- [ ] Post-chargen B&B acquisition/progression through approved workflow, not XP (REQ-019)
- [ ] Resolved/Negated state handling (non-destructive, preserves prior level) (REQ-020)
- [ ] Epic state handling (explicit configured effect, no implied modifier) (REQ-020)
- [ ] Destructive deletion safeguards: warning, two confirmations, audit snapshot, linked correction (REQ-021)
- [ ] B&B search: `+bnb <id>`, `+bnb/here <tag>`, `+bnb/search <tag>` (REQ-022)
- [ ] Culmination model and staff approval workflow (REQ-023)
- [ ] Narrative History model, qualifying-events list, privacy/visibility (REQ-024)
- [ ] Audit log, distinct from Narrative History (REQ-006, GL-17)
- [ ] Correction/reversal pattern: append-only, links to original, never overwrite (CP-07)

## Phase 4: Standard Rolls and Pending-Roll Flow

- [ ] 2d20 open-ended dice engine: explosion on double-20, implosion on double-1, chained (Addendum §2 Steps 1)
- [ ] Boon/Bane die reroll mechanics applied to the full explosion chain (Addendum §2 Step 2)
- [ ] Mechanical modifier application (Skill + Aspect + other), no cap (Addendum §2 Step 3, §4)
- [ ] Difficulty comparison and margin calculation (Addendum §1)
- [ ] Six degrees of success determination and GM-less/GM-led output formatting (Addendum §8.1)
- [ ] Pre-roll probability calculation and extraordinary-luck flagging (≤0.01%) (Addendum §9)
- [ ] Pending-roll state model: player/character, Skill/Aspect, context, suggested/selected entries by category (REQ-027)
- [ ] Standard roll flow: validate → candidates → pending → suggestions → selection → resolve → history (REQ-028)
- [ ] "No candidates found" manual-identification fallback (REQ-028)
- [ ] Pending-roll limits: 1 standard / 2 GM-assisted (CI-04)
- [ ] Pending-roll expiry: 720 hours wall-clock, no auto-resolve (Addendum §6)
- [ ] Roll history and completed-roll record (REQ-031)

## Phase 5: GM-Assisted Rolls and Scene Integration

- [ ] Scene policy configuration: Required / Optional / Unavailable (REQ-029)
- [ ] GM mandatory vs. optional B&B marking (REQ-029)
- [ ] Reveal-policy-scoped GM visibility (privacy-safe wording, REQ-029, REQ-005)
- [ ] Player abort before GM submission, with GM notification (REQ-029)
- [ ] Staff force-abort with reason and audit (REQ-029)
- [ ] `+roll/gm`, `+roll suggested`, `+roll <tag>`, `+roll none` command implementations (REQ-026)

## Phase 6: Complete MUSH/Web UI Parity

- [ ] SOUL Sheet — MUSH (`+soul`) and web, one-screen concise format (CI-02, REQ-033)
- [ ] Drill-down Aspect/Skill detail views
- [ ] XP balances, advancement costs, and history — both interfaces
- [ ] Resonance display — both interfaces
- [ ] B&B catalogue browsing and character detail — both interfaces (REQ-035)
- [ ] Culmination display — both interfaces
- [ ] Narrative History display — both interfaces
- [ ] Roll history and pending-roll status/reminders — both interfaces (REQ-035)
- [ ] Chargen and advancement UI: limits/costs/explanations shown before commitment, unfinished work preserved (REQ-034)
- [ ] Staff UI: framework/Resonance/B&B/Culmination/advancement management, no direct DB manipulation (REQ-036)
- [ ] Web accessibility: keyboard-accessible controls, not color/icon-only (REQ-033)

## Phase 7: Inklings and Grimoire Integrations

- [ ] Inklings validation hook (`validate_outcome`) — normalized payload, no state mutation (REQ-039)
- [ ] Inklings application hook (`apply_outcome`) — atomic, idempotent, Narrative History/audit (REQ-039)
- [ ] Equivalent standalone staff path for every Inklings-triggered outcome (REQ-039)
- [ ] Grimoire read-only API exposure: Skills/Aspects/Resonance (REQ-040)
- [ ] Grimoire branch → Spirit Skill mapping support, without a dedicated Arcana Skill (REQ-040)
- [ ] Optional-plugin-absence handling: capability detection, dependent-path-only disablement, actionable warnings (REQ-007, REQ-038)

## Phase 8: Migration, Documentation, Tests, and Release Review

- [ ] FS3 migration scripts and guide validated against real data (`docs/development/Migration_From_FS3.md`)
- [ ] Full documentation pass: architecture, reference, development docs current with implementation
- [ ] Test coverage targets met (`docs/development/Testing.md`): 80%+ overall, 90%+ APIs
- [ ] FINAL Appendix C acceptance criteria verified end-to-end
- [ ] Release process followed (`docs/development/Release_Process.md`)
- [ ] AI-generated code reviewed for spec compliance, AresMUSH conventions, correctness, authorization/privacy, rule duplication, configuration/localization, interface parity, and maintainability (FINAL Appendix D)

## Documentation

- [x] Architecture documentation rebuilt from FINAL.md (2026-07-23)
- [x] Reference documentation rebuilt from FINAL.md + Addendum (2026-07-23)
- [x] Development documentation rebuilt from FINAL.md (2026-07-23)
- [ ] API documentation kept current as implementation reveals concrete class names
- [ ] Player command help files (`plugin/help/en/`)
- [ ] `manage soul` admin help topic (`plugin/help/admin/`)
- [ ] README with installation and setup
- [ ] Configuration reference kept current with actual `soul.yml` behavior

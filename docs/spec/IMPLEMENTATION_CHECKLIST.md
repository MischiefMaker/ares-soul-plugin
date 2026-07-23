# SOUL Implementation Checklist

Progress tracking for SOUL subsystem implementation, structured around `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") Appendix D's recommended implementation order. REQ-* references point to FINAL's Requirements Index; Addendum §* references point to `docs/spec/Implementation_Specification_Addendum.md`.

## Phase 1: Plugin Skeleton, Configuration, Localization, Permissions

**Status:** ✅ Complete (2026-07-23) — verified against real, current AresMUSH core source (`MischiefMaker/aresmush`, synced to 2026-07-08) and the Inklings plugin as a working reference implementation.

- [x] Plugin module structure and initialization (`plugin/soul.rb` — `plugin_dir`, `shortcuts`, `check_config`)
- [x] Plugin dispatch registration points defined (`get_cmd_handler`/`get_event_handler`/`get_web_request_handler` — no commands/events/handlers registered yet since no subsystem exists to dispatch to; wired in later phases)
- [x] Configuration loading: `Global.read_config` called fresh at every use site, never memoized (CP-06) — confirmed this means "safe under a staff config reload," not "re-reads the YAML file from disk every call"
- [x] Startup configuration validation (`plugin/soul_config_validator.rb`, using the real `AresMUSH::Manage::ConfigValidator` mechanism every bundled core plugin uses): structure, required keys, ranges, enum values for all Phase 1-checkable settings. Cross-referential checks (Skill→Aspect key resolution, B&B tag uniqueness) deferred to Phase 2/3 once those models exist.
- [x] Localization setup (`plugin/locales/locale_en.yml`)
- [x] Permission structure and default mappings (`Soul.can_manage_soul?`/`can_play?`/`can_review_rolls?` in `plugin/soul.rb`, flat top-level config keys — see `docs/reference/Permissions.md`)
- [x] `manage soul` admin help topic scaffolding (`plugin/help/en/manage_soul.md`, CI-08 — single `help/en/` directory, not a separate `admin/` folder; admin-only status signaled via a "Permission Required" note in the body)
- [x] Default `game/config/soul.yml` shipped, matching `docs/reference/Default_Config.md`
- [x] Config validator spec (`plugin/spec/soul_config_validator_spec.rb`)

## Phase 2: Character Framework, Skills, Aspects, Resonance, XP Ledger

**Status:** ✅ Core models and service APIs complete (2026-07-23) — verified against real AresMUSH core (FS3Skills plugin, the closest existing precedent for character ratings/XP/chargen point budgets) and Inklings' chargen-approval integration pattern. Player/staff-facing commands and full chargen UI are explicitly deferred — see "Deferred to Later Phases" below.

- [x] Aspects and Skills as a **configured catalogue**, not DB models (`SoulFrameworkApi`, reading `game/config/soul.yml`'s `framework.aspects`/`framework.skills`) — corrected from an earlier draft that modeled these as separate Ohm::Model classes; verified against FS3Skills, where ability *definitions* are pure config and only the per-character *rating* is DB-backed (REQ-008, REQ-009, REQ-010)
- [x] `CharacterAspect`, `CharacterSkill` models — per-character ratings, shaped like FS3Skills' own `FS3ActionSkill` (`plugin/models/character_aspect.rb`, `character_skill.rb`)
- [x] Aspect roll contribution: `SoulCharacterApi.aspect_contribution`/`get_effective_base` (`round_nearest(rating × aspect.weight)`, default weight 0.20) (Addendum §7)
- [x] Resonance: `SoulResonanceApi` — chargen point/cap table (REQ-012 canonical formula), pre-lock `set_resonance`, `lock_at_approval` (called from the game's own `plugins/chargen/custom_approval.rb` via `custom-install/custom_approval.snippet.rb` — **not** a plugin-defined hook class; there is no framework-level chargen-approval dispatch), staff `correct` with a lightweight audit trail pending Phase 3's real Audit model
- [x] XP ledger: `soul_xp_available`, `soul_xp_earned`, `soul_xp_spent`, `soul_catchup_xp_earned` Character attributes + `SoulXpLedgerEntry` idempotency-keyed award/spend records (REQ-013)
- [x] XP cost formula (`SoulXpApi.calculate_cost`) implemented and unit-tested against Addendum §3 worked examples — **found and corrected an arithmetic error in the Addendum's own +5 Resonance example** (stated 6.1×/610%, should be 7.1×/710% per the formula as written; see the Addendum §3 correction note)
- [x] Catch-up XP (`SoulXpApi.award`/`catchup_eligible?`/`median_earned_xp`): median computed live across `Chargen.approved_chars` on every award rather than a separate cached recalculation step (still satisfies "weekly recalculation," since the weekly award cron is the main trigger point), 2x multiplier, gap cap, `apply_catchup:` flag (defaults on for automatic sources; the manual-grant staff command omits it) (REQ-014, Addendum §8)
- [x] XP spend/advancement flow: validate → cost → atomic deduct+advance → ledger (`SoulXpApi.spend`) (REQ-015)
- [x] Weekly XP award cron (`plugin/events/soul_xp_cron_handler.rb`), using the verified real `Cron.is_cron_match?`/`CronEvent` mechanism (confirmed via FS3Skills' and Inklings' own cron handlers)

### Deferred to Later Phases (explicitly out of scope for this pass)

- [ ] Character Generation **UI/commands**: framework display, Resonance selection form, Skill allocation validation surfaced to the player — the underlying `SoulResonanceApi`/`SoulCharacterApi` methods exist, but MUSH commands and web chargen integration belong with Phase 6 (Complete MUSH/Web UI Parity), matching how FS3Skills' own chargen UI is a separate layer over its rating storage
- [ ] Chargen B&B selection (REQ-011) — depends on Phase 3's B&B catalogue model, which doesn't exist yet
- [ ] Narrative History entry for approved starting Resonance (REQ-012) — depends on Phase 3's Narrative History model; `SoulResonanceApi.lock_at_approval` has a `TODO(Phase 3)` marking exactly where this plugs in
- [ ] Staff XP commands (`+xp/award`, `+xp/award/catchup`, `+xp/scene`, `+xp/scene/catchup`, correction) — the `SoulXpApi.award`/`spend` methods these would call already exist; the MUSH command layer is Phase 6 territory
- [ ] Scene sharer/participant and forum XP award sources (REQ-013) — require Scenes/Forum plugin integration points not yet investigated; only the weekly award source is wired so far

## Phase 3: Boons & Banes, Culminations, Narrative History/Audit

**Status:** ✅ Core models and service APIs complete (2026-07-23) — verified against real AresMUSH core (the Achievements plugin as the closest precedent for a per-character granted-record model; Roles plugin for the real custom-event convention). Commands/UI deferred to Phase 6, consistent with Phase 2's precedent.

- [x] B&B catalogue model: numeric ID (Ohm's own auto-increment), tag, kind (boon/bane), category, level definitions, chargen flags (`BnbCatalogueEntry`, REQ-017)
- [x] Character B&B entry model: instance ID, level/state, private explanation, associated Skills, source, progression history, GM notes (`CharacterBnbEntry`, REQ-018)
- [x] Chargen B&B acquisition with per-Resonance-level limits (`SoulBnbApi.validate_chargen_limits`, chargen-sourced grants only) and continuous 2:1 ratio validation (`SoulBnbApi.ratio_satisfied_after_boon?`, every Boon grant regardless of source) (REQ-019, Addendum §5)
- [x] Post-chargen B&B acquisition/progression through `SoulBnbApi.grant`/`progress` — no XP cost path exists for B&Bs (REQ-019)
- [x] Resolved/Negated state handling: non-destructive, preserves prior level via `preserved_level_state`, restorable (`SoulBnbApi.resolve`/`restore`) (REQ-020)
- [x] Epic state handling: catalogue-entry-level `epic_modifier`, no implied default (`SoulBnbApi.level_modifier`) (REQ-020)
- [x] Destructive deletion safeguards: reason required, `confirmations: 2` required, audit snapshot, linked Narrative History correction (`SoulBnbApi.delete`) (REQ-021)
- [x] Culmination model and staff approval workflow: propose (with deterministic duplicate detection)/approve/deny/revoke/correct (`Culmination`, `SoulCulminationApi`) (REQ-023)
- [x] Narrative History model, qualifying-events creation, owner/staff-only privacy (`NarrativeHistoryEntry`, `SoulNarrativeHistoryApi`) (REQ-024)
- [x] Audit log, distinct from Narrative History, staff-only (`SoulAuditEntry`, `SoulAuditApi`) (REQ-006, GL-17)
- [x] Correction/reversal pattern: append-only `correction_log`/`progression_history` arrays, links to original, never overwrite (CP-07) — applied to `Culmination`, `CharacterBnbEntry`, and backfilled into Phase 2's `SoulResonanceApi.correct`
- [x] Real custom-event mechanism (`SoulBnbTransitionedEvent`, `SoulCulminationApprovedEvent` via `Global.dispatcher.queue_event`) — corrects an unverified `get_hooks`/`dispatcher.dispatch(name, hash)` mechanism assumed in the Phase 1 doc rebuild, which has no basis in real core (see `docs/architecture/API_and_Hooks.md`'s "Hooks" section)

### Deferred to Later Phases

- [ ] B&B search/lookup **commands**: `+bnb <id>`, `+bnb/here <tag>`, `+bnb/search <tag>` (REQ-022) — the underlying `SoulBnbApi.get_catalogue_entry`/`search` methods exist; MUSH commands are Phase 6 territory, same as Phase 2's XP/Resonance commands
- [ ] Roll-modifier contribution hook — the previously-documented `get_hooks`/`:soul_roll_modifiers` design has no basis in real core; needs a fresh design against a confirmed dispatch point when Phase 4/5 builds the roll engine
- [ ] `SoulXpAwardedEvent`/`SoulSkillAdvancedEvent` — documented in `API_and_Hooks.md` as the planned shape but not yet fired by Phase 2's `SoulXpApi`/`SoulCharacterApi`; add when an integration actually needs them

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

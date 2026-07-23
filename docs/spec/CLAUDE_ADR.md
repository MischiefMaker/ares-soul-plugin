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

**Phase:** ✅ Phase 1 complete. ✅ Phase 2 core models/APIs complete (Character Framework, Skills, Aspects, Resonance, XP Ledger) — commands, chargen UI, and B&B/Narrative-History-dependent pieces explicitly deferred (see `IMPLEMENTATION_CHECKLIST.md` Phase 2 "Deferred to Later Phases"). Ready to begin Phase 3 (Boons & Banes, Culminations, Narrative History/Audit).

## Reference Repositories in This Session

Two additional repos were added to verify Phase 1 against real source rather than documented-but-unconfirmed conventions (per FINAL.md Appendix D's requirement to inspect the closest official plugins before implementing):

- `MischiefMaker/aresmush` — a fork of AresMUSH core. **Was frozen at a 2019-12-15 commit when first added; synced to a live 2026-07-08 commit mid-session at the user's instruction.** Any finding sourced from this repo should be treated as reflecting its currently-synced commit, not assumed permanently current — re-sync before relying on it in a future session if meaningful time has passed.
- `MischiefMaker/ares-inklings-plugin` — the Inklings plugin, used as a working reference implementation (not just its dev guide). Its `ARES_PLUGIN_DEVELOPMENT_GUIDE.md` was updated this session (Lessons 30-35) with corrections discovered while building SOUL's Phase 1 against real source — read those lessons before starting Phase 2, since several correct earlier assumptions about SOUL's own docs were found wrong this way.

## Critical Incident: Fabricated Documentation (Discovered and Corrected 2026-07-23)

A prior Claude session (2026-07-22, commit `4c9df1b`) wrote `docs/architecture/*`, `docs/reference/*`, `docs/development/*`, and this file's predecessor as generic placeholder scaffolding — by its own admission, "created initial templates" — without deriving any of it from FINAL.md, which the project owner had uploaded directly that same day (commit `649fdd2`). The two described incompatible character models: fabricated docs used Combat/Social/Arcane aspects, a 0-5 skill range, a flat XP table, and category-based B&Bs with no catalogue/instance split; FINAL.md specifies Body/Mind/Spirit aspects, a 0-10 skill range, an algebraic XP cost formula, and a two-layer numeric-ID/tag B&B catalogue with Minor/Major/Legendary/Negated/Epic levels.

This was caught during a 2026-07-23 documentation review (prompted by the user asking Claude to re-review all docs and the Inklings dev guide before starting implementation), confirmed via `git log` against each file, and the fabricated material was archived to `docs/archive/` (see `docs/archive/README.md` for the full discrepancy table). All architecture/reference/development documentation has since been rebuilt from FINAL.md, SOUL_Design_Decisions.md, and the Addendum.

**Lesson for future sessions:** Never write architecture/reference scaffolding without deriving it from the actual governing specification. If a specification file exists, read it fully before writing any supporting documentation — do not fill gaps with generic assumptions.

## Recent Changes

### Phase 2 Implementation: Character Framework, Skills, Aspects, Resonance, XP Ledger (2026-07-23)

Before writing code, inspected `plugins/fs3skills/` in the (now-current) AresMUSH core — the closest real precedent for character ratings, XP, and chargen point budgets — plus re-read `Global.read_config`/`Ohm::DataTypes`/`Cron` source directly rather than assuming Phase 1's conventions generalized cleanly to richer per-character data.

**Key finding that changed the design:** Aspects and Skills should be a **configured catalogue**, not separate `Ohm::Model` DB classes. FS3Skills has zero DB-backed "ability definition" table — `plugins/fs3skills/helpers/utils.rb`'s `attrs`/`action_skills`/`languages` are pure `Global.read_config` reads; only the per-character rating gets an `Ohm::Model` (`FS3ActionSkill`, `FS3Attribute`, etc., each just `reference :character` + a name + a `rating`). The original architecture doc modeled `Aspect`/`Skill` as full catalogue tables — corrected this session; `docs/architecture/Data_Model.md` now documents the config-driven approach, and only `CharacterAspect`/`CharacterSkill` (the per-character rating half) are real models, matching `FS3ActionSkill`'s shape exactly.

**Other findings from real source, applied to the implementation:**
- `Ohm::DataTypes::DataType::Integer`'s cast is `x.to_i` with **no nil guard** — an attribute typed this way silently reads an unset value as `0`. This matters for Resonance, where R0 is a valid, meaningfully-different-from-unset choice: `resonance` is a plain untyped attribute instead, parsed manually in `SoulResonanceApi.get_resonance` to preserve the nil-vs-R0 distinction. (`Time`/`Date`/`Hash`/`Array`/`Set` casts all guard with `x && ...`; `Integer`/`Float`/`Decimal` do not.)
- The real periodic-task mechanism is `CronEvent` (fired every minute) + `Cron.is_cron_match?(cron_spec, event.time)`, confirmed via both FS3Skills' `xp_cron_handler.rb` and Inklings' `inkling_xp_cron_handler.rb`. `docs/reference/Configuration.md`'s earlier placeholder `xp.catchup.schedule: "weekly"` string wasn't actionable against this — replaced with a real cron-format `xp.weekly_award_cron` hash (`day_of_week`/`hour`/`minute`), validated with `Manage::ConfigValidator#check_cron`.
- Catch-up XP eligibility doesn't need its own separate recalculation job — `SoulXpApi.median_earned_xp` is computed live from `Chargen.approved_chars` on every award, so it's always current without a cache to keep in sync.
- `Chargen.approved_chars` (not `Character.all`) is the real population for both the weekly award and the catch-up median — it excludes NPCs, rosters, and inactive characters, confirmed via `plugins/chargen/public/chargen_api.rb`.
- Chargen-approval integration is the same manual-paste-snippet mechanism as Inklings' own (Lesson 33 from Phase 1) — `SoulResonanceApi.lock_at_approval` is called from `custom-install/custom_approval.snippet.rb`, not a plugin-defined hook class.

**Files added:** `plugin/models/character_soul_fields.rb`, `character_aspect.rb`, `character_skill.rb`, `soul_xp_ledger_entry.rb`; `plugin/public/soul_framework_api.rb`, `soul_character_api.rb`, `soul_resonance_api.rb`, `soul_xp_api.rb`; `plugin/events/soul_xp_cron_handler.rb`; `custom-install/custom_approval.snippet.rb`; three spec files. `game/config/soul.yml` and `soul_config_validator.rb` updated for the real cron format.

**Also found and corrected:** an arithmetic error in the Addendum's own §3 worked example (+5 Resonance stated as a 6.1×/610% multiplier; the formula as written actually produces 7.1×/710% — `1 + 0.22×5 + 1×5 = 7.1`, not `6.1`). Fixed the worked-example arithmetic only; the formula/decision itself is unchanged. Implementation (`SoulXpApi.calculate_cost`) and its spec both use the corrected 7.1× figure.

**Explicitly deferred** (see `IMPLEMENTATION_CHECKLIST.md` Phase 2 for the full list): chargen UI/commands (Phase 6), B&B chargen selection (needs Phase 3's catalogue), the Narrative History entry for approved Resonance (needs Phase 3's model — `lock_at_approval` has a `TODO(Phase 3)` marking exactly where), and scene/forum XP award sources (need Scenes/Forum integration points not yet investigated).

### Phase 1 Implementation, Verified Against Real Source (2026-07-23)

Wrote the plugin skeleton after re-syncing `MischiefMaker/aresmush` from its stale 2019 snapshot and reading real, current source for every convention used (plugin registration/dispatch, config validation, permission checks, help file loading) rather than relying solely on the documented-but-unverified conventions from the earlier doc rebuild:

- `plugin/soul.rb` — module registration (`plugin_dir`, `shortcuts`), permission helpers (`can_manage_soul?`, `can_play?`, `can_review_rolls?`), `check_config` delegating to a validator class.
- `plugin/soul_config_validator.rb` — uses the real `AresMUSH::Manage::ConfigValidator` mechanism (confirmed via `jobs_config_validator.rb`, `chargen_config_validator.rb`, and ten more bundled plugins, all following the identical `check_config` → `<Name>ConfigValidator#validate` → `Manage::ConfigValidator` shape).
- `game/config/soul.yml` — full default config, corrected to nest everything under a top-level `soul:` key (confirmed against `ConfigReader`'s section-per-file model) with flat permission keys (see below).
- `plugin/locales/locale_en.yml`, `plugin/help/en/soul.md`, `plugin/help/en/manage_soul.md`, `plugin/spec/soul_config_validator_spec.rb`.

**Corrections this verification pass made to the 2026-07-23 doc rebuild** (all now fixed in the docs themselves, and reflected in the Inklings dev guide's new Lessons 30-35):
1. Permission config keys are flat top-level settings (`manage_permission`, `play_permission`, `gm_review_permission`), not a nested `permissions: {}` hash — the nested version was an unforced invention never checked against Inklings' own `manage_permission` precedent.
2. Permission checks are plain module methods on `Soul` itself (`Soul.can_manage_soul?`), not a separate `Permissions` class — matches `Inklings.can_manage_inklings?`.
3. Help files load from a single `help/en/` directory — there is no `help/admin/` split. Admin topics are marked with a "Permission Required" note in the body (see `manage_inklings.md`), not routed to a different folder.
4. There is no `hooks/` directory with framework-level auto-dispatch — `get_cmd_handler`/`get_event_handler`/`get_web_request_handler` are the only three dispatch points the core `Dispatcher` actually calls. Chargen integration (Phase 2+) happens via manually-pasted `custom_approval.rb`/`custom_app_review.rb` snippets in the game's own `plugins/chargen/` directory, not a plugin-defined hook class — confirmed by grepping current core for `chargen_finalize` (zero hits; Inklings' own `hooks/chargen_hook.rb` turned out to be unwired dead code).
5. "Config is read live" means `Global.read_config` is called fresh at every use site (never memoized in plugin code) so a staff config reload takes effect immediately — not that AresMUSH re-parses the YAML file from disk on every call (it's cached in memory from boot/reload).
6. Test fixtures use the Fabrication gem (`Fabricate(:character)`, confirmed from Inklings' own specs), not FactoryBot; tests live in a flat `plugin/spec/*.rb` (no subdirectories), not `spec/api/`, `spec/commands/`, etc.

Docs updated to reflect all six corrections: `Permissions.md`, `Default_Config.md`, `Configuration.md`, `Plugin_Architecture.md`, `Coding_Standards.md`, `Testing.md`.

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

### Before Phase 3 Begins

- [ ] Finalize exact Ruby class names for services (FINAL leaves this an implementation decision, REQ-004) — `SoulFrameworkApi`/`SoulCharacterApi`/`SoulResonanceApi`/`SoulXpApi` now exist; Phase 3 needs `SoulBnbApi`, `SoulCulminationApi`, `SoulNarrativeHistoryApi`, `SoulAuditApi`
- [ ] Decide B&B catalogue seeding approach: command-based creation with README examples (per DD-02), confirmed still current
- [ ] Finalize non-canonical command syntax still open per REQ-037/REQ-045 (see `docs/reference/Commands.md` "Proposed" rows — e.g. exact abort-roll syntax)
- [ ] Finalize API contracts between Ruby backend and Ember web portal for each REQ-046 required capability
- [x] ~~Design cron/scheduler approach for weekly catch-up recalculation and weekly XP award~~ — done in Phase 2 (`plugin/events/soul_xp_cron_handler.rb`, real `Cron`/`CronEvent` mechanism)
- [x] ~~Re-verify the real `custom_approval.rb` snippet mechanism~~ — done in Phase 2 (`custom-install/custom_approval.snippet.rb`)
- [ ] When Phase 3's Narrative History/Audit models are built, backfill `SoulResonanceApi.lock_at_approval`'s `TODO(Phase 3)` marker and migrate `resonance_correction_log` (currently a lightweight Character attribute) to the real Audit model

## Resolved Architecture Questions

These were open in the pre-fabrication era of this project and are now settled by FINAL.md:

- **Character Framework:** Body, Mind, Spirit Aspects; Skills belong to exactly one Aspect by stable key (REQ-008, REQ-009).
- **Resonance:** Chargen-only, R-3 to R3, locks at approval, does not decay or advance later (REQ-012).
- **B&B mechanics:** Two-layer catalogue/instance model with numeric IDs, tags, and configurable levels (REQ-016 through REQ-022).
- **Roll modifiers:** B&B and plugin-contributed modifiers via die rerolls (dice) plus a bounded flat sum (mechanical modifiers), per Addendum §2 and FINAL REQ-030.
- **Catch-up XP:** Accelerated earning only, weekly median-based, capped at the gap (REQ-014, Addendum §8).
- **GM-assisted rolls:** Per-scene configurable policy (Required/Optional/Unavailable), mandatory vs. optional B&B selection (REQ-029).

## Session Notes

### Session: 2026-07-23 (Phase 2 Implementation)

- User asked to re-review all documentation and the Inklings dev guide again before starting Phase 2, per the established pattern.
- Explored `plugins/fs3skills/` in the (re-verified current) AresMUSH core as the closest real precedent for character ratings, XP, and chargen point budgets — found it uses config-driven ability definitions with only per-character ratings DB-backed, which corrected the planned Aspect/Skill model design before any code was written (see Recent Changes above).
- Implemented Phase 2 core models and service APIs: Character Framework (config-driven catalogue + `CharacterAspect`/`CharacterSkill`), Resonance (`SoulResonanceApi`), XP ledger (`SoulXpApi`, `SoulXpLedgerEntry`), weekly XP cron.
- Found and corrected an arithmetic error in the Addendum's own §3 worked example (+5 Resonance: stated 6.1×/610%, corrected to 7.1×/710% to match the formula as written) — a factual arithmetic fix within the "may add to it" permission for the Addendum, not a decision change.
- Fixed `docs/architecture/Data_Model.md`, `API_and_Hooks.md`, and `Integration_Guide.md` to match the corrected Aspect/Skill design and a couple of small `SoulFrameworkApi`/`SoulCharacterApi` method-naming mixups from the Phase 1 doc rebuild.
- Explicitly deferred chargen UI/commands, B&B chargen selection, the Resonance Narrative History entry, and scene/forum XP sources — see `IMPLEMENTATION_CHECKLIST.md` Phase 2.
- **Next:** Phase 3 — Boons & Banes, Culminations, Narrative History/Audit (see `docs/spec/IMPLEMENTATION_CHECKLIST.md` Phase 3 and `docs/spec/ROADMAP.md`). Backfill the `TODO(Phase 3)` markers left in `SoulResonanceApi` once the Narrative History/Audit models exist.

### Session: 2026-07-23 (Phase 1 Implementation)

- Reviewed all documentation in the repo plus the Inklings AresMUSH Plugin Development Guide, as instructed before beginning the next implementation phase.
- Discovered the fabricated-documentation incident (see above); confirmed via git history; user confirmed suspicion of fabrication.
- User clarified document authority: FINAL.md and SOUL_Design_Decisions.md are creator-built and protected; the Addendum is co-developed (may be added to, not rewritten); everything else should be archived and rebuilt.
- Added protective banners to FINAL.md and SOUL_Design_Decisions.md.
- Archived 17 fabricated files to `docs/archive/`.
- Rebuilt all architecture, reference, and development documentation from the correct sources.
- User asked to add both `MischiefMaker/aresmush` and `MischiefMaker/ares-inklings-plugin` to the session for source verification before writing any code, per FINAL Appendix D. Found the aresmush fork frozen at a 2019 commit; user synced it to 2026-07-08 mid-session.
- Read real source for plugin registration/dispatch, config validation, permission checks, model conventions, command/web-handler patterns, and help file loading across both repos.
- Implemented Phase 1 (`plugin/soul.rb`, `soul_config_validator.rb`, `game/config/soul.yml`, `locale_en.yml`, help topics, config validator spec), correcting six discrepancies the verification pass surfaced in the earlier doc rebuild (see above).
- At user's request, added the six corrections as Lessons 30-35 to the Inklings plugin's own `ARES_PLUGIN_DEVELOPMENT_GUIDE.md`, committed and pushed to that repo's `main`.
- **Next:** Phase 2 — Character Framework, Skills, Aspects, Resonance, XP Ledger (see `docs/spec/IMPLEMENTATION_CHECKLIST.md` Phase 2 and `docs/spec/ROADMAP.md`).

### Session: 2026-07-23 (Earlier — Addendum finalization)

- Resolved all 10 items in FINAL's REQ-045 via `Implementation_Specification_Addendum.md`.
- Fixed three internal inconsistencies in the Addendum (XP status label, extraordinary threshold, stale "pending" language).

### Session: 2026-07-22

- Project owner uploaded `SOUL_LLM_Implementation_Specification_FINAL.md` directly.
- A separate session (unrelated to the Addendum work) fabricated the now-archived documentation scaffolding.

---

**Note:** This document is a living record. Each implementation session should update this section with current status, recent decisions, and outstanding questions — it is the context-bridge between sessions. Before writing new architecture/reference documentation in any future session: read FINAL.md and SOUL_Design_Decisions.md in full first. Do not invent scaffolding.

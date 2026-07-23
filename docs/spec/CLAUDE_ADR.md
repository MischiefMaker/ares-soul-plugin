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

**Session Date:** 2026-07-24

**Branch:** `main`

**Phase:** ✅ Phases 1-5 complete. 🔶 Phase 6 (Complete MUSH/Web UI Parity) in progress — Sheet/B&B/XP/Culmination/History/Framework-staff command layer already complete (Codex, earlier); roll commands and audit-log viewing handed to Codex (`docs/handoffs/Phase_6_Roll_Commands_and_Audit.md`), pending implementation and review.

**Delegation model changed this session:** `Implementation_Specification_Addendum.md` was updated with a new, much broader Codex role (models, services, APIs, events, cron jobs, tests — not just command/web adapters as under the narrower LlamaCoder rules that preceded it). See the Addendum's "SOUL Codex Handoff Instructions" section. Claude's role is now consistently: architecture, mathematically/architecturally sensitive implementation, design-gap resolution, and review — with conventional CRUD/service implementation work delegated to Codex once the design is locked.

## Reference Repositories in This Session

Two additional repos were added to verify Phase 1 against real source rather than documented-but-unconfirmed conventions (per FINAL.md Appendix D's requirement to inspect the closest official plugins before implementing):

- `MischiefMaker/aresmush` — a fork of AresMUSH core. **Was frozen at a 2019-12-15 commit when first added; synced to a live 2026-07-08 commit mid-session at the user's instruction.** Any finding sourced from this repo should be treated as reflecting its currently-synced commit, not assumed permanently current — re-sync before relying on it in a future session if meaningful time has passed.
- `MischiefMaker/ares-inklings-plugin` — the Inklings plugin, used as a working reference implementation (not just its dev guide). Its `ARES_PLUGIN_DEVELOPMENT_GUIDE.md` was updated this session (Lessons 30-35) with corrections discovered while building SOUL's Phase 1 against real source — read those lessons before starting Phase 2, since several correct earlier assumptions about SOUL's own docs were found wrong this way.

## Critical Incident: Fabricated Documentation (Discovered and Corrected 2026-07-23)

A prior Claude session (2026-07-22, commit `4c9df1b`) wrote `docs/architecture/*`, `docs/reference/*`, `docs/development/*`, and this file's predecessor as generic placeholder scaffolding — by its own admission, "created initial templates" — without deriving any of it from FINAL.md, which the project owner had uploaded directly that same day (commit `649fdd2`). The two described incompatible character models: fabricated docs used Combat/Social/Arcane aspects, a 0-5 skill range, a flat XP table, and category-based B&Bs with no catalogue/instance split; FINAL.md specifies Body/Mind/Spirit aspects, a 0-10 skill range, an algebraic XP cost formula, and a two-layer numeric-ID/tag B&B catalogue with Minor/Major/Legendary/Negated/Epic levels.

This was caught during a 2026-07-23 documentation review (prompted by the user asking Claude to re-review all docs and the Inklings dev guide before starting implementation), confirmed via `git log` against each file, and the fabricated material was archived to `docs/archive/` (see `docs/archive/README.md` for the full discrepancy table). All architecture/reference/development documentation has since been rebuilt from FINAL.md, SOUL_Design_Decisions.md, and the Addendum.

**Lesson for future sessions:** Never write architecture/reference scaffolding without deriving it from the actual governing specification. If a specification file exists, read it fully before writing any supporting documentation — do not fill gaps with generic assumptions.

## Recent Changes

### Phase 6 Handoff Correction: Missing resolve_pending Call (2026-07-24)

A material omission was found in the Phase 6 handoff before Codex began implementation: §5.3's selection-disambiguation algorithm specified `select_entries` for the `suggested`/`none`/tag-list forms but never specified any call to `resolve_pending` — meaning a fully-selected pending roll would sit in `"awaiting_selection"` forever with no path to ever producing a completed `Roll`. Fixed by adding an explicit new §5.3.1: a successful `select_entries` must immediately trigger `resolve_pending` in the same command/web invocation, matching CI-03's conversational flow (selection flows directly into resolution, with no separate "now roll it" step described anywhere in the spec). A `select_entries` failure never attempts resolution; a `resolve_pending` failure after a successful selection leaves the pending roll selectable again rather than stuck. Command-surface table, acceptance criteria, and testing requirements all updated to reflect this.

### Phase 6 Handoff: Roll Commands and Audit Command (2026-07-24)

Reviewed the existing Phase 1-3 command/web-handler layer (already complete under the "Phase 6" label in `IMPLEMENTATION_CHECKLIST.md`) to find the actual remaining gaps: Rolls (Phases 4-5) never got any command surface at all, and its own item 8 flagged that staff Audit-log viewing was never designed. Both closed in one handoff (`docs/handoffs/Phase_6_Roll_Commands_and_Audit.md`), extending existing files (`SoulStaffCmd`/`SoulStaffWebHandler` gain an `"audit"` switch) plus two new files (`SoulRollCmd`/`SoulRollWebHandler`).

**Two real gaps in FINAL's canonical roll syntax resolved before writing the handoff** (documented in `Commands.md` and `IMPLEMENTATION_CHECKLIST.md`, not left for Codex):
1. `+roll <skill>` (REQ-026) has no difficulty argument at all — resolved as defaulting to Standard, with a Proposed `=<difficulty>` extension.
2. REQ-026 lists `+roll <skill>` (start) and `+roll <tag> [<tag>...]` (select) as the identical bare command with no switch distinguishing them — resolved with an explicit precedence rule: `suggested`/`none` keywords first, then tag-selection if the caller already has an open pending roll, otherwise a fresh start. This matters because a naive implementation could misinterpret a second `+roll <skill>` as re-starting rather than continuing the existing conversation.

Also specified (not left ambiguous) how `+roll/mark` resolves player-facing tags to the `gm_submit_selections` API's entry-ID contract (via the same privacy-filtered candidate view the GM already sees, never against the roller's full B&B collection), and where scene-GM authority is checked twice for good reason: once by the command layer for the `+roll/review` no-argument discovery list (since `get_pending_gm_review` is a plain query with no authorization of its own), and once already inside `SoulRollApi` for every operation that touches a specific pending roll (which the command layer must NOT re-check, per CP-09).

Three small read-only query methods were added to `SoulRollApi`'s scope (`get_open_pending_for_selection`, `get_open_pending_rolls`, `get_pending_gm_review`) — pure lookups needed for command-layer disambiguation and discovery, no new authorization rules.

### Phase 5 Review Findings (2026-07-24)

Codex implemented `docs/handoffs/Phase_5_GM_Assisted_Rolls.md` in full and pushed to the `Codex` branch (merge base matched `main`'s tip exactly this time — no staleness issue like Phase 4's). Review found `gm_submit_selections`, scene-GM authorization (`can_review_pending?`), `force_abort_pending`, the narrowed `abort_pending` window, and the dual-status expiry sweep all implemented correctly and matching the handoff precisely, with thorough test coverage for each.

**Codex flagged a real ambiguity in the handoff itself** rather than guessing silently: my instruction that "`select_entries` is unchanged" conflicted with the requirement that GM-assisted rolls limit players to GM-approved optional entries — if `select_entries`'s bulk-`suggested` accept still pulled from the full `system_suggested_entries` (not the GM-filtered `gm_suggested_entries`), the GM's review would be pointless. Codex resolved this correctly for the `suggested`/`none` forms by branching on `pending.gm_assisted`.

**But one path was left open:** the `tags:` selection form still let a player name a specific B&B by tag that *was* a system candidate but that the GM reviewed and did not mark mandatory or optional — it fell through into `manually_identified_entries` and was silently applied, letting the player route around the GM's exclusion. Per the handoff's own §5.6 ("an id the GM doesn't mention is dropped from consideration, not implicitly optional"), this defeats the point of GM review. Fixed directly in `select_entries` after merge: a GM-assisted roll's tag-selection now explicitly rejects any tag matching a reviewed-and-excluded candidate (returns `{ error: }`), while still permitting manual identification of B&Bs the system never proposed as candidates at all — those were never subject to GM review to begin with, so the fix doesn't touch that path. Added three specs: the rejection case, the still-permitted genuinely-new-candidate case, and the still-permitted GM-approved-tag case.

Phase 5 is complete. Phase 6 (Complete MUSH/Web UI Parity) is next — the full command/web-handler layer for every subsystem built so far, including rolls for the first time.

### Phase 5 Handoff: GM-Assisted Rolls (2026-07-24)

Reviewed FINAL §6.4.4 (REQ-029), CI-03/CI-04, and `docs/reference/Permissions.md`'s Scene-GM section before designing. Checked the real AresMUSH `Scene` model (`plugins/scenes/public/scene.rb`) rather than assuming a "GM" concept exists on it — it doesn't; `Scene` has only `owner`/`participants`/`is_participant?`, no dedicated GM field. Resolved this gap as a Claude design decision: scene-GM authority = `Soul.can_review_rolls?(character) && scene.is_participant?(character)` (global GM permission tier, scoped to actual scene presence) — recorded explicitly in the handoff and `Data_Model.md` rather than silently assumed.

Also confirmed the real player-notification mechanism (`Login.notify(char, type, message, reference_id, ...)`, `plugins/login/public/login_api.rb`) for REQ-029's "notify affected participants" on force-abort, rather than inventing a new one.

Extends Phase 4's `SoulRollApi` in place (`docs/handoffs/Phase_5_GM_Assisted_Rolls.md`) rather than adding new files: `start_roll` gains scene-policy resolution and a new `gm_requested:` flag; new `PendingRoll` status `awaiting_gm`; new `get_gm_candidate_view` (privacy-filtered per `gm_reveal_categories`) and `gm_submit_selections` (restricted to the roll's own candidate list — an unmentioned candidate is dropped, not implicitly optional); `resolve_pending` now folds in GM-mandatory entries so they survive `+roll none` (REQ-029); `abort_pending`'s window narrows once the GM has submitted, with a new `force_abort_pending` for staff/scene-GM at any open status. Pending-roll limits (1 standard / 2 GM-assisted, CI-04) are two independent per-player caps, not a shared pool — a design point CI-04's wording doesn't state explicitly but implies by giving them separate numbers.

Handed to Codex following the same pattern that worked for Phase 4: full authorization rules, state-machine transitions, and privacy-filtering logic specified precisely enough that no architectural judgment is required to implement it, since a bug in scene-GM authorization or privacy filtering would be a real security/privacy defect, not just a cosmetic issue.

### Phase 1-3 Command/Web-Handler Layer: Codex Implementation and Review (2026-07-23/24)

Wrote a LlamaCoder-style handoff for the command/web-handler adapter layer covering Phases 1-3 (Sheet, XP, B&B, Culmination, History), then the project owner clarified Codex — not LlamaCoder — was already implementing it against a broader delegation model. Reviewed Codex's push to the `Codex` branch before merging:

**Real bugs found and fixed before merge** (both in Claude's own Phase 3 API work, surfaced by Codex's implementation attempt): `SoulXpApi.get_scene_participants` assumed a nonexistent `Scene#characters`/`Scene#people` collection — real AresMUSH uses `Scene#participants`; fixed. `SoulXpApi.correct` only ever added to available XP despite being documented as able to "reverse a prior award or spend" — added a `direction:` parameter (`"correction"`/`"reversal"`) to cover both cases.

**Design gaps Codex correctly declined to guess at, rather than inventing syntax:** `+soul/framework` correction syntax (target/attribute/value never specified — implemented read-only), `+bnb/progress` vs. `resolve` (the dedicated resolve API requires a `reason` the command syntax doesn't capture — implemented as level-progression only, not silently bypassing the audit requirement), Audit-viewing command surface (mentioned in scope, never given syntax — not implemented). All recorded in `IMPLEMENTATION_CHECKLIST.md` Phase 6.

**Also surfaced, not yet resolved:** a pre-existing `Soul::` vs `AresMUSH::` namespace mismatch between some specs and the actual model/API namespace, and a missing `plugin/spec/spec_helper.rb` test harness (same gap noted independently by Codex in both the Phase 1-3 handoff and its own implementation notes — likely a repository-level setup step never completed, not a code bug).

### Phase 4 In Progress: Dice/Probability Engine (Claude-implemented) + Roll Service Handoff (2026-07-24)

Reviewed FINAL §6.4 and Addendum §§1-2, 6, 8.1, 9 (rolls, dice mechanics, expiry, degrees of success, extraordinary luck) before starting. Implemented `plugin/public/soul_dice_engine.rb` directly rather than delegating it, because getting the probability calculation right requires a subtlety the spec doesn't spell out: a chain segment's post-reroll contribution and whether that segment triggered continuation are **correlated** (both derive from the same pre-reroll dice), so naively treating them as independent would silently misestimate probability for any nonzero Boon/Bane modifier. Derived the correct approach: per-die post-reroll value converges to a uniform distribution over non-band values regardless of the original in-band value (memoryless resampling), which makes an exact recursive convolution over chain segments tractable — implemented with a bounded recursion depth (12 levels; truncated probability mass is on the order of (1/400)^12, unrepresentable in a Float). Chose exact analytical calculation over Monte Carlo specifically because FINAL REQ-030 requires deterministic, reproducible results across MUSH/web/tests/integrations, and Addendum §9 requires the probability to be calculated pre-roll and stored for audit — a randomly-varying estimate would satisfy neither. Validated the implementation against a 200,000-trial Monte Carlo simulation (0.835 analytical vs. 0.8347 empirical at Standard difficulty, no modifier) plus edge-case tests for near-maximal Boon/Bane modifiers (capped the reroll band at 19 of 20 faces — an implementation safety margin, not a spec rule, since a full-range band would make the reroll loop never terminate).

**Found and resolved a genuine spec gap while designing the roll-resolution flow:** Addendum §8.1's degrees-of-success table gives Failure and Catastrophic Failure the identical `margin < -10` condition, unlike every other adjacent pair in the table. Resolved by mirroring the Success/Exceptional Success split (Failure becomes the mirrored 10-point band `-20 <= margin < -10`; Catastrophic Failure becomes `margin < -20`) — documented as an explicit implementation note in the Addendum itself, plus updated `game/config/soul.yml`'s `degrees_of_success` block with the new `failure_min`/`catastrophic_failure_min: -20` keys.

Wrote `docs/handoffs/Phase_4_Roll_Service_and_Models.md` for the remaining Phase 4 work (`Roll`/`PendingRoll` models, `SoulRollApi` orchestration, cron-driven pending-roll expiry sweep) under the new, broader Codex delegation rules — this is conventional CRUD/service work following Phase 1-3's established shape, unlike the dice engine itself.

### Phase 3 Implementation: Boons & Banes, Culminations, Narrative History/Audit (2026-07-23)

Confirmed the B&B catalogue design decision from the Phase 1 doc rebuild (`BnbCatalogueEntry` as a real DB model, unlike Aspects/Skills) was correct by re-checking it against FINAL and DD-02 before writing code: FINAL REQ-017 requires "a unique numeric ID" (implying database auto-assignment, not a config key an admin picks), and `SOUL_Design_Decisions.md` DD-02 (creator-built, protected) explicitly says B&Bs are created via in-game commands, not seeded from config. Inspected the real Achievements plugin (`plugins/achievements/`) as the closest precedent for a per-character granted-record model (config-independent, bespoke per grant) — informed the simpler `Culmination` model, which unlike B&Bs has no shared catalogue at all.

**A significant additional finding, parallel to Phase 1's Lesson 33:** Inklings' own `dispatch_inkling_*` methods (`plugin/inklings.rb`) call `Global.dispatcher.dispatch("inkling:submitted", inkling)`, guarded by `if Global.dispatcher.respond_to?(:dispatch)`. The real `AresMUSH::Dispatcher` class (`engine/aresmush/commands/dispatcher.rb`) has no `dispatch` method at all — only `queue_command`/`queue_event`/`queue_timer`/`queue_action`/`spawn`/`on_command`/`on_event`/`on_web_request`. Every one of those Inklings calls is silently inert; the `respond_to?` guard is always false against real core. This is the same failure shape as `chargen_finalize`: a dispatch-shaped method that reads plausibly but has zero real callers. It also meant this project's own `API_and_Hooks.md` (written before this was caught) had the same invented pattern, plus an entirely separate invented `get_hooks(plugin_symbol, hook_name)` dispatch point that also has zero references anywhere in current core. Both are now flagged in the docs rather than silently propagated into Phase 3's actual code, which uses the real, confirmed mechanism instead: `Global.dispatcher.queue_event SomeEvent.new(...)`, with event classes defined **flat under `AresMUSH::`**, never nested under the plugin's own module (confirmed against `plugins/roles/public/roles_events.rb` — a real plugin-specific event, not a core one, ruling out "maybe only core events are flat").

**Files added:** `plugin/models/bnb_catalogue_entry.rb`, `character_bnb_entry.rb`, `culmination.rb`, `narrative_history_entry.rb`, `soul_audit_entry.rb`; `plugin/public/soul_bnb_api.rb`, `soul_culmination_api.rb`, `soul_narrative_history_api.rb`, `soul_audit_api.rb`, `soul_events.rb`; three spec files. Backfilled Phase 2's `TODO(Phase 3)` marker in `SoulResonanceApi.lock_at_approval`/`.correct` now that `SoulNarrativeHistoryApi`/`SoulAuditApi` exist.

**Explicitly deferred** (see `IMPLEMENTATION_CHECKLIST.md` Phase 3): B&B search/lookup commands (Phase 6), the roll-modifier contribution hook (needs a fresh design in Phase 4/5 now that `get_hooks` is confirmed fake), and firing `SoulXpAwardedEvent`/`SoulSkillAdvancedEvent` from Phase 2's APIs (documented shape exists, not yet wired).

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

### Before Phase 4 Begins

- [x] ~~Finalize exact Ruby class names for services~~ — `SoulFrameworkApi`/`SoulCharacterApi`/`SoulResonanceApi`/`SoulXpApi`/`SoulBnbApi`/`SoulCulminationApi`/`SoulNarrativeHistoryApi`/`SoulAuditApi`/`SoulDiceEngine` all now exist; `SoulRollApi` handed to Codex, not yet implemented
- [ ] Decide B&B catalogue seeding approach: command-based creation with README examples (per DD-02), confirmed still current — `SoulBnbApi.create_catalogue_entry` exists; no seed data has been created
- [ ] Finalize non-canonical command syntax still open per REQ-037/REQ-045 (see `docs/reference/Commands.md` "Proposed" rows — e.g. exact abort-roll syntax)
- [ ] Finalize API contracts between Ruby backend and Ember web portal for each REQ-046 required capability
- [ ] **Design the roll-modifier contribution mechanism against a confirmed dispatch point** — still unresolved; the previously-assumed `get_hooks`/`:soul_roll_modifiers` design has zero basis in real AresMUSH core. Deliberately still out of scope for the Phase 4 roll-service handoff (see `docs/handoffs/Phase_4_Roll_Service_and_Models.md` §1) — B&B modifiers are the only modifier source Phase 4 implements; cross-plugin contribution needs its own design pass once an actual integration needs it.
- [x] ~~Design cron/scheduler approach for weekly catch-up recalculation and weekly XP award~~ — done in Phase 2 (`plugin/events/soul_xp_cron_handler.rb`, real `Cron`/`CronEvent` mechanism); Phase 4's handoff extends the same handler for pending-roll expiry rather than registering a second `CronEvent` handler (the real `Dispatcher` only supports one handler per event name per plugin)
- [x] ~~Re-verify the real `custom_approval.rb` snippet mechanism~~ — done in Phase 2 (`custom-install/custom_approval.snippet.rb`)
- [x] ~~Backfill `SoulResonanceApi.lock_at_approval`'s `TODO(Phase 3)` marker~~ — done in Phase 3; `resonance_correction_log` was kept alongside the new `SoulAuditEntry`/`NarrativeHistoryEntry` writes (fast character-scoped access) rather than migrated away from, since removing it would cost a lookup with no real benefit

### Phase 4 Review Findings (2026-07-24)

Codex implemented `docs/handoffs/Phase_4_Roll_Service_and_Models.md` in full (`Roll`/`PendingRoll` models, `SoulRollApi`, cron expiry sweep via the existing `XpCronHandler`, specs) and pushed to the `Codex` branch. Review found the implementation faithful to the handoff's design in every respect — candidate B&B identification, signed modifier summation, difficulty/margin/degree-of-success calculation, the succeeded-vs-failed extraordinary-probability branch, expiry sweep, cron wiring (extending the existing handler rather than attempting a second `CronEvent` registration) — with one real defect:

**`resolve_pending(pending_roll_id)` had no caller-identity argument.** Codex built against the handoff's original (pre-fix) signature — the branch's merge-base predates the commit that added the `character` parameter, since Codex had already started work before that fix was pushed. Fixed directly after merge: added the `character` parameter, reused the existing `validate_owned_open_pending` helper Codex had already written for `select_entries`/`abort_pending` (rather than duplicating a third ownership-check implementation), updated all spec call sites, and added an explicit ownership-rejection test. No other changes were needed.

Also confirmed during review: `DataType::Float` (used for `Roll#success_probability`) is a real, valid Ohm data type (`engine/aresmush/models/ohm_data_types.rb`, cast `x.to_f`) — not previously used elsewhere in this codebase, but not an invented one either; worth knowing it has the same no-nil-guard behavior as `Integer`/`Decimal`, though it doesn't matter here since `success_probability` is always set at `Roll` creation, never read before that.

**Known pre-existing issue, not introduced by Phase 4:** `plugin/spec/spec_helper.rb` still doesn't exist, so none of this session's specs (Phase 4's included) have actually been executed — only `ruby -c` syntax-checked. This was flagged independently by Codex during both the Phase 1-3 and Phase 4 handoffs; it appears to be a repository-level test-harness setup step (likely requiring the real AresMUSH engine/gems) that was never completed, not a bug in any phase's code.

## Resolved Architecture Questions

These were open in the pre-fabrication era of this project and are now settled by FINAL.md:

- **Character Framework:** Body, Mind, Spirit Aspects; Skills belong to exactly one Aspect by stable key (REQ-008, REQ-009).
- **Resonance:** Chargen-only, R-3 to R3, locks at approval, does not decay or advance later (REQ-012).
- **B&B mechanics:** Two-layer catalogue/instance model with numeric IDs, tags, and configurable levels (REQ-016 through REQ-022).
- **Roll modifiers:** B&B and plugin-contributed modifiers via die rerolls (dice) plus a bounded flat sum (mechanical modifiers), per Addendum §2 and FINAL REQ-030.
- **Catch-up XP:** Accelerated earning only, weekly median-based, capped at the gap (REQ-014, Addendum §8).
- **GM-assisted rolls:** Per-scene configurable policy (Required/Optional/Unavailable), mandatory vs. optional B&B selection (REQ-029).

## Session Notes

### Session: 2026-07-23 (Phase 3 Implementation)

- User asked to re-review all documentation, FINAL, and the Addendum again before starting Phase 3, per the established pattern.
- Re-read FINAL §6.1-§6.3 (REQ-016 through REQ-024) and Addendum §5 (chargen B&B ratio/limits) in full before writing any code.
- Confirmed the B&B catalogue should remain a real DB model (not config-driven like Aspects/Skills) by cross-checking FINAL REQ-017's "unique numeric ID" requirement and DD-02's "created via in-game commands" against the Phase 1 doc rebuild - this was a check, not a redesign, and it held up.
- User clarified mid-implementation that a B&B "type" field with configurable Arcane/Mundane defaults was needed - this was already present as `category`; briefly renamed to `type` per the initial phrasing, then reverted back to `category` once the user confirmed "category is fine."
- Found that Inklings' own custom "event" system (`dispatch_inkling_*` methods) calls a `Global.dispatcher.dispatch` method that doesn't exist on the real `Dispatcher` class - silently inert, the same failure shape as Lesson 33's `chargen_finalize`. Also found this project's own `API_and_Hooks.md`/`Integration_Guide.md` had invented an unverified `get_hooks` dispatch point with the same problem. Implemented the real mechanism (`Global.dispatcher.queue_event`, flat event classes) instead and flagged both docs.
- Implemented Phase 3 models and service APIs: B&B catalogue/instance (`SoulBnbApi`), Culminations (`SoulCulminationApi`), Narrative History and Audit (`SoulNarrativeHistoryApi`, `SoulAuditApi`).
- Backfilled Phase 2's `TODO(Phase 3)` marker in `SoulResonanceApi`.
- Explicitly deferred B&B commands, the roll-modifier hook redesign, and firing the two not-yet-wired XP/Skill events - see `IMPLEMENTATION_CHECKLIST.md` Phase 3.
- **Next:** Phase 4 — Standard Rolls and Pending-Roll Flow (see `docs/spec/IMPLEMENTATION_CHECKLIST.md` Phase 4 and `docs/spec/ROADMAP.md`). Design the roll-modifier contribution mechanism against a confirmed dispatch point before implementing it.

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

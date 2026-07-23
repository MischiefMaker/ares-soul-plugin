# Codex Handoff: Phase 6 Roll Commands/Web Handlers and Audit Command

**Prepared by:** Claude (project architect)
**Date:** 2026-07-24
**Workflow:** Follows the "SOUL Codex Handoff Instructions" in `docs/spec/Implementation_Specification_Addendum.md`.

---

## 1. Scope

Phase 6 is "Complete MUSH/Web UI Parity" across every subsystem. Sheet, B&B, XP, Culmination, and History already have a full command/web-handler layer (Phase 1-3, `plugin/commands/soul_*_cmd.rb` / `plugin/web/soul_*_web_handler.rb`). The only subsystem with **zero** command/web surface is Rolls (Phases 4-5's `SoulRollApi`) — this handoff closes that gap, plus one small pre-existing hole: staff audit-log viewing was never given a command (noted since the Phase 1-3 handoff's implementation notes).

**In scope:**
- New `SoulRollCmd` / `SoulRollWebHandler` covering the full roll command family (start, GM-request, select, abort, force-abort, pending list, history, GM review, GM mark).
- Three small read-only query additions to `SoulRollApi` (§4) needed by the command layer — no new authorization logic, no new business rules.
- Extending the existing `SoulStaffCmd` / `SoulStaffWebHandler` with an `"audit"` switch (not a new file — same pattern as the existing `"framework"`/`"resonance"`/`"reload"` switches).
- Registering everything in `plugin/soul.rb`'s `get_cmd_handler`/`get_web_request_handler`.
- Locale strings, a new `plugin/help/en/soul_rolls.md`, and specs.

**Explicitly out of scope:**
- Any change to `SoulRollApi`'s existing authorization/state-machine logic (`start_roll`, `select_entries`, `resolve_pending`, `abort_pending`, `force_abort_pending`, `gm_submit_selections`, `get_gm_candidate_view`, `expire_stale_pending_rolls`) — call these, don't modify them.
- Any change to `SoulDiceEngine` — locked dependency, unchanged since Phase 4.
- Roll-modifier contribution from other plugins — still no confirmed dispatch point.
- Ember/web-portal components for rolls — this handoff covers the Ruby web *handler* (the request/response contract), not the frontend component. Follow the existing `web-portal/app/components/soul/*` files from Phase 1-3 as the pattern once this lands, in a later pass.

## 2. Relevant Specification Sections

- `docs/reference/Commands.md`'s "Rolls" section and the `+soul/audit` row — **read the current version**, not memory of an earlier draft. It was just updated with the exact syntax this handoff implements, including two design decisions Claude made to close real gaps (§5.1, §5.2 below).
- `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` REQ-026 (canonical roll commands), CI-03 (conversational roll flow), CI-04 (pending-roll limits), CI-05 (short, guessable commands), CI-08 (`manage soul` help topic naming).
- `docs/architecture/API_and_Hooks.md`'s Roll Initiation/Completion section for the full `SoulRollApi` surface this command layer calls.
- `docs/reference/Permissions.md`'s Scene-GM section and `docs/handoffs/Phase_5_GM_Assisted_Rolls.md` §5.1 for scene-GM authorization (already implemented in `SoulRollApi.can_review_pending?` — the command layer doesn't re-derive this, see §5.3).

## 3. Repository Files Expected to Change

```
plugin/commands/soul_roll_cmd.rb          # new
plugin/web/soul_roll_web_handler.rb       # new
plugin/commands/soul_staff_cmd.rb         # modify - add "audit" switch
plugin/web/soul_staff_web_handler.rb      # modify - add "soulAudit" case
plugin/public/soul_roll_api.rb            # modify - three new query methods only (§4)
plugin/soul.rb                            # modify - register new command/web dispatch
plugin/locales/locale_en.yml              # extend - new soul.* roll/audit strings
plugin/help/en/soul_rolls.md              # new
plugin/spec/soul_roll_cmd_spec.rb         # new
plugin/spec/soul_roll_web_handler_spec.rb # new
plugin/spec/soul_roll_api_spec.rb         # extend - cover the three new query methods
plugin/spec/soul_staff_cmd_spec.rb        # extend - cover the new "audit" switch
plugin/spec/soul_staff_web_handler_spec.rb # extend - cover "soulAudit"
```

## 4. Existing Services/APIs That Must Be Used

Every method below already exists and is fully tested (Phases 4-5) except the three marked **NEW** — those are the only additions this handoff makes to `SoulRollApi` itself, and they are pure read-only queries with no new authorization rules.

```ruby
SoulRollApi.get_candidate_bnbs(character, skill_key)
SoulRollApi.start_roll(character, skill_key, context: {}, gm_requested: false)
SoulRollApi.get_gm_candidate_view(pending_roll_id, gm)
SoulRollApi.gm_submit_selections(pending_roll_id, gm, mandatory_ids: [], optional_ids: [])
SoulRollApi.select_entries(pending_roll_id, character, tags: [], suggested: false, none: false)
SoulRollApi.resolve_pending(pending_roll_id, character)
SoulRollApi.abort_pending(pending_roll_id, actor, reason:)
SoulRollApi.force_abort_pending(pending_roll_id, actor, reason:)
SoulRollApi.get_roll_history(character, limit: 50)

# NEW - single most-recent pending roll in "awaiting_selection" status for this
# character, or nil. Used by the bare +roll command to decide whether
# "suggested"/"none"/a bare tag list means "select on my open roll" vs. "start
# a new roll" (see §6). Read-only query, no authorization logic of its own -
# the caller (SoulRollCmd) already knows it's operating as/for this character.
SoulRollApi.get_open_pending_for_selection(character)
  # => PendingRoll or nil

# NEW - every open pending roll (both "awaiting_gm" and "awaiting_selection")
# belonging to this character, for +roll/pending. Read-only query.
SoulRollApi.get_open_pending_rolls(character)
  # => [PendingRoll, ...]

# NEW - every "awaiting_gm" pending roll scoped to this scene, for +roll/review
# with no argument (GM discovery of what's waiting on them). Read-only query -
# does NOT itself check scene-GM authority; the command layer must still call
# SoulRollApi.get_gm_candidate_view (which DOES check authority) before showing
# any candidate detail. Listing "a roll exists in this scene, roller X, skill Y"
# is not privacy-sensitive on its own - everyone in the scene already knows who's
# rolling.
SoulRollApi.get_pending_gm_review(scene)
  # => [PendingRoll, ...]
```

```ruby
Soul.can_play?(character)
Soul.can_manage_soul?(character)
Soul.can_review_rolls?(character)
SoulAuditApi.get_audit(character, viewer, limit: 50)   # existing, unchanged - staff-only even for the subject
SoulFrameworkApi.get_skill(skill_key)                    # for resolving a skill name/key to display info if needed
```

## 5. Constraints and Invariants That May Not Change

### 5.1 Scene-GM authorization is already enforced inside `SoulRollApi` — don't duplicate it

`get_gm_candidate_view` and `gm_submit_selections` and `force_abort_pending` already call `SoulRollApi.can_review_pending?` internally and return `{ error: }` for an unauthorized caller. The command layer's job is to call these methods and surface their `{ error: }`/`{ success: }` result — it must **not** re-implement the `Soul.can_review_rolls?(enactor) && scene.is_participant?(enactor)` check itself as a pre-condition, since that would be redundant logic living in two places (violates CP-09, One Rule One Home). The one exception is `+roll/review` with **no** argument (the discovery list) — see §5.4.

### 5.2 Difficulty defaults to "standard"; the `=<difficulty>` extension is optional

Per `Commands.md`'s newly-added note: FINAL's canonical `+roll <skill>` has no difficulty argument at all. Default to `"standard"` when the player doesn't specify one. `+roll <skill>=<difficulty>` and `+roll/gm <skill>=<difficulty>` are the Proposed extension for choosing an explicit tier — parse the difficulty key case-sensitively as given (don't downcase/normalize it yourself; `SoulRollApi.start_roll` → `resolve_difficulty` already validates it against `rolls.difficulties` and returns a clear `{ error: "Unknown difficulty: ..." }` for a bad key — let that error surface rather than pre-validating in the command).

### 5.3 The bare `+roll` command's argument disambiguation (exact algorithm)

`+roll` and `+roll <args>` share one command class with `cmd.switch == nil`. There is no separate switch distinguishing "start a roll" from "select on my existing roll" — REQ-026 lists both as the same bare `+roll` form, disambiguated by the caller's current state. Implement exactly this precedence, checked in order:

1. Take `raw = cmd.args.to_s.strip`.
2. If `raw` is blank (bare `+roll`, no argument): show the enactor's current open pending roll status (via `get_open_pending_for_selection` first, else the most recent `get_open_pending_rolls` entry, else "no open pending roll" - display only, no state change).
3. Else if `raw.casecmp("suggested").zero?`: this is a **selection**, not a skill name. Require `get_open_pending_for_selection(enactor)` to return a roll (error "You have no pending roll awaiting your selection." if not), then call `SoulRollApi.select_entries(pending.id, enactor, suggested: true)`.
4. Else if `raw.casecmp("none").zero?`: same as above but `none: true`.
5. Else if `get_open_pending_for_selection(enactor)` returns a roll (the character already has one awaiting selection): treat `raw` as a **tag list** — split on whitespace, call `select_entries(pending.id, enactor, tags: split_tags)`. This takes precedence over skill-starting even if `raw` happens to also look like a valid skill key, per REQ-026's design (once a roll is pending, `+roll <anything>` continues that conversation, matching CI-03's "the player remains the roller" framing — a second `+roll <skill>` while one is already open should not be interpretable as starting a second one when the standard limit is 1 anyway).
6. Else (no open pending roll awaiting selection): this is a **start**. Split `raw` on `=` at most once: `skill_part, difficulty_part = raw.split("=", 2)`. Call `SoulRollApi.start_roll(enactor, skill_part, context: { difficulty: difficulty_part || "standard" }, gm_requested: false)`.

`+roll/gm <skill>[=<difficulty>]` (switch `"gm"`) only ever means **start** (§5.2's extension applies identically) — it does not participate in the selection-disambiguation above, since REQ-026 doesn't describe a "+roll/gm suggested" form and none is needed (once a GM-assisted roll exists, the player continues it via the same bare `+roll suggested`/`+roll none`/`+roll <tag>` forms as any other pending roll — `select_entries` already branches on `pending.gm_assisted` internally, per Phase 5). Parse `+roll/gm`'s argument the same way as step 6 (skill/difficulty split), then call `start_roll(enactor, skill, context: { difficulty: ... }, gm_requested: true)`.

### 5.4 `+roll/review` has two forms — only one needs scene-GM authority checked by the command itself

- `+roll/review` (no argument): lists open (`"awaiting_gm"`) pending rolls in the enactor's current scene (`enactor_room && enactor_room.scene`, same pattern as `soul_bnb_cmd.rb`'s `+bnb/here`). This is the one place the command layer itself gates on scene-GM authority (`Soul.can_manage_soul?(enactor) || (Soul.can_review_rolls?(enactor) && scene && scene.is_participant?(enactor))`) **before** calling `get_pending_gm_review(scene)`, since that query itself doesn't check authority (§4's note). If there's no active scene, return "No active scene." rather than an authority error.
- `+roll/review <roll id>`: calls `SoulRollApi.get_gm_candidate_view(roll_id, enactor)` directly — that method already checks authority internally; don't duplicate it (§5.1).

### 5.5 `+roll/mark` resolves tags to entry IDs via the candidate view — never accepts raw IDs from the player

`gm_submit_selections` takes `mandatory_ids:`/`optional_ids:` (entry IDs), but the command's syntax takes tags (`+roll/mark <roll id>=<mandatory tags>/<optional tags>`) for CI-05 readability. Resolve tags to IDs by first calling `get_gm_candidate_view(roll_id, enactor)` (which both authorizes the GM and returns each candidate's `id`/`tag`), then matching each requested tag case-insensitively against that returned candidate list only — **not** against the roller's full B&B collection (a GM should only ever be able to mark something that's actually a candidate for this specific roll, matching `gm_submit_selections`'s own restriction to `system_suggested_entries`, which the candidate view already reflects). An unmatched tag is a command-level error ("No candidate tagged '...' on this roll.") before `gm_submit_selections` is ever called — don't let an invalid tag silently resolve to nothing and submit an incomplete list.

Split syntax: `left, right = cmd.args.split("=", 2)`, then `mandatory_str, optional_str = right.to_s.split("/", 2)`. Either half MAY be empty (e.g. `+roll/mark 12=/approved` marks nothing mandatory, `approved` optional) — an empty string splits to an empty tag list, not an error.

### 5.6 `+roll/abort` and `+roll/forceabort` both require a reason

`abort_pending`/`force_abort_pending` both return `{ error: }` for a blank reason already — the command doesn't need to pre-validate this, but `required_args` (the `CommandHandler` convention used throughout this codebase) should still list the reason as required so the player gets an immediate, actionable "usage" message rather than a round-trip to the API for something this obviously missing (CI-07, Actionable Errors).

### 5.7 Audit command mirrors the existing History command's shape exactly

`+soul/audit <character>` is staff-only, unlike `+soul/history` (which allows self-view). Add it to `SoulStaffCmd` (not a new command class) as a new `case cmd.switch` branch, following `"framework"`'s existing no-argument-parsing shape but requiring a character argument like `"resonance"` does. `SoulAuditApi.get_audit(character, viewer, limit: 50)` already enforces `Soul.can_manage_soul?(viewer)` internally and returns `[]` for anyone else — but `SoulStaffCmd`'s own `check_permission` already gates the entire command on `Soul.can_manage_soul?`, so this is consistent, not redundant with a *different* rule (it's the same manage_soul gate `SoulStaffCmd` already applies to every other switch).

### 5.8 Conventions unchanged from Phase 1-3's command layer

Commands `include CommandHandler`; web handlers are plain classes with `handle(request)` calling `Website.check_login(request)`; every user-facing string goes in `plugin/locales/locale_en.yml` under `soul:`; boolean-like values are `"true"`/`"false"` strings; `Global.read_config` is never memoized; API results are always `{ error: }` or `{ success: true, ... }` / bare data.

## 6. Method Signatures / Command Surface to Implement

```ruby
# plugin/public/soul_roll_api.rb - three additions, alongside the existing
# get_roll_history/expire_stale_pending_rolls methods:
SoulRollApi.get_open_pending_for_selection(character)
SoulRollApi.get_open_pending_rolls(character)
SoulRollApi.get_pending_gm_review(scene)
```

```
+roll                                        -> show status of own open pending roll, if any
+roll <skill>                                -> start_roll(..., context: {difficulty: "standard"})
+roll <skill>=<difficulty>                   -> start_roll(..., context: {difficulty: <difficulty>})
+roll/gm <skill>[=<difficulty>]              -> start_roll(..., gm_requested: true)
+roll suggested                              -> select_entries(..., suggested: true) on own open roll
+roll none                                   -> select_entries(..., none: true) on own open roll
+roll <tag> [<tag> ...]                      -> select_entries(..., tags: [...]) on own open roll
+roll/abort <roll id>=<reason>               -> abort_pending
+roll/forceabort <roll id>=<reason>          -> force_abort_pending
+roll/pending                                -> get_open_pending_rolls(enactor)
+roll/history                                -> get_roll_history(enactor)
+roll/review                                 -> get_pending_gm_review(scene) [command-gated, §5.4]
+roll/review <roll id>                       -> get_gm_candidate_view(roll_id, enactor) [API-gated]
+roll/mark <roll id>=<mandatory>/<optional>  -> tag resolution (§5.5) then gm_submit_selections

+soul/audit <character>                      -> SoulStaffCmd new switch, SoulAuditApi.get_audit
```

Web handler (`soulRoll`, `soulRollStart`, `soulRollGm`, `soulRollSelect`, `soulRollAbort`, `soulRollForceAbort`, `soulRollPending`, `soulRollHistory`, `soulRollReview`, `soulRollMark`, plus `soulAudit` on the existing staff handler) should expose the same operations 1:1 — follow `soul_xp_web_handler.rb`'s existing pattern of one `request.cmd` value per distinct operation, each delegating to the identical `SoulRollApi` call the MUSH command uses, per CP-05 parity. Resolution of `pending_roll_id`/character/scene from `request.args` follows the same pattern as the existing web handlers (`Character.find_one_by_name`, `Scene[...]`, etc.).

## 7. Acceptance Criteria

- Every row in `Commands.md`'s Rolls section and the new `+soul/audit` row has a working MUSH command and an equivalent web handler operation.
- `+roll <skill>` with no existing pending roll starts one at Standard difficulty; `+roll <skill>=<difficulty>` overrides it; an invalid difficulty key surfaces `SoulRollApi`'s own error, not a new one.
- Once a pending roll is `"awaiting_selection"`, `+roll <anything-that-isn't-suggested/none>` is treated as tag selection, never re-interpreted as starting a second roll.
- `+roll/review` (no arg) requires scene-GM authority checked by the command; `+roll/review <id>` relies entirely on `get_gm_candidate_view`'s own authorization (no duplicate check in the command).
- `+roll/mark` rejects an unrecognized tag before calling `gm_submit_selections`, and correctly handles an empty mandatory or optional half.
- `+roll/abort`/`+roll/forceabort` without a reason fail via `required_args` with an actionable usage message, not a bare API error round-trip.
- `+soul/audit <character>` is unreachable by a non-`manage_soul` caller, including the subject character viewing their own audit log (unlike `+soul/history`).
- No new authorization logic is duplicated between the command layer and `SoulRollApi` — verified by inspection, not just tests (§5.1).

## 8. Testing Requirements

- `plugin/spec/soul_roll_cmd_spec.rb`: cover every command form in §6, including the disambiguation precedence in §5.3 (a bare `+roll <word>` that would otherwise look like a skill name but resolves as tag-selection because a pending roll is open), the `+roll/mark` tag-resolution success/failure paths, and the `+roll/review` no-arg scene-authority gate.
- `plugin/spec/soul_roll_web_handler_spec.rb`: authenticated success, unauthenticated rejection, and permission-denied paths for each `request.cmd` value.
- `plugin/spec/soul_roll_api_spec.rb`: extend with specs for the three new query methods (empty results, correct filtering by character/scene/status).
- `plugin/spec/soul_staff_cmd_spec.rb` / `soul_staff_web_handler_spec.rb`: extend with the new `"audit"` switch, asserting the subject character themselves cannot view their own audit log even with `manage_soul` absent.
- Run `ruby -c` on every new/modified file; note (as every prior phase's implementation notes have) whether `plugin/spec/spec_helper.rb`'s continued absence still prevents actually executing the suite.

## 9. Existing Repository Conventions Relevant to This Task

- `plugin/commands/soul_xp_cmd.rb` and `soul_bnb_cmd.rb` for switch-based command routing, `ArgParser` usage, and the `enactor_room && enactor_room.scene` pattern for scene-scoped commands.
- `plugin/commands/soul_staff_cmd.rb` for the exact shape to extend with `"audit"`.
- `plugin/web/soul_xp_web_handler.rb` for the web-handler-to-API delegation pattern and `GameApi` response shape.
- `plugin/help/en/soul_bnb.md` as the template for the new `soul_rolls.md` (YAML frontmatter `title:`, no `admin/` split).

---

**Known exclusion reminder:** if the §5.3 disambiguation algorithm, the §5.5 tag-resolution approach, or the §5.4 scene-authority split between command-layer and API-layer checks proves awkward once you're inside the code, stop and report it — these are Claude's explicit resolutions of real gaps in FINAL's canonical syntax (no difficulty argument, no stated selection/start disambiguation rule), not implementation details open to reinterpretation.

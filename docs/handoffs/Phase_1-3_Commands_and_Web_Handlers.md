# LlamaCoder Handoff: Commands & Web Handlers for Phases 1-3

**Prepared by:** Claude (project architect)
**Date:** 2026-07-23
**Workflow:** This handoff follows the "SOUL LlamaCoder Handoff Instructions" in `docs/spec/Implementation_Specification_Addendum.md`. LlamaCoder implements; Claude reviews every change before acceptance.

---

## 1. Scope

Implement the **command and web-handler adapter layer** for the SOUL functionality already built in Phases 1-3: Sheet display, XP award/spend, Boons & Banes, Culminations, and Narrative History/Audit viewing.

All business logic, validation, permission rules, and data models for this scope **already exist and are unit-tested**. This task is thin-adapter work only:

- MUSH commands parse arguments, call an existing `public/*_api.rb` method, and format the result as text via localization strings.
- Web handlers parse `request.args`, call the same API methods, and return plain hashes for `GameApi`.
- Ember components bind to those web handlers per the existing `GameApi` contract.

**Explicitly out of scope:**

- Rolls (`+roll`, `+roll/gm`, `+roll/abort`, etc.) and anything roll-related. Phase 4 (the dice engine and pending-roll flow) has not been built yet, and the roll-modifier hook mechanism still needs a fresh design against confirmed AresMUSH source (see §5 below). Do not create `SoulRollCmd`, `SoulRollApi`, or any roll web handler in this pass.
- Any change to `plugin/public/*_api.rb`, `plugin/models/*.rb`, or `game/config/soul.yml` beyond what's listed in §3. If an existing API's signature seems inconvenient for a command, **stop and flag it** — do not change the API to suit the command.
- Inklings/Grimoire integration hooks (Phase 7).

## 2. Relevant Specification Sections

- `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` — CP-02 (MUSH-first), CP-05 (MUSH/web parity), CI-02 (one-screen Sheet), CI-05 (short, guessable commands), CI-08 (`manage soul` help topic naming), REQ-002 (server-side permission re-checks), REQ-005 (permission tiers/privacy), REQ-015 (XP commands), REQ-021 (two-step destructive confirmation), REQ-022 (B&B lookup commands), REQ-023 (Culmination proposal ownership), REQ-026 (roll commands — **not in this handoff**, listed only so you don't accidentally implement it), REQ-032/CP-05 (web parity), REQ-036 (no direct DB manipulation for staff), REQ-037 (command syntax needing owner approval).
- `docs/reference/Commands.md` — the full command table this handoff implements (see §6 for exactly which rows).
- `docs/reference/Permissions.md` — permission tiers, `Soul.can_play?`/`Soul.can_manage_soul?`/`Soul.can_review_rolls?`, privacy model.
- `docs/architecture/API_and_Hooks.md` — the API method signatures this layer must call (reproduced in §4).
- `docs/architecture/Data_Model.md` — field names/shapes for anything a command or web handler formats for display.
- `docs/development/Coding_Standards.md` — file layout, naming conventions, error-handling contract, localization pattern.
- `ARES_PLUGIN_DEVELOPMENT_GUIDE.md` (linked from `CLAUDE.md`) — GameApi contract, component patterns, installation conventions.

## 3. Files Expected to Be Created or Modified

```
plugin/commands/
  soul_sheet_cmd.rb              # +soul, +soul <character>
  soul_bnb_cmd.rb                # +bnb, +bnb/here, +bnb/search, +bnb/catalogue,
                                  # +bnb/create, +bnb/grant, +bnb/progress, +bnb/delete
  soul_xp_cmd.rb                 # +xp, +xp/spend, +xp/history, +xp/award,
                                  # +xp/award/catchup, +xp/scene, +xp/scene/catchup,
                                  # +xp/correct
  soul_culmination_cmd.rb        # +culmination, +culmination/propose, +culmination/approve
  soul_history_cmd.rb            # +soul/history, +soul/history <character>
  soul_staff_cmd.rb              # +soul/framework, +soul/resonance, +soul/reload

plugin/web/
  soul_sheet_web_handler.rb
  soul_bnb_web_handler.rb
  soul_xp_web_handler.rb
  soul_culmination_web_handler.rb
  soul_history_web_handler.rb
  soul_staff_web_handler.rb

plugin/soul.rb                   # register new cmd/web handlers in
                                  # get_cmd_handler / get_web_request_handler
                                  # (DO NOT touch get_event_handler registrations
                                  # already present for Phase 3 events)

plugin/locales/locale_en.yml      # add soul.commands.* help/desc strings and any
                                  # new user-facing message strings this layer needs
                                  # (extend the existing file — do not replace it)

plugin/help/en/soul_commands.md   # help soul_commands
plugin/help/en/soul_bnb.md        # help soul_bnb
plugin/help/en/manage_soul.md     # extend existing file — CI-08 naming already correct

plugin/spec/soul_sheet_cmd_spec.rb
plugin/spec/soul_bnb_cmd_spec.rb
plugin/spec/soul_xp_cmd_spec.rb
plugin/spec/soul_culmination_cmd_spec.rb
plugin/spec/soul_history_cmd_spec.rb
plugin/spec/soul_staff_cmd_spec.rb
plugin/spec/soul_*_web_handler_spec.rb   # one per web handler above

web-portal/app/components/soul/           # Ember components for sheet/bnb/xp/culmination/history tabs
web-portal/app/templates/components/soul/ # matching templates
```

Do not create a `plugin/hooks/` directory or any file under it — no lifecycle hook is part of this scope.

## 4. Existing Services/APIs That Must Be Used

These already exist, are fully implemented, and are unit-tested. **Call them; do not reimplement their logic in a command or handler.**

### Framework (read-only catalogue)
```ruby
SoulFrameworkApi.get_aspects                       # => [{key:, name:, description:, order:}, ...]
SoulFrameworkApi.get_aspect(aspect_key)             # => hash or nil
SoulFrameworkApi.get_skills(aspect_key: nil)        # => [{key:, name:, aspect_key:, order:}, ...]
SoulFrameworkApi.get_skill(skill_key)               # => hash or nil
SoulFrameworkApi.skill_min_rating / skill_max_rating
```

### Character Ratings
```ruby
SoulCharacterApi.get_skill_rating(character, skill_key)
SoulCharacterApi.get_aspect_rating(character, aspect_key)
SoulCharacterApi.get_effective_base(character, skill_key)
SoulCharacterApi.set_skill_rating(character, skill_key, rating, enactor)   # staff-only (+soul/framework)
SoulCharacterApi.set_aspect_rating(character, aspect_key, rating, enactor) # staff-only (+soul/framework)
```

### Resonance
```ruby
SoulResonanceApi.get_resonance(character)           # => -3..3, or nil
SoulResonanceApi.chargen_allowance(resonance)
SoulResonanceApi.locked?(character)
SoulResonanceApi.correct(character, new_value, actor:, reason:)   # +soul/resonance (staff)
```

### XP
```ruby
SoulXpApi.award(character, amount, source:, idempotency_key: nil, apply_catchup: true)
  # => { success: true, awarded:, base_award:, catchup_portion: } or { error: }
SoulXpApi.calculate_cost(character, skill_key, target_rating)
SoulXpApi.spend(character, skill_key, amount, enactor)
  # => { error: } or { success: true, new_rating:, cost:, xp_remaining: }
SoulXpApi.get_available_xp(character)
SoulXpApi.get_lifetime_earned_xp(character)
SoulXpApi.get_lifetime_spent_xp(character)
SoulXpApi.get_catchup_xp_earned(character)
SoulXpApi.get_history(character, limit: 50)
```

**⚠️ Blocking gap:** There is no existing `SoulXpApi.correct` method — `+xp/correct` (Proposed) cannot be implemented until it exists. See §9 (Known Gaps) below.

### Boons & Banes
```ruby
SoulBnbApi.create_catalogue_entry(name:, description:, kind:, tag:, enactor:, category: nil,
                                   epic_modifier: nil, chargen_available: true,
                                   flag_for_review: false, modifier_eligible: false,
                                   skill_associations: [])
SoulBnbApi.get_catalogue(kind: nil, category: nil, active_only: true)
SoulBnbApi.get_catalogue_entry(id_or_tag)           # numeric ID or tag, case-insensitive
SoulBnbApi.search(query)
SoulBnbApi.get_character_entries(character)          # owner/authorized-staff view
SoulBnbApi.get_character_entry_public(character, id) # public-safe view (no explanation/GM notes)
SoulBnbApi.grant(character, catalogue_ref, level_state:, source:, explanation: nil, enactor: nil)
SoulBnbApi.progress(entry_id, new_level_state, source:, explanation: nil, enactor: nil)
SoulBnbApi.resolve(entry_id, reason:, enactor:)
SoulBnbApi.restore(entry_id, enactor:)
SoulBnbApi.delete(entry_id, enactor:, confirmations:, reason:)   # requires confirmations: 2
```

### Culminations
```ruby
SoulCulminationApi.propose(character, title:, description:, source:, enactor: nil)
SoulCulminationApi.approve(culmination_id, enactor)
SoulCulminationApi.deny(culmination_id, enactor, reason:)
SoulCulminationApi.revoke(culmination_id, enactor, reason:)
SoulCulminationApi.correct(culmination_id, enactor, reason:, title: nil, description: nil)
SoulCulminationApi.get_culminations(character, status: nil)
```

### History / Audit
```ruby
SoulNarrativeHistoryApi.get_history(character, viewer, limit: 50)   # owner or Soul.can_manage_soul?
SoulAuditApi.get_audit(character, viewer, limit: 50)                # staff-only, even the subject character
```

### Permission Checks
```ruby
Soul.can_play?(enactor)
Soul.can_manage_soul?(enactor)
Soul.can_review_rolls?(enactor)   # exists for Phase 4 use; not needed for this scope's commands
```

## 5. Constraints and Invariants That May Not Change

These are hard-won, source-verified conventions from this session. Violating them reintroduces bugs that were already found and fixed once.

1. **Dispatch registration.** `AresMUSH::Dispatcher` only has three real registration points: `get_cmd_handler`, `get_event_handler`, `get_web_request_handler` (all defined in `plugin/soul.rb`). There is **no** `get_hooks` method anywhere in real AresMUSH core — do not add one, and do not add any lifecycle "hook" dispatch of your own invention for this scope.
2. **Commands use `include CommandHandler`**, not subclassing. Structure: `handle`, `parse_args`, `check_*` predicate methods (run alphabetically by AresMUSH's own convention — name them so the desired order results), `required_args`. Permission failures return a message string from a `check_*` method; do not hand-roll permission branching inside `handle`.
3. **Web handlers are plain classes** with a single `handle(request)` method. Use `request.args`, `request.enactor`, `request.cmd`. Call `AresMUSH::Website.check_login(request)` where a login is required. Delegate to the same `public/*_api.rb` methods the commands use — never duplicate business logic between the MUSH command and the web handler for the same operation.
4. **Never trust client-supplied IDs or permissions.** Per REQ-002, every web handler and command must re-derive the acting character from the authenticated session/enactor and re-check permissions server-side, even though the API methods themselves also re-check (defense in depth, not redundant).
5. **API contract:** every `public/*_api.rb` method already returns a hash on both paths — `{ error: "..." }` on failure, `{ success: true, ... }` (or a bare data hash for pure reads) on success. Commands/handlers must check `result[:error]` first, always. Do not add new failure modes (e.g., raising exceptions) to how commands consume these APIs.
6. **Boolean-like fields are plain `"true"`/`"false"` strings**, compared with `==`, never treated as Ruby truthy/falsy directly and never cast through `DataType::Boolean` (its cast turns even the string `"false"` truthy). This matters when formatting `chargen_available`, `resolved`, `active`, etc. for display.
7. **Events are already wired** for B&B transitions and Culmination approval (`SoulBnbTransitionedEvent`, `SoulCulminationApprovedEvent`, fired via `Global.dispatcher.queue_event` in the existing API methods). Commands/handlers must **not** fire these events themselves — calling the API method is sufficient, the event fires inside it.
8. **Localization:** every user-facing string goes in `plugin/locales/locale_en.yml` under the `soul:` namespace, referenced via `t('soul.some_key', var: value)`. `t()` only resolves inside `CommandHandler`-mixed-in classes; web handlers need their own small text lookup or must return raw data and let the Ember layer localize (prefer the latter — keep web handlers thin).
9. **Help files** live in a single flat `plugin/help/en/*.md` directory (no `admin/` subdirectory) with YAML frontmatter `title:` required. Admin-only topics are marked with a "Permission Required" blockquote in the body, not by file location. The staff help topic must be named exactly `manage soul` (CI-08) — this file (`manage_soul.md`) already exists from Phase 1; extend it, don't rename it.
10. **Two-step destructive confirmation (REQ-021):** `+bnb/delete` must require the caller to pass `confirmations: 2` through to `SoulBnbApi.delete` — implement this as the command prompting for and counting two explicit confirmations (e.g., requiring the command to be repeated, or a `/confirm` sub-argument), not a single y/n prompt.
11. **Do not implement the "Providing Roll Modifiers" pattern or any `get_hooks(...)` call** — see `docs/architecture/API_and_Hooks.md`'s "Hooks" section, which documents this as an unverified/fake mechanism from an earlier draft. If any command in this scope seems to need a roll-modifier contribution point, stop — that's out of scope (Phase 4/5).
12. **Config reads are always fresh** — call `Global.read_config("soul", ...)` at the point of use; never memoize in a constant or instance variable. This is what makes `+soul/reload` meaningful (it doesn't need to do anything beyond confirming to staff that config is already live-read).
13. **Canonical command syntax below is locked** by FINAL and SHALL NOT be renamed. Proposed syntax (also below) is this project's own draft and may still change during review — implement it as specified here, but do not treat "Proposed" as license to invent a different syntax than what's listed.

## 6. Command Surface to Implement

Reproduced from `docs/reference/Commands.md`. **Status** column: Canonical = exact syntax locked by FINAL, SHALL NOT be renamed. Proposed = drafted for this project, not yet FINAL-locked, but this is the syntax to implement pending owner review.

### Sheet
| Command | Status | Purpose | Permission |
|---|---|---|---|
| `+soul` | Canonical (CI-02) | Display your SOUL Sheet: Aspects/Skills, condensed B&B summaries, XP, Resonance | `play` |
| `+soul <character>` | Proposed | View another character's authorized SOUL Sheet (staff, or scene-GM per reveal policy) | staff/gm |

The default Sheet must fit roughly one MUSH screen (CI-02).

### Boons & Banes
| Command | Status | Purpose | Permission |
|---|---|---|---|
| `+bnb <id>` | Canonical (REQ-022) | Show catalogue description; if owned, also show the character-specific explanation | `play` |
| `+bnb/here <tag>` | Canonical (REQ-022) | Minimal scene-scoped lookup limited to involved players and permitted data | `play` |
| `+bnb/search <tag>` | Canonical (REQ-022) | Staff/admin global search; may support detail/full modes | `manage_soul` |
| `+bnb/catalogue` | Proposed | Browse the full public catalogue | `play` |
| `+bnb/create <name>=<description>` | Proposed | Create a new catalogue entry (category, level defaults, chargen flags via follow-up prompts) | `manage_soul` |
| `+bnb/grant <character>/<catalogue id or tag>=<explanation>` | Proposed | Grant a character entry (post-chargen, non-XP) | `manage_soul` |
| `+bnb/progress <character>/<entry id>=<new level>` | Proposed | Progress or resolve/negate an existing character entry | `manage_soul` |
| `+bnb/delete <entry id>` | Proposed | Two-confirmation destructive delete (REQ-021) | `manage_soul` |

Name collisions must return matching names, IDs, and tags for disambiguation (GL-10).

### XP
| Command | Status | Purpose | Permission |
|---|---|---|---|
| `+xp` | Proposed | View your `xp_available`, `xp_earned`, `xp_spent`, `catchup_xp_earned` | `play` |
| `+xp/spend <skill>=<amount>` | Proposed | Spend XP to advance a Skill (cost shown before commitment, REQ-015) | `play` |
| `+xp/history` | Proposed | View your XP ledger | `play` |
| `+xp/award <character>=<amount>/<reason>` | Canonical (REQ-015) | Grant the raw amount to one character; no catch-up | `manage_soul` |
| `+xp/award/catchup <character>=<amount>/<reason>` | Canonical (REQ-015) | Grant to one character, applying configured catch-up | `manage_soul` |
| `+xp/scene <amount>/<reason>` | Canonical (REQ-015) | Award to approved participants of the current scene; no catch-up | `manage_soul` |
| `+xp/scene <scene id>=<amount>/<reason>` | Canonical (REQ-015) | Award to approved participants of a named scene; no catch-up | `manage_soul` |
| `+xp/scene/catchup <amount>/<reason>` | Canonical (REQ-015) | Scene award (current scene) with catch-up | `manage_soul` |
| `+xp/scene/catchup <scene id>=<amount>/<reason>` | Canonical (REQ-015) | Scene award (named scene) with catch-up | `manage_soul` |
| `+xp/correct <character>=<amount>/<reason>` | Proposed | Correct/reverse a prior award or spend, preserving the original ledger entry | `manage_soul` |

Scene-targeted awards should preview recipients (via `Chargen.approved_chars` scoped to the scene) and may require confirmation before applying.

### Culminations
| Command | Status | Purpose | Permission |
|---|---|---|---|
| `+culmination <character>` | Proposed | View a character's Culminations | `play` (own) / staff (others) |
| `+culmination/propose <character>=<title>/<description>` | Proposed | Propose a Culmination for staff review | `manage_soul` (or approved Inkling outcome — N/A this scope) |
| `+culmination/approve <id>` | Proposed | Approve a proposed Culmination | `manage_soul` |

### History
| Command | Status | Purpose | Permission |
|---|---|---|---|
| `+soul/history` | Proposed | View your own Narrative History | `play` |
| `+soul/history <character>` | Proposed | View an authorized character's Narrative History | staff |

(`+roll/history` is listed in `Commands.md` but is roll-related — **not in this handoff**.)

### Staff (`manage soul`)
| Command | Status | Purpose | Permission |
|---|---|---|---|
| `+soul/framework` | Proposed | Review/correct Character Framework state (Aspects, Skills) | `manage_soul` |
| `+soul/resonance <character>=<value>/<reason>` | Proposed | Correct a character's locked Resonance | `manage_soul` |
| `+soul/reload` | Proposed | Reload live configuration from `game/config/soul.yml` | `manage_soul` |

Staff tools SHALL NOT require direct database manipulation (REQ-036) — every staff action above must go through an existing API method, never raw Ohm model access.

### Help Files
- `help soul` — already exists (Phase 1)
- `help soul_commands` — new, this reference
- `help soul_bnb` — new, Boons and Banes
- `help manage soul` — already exists (Phase 1), extend with the new staff commands

## 7. Acceptance Criteria

- Every command above is registered in `plugin/soul.rb`'s `get_cmd_handler` and dispatches correctly.
- Every command has a corresponding web handler registered in `get_web_request_handler`, and the web handler calls the identical underlying API method (CP-05/REQ-032 parity) — no command-only or web-only business logic.
- Every command/handler re-checks permission server-side via `Soul.can_play?`/`Soul.can_manage_soul?` even where the API also checks (REQ-002 defense in depth).
- `+bnb/delete` cannot execute with fewer than two explicit confirmations (REQ-021).
- `+soul` (no argument) renders within roughly one MUSH screen (CI-02) — Aspects/Skills condensed, B&B summaries condensed (not full explanations), XP and Resonance one line each.
- Scene-GM viewing (`+soul <character>` under gm permission, and any GM-facing B&B reveal) respects the configured `gm_reveal_categories` from `docs/reference/Permissions.md` — never exposes character explanations or GM notes unless configured to.
- Staff corrections (Resonance, XP correct/reversal) record the acting staff member and a reason, surfaced through the existing audit trail (`SoulAuditApi`) — not a new ad hoc log.
- No command or web handler references `get_hooks`, `Global.dispatcher.dispatch(...)`, or any roll-related API/model.
- All new user-facing text is in `plugin/locales/locale_en.yml` under `soul:` — no hardcoded strings in command/handler files.
- `help soul_commands`, `help soul_bnb`, and the extended `help manage soul` render correctly and CI-08 naming is exact (`manage soul`, not "managing soul").
- Ember components for each tab follow the `GameApi` contract in `docs/development/Coding_Standards.md` (`requestOne` vs. `requestMany` matched to actual handler return shape) and Bootstrap 5 styling conventions.

## 8. Testing Requirements

- One spec file per command (`plugin/spec/soul_*_cmd_spec.rb`) and per web handler, following the existing flat `plugin/spec/*.rb` layout (no subdirectories), using Fabrication (`Fabricate(:character)`), each wrapped in `module AresMUSH ... end` with `require_relative 'spec_helper'`.
- Cover for every command: success path, permission-denied path, not-found/invalid-argument path, and (where relevant) the two-confirmation destructive-delete path.
- Cover for every web handler: authenticated success, unauthenticated/`check_login` rejection, permission-denied, and malformed-args handling.
- At least one test per Sheet/History/Audit path asserting privacy is respected — e.g., a non-owner, non-staff character cannot read another character's Narrative History or Audit via the web handler even if they guess an ID.
- Run `ruby -c` on every new Ruby file and validate `game/config/soul.yml` (if touched) parses as YAML before considering the work done.

## 9. Known Gaps (Resolved)

All blocking gaps have been resolved:

### Gap 1: `SoulXpApi.correct` (Resolved)

Added to `plugin/public/soul_xp_api.rb`: `SoulXpApi.correct(character, amount, reason:, actor:, direction: "correction")`. Records the correction to audit + Narrative History, following the same pattern as `SoulResonanceApi.correct`. Does not destroy the original ledger entry.

### Gap 2: Scene Participant Resolution (Resolved)

Added to `plugin/public/soul_xp_api.rb`: `SoulXpApi.get_scene_participants(scene = nil)`. Returns approved, active characters currently in a given scene, filtered to the same population as the XP median calculation (`Chargen.approved_chars`). Used by `+xp/scene` command to preview recipients before committing.

**Caveat:** Implementation assumes standard AresMUSH Scene model with `.characters` or `.people` collection. Verify against actual AresMUSH core scene API when available; if the mechanism differs, update the helper implementation but the interface contract remains the same.

### Gap 3: `SoulResonanceApi.correct` Signature (Resolved)

The handoff originally spec'd this as a positional `enactor` parameter. Corrected in §4 to `actor:` (keyword), matching the actual implementation.

---

## 10. Explicit Statement

**LlamaCoder must not make architectural changes.** Do not redesign any `public/*_api.rb` method, rename any model field or config key, invent a new dispatch mechanism, add a roll or roll-modifier feature, or restructure the plugin's file layout beyond what's listed in §3. If an existing API's signature seems to be missing something a command needs, **stop and report the gap** — do not add the missing business logic directly inside a command file. (Gaps 1-2 above are known; other gaps should be reported the same way.)

---

**After LlamaCoder finishes:** Claude will review every change for specification compliance, AresMUSH convention compliance, architectural correctness, authorization/privacy, configuration, localization, duplication, edge cases, web/MUSH parity, tests, and documentation currency, per the Addendum's standing review checklist, before accepting the implementation.

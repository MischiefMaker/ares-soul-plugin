# SOUL Bug List

Running log of issues found during internal testing (non-live game install, started 2026-07-24). Newest first. This is a working document, not a release artifact — see `docs/spec/CLAUDE_ADR.md`/`IMPLEMENTATION_CHECKLIST.md` for the permanent record once an item is resolved and folded into the normal documentation.

**Status values:** 🔴 Open · 🟡 Needs a decision · ✅ Fixed (commit noted)

---

## Feature Requests (from testing)

### FR-002: Custom-install snippets must never show copy-target code as commented-out text

**Status:** ✅ Fixed (`custom-install/custom_approval.snippet.rb`, `custom_char_fields.snippet.rb`, `custom_scene_data.snippet.rb`)

**Requested:** 2026-07-24, internal testing, after a direct push to `main` (`9a219fd`) uncommented four lines in `custom_char_fields.snippet.rb`'s OPTION B block and Claude initially (wrongly) recommented them back: *"All code that should be copied SHOULD NOT EVER BE COMMENTED."*

Audited every `.rb`/`.yml`/`.hbs` file under `custom-install/` for this pattern. The `.hbs` and `.yml` snippets were already correct — they use HTML/YAML comments exclusively for instructions, with the actual markup/config always shown plain. Three `.rb` files had it backwards: real code the reader is meant to paste was shown prefixed with `#`, requiring a reader to either strip the `#` characters manually or (worse) copy them in and end up with dead code. Fixed by uncommenting every such block:

- `custom_approval.snippet.rb`'s "EXAMPLE" section (previously a fully-commented `def self.custom_approval` block).
- `custom_char_fields.snippet.rb`'s OPTION B insertion lines, and its "combined method might look like" example (the placeholder `fields[:some_other_field] = ...` was changed to `= "..."` — bare `...` parses as Ruby's argument-forwarding token with a warning, `"..."` is an unambiguous string placeholder).
- `custom_scene_data.snippet.rb`'s OPTION B insertion lines.

One inherent consequence, not a bug: `custom_scene_data.snippet.rb` no longer passes a standalone `ruby -c` (its OPTION B block is two bare `key: value,` hash fragment lines, meant to be pasted *inside* an existing hash literal — never valid as a top-level statement on their own). Verified the fragment itself is valid Ruby once embedded in real context. Future audits of this file should expect that `ruby -c` failure and not mistake it for a regression.

### FR-001: `+bnb` alone should list the player's own Boons and Banes

**Status:** ✅ Done (`plugin/commands/soul_bnb_cmd.rb`)

**Requested:** 2026-07-24, internal testing: *"I'd like 'bnb' on its own to give an expanded list of BNBs with the ID, name, tag, and player's description."*

A bare `+bnb` previously required an argument and just returned an "invalid syntax" error — there was no command to list all of a player's own entries at once (only single-entry lookup by ID/tag, the scene-scoped `/here`, and the public `/catalogue`). Added `SoulBnbCmd#show_own_entries`, reached when `+bnb` is given with no reference: lists every entry `SoulBnbApi.get_character_entries(enactor)` returns, each showing catalogue ID, tag, name, kind, level, and the character's own private `character_explanation` (never shown to anyone else). Operates strictly on `enactor` — no new privacy exposure, matching the same self-only scope `+xp`/`+soul` already use for private data.

**Not yet done (flagged, not actioned):** the web Sheet's B&B list (`soul_sheet_web_handler.rb#serialize_bnb`) still omits `character_explanation` entirely, so there's no web equivalent of this expanded view yet. Didn't add it in this pass because it's not a simple parity mirror — the Sheet can be viewed by staff and scene-GMs as well as the owner (`can_view?`), and `character_explanation` is a privacy-sensitive "broader reveal" field elsewhere in this project (`docs/reference/Permissions.md`'s GM-reveal-categories). Naively adding it to `serialize_bnb` would leak private explanations to scene-GMs viewing another character's sheet. Needs a real decision (e.g. only include it when `character == enactor` or `Soul.can_manage_soul?(enactor)`) rather than a reflexive copy-paste.

---

## BUG-005: `+soul/cg` told unapproved players "permission denied" — self-contradictory permission check

**Status:** ✅ Fixed (`plugin/commands/soul_chargen_cmd.rb`, `plugin/web/soul_chargen_web_handler.rb`)

**Reported:** 2026-07-24, internal testing. User's exact report: *"soul/cg tells unapproved players they don't have permission to do that."* Initial ask was to rename the command again (to `soulcg/`), on the assumption this was another namespace collision like BUG-004.

**Root cause (not a namespace issue — confirmed by tracing the code, not renaming blindly):** `SoulChargenCmd#check_permission` and the equivalent check in `SoulChargenWebHandler` both gated on `Soul.can_play?(enactor)` *before* their own `enactor.is_approved?` check. That ordering only made sense under the old `play_permission: "play"` default. After BUG-002 changed `Soul.can_play?` to default to `enactor.is_approved?`, the two checks became directly contradictory for this one command family: an **unapproved** character (the only intended user of chargen) now fails `can_play?` immediately, and never reaches the code's own `is_approved?` check — which exists specifically to block the *opposite* case (already-approved characters). Verified this by tracing both the MUSH command and the web handler; both had the identical bug, so the web chargen tab was equally broken.

**Fix:** Removed the `Soul.can_play?` gate from both `SoulChargenCmd#check_permission` and `SoulChargenWebHandler#handle`. Chargen's own `is_approved?` check (block already-approved characters, allow everyone else) is the complete, correct gate on its own — it was always redundant to also require `can_play?`, and became actively wrong once `can_play?`'s definition changed. Command stays `+soul/cg`; no further renaming needed (confirmed with the user before implementing, since the rename they initially asked for wouldn't have fixed this).

---

## BUG-004: `+chargen` commands didn't work — `chargen` is shadowed by a core shortcut, not free

**Status:** ✅ Fixed (`plugin/soul.rb`, `plugin/commands/soul_chargen_cmd.rb`, help/docs)

**Reported:** 2026-07-24, internal testing. User's exact report/instruction: *"chargen commands do not work -- we need a unique namespace and +chargen is taken. Use +soul/cg"*

**Root cause:** This project's own Phase 9 verification (see `docs/spec/CLAUDE_ADR.md`'s Character Generation UI section) checked whether `"chargen"` was claimed as a root word by core AresMUSH's own Chargen plugin (`plugins/chargen/chargen.rb`'s `get_cmd_handler`) and correctly found it wasn't — that plugin only claims `app`/`bg`/`cg`/`hook`. What that check missed: core's `game/config/chargen.yml` also defines a **shortcut**, `chargen: cg`, which rewrites the literal typed word "chargen" to "cg" *before command dispatch ever runs* (AresMUSH's shortcut-expansion step happens ahead of `cmd.root` matching). So `+chargen` on any stock game was never reaching SOUL at all — it silently became `+cg` (core's own chargen review command) first. Checking a plugin's `get_cmd_handler` alone is not sufficient to confirm a root word is free; its `shortcuts:` config must be checked too. Recorded as a lesson for future root-word choices.

**Fix:** Renamed the entire chargen command family from a standalone `+chargen` root to `+soul/cg` — a compound switch under the existing `soul` root (`cg`, `cg/resonance`, `cg/skill`, `cg/bnb`, `cg/drop`), using the same embedded-slash-switch convention already established for `+soul/framework/skill` and `+xp/award/catchup`. Namespacing under `soul` specifically (rather than picking another bare root) avoids colliding with this same shortcut mechanism a second time. `SoulChargenCmd` gained a `sub_switch` helper that strips the `cg` prefix so its internal dispatch logic is otherwise unchanged. Web operations (`soulChargenStatus` etc.) were never affected — they're plain string identifiers, not MUSH command roots, so no web-side change was needed. Updated `docs/reference/Commands.md`, `README.md`, `plugin/help/en/soul_chargen.md`, `plugin/locales/locale_en.yml`, and the relevant specs (`soul_chargen_cmd_spec.rb`).

**No `custom-install/` changes** — the chargen web-mounting snippets reference the Ember component `soul/chargen`, not the MUSH command syntax, so nothing there needed to change.

---

## BUG-003: `+soul/reload` naming is confusing — command does nothing a reload implies

**Status:** 🟡 Needs a decision

**Reported:** 2026-07-24, internal testing.

**Report:** "Soul/reload doesn't seem necessary -- returns the message: `%% SOUL configuration is read live; no plugin cache needs reloading. Current configuration is valid.`"

**Analysis:** Not a functional bug — SOUL reads `game/config/soul.yml` live on every call (`Global.read_config`, never cached), so there is genuinely nothing to "reload." `+soul/reload` calls `Soul.check_config` and reports validation errors, which is real, useful value after editing the config file — but the command's *name* promises an action ("reload") that doesn't happen, which is what's producing the "doesn't seem necessary" reaction. This is a naming/expectation problem, not a missing-feature problem.

**Recommendation (not yet applied):** Rename the player-facing verb to something that matches what it does — e.g. `+soul/validate` — and keep `+soul/reload` working as an alias so nothing already muscle-memoried breaks. Needs a decision on the new name before touching `soul_staff_cmd.rb`, `soul.rb`'s switch routing, help files, and `docs/reference/Commands.md`.

---

## BUG-002: `play_permission` defaulted to `"play"`, which isn't a real permission

**Status:** ✅ Fixed (`plugin/soul.rb`, `plugin/soul_config_validator.rb`, `game/config/soul.yml`)

**Reported:** 2026-07-24, internal testing — user asked what the setting was even for and noted there's no built-in default permission for it.

**Root cause:** Same class of bug as BUG-001 (see below) — `"play"` was never a permission any bundled AresMUSH plugin registers (confirmed against the real `+role/list` output and `Roles.all_permissions`, which collects every plugin's declared `permissions:` config). Unlike `manage_permission`/`gm_review_permission` (which gate genuinely elevated capabilities that vary per game), the base "can play SOUL at all" tier isn't naturally a grantable permission at all in AresMUSH's model — the real equivalent is chargen approval status (`Character#is_approved?`), used everywhere else in this project for exactly this gate.

**Fix:** `Soul.can_play?` now returns `true` for any approved character with no configuration required, and treats `play_permission` (now optional, `nil` by default) as an *additional* grant on top of approval rather than the sole gate — e.g. to let staff or beta-testers in before their own character is approved. `soul_config_validator.rb`'s `play_permission` check changed from required-nonblank to optional-if-present. Updated `game/config/soul.yml`, `docs/reference/Permissions.md`, `docs/reference/Default_Config.md`, and fixed `plugin/spec/soul_roll_api_spec.rb` (stubbed the old `has_permission?("play")` path, which no longer runs) and `plugin/spec/soul_config_validator_spec.rb`.

---

## BUG-001: `gm_review_permission` defaulted to `"gm"`, which isn't a real permission

**Status:** ✅ Fixed (`plugin/soul.rb`, `game/config/soul.yml`)

**Reported:** 2026-07-24, internal testing — user's exact report: *"'gm_review_permission' is default 'gm', which isn't a default permission. Should be manage_scenes."*

**Root cause:** Confirmed against the real AresMUSH engine (`plugins/scenes/helpers/permissions.rb`, `install/init_db.rb`'s seed roles, and the user's own live `+role` permission listing): `"gm"` has never been a permission any bundled plugin registers or any default role grants. No fresh AresMUSH install has anyone able to satisfy `has_permission?("gm")` without a staffer inventing that exact string and assigning it by hand — meaning GM-assisted-roll review didn't work out of the box for anyone. `"manage_scenes"` is a real, pre-existing Scenes-plugin permission ("Can use scene-related admin tools, like stopping or unsharing scenes") that already represents scene-authority staff — the correct default, and the user's suggested fix.

**Fix:** Changed the fallback in `Soul.can_review_rolls?` and `game/config/soul.yml`'s shipped default from `"gm"` to `"manage_scenes"`. Updated `docs/reference/Permissions.md` and `docs/reference/Default_Config.md` to match. `plugin/spec/soul_config_validator_spec.rb`'s fixture updated to a real permission name (it was only asserting structural validity, not the specific string, so this didn't change test semantics).

---

## Template for New Entries

```markdown
## BUG-NNN: <short title>

**Status:** 🔴 Open / 🟡 Needs a decision / ✅ Fixed (<commit/file>)

**Reported:** <date>, <context — internal testing, etc.>

**Report:** <verbatim or close-to-verbatim what was observed>

**Root cause:** <what's actually happening, verified against real source — not assumed>

**Fix:** <what changed, or the open question if not yet resolved>
```

# SOUL Bug List

Running log of issues found during internal testing (non-live game install, started 2026-07-24). Newest first. This is a working document, not a release artifact — see `docs/spec/CLAUDE_ADR.md`/`IMPLEMENTATION_CHECKLIST.md` for the permanent record once an item is resolved and folded into the normal documentation.

**Status values:** 🔴 Open · 🟡 Needs a decision · ✅ Fixed (commit noted)

---

## Feature Requests (from testing)

### FR-012: Unique CSS classes for installer styling hooks

**Status:** 🟡 Partially done — plain HTML wrappers fixed; `BsModalSimple` components not addressed

**Requested:** 2026-07-25, `docs/development/mischief_bug_list.md` item 15: *"Ensure we are including unique CSS classes wherever possible, for installers to be able to hook into their custom CSS."*

**Audit:** most `soul/*` Ember components already had a unique top-level wrapper class (`soul-bnb`, `soul-chargen`, `soul-culminations`, `soul-history`, `soul-staff`, `soul-xp`, `soul-sheet`). Found and fixed three real gaps: `sheet.hbs`'s loading/error states had no class at all (`soul-sheet-loading`/`soul-sheet-error` added); `roll.hbs`'s two dropdown-menu `<li>` items were bare (`soul-roll-nav-item`/`soul-roll-review-nav-item` added); `scene-tools.hbs`'s dropdown `<li>` was bare and its modal only had an `id`, no class (`soul-scene-tools-nav-item`/`soul-scene-tools` added).

**Not addressed:** the `BsModalSimple` invocations in `chargen.hbs`, `roll.hbs`, and `sheet.hbs` (an `ember-bootstrap` component, not plain HTML) were left alone — no `ember-bootstrap` addon source was available in this session to verify whether it accepts a passthrough class attribute, and guessing at an unverified API risked shipping a silently-no-op attribute. Needs a follow-up with the addon's actual API (or its rendered DOM inspected in a running portal) before adding a class there.

### FR-011: B&B catalogue entries require at least one associated Skill, surfaced in chargen

**Status:** ✅ Done (`plugin/public/soul_bnb_api.rb`, `soul_framework_api.rb`, `plugin/commands/soul_bnb_cmd.rb`, `soul_chargen_cmd.rb`, `plugin/web/soul_chargen_web_handler.rb`, `web-portal/app/components/soul/staff.js`, `web-portal/app/templates/components/soul/staff.hbs`/`chargen.hbs`, docs)

**Requested:** 2026-07-25, `docs/development/mischief_bug_list.md` item 8: *"bnbs need to take 'impacted skills' when adding them to a player, so that the roll command knows what to suggest. This could be added in a second step, but it needs to be required and explained, including in chargen."*

**The mechanism already existed and was already wired into rolls** — `BnbCatalogueEntry#skill_associations` (an array attribute) was already read by `SoulRollApi` to match B&B candidates to a Skill roll. What was actually missing was narrower than the "second step" the report anticipated: `+bnb/create` (the MUSH command) never exposed this field at all — only the web `soulBnbCreate` operation accepted it, and neither interface required it, so a staffer creating B&Bs the normal way (MUSH) would silently produce entries `+roll` could never suggest.

**Done:**
- `SoulBnbApi.create_catalogue_entry` now requires a non-empty `skill_associations` list and validates every key against `SoulFrameworkApi.valid_skill_key?`, returning a clear error otherwise — the single source of truth, so both MUSH and web get this for free (CP-09).
- `+bnb/create` syntax extended: `<kind>/<tag>/<name>/<skill1,skill2,...>=<description>` (comma-separated Skill keys, new 4th slash-segment). Old 3-segment syntax (no Skill list) now correctly fails with "At least one associated Skill is required."
- The web staff "Create Catalogue Entry" form (`soul/staff`) gained a comma-separated Skill-keys input, parsed the same way as the MUSH command, so it isn't left broken by the new requirement.
- **Chargen ("including in chargen"):** `+soul/cg/catalogue` (MUSH) and the chargen catalogue modal (web) now both display each entry's associated Skills, so players can see what a B&B affects before selecting it — `SoulChargenWebHandler.catalogue_hash` and `SoulChargenCmd#show_catalogue` both resolve Skill keys to display names via `SoulFrameworkApi.get_skill`.
- Updated `docs/reference/Commands.md`, `plugin/help/en/soul_bnb.md`/`manage_soul.md`, `docs/reference/Default_BnBs.md`'s examples, `docs/development/Migration_From_FS3.md`'s B&B migration examples, and README's new starter-B&B install step (FR-010) — all previously showed the old 3-segment syntax.
- `plugin/spec/soul_bnb_api_spec.rb`'s `create_boon`/`create_bane` test helpers (used by ~24 examples across the file for unrelated features) now pass a stubbed Skill key, since the new requirement would otherwise have broken every one of them. New spec coverage for the requirement itself, the syntax parsing, and the web form's argument-passing.

### FR-010: Default starter Boons & Banes added to install instructions

**Status:** ✅ Done (`README.md`)

**Requested:** 2026-07-25, `docs/development/mischief_bug_list.md` item 13: *"We were going to include some default bnbs in the install instructions which never got added,"* listing four: Cursed (bane), Artifact (boon), Contacts (boon), Bad Reputation (bane).

**Done:** Added an "Optional but recommended: create starter Boons & Banes" subsection to README's Step 2 (Configure Your Framework), with the exact four entries as ready-to-run `+bnb/create` commands (using the corrected syntax from FR-011, with a placeholder Skill key installers replace with one of their own configured Skills, since Skills are entirely game-specific config). Cross-references `docs/reference/Default_BnBs.md` for more examples and catalogue anatomy.

### FR-009: Chargen readiness checks for Skill/Aspect points and B&B ratio

**Status:** ✅ Done, informational only — 🟡 whether it should also block approval is an open decision

**Requested:** 2026-07-25, `docs/development/mischief_bug_list.md` item 12: *"Add cg checks for: Points spent on Aspects < Points allowed, points spent on skills < points allowed, bnbs < allowed number and ratio as 3 separate items. See inklings for how to implement."* (Inklings' own source was not available in this session to consult directly for its implementation pattern — implemented from this project's own established conventions instead.)

**Existing enforcement, confirmed first:** `SoulChargenWebHandler.set_skill`/`.set_aspect` already reject any allocation that would *exceed* budget, and `SoulBnbApi.grant` already rejects a chargen grant that would violate the 2:1 ratio or a Resonance-level count/level limit — none of the three can currently be over-spent. What was missing was visibility into whether a character is *under*-spent or otherwise not "ready," since nothing currently stops leaving points unallocated or approving with an unsatisfied ratio (e.g., one Bane and zero Boons).

**Done:** Added three informational readiness indicators to `+soul/cg` (MUSH) and the chargen status payload (web): `skill_points_fully_spent`, `aspect_points_fully_spent`, `bnb_ratio_satisfied` (new `SoulBnbApi.ratio_currently_satisfied?`, checking the ratio as it stands rather than `.ratio_satisfied_after_boon?`'s hypothetical one-more-Boon check). Displayed as a color-coded "Readiness" line in both the MUSH status display and a new banner in `chargen.hbs`.

**Deliberately not implemented:** approval is not blocked on any of these. Making chargen *require* full allocation and a satisfied ratio before a character can be approved is a real product decision (e.g., should staff be able to override it? should partial Aspect spend ever be legitimate?) that the report's phrasing didn't unambiguously resolve — implemented the safe, reversible half (visibility) and left the blocking half for an explicit decision rather than guessing at approval-gating behavior.

### FR-008: `+soul` added to `app_review_commands`; Inklings needs the same for `inkling/list`

**Status:** ✅ Done for SOUL's own README; Inklings-side change out of scope for this repo

**Requested:** 2026-07-25, `docs/development/mischief_bug_list.md` item 11: *"Installers should add to app_review_commands: - soul %{name} -- Note: we should add inkling/list ${name} to the Inkling instructions as well."*

**Done:** Confirmed `app_review_commands` is a real core AresMUSH `chargen.yml` config list (drives what `app <character>` runs automatically during staff review) against the real engine source. Added a README step (in Step 4, alongside the existing chargen-stage installation) instructing installers to add `soul %{name}` to the list, with a pointer to also add Inklings' `inkling/list %{name}` if that plugin is installed. The Inklings-side documentation change itself lives in the separate `ares-inklings-plugin` repository, not accessible from this session — flagged here rather than silently skipped.

### FR-007: FS3 disable instructions (plugin, chargen stage, `app_review_commands`)

**Status:** ✅ Done (`docs/development/Migration_From_FS3.md`)

**Requested:** 2026-07-25, `docs/development/mischief_bug_list.md` item 10: *"We need to add explanations how to disable FS3, including de-listing it in chargen, including: disabling the plugin, removing the chargen steps and app_review_commands for sheet."*

**Done:** `Migration_From_FS3.md`'s "Long-Term Considerations" section previously only said "Remove or hide FS3 commands... once migration is validated" — no concrete steps. Replaced with a verified, concrete procedure (checked against the real engine): (1) add `fs3skills` to `game/config/plugins.yml`'s `disabled_plugins` (real `PluginManager#is_disabled?` mechanism); (2) remove FS3's `abilities` chargen stage from `chargen.yml` (confirmed that's FS3's own stage, `plugins/fs3skills/helpers/chargen.rb`, not a core one); (3) remove FS3's `+sheet` command (`plugins/fs3skills/commands/sheet_cmd.rb`) from `app_review_commands` and add `soul %{name}` in its place (ties into FR-008).

### FR-006: Chargen help text corrected — Aspects DO advance post-chargen; dropped the command-name backstory

**Status:** ✅ Done (`plugin/help/en/soul_chargen.md`)

**Requested:** 2026-07-25, `docs/development/mischief_bug_list.md` item 9, quoting the then-current help text and correcting it: *"This is wrong: Aspects will allow post-chargen advancement. Resonance does not allow changing after chargen. Everything else does. Remove the language about the chargen command. Players do not care. Just tell them the commands they need."*

**Context:** the factual claim itself (Aspects have no post-chargen advancement) had already been superseded by an unrelated, larger rework — Aspects now mirror Skills with an `xp.cost.aspect_cost_multiplier`-priced `+xp/spend/aspect` advancement path, `aspect_max_rating` defaulting to 10 (an "ultimate cap" like Skills, not a 0-5 chargen-only range) — landed in the intervening "Fix SOUL profile and chargen web UI" commit series, which had already partially corrected this help text (added "After approval, both Skills and Aspects can be advanced by spending XP") but left two things unaddressed.

**Done:** Removed the closing paragraph explaining the `+chargen`-vs-`+soul/cg` naming collision (real backstory for developers, not something a player needs to read to use the commands) and removed the stale "(default 5)" aside on the Aspect max rating (now game-configurable, no longer always 5). Also added an explicit sentence stating Resonance is the *only* choice that locks permanently at approval — the report's second correction.

### FR-004: Default Skill set changed to setting-specific names

**Status:** ✅ Done — skills changed; the related Aspect-values question was resolved by the user and implemented as FR-005 below.

**Requested:** 2026-07-24, internal testing: *"We need to change the default skills. Also Body, Mind and Spirit need to take values -- these are the aspects in the roll."* New Skill set specified per Aspect:
- Body: Strength, Speed, Stamina
- Mind: Intelligence, Learning, Wit
- Spirit: Ceremonial Magic, Hedgecraft, Natural

**Done:** Updated the shipped default Skill list (`game/config/soul.yml`, mirrored in `docs/reference/Default_Config.md`) to the set above. Net change from the old starter set: Body's Reflexes → Speed (Strength/Stamina unchanged); Mind fully replaced (Investigation/Empathy/Academics → Intelligence/Learning/Wit); Spirit fully replaced except Ceremonial Magic, which was already there (Resolve/Presence → Hedgecraft/Natural). Stable keys: `strength`, `speed`, `stamina`, `intelligence`, `learning`, `wit`, `ceremonial_magic`, `hedgecraft`, `natural`. This is the shipped *default* — an already-installed game's own `game/config/soul.yml` is a separate copy and needs the same edit applied by hand (or a fresh `plugin/install` merge) to take effect there.

**Open question, now resolved:** "Body, Mind and Spirit need to take values" flagged a real gap: Aspect ratings defaulted to 0 for every character and nothing in normal play ever set them — chargen only let players allocate Skills (FINAL REQ-011's canonical flow lists Skills only), so the Aspect Contribution term (`rating × 0.20`) in the roll formula was effectively always 0. Asked the user which mechanism should set the value (derive from Skills / add to chargen / flat default); the user answered directly — see FR-005.

### FR-005: Aspect point-buy added to chargen

**Status:** ✅ Done (`plugin/public/soul_resonance_api.rb`, `soul_framework_api.rb`, `soul_character_api.rb`, `plugin/web/soul_chargen_web_handler.rb`, `plugin/commands/soul_chargen_cmd.rb`, `plugin/soul_config_validator.rb`, `game/config/soul.yml`, web `chargen.js`/`.hbs`)

**Requested:** 2026-07-24, internal testing, resolving FR-004's open question with an explicit decision that reverses FINAL's REQ-011 canonical chargen flow (chargen previously excluded Aspect allocation — a decision `docs/spec/CLAUDE_ADR.md` had documented as intentional during Phase 9): *"Aspect point-buy to chargen. That should not have been excluded. We will need a configurable min and max -- 0 and 5 by default. Let's allocate 5 points in chargen, with 1 extra point for each resonance level (or 1 less for R-). these should be configurable as well."*

**Done:** Added a full Aspect point-buy allocation step to chargen, mirroring the existing Skill point-buy architecture end-to-end rather than inventing a parallel mechanism (CP-09 "One Rule One Home"):
- New config: `framework.aspect_min_rating`/`aspect_max_rating` (default `0`/`5`) — a single lifetime range, not a two-tier starting-cap/ultimate-cap split like Skills, because Aspects have no post-chargen XP-spend advancement path for a lower "starting" cap to protect against being exceeded later. `resonance.r0_aspect_points` (default `5`), `positive_aspect_points_per_level`/`negative_aspect_points_per_level` (default `1` each) — same `base + (Resonance × rate)` formula Skills already use in `SoulResonanceApi.chargen_allowance`, extended to also return `aspect_points`.
- `plugin/soul_config_validator.rb` validates the new range and integer keys.
- `SoulCharacterApi.set_aspect_rating` gained min/max range validation it previously completely lacked (a real pre-existing bug, not introduced by this feature — found while wiring up player-facing Aspect allocation; low-consequence while Aspect-setting was staff-only via `+soul/framework/aspect`, load-bearing once exposed via point-buy).
- `SoulChargenWebHandler.set_aspect`/`status` enforce the same spend-budget pattern as `set_skill`/`status` (shared class methods, used by both the MUSH command and the web handler).
- `+soul/cg/aspect <key>=<rating>` (MUSH), new `soulChargenAspect` web operation, and an Aspect point-buy card with +/- controls in the Ember chargen UI (`chargen.js`/`.hbs`), matching the existing Skill controls' bounds-checking and disabled-state pattern.

Aspect point math (base 5, rate 1) verified by hand: R-3→2, R-1→4, R0→5, R+1→6, R+3→8.

This is a deliberate reversal of the Phase 9 ADR entry documenting "Aspects are never part of the chargen point-buy" — see the corresponding `docs/spec/CLAUDE_ADR.md` entry for the correction. Shipped in the *default* `game/config/soul.yml` — an already-installed game's own copy is a separate file and needs the same config keys added by hand (or a fresh `plugin/install` merge) to take effect there.

### FR-003: Owners and staff need private B&B detail on both MUSH and web (FR-001's flagged follow-up)

**Status:** ✅ Done (`plugin/commands/soul_bnb_cmd.rb`, `plugin/web/soul_sheet_web_handler.rb`, `web-portal/app/components/soul/sheet.js`/`.hbs`)

**Requested:** 2026-07-24, internal testing, closing the gap FR-001 flagged: *"We need people and staff to be able to see the player-specific details of their own bnbs on both the web and MUSH. I suggest on the web it be a pop up modal on the list of bnbs."*

**MUSH — a real gap, not just missing polish:** staff had no way at all to see another character's private B&B explanation. `+bnb <id or tag>` (and FR-001's bare `+bnb`) only ever looked at `enactor` — there was no staff path to view someone *else's* explanation on the MUSH side, even though the equivalent web `soulBnb` lookup operation already supported it via a `character` arg. Added `+bnb/detail <character>[=<id or tag>]` (staff-only, added to `staff_switches`): bare lists that character's own entries with explanations (mirrors FR-001's `show_own_entries`); with `=<id or tag>` shows one entry in full. Refactored `show_own_entries`/`show_entry` into shared `show_entries_for(character, whose:)`/`show_entry_for(character, reference, label:)` methods so self-view and staff-view share one code path — no duplicated logic. New locale strings (`bnb_own_title` and `bnb_detail`'s label are now parameterized: "Your Boons & Banes" / "Jordan's Boons & Banes", "Your explanation" / "Jordan's explanation").

**Web — the privacy-gated fix flagged in FR-001:** `SoulSheetWebHandler#serialize_bnb` now includes `description` (always, it's public) and `explanation` (only when `character == enactor || Soul.can_manage_soul?(enactor)` — explicitly *not* for the scene-GM viewer tier `can_view?` otherwise allows, matching `docs/reference/Permissions.md`'s existing "a GM does not gain global visibility into a character's private B&B explanations... by virtue of being a GM"). Added an `explanation_visible` boolean so the client can distinguish "not authorized to see this" from "authorized, but nothing was written" — collapsing both to a falsy `explanation` would have been misleading. On the web, each row in the Sheet's B&B table is now clickable and opens a `BsModalSimple` (the same modal component `roll.hbs` already established as this project's convention) showing tag/kind/level/state/description, plus the explanation section when visible, or an explanatory placeholder when not.

Specs cover: `+bnb/detail`'s staff-only gate, its two argument shapes, and the three-way explanation-visibility split (owner, staff, scene-GM) on the web handler.

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

**Web/staff follow-up:** flagged here as needing a real privacy decision rather than a reflexive copy-paste — done in FR-003 above.

---

## BUG-009: `Global.read_config` called three keys deep — `ArgumentError` crashed `+xp/spend`, catch-up eligibility, and Grimoire's branch lookup

**Status:** ✅ Fixed (`plugin/public/soul_xp_api.rb`, `soul_framework_api.rb`, and their specs)

**Reported:** 2026-07-25, `docs/development/mischief_bug_list.md` item 14 (second half). User's exact report, from live game logs: `xp/spend/aspect mind=1` failed every time with `Error: "wrong number of arguments (given 4, expected 1..3)"`, backtrace through `global.rb:8:in 'read_config'` → `soul_xp_api.rb:109:in 'calculate_cost'` → `soul_xp_cmd.rb:106:in 'spend_xp'`.

**Root cause, confirmed against the real engine (`/workspace/aresmush/engine/aresmush/global.rb`, `config/config_reader.rb`):** `Global.read_config(section, key = nil, subkey = nil)` supports at most **two levels** of nesting below the plugin name (3 args total) — `ConfigReader#get_config` only ever indexes `section → key → subkey`, nothing deeper. `SoulXpApi.calculate_cost` called it with **four** args in nine places (`Global.read_config("soul", "xp", "cost", "skill_curve_numerator")`, etc. — `soul.xp.cost.*` is three levels deep), plus two more in `catchup_eligible?`/`.award` (`soul.xp.catchup.*`) and one in `SoulFrameworkApi.get_skill_for_grimoire_branch` (`soul.integrations.grimoire.branch_skill_map`) — every one of these raised `ArgumentError` unconditionally, every time it ran, in a real game. This is the same "spec mocks an interface the real method doesn't have" failure mode this project has hit before (see BUG history) — every spec covering these methods mocked `Global.read_config` with the same over-deep 4-arg signature, so the test suite passed while the real code was 100% broken.

**Fix:** Changed every over-deep call to the pattern already used correctly elsewhere in this codebase (e.g. `SoulBnbApi.level_modifier`): read the two-level parent hash once (`Global.read_config("soul", "xp", "cost")`), then index into it with plain Ruby hash access (`cost_config["skill_curve_numerator"]`). Applied to `calculate_cost`, `catchup_eligible?`, `.award`, and `get_skill_for_grimoire_branch`. Updated `soul_xp_api_spec.rb`'s and `soul_framework_api_spec.rb`'s `Global.read_config` mocks to match the real two-level signature (both would otherwise have kept masking this class of bug going forward). Audited every other `Global.read_config` call in `plugin/` for the same over-deep pattern — no other instances found.

---

## BUG-008: `app/approve` raised `Ohm::IndexNotFound` — B&B chargen finalization queried an unindexed attribute

**Status:** ✅ Fixed (`plugin/models/narrative_history_entry.rb`)

**Reported:** 2026-07-25, `docs/development/mischief_bug_list.md` item 14 (first half). User's exact report, from live game logs: `app/approve useless` raised `Ohm::IndexNotFound` but completed anyway. Backtrace through `ohm.rb:1484:in 'to_indices'` → `soul_bnb_api.rb:232:in 'block in finalize_chargen_grants'` → `custom_approval.rb:8`.

**Root cause:** `SoulBnbApi.finalize_chargen_grants` calls `NarrativeHistoryEntry.find(soul_record_type: ..., soul_record_id: ...)` to check whether an entry's approval history was already created (so re-approval doesn't duplicate it). Ohm requires every attribute used in a `.find` filter to have a declared `index` — `NarrativeHistoryEntry` indexed `soul_record_type` but never `soul_record_id`, so any multi-key `.find` including it raised immediately. The error was non-fatal only because AresMUSH's own command dispatcher rescues and logs errors from hook code rather than aborting the approval — meaning the "starting B&B" Narrative History entry silently never got created for any approval, every time, since this hook was written.

**Found the identical bug a second time while fixing this:** `SoulCulminationApi` (`plugin/public/soul_culmination_api.rb:130`) has the exact same `NarrativeHistoryEntry.find(soul_record_type:, soul_record_id:)` call pattern, checking for existing Culmination-approval history — it would have raised the same `Ohm::IndexNotFound` the first time it ran, just not yet reported because no Culmination had gone through approval in this testing session.

**Fix:** Added `index :soul_record_id` to `NarrativeHistoryEntry`. Single-line fix at the root cause fixes both call sites (`SoulBnbApi.finalize_chargen_grants` and `SoulCulminationApi`'s approval-history check) since they share the same model. No spec change needed — the existing `soul_bnb_api_spec.rb` coverage for `.finalize_chargen_grants` was already correct Ruby, it just never ran against a real Redis-backed Ohm store in a context where this would surface (this project's specs are `ruby -c`/read verified in this session, not executed against a live game — the bug only surfaced via the user's actual live testing).

---

## BUG-007: SOUL web portal components crashed with "WeakMap key null" and cascading route-transition errors

**Status:** ✅ Fixed (prior session — see the "Fix SOUL profile and chargen web UI" commit series; verified clean by a fresh audit today)

**Reported:** 2026-07-24/25, `docs/development/mischief_bug_list.md` items 4 and 6. User's reports: the web chargen tab loaded nothing and the profile page threw `WeakMap key null must be an object or an unregistered symbol`; separately, navigating to any page after loading a profile threw `More context objects were passed than there are dynamic segments for the route`.

**Root cause:** two independent issues. (1) Every `soul/*` Ember template referenced component properties without the `this.` prefix (e.g. `{{rollOpen}}`, `{{selectedSkill}}`, `{{candidates}}`) — implicit unprefixed property lookup that this portal's Ember version no longer resolves reliably, so these properties read as `null`/`undefined` at points the framework's internals (a `WeakMap`) require a real object, throwing. (2) Chargen's permission gate incorrectly required `Soul.can_play?` in addition to `is_approved?` (the same class of bug as BUG-005, independently present in an earlier version of this code path), and the chargen component silently discarded any API error instead of surfacing it — so an unapproved character's chargen tab looked empty with zero diagnostic signal. The route-transition error was a cascading failure once the primary `WeakMap` exception put the router in a broken state.

**Fix (prior session, ~20 commits titled "Fix SOUL profile and chargen web UI"):** every `soul/*` template's component-property references were updated to the `this.`-prefixed form (`roll.hbs`, `staff.hbs`, `sheet.hbs`, `scene-tools.hbs`, `xp.hbs`, `history.hbs`, `culmination.hbs`, `chargen.hbs`, `bnb.hbs`); the redundant `can_play?` chargen gate was removed; `chargen.js`'s `refreshStatus` now surfaces a failed status fetch as a real error instead of a blank tab. **Verified today** with a full grep audit of every `soul/*` `.hbs` file for any remaining unprefixed component-property reference (as opposed to a correctly-unprefixed `{{#each ... as |x|}}` block param) — none found; the fix is complete and holding.

---

## BUG-006: Missing locale keys broke `+bnb`'s ownership display ("Translation missing")

**Status:** ✅ Fixed (prior session; verified present in `plugin/locales/locale_en.yml` today)

**Reported:** 2026-07-24, `docs/development/mischief_bug_list.md` item 1. User's report: using `+bnb` gave `Translation missing: en.soul.bnb_own_title`.

**Root cause:** `bnb_own_title`, `bnb_own_line`, `bnb_your`, `bnb_your_explanation`, `bnb_whose`, `bnb_whose_explanation` were referenced by FR-001's ownership-display code but were never added to `locale_en.yml`.

**Fix (prior session):** all six keys added, with the detail label made generic so it works across the command's self-view and staff-view (FR-003) call paths. **Verified today**: all six present in the current `locale_en.yml`.

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

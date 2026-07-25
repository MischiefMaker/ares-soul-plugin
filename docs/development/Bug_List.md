# SOUL Bug List

Running log of issues found during internal testing (non-live game install, started 2026-07-24). Newest first. This is a working document, not a release artifact — see `docs/spec/CLAUDE_ADR.md`/`IMPLEMENTATION_CHECKLIST.md` for the permanent record once an item is resolved and folded into the normal documentation.

**Status values:** 🔴 Open · 🟡 Needs a decision · ✅ Fixed (commit noted)

---

## Feature Requests (from testing)

### FR-030: Boon/Bane Progress/Regress buttons (kind-aware direction) and an Add/Remove reorganization, on both the profile staff panel and the admin page

**Status:** ✅ Done (`plugin/public/soul_bnb_api.rb`, `plugin/web/soul_bnb_web_handler.rb`, `plugin/soul.rb`,
`webportal/components/soul-staff.js`, `webportal/templates/components/soul-staff.hbs`,
`webportal/controllers/admin-soul.js`, `webportal/routes/admin-soul.js`, `webportal/templates/admin-soul.hbs`, specs)

**Requested:** 2026-07-25, live testing, across several follow-up messages: "On the admin page and profile
admin section, let's add an 'increase/decrease BNB' option. If it's just moving up or down a level, we don't
want to reset skills... have the BNB dropdown only of the player's BNBs, an explanation box right beneath
it, and right after that, an 'Increase' and 'Decrease' button. We'll put the delete here as well - get rid
of the 'Character Entry ID', and just reference the dropdown above... Then small hr break, 'Add/Remove'
Header and then the other options - add a catalogue BNB, select a specific level, change the skills."
Then, correcting the button naming: "Actually, let's keep the 'Progress' and 'Resolve' language - that's
better than 'Increase'/'Decrease'. But we need to make sure Progress is increasing Boons and decreasing
Banes. And we should add a 'Regress' to do the opposite."

**Implementation:** `SoulBnbApi.progress_direction(entry_id, direction, ...)` is new - it steps a
minor/major/legendary entry one rung along `LEVEL_LADDER`, delegating to the existing `.progress` for the
actual update (so history/Narrative History/`SoulBnbTransitionedEvent` are identical to picking that level
explicitly - nothing about `.progress` itself changed, and the MUSH `+bnb/progress` command, which still
picks an explicit level, is untouched). "Progress" is never simply "up the ladder" - it's whichever direction
is good for the character: a Boon strengthens (minor → major → legendary), a Bane weakens (legendary → major
→ minor); "Regress" is the reverse. Neither touches `associated_skills` at all (same as the pre-existing
`.progress`), so the stated "don't reset skills" concern was already satisfied by reusing that method rather
than something new. Added the `soulBnbAdjustLevel` web command (registered in both `SoulBnbWebHandler`'s
`staff_commands` and `Soul.get_web_request_handler`'s dispatch table - BUG-016's lesson applied again).

Both the profile staff panel and the admin page's new "Manage a Player's Boons and Banes" section (which
didn't exist before this - added a Player `PowerSelect` matching the "Award XP to Players" precedent) now
show: a dropdown of the target character's own B&B entries (no more free-text "Character Entry ID"), an
explanation/reason box, Progress/Regress/Resolve/Restore buttons, and the existing two-checkbox Permanently
Delete - all acting on the dropdown selection. Below an `<hr>`, an "Add/Remove" header groups the existing
"Grant a new Boon or Bane" form (catalogue picker, level select, Skill multi-select, explanation, Grant).
After any successful action the selected entry is cleared (not left pointing at now-stale pre-update data)
and the list is refreshed from the server.

Also fixed in passing: `SoulCulminationApi.correct` used `title || culmination.title` to decide whether to
overwrite - Ruby's `||` treats `""` as truthy, so an intentionally-blank "leave unchanged" field would have
silently blanked the existing title/description. Changed to `.presence ||`. No test previously covered
`.correct` at all; added coverage for the update/blank-preserves/reason-required cases.

---

### FR-029: XP history limited to the last 5 entries, with a "Recent XP History" header

**Status:** ✅ Done (`plugin/web/soul_xp_web_handler.rb`, `webportal/templates/components/soul-xp.hbs`)

**Requested:** 2026-07-25, live testing (with screenshot of an unbounded, unlabeled history list): "In the
profile, this record will eventually get super long. I think let's just display the last 5 entries, and add
a header like 'Recent XP History'."

Same shape as the Roll history limit (FR-019) - `SoulXpApi.get_history` already accepted a `limit:` (default
50, used nowhere), so `SoulXpWebHandler#summary` now passes `limit: 5`. Added the requested header above the
list in `soul-xp.hbs`.

---

### FR-028: Culmination "?" tooltip, and a broad ID/tag-to-dropdown pass across chargen, profile, and the admin page

**Status:** ✅ Done (`webportal/templates/components/soul-staff.hbs`, `webportal/templates/admin-soul.hbs`,
`webportal/controllers/admin-soul.js`, `webportal/routes/admin-soul.js`)

**Requested:** 2026-07-25, live testing, after asking what a Culmination is and getting an explanation:
"Yes, let's add a ? with a pop up explaining what it is. On the admin side, they shouldn't need to enter an
ID unless editing an existing one - and that can be solved with a dropdown. When adding a new one, we'll
auto-assign the ID with a unique number. In fact, review chargen, profile and admin page and try to avoid
places where we ask for id or tag, where we could provide a dropdown instead." Then, clarifying scope: "I
mean any ID or tag, not just Culminations, to clarify. Let's make this user-friendly."

**Tooltip:** a plain HTML `title` attribute on a small badge next to the "Culminations" heading (matching the
only existing precedent for this in the sibling Inklings plugin - a native `title=`, not a Bootstrap JS
tooltip/popover, which would need explicit init this codebase never sets up) - `title`/`description` were
already free-text creation fields on Propose, so no ID was ever needed there; the only place an ID was ever
typed was Approve/Deny/Revoke/Correct, now a `PowerSelect` over `soulCulminations` (title + status) instead.
Correct got its own separate Title/Description fields distinct from Propose's - sharing one set across both
would have let leftover Propose text silently overwrite an unrelated Culmination's title on Correct, a real
trap caught before shipping it.

**Full audit result** (chargen already clean from this session's earlier dropdown work; player-facing
`soul-bnb.hbs` has no reference-lookup fields, its search box is a live filter, not an ID lookup, so it stays):
- `soul-staff.hbs`'s "Character entry ID" (Manage an existing B&B entry) → `PowerSelect` over the character's
  own entries (`soulBnbList`) - folded into FR-030's larger reorganization of that section.
- `admin-soul.hbs`'s "Scene ID" (Award XP to Scene) → `PowerSelect` over `scenes` (Scenes plugin's own web
  command, `filter: 'Recent'` - already a hard dependency via `Scenes.add_to_scene`, same cross-plugin reuse
  precedent as the `characters` command already used for the player pickers).
- `admin-soul.hbs`'s free-text "boon or bane" Kind field (create catalogue entry) → a native `<select>` -
  not an ID/tag, but the same class of "typo silently fails validation" problem the user asked to eliminate.

**Deliberately left alone:** the GM Review modal's "Force-Abort Any Open Roll" Roll ID field
(`soul-roll.hbs`) - it's an escape hatch for a roll that may not be in the current scene's own pending list at
all (the only other force-abort path is scoped to `scene_id`), so a dropdown there would need a new
system-wide "all open rolls" fetch; flagging as a known follow-up rather than building it speculatively.
Catalogue Tag fields (chargen B&B, admin catalogue create) also stay free text deliberately - a Tag is new
data staff are choosing for a record that doesn't exist yet, not a reference to something already there.

---

### FR-026: Roll modal dropdown overflow, and the manual B&B picker made always-visible

**Status:** ✅ Done (`webportal/templates/components/soul-roll.hbs`)

**Requested:** 2026-07-25, live testing (with screenshot): "Roll is looking better, but the dropdowns need to
be narrower to fit into the modal... The suggest bnb is coming up, but there's nowhere for players to add
their own. Add a dropdown to the screen with suggestions, with all bnbs, for players to choose from."

**Dropdown width:** The Skill/Difficulty `PowerSelect`s sat in `col-6` columns with no truncation, so a long
Skill name plus rating (e.g. "Persuasion (10)") could push the trigger wider than its column. Added
`@triggerClass="text-truncate"` to both, and widened the breakpoint to `col-12 col-sm-6` so they stack
instead of overflowing on a narrow viewport.

**Manual B&B picker:** This already existed as of the BUG-018 fix (`manual_options` on
`SoulRollApi.get_player_candidate_view` - every owned, unresolved B&B not already offered as a suggested
candidate, regardless of which Skill it's tied to) but the `PowerSelectMultiple` was wrapped in
`{{#if this.manualOptions.length}}`, so it disappeared entirely whenever a character had nothing left to
manually add - which looks identical to "this feature doesn't exist" rather than "you have nothing else to
add." Removed that conditional; the picker now always renders, disabled with a "No other Boons/Banes
available" placeholder when `manualOptions` is empty instead of vanishing.

---

### FR-025: XP spend on the profile is always by 1, not an arbitrary amount

**Status:** ✅ Done (`webportal/components/soul-xp.js`, `webportal/templates/components/soul-xp.hbs`)

**Requested:** 2026-07-25, live testing: "In the profile for the player, let's take out the 'adjust by' #
selector and just make it always by 1. They can use it multiple times to go up more than one."

Removed the "Increase by" number input and `spendAmount` state; `previewSpend`/`confirmSpend` now always
send `amount: 1` to `soulXpSpend`. The Preview button reads "Preview +1" so its effect is unambiguous
without the removed field.

---

### FR-024: B&B display shows associated Skills, drops the ID, and capitalizes Kind/Level

**Status:** ✅ Done (`plugin/public/soul_bnb_api.rb`, `plugin/commands/soul_sheet_cmd.rb`,
`plugin/locales/locale_en.yml`, `webportal/templates/components/soul-bnb.hbs`)

**Requested:** 2026-07-25, live testing: "The bnb display should show the impacted skills, also in the MUSH
'soul' command. Let's remove the #, since they will mostly use the key for it. And put the key beside it
like 'Artifact [artifact]' instead. Under Kind and Level, capitalize Boon/Bane and Major/Minor, etc."

`SoulBnbApi.get_character_entry_public` - the shared serializer behind the profile's B&B table/detail modal,
the roll modal's candidate list, and `+bnb`'s own lookups - now includes `skills` (associated Skill display
names, joined) and capitalizes `kind`/`level_state` for display (`.to_s.capitalize`; the raw lowercase model
values are still used internally for level-modifier lookups and `level_definitions` config keys, only the
returned hash changed). The MUSH `soul` command (`SoulSheetCmd`) gained the same Skill-name list in its
`soul.bnb_summary` line, computed the same way (catalogue tag/name-map already established for the chargen
web handler's own catalogue listing). `soul-bnb.hbs`'s table dropped the leading `#{{entry.id}}` and now
reads `{{entry.name}} [{{entry.tag}}]`, added a Skills column, and the detail modal shows the same list.

---

### FR-023: Profile staff panel - single "Correct" button with a Skill/Aspect dropdown, Resonance correction removed

**Status:** ✅ Done (`webportal/components/soul-staff.js`, `webportal/templates/components/soul-staff.hbs`)

**Requested:** 2026-07-25, live testing: "Let's remove adjusting resonance, since that's not supposed to be
something getting done very often. They can do it on the admin page if it really needs doing. Under Adjust
Skill or Aspect -- make a dropdown of skills and aspects. Can we just have one 'Correct' button that fixes
whichever one it is, rather than 'Correct Skill' 'Correct Aspect'?"

Replaced the free-text "Skill or Aspect key" `<Input>` and the two separate buttons with a single `PowerSelect`
(`frameworkOptions`, loaded from the existing `soulFramework` command - Aspects and Skills tagged with
`kind: 'aspect'`/`'skill'`) and one "Correct" button that reads `kind`/`key` off the selected option before
calling `soulFrameworkCorrect` - no change to that command's contract, which already took `kind` as an
argument. Removed the "Adjust Resonance" `<details>` section (`correctResonance` action, `soulResonance`
call) entirely; `SoulResonanceApi.correct`/the `soulResonance` web command are untouched and still reachable
via the MUSH staff command `+soul/resonance` (`soul_staff_cmd.rb`) - **note: there is currently no
web-portal path to it at all, on the profile or the `/admin-soul` page** (the admin page comment describing
the split assumed the profile panel would keep it). If Resonance correction needs a web UI, it should be
added to `/admin-soul` rather than restored here - flagging as open, not building it speculatively. The
audit log display (previously nested under "Adjust Resonance", unrelated to Resonance specifically) moved to
its own "Audit Log" `<details>` section so it isn't lost.

---

### FR-022: Removed the profile Sheet's "Effective" Skill column

**Status:** ✅ Done (`plugin/web/soul_sheet_web_handler.rb`, `webportal/templates/components/soul-sheet.hbs`)

**Requested:** 2026-07-25, live testing: "On the profile, what is the 'effective' column for the skills? None
of them show anything?" then, after explanation: "No, remove it. Players don't need that level of detail."

**Background:** The column showed `SoulCharacterApi.get_effective_base` - Skill rating plus the rounded
Aspect contribution (`round(aspect_rating * 0.20)`, FINAL REQ-030) - the exact base modifier a roll builds
on. It wasn't broken; it just equalled the Rating column for most characters, since an Aspect needs a
rating of 3+ before its contribution rounds up to even +1 at the default 0.20 weight, which made it look
inert during early testing. Decided this is more mechanical detail than players need on their own Sheet.

**Fix:** Removed the "Effective" column from `soul-sheet.hbs` and stopped including `effective_base` in
`SoulSheetWebHandler#handle`'s per-Skill hash. `SoulCharacterApi.get_effective_base` itself is untouched -
`SoulRollApi` still calls it directly to compute the actual roll math; only the Sheet display changed.

---

### FR-021: Boon/Bane level and Skill fields converted to dropdowns everywhere they're entered

**Status:** ✅ Done (`webportal/components/soul-chargen.js`, `webportal/templates/components/soul-chargen.hbs`,
`webportal/components/soul-bnb.js`, `webportal/templates/components/soul-bnb.hbs`,
`webportal/components/soul-staff.js`, `webportal/templates/components/soul-staff.hbs`,
`webportal/routes/admin-soul.js`, `webportal/controllers/admin-soul.js`, `webportal/templates/admin-soul.hbs`)

**Requested:** 2026-07-25, live testing: "I would also like to copy the boon/bane dropdown selection (and
levels) from chargen to the admin panel and page. Also in the modal the request to add one from the web,
let's make the level a dropdown similarly. In all places, I would also like the associated skill to be a
dropdown of available skills (but able to select more than one, like the player-dropdown)."

**Background:** Chargen's B&B picker already used a catalogue `PowerSelect` and a free-text comma-separated
Skill `<Input>`. Every other surface that grants, requests, or configures a B&B - the profile page's "Add a
Boon/Bane" modal (`soul-bnb.hbs`), the profile staff panel's Grant flow (`soul-staff.hbs`), and the admin
page's catalogue create/edit-skills forms (`admin-soul.hbs`) - used free-text `<Input>`s for level and Skill
keys instead, which is error-prone (typos silently fail to match a real Skill/level) and inconsistent with
the player-dropdown convention already used elsewhere (e.g. `admin-soul.hbs`'s XP-to-Player picker).

**Implementation:** Level fields became native `<select>`s (minor/major/legendary, matching chargen).
Skill fields became `PowerSelectMultiple` bound to the config-driven Skill catalogue
(`SoulFrameworkApi.get_skills`, already exposed as `available_skills` on `soulBnbCatalogue`'s response),
following the same pattern as the existing player-name `PowerSelect`s. Chargen's own conversion (multi-select
Skill picker replacing the comma-split `<Input>`, plus a `(not this.bnbSkills.length)` fix for the
empty-array-is-truthy footgun in the Add button's disabled check) landed earlier in this batch alongside
BUG-018's fix; this entry covers the remaining three surfaces:
- `soul-bnb.hbs`'s "Add a Boon/Bane" modal: Level `<Input>` → native `<select>`; Skill `<Input>` →
  `PowerSelectMultiple` over `availableSkills`.
- `soul-staff.hbs`'s "Adjust Boons and Banes" → Grant subsection: added a catalogue `PowerSelect`
  (`soul-staff.js` gained `loadCatalogue()`, fetching `soulBnbCatalogue` on `didReceiveAttrs`), a Level
  `<select>`, and a Skill `PowerSelectMultiple`. This also fixed a real pre-existing bug: `bnbGrant()` never
  sent `associated_skills` at all, so any catalogue entry without fixed Skills would grant with no Skill
  association - same class of bug as BUG-015 on the chargen side, just never reported because staff rarely
  exercises this path against a live game.
- `admin-soul.hbs`'s catalogue section: the create-form's Skill field (comma-separated `<Input>`) → a
  `PowerSelectMultiple`; the edit-skills subsection's catalogue-ID-or-tag `<Input>` → a `PowerSelect` over
  `model.catalogue.entries`, and its Skill-keys `<Input>` → a `PowerSelectMultiple`. `admin-soul.js`'s route
  now fetches `catalogue: this.gameApi.requestOne('soulBnbCatalogue', { per_page: 1000 }, 'home')`
  alongside `requests`/`characters`; the controller's `bnbCreate`/`bnbSetSkills` actions now map selected
  Skill/entry objects to key/id arrays instead of parsing free text.

All four surfaces now share the same catalogue-`PowerSelect` / level-`<select>` / Skill-`PowerSelectMultiple`
pattern. No backend/API changes were needed - `soulBnbCreate`, `soulBnbSetSkills`, and `soulBnbGrant` already
accepted `skill_associations`/`associated_skills` as arrays; only the web layer was ever sending
mis-shaped or missing data.

---

### FR-020: Roll results now always post to the scene transcript (reverses the original private-by-design decision)

**Status:** ✅ Done (`plugin/public/soul_roll_api.rb`, `plugin/web/soul_roll_web_handler.rb`,
`webportal/components/soul-roll.js`, `webportal/templates/components/soul-roll.hbs`, `README.md`, spec)

**Requested:** 2026-07-25, live testing: "Roll results should always be posted to the scene." (with a
screenshot of the old "This result has not been posted to the scene..." message).

**Background:** Phase 9's Scene Page Roll Widget work made a deliberate design decision that roll results
would stay private to the roller, never auto-posting to the scene transcript (see
`docs/spec/IMPLEMENTATION_CHECKLIST.md`'s 2026-07-24 entry) - REQ-031 never actually mandates this either
way (it only requires notifications not leak private data), so this was purely an implementation choice,
not a spec conflict, and safe to reverse.

**Implementation:** verified the real posting mechanism against AresMUSH core rather than inventing one -
`FS3Skills.emit_results` (`plugins/fs3skills/helpers/rolls.rb`) is the one existing precedent for a
plugin posting roll results into a scene, and it calls `Scenes.add_to_scene(room.scene, message)` with no
explicit `character` argument, defaulting to `Game.master.system_character` rather than attributing the
post to the roller. `SoulRollApi.resolve_pending` now calls a new private `post_to_scene(character, roll)`
after creating the `Roll` record: resolves `roll.scene_id` to a real `Scene` (a no-op, not an error, if
there isn't one - e.g. a MUSH `+roll` made outside any scene) and posts a system-authored pose built from
the Skill name, `degree_of_success` (humanized), final result, and difficulty. `Scenes.add_to_scene`'s own
guards (disabled logging, blank pose) are trusted rather than duplicated. `resolve_pending` and the web
`soulRollSelect` response both now include `posted_to_scene`; the web roll modal shows "Posted to the
scene." instead of the old "has not been posted" disclaimer. No MUSH-side text change needed - the player
sees the pose land in the room directly.

---

### FR-019: Roll UI cleanup batch — GM-less scenes, owned-B&B dropdown, display polish

**Status:** ✅ Done (`plugin/public/soul_roll_api.rb`, `plugin/web/soul_roll_web_handler.rb`,
`plugin/commands/soul_roll_cmd.rb`, `plugin/soul.rb`, `webportal/components/soul-roll.js`,
`webportal/templates/components/soul-roll.hbs`, help/docs, specs)

**Requested:** 2026-07-25, live testing, several related requests in quick succession:
1. "We need to revisit the GM roll too, since if you use it in a scene with no GMs, it's just stuck."
2. "And let's hide this if there are no pending rolls." (Open Pending Rolls section, always shown)
3. "I don't think we display the whole roll history -- maybe just the last 5, or it will get overwhelming
   fast."
4. "the player-selected bnbs should come from a dropdown of ones they have. But needs multi-select."
5. "Don't show the target for the difficulties, just the names." / "instead of 'rating', let's do the
   skills like Strength (0), Speed (1)." / "This should make them small enough that skill and diff can fit
   on the same line."

**GM-less scene fix:** a GM-assisted roll's only way out used to be full `/abort` (losing the roll
entirely) - there was no way to just proceed without a GM. Added `SoulRollApi.cancel_gm_request`: moves an
`awaiting_gm` pending roll to `awaiting_selection` and flips `gm_assisted` to `false`, falling back to the
roll's own `system_suggested_entries` (already computed by `start_roll` for every roll, GM-assisted or
not) via `get_player_candidate_view`'s existing branching. The eventual `Roll` record honestly reflects
that no GM ever touched it, rather than misreporting it as GM-assisted. New web op `soulRollCancelGm`
(registered in `Soul.get_web_request_handler` - see BUG-016 for why that step matters) and MUSH
`+roll/cancelgm <roll id>`, plus a "No GM Available - Proceed Without One" button on the web modal's
"Waiting for GM Review" stage.

**Owned-B&B dropdown:** `get_player_candidate_view` now also returns `manual_options` - the character's
owned, unresolved entries not already offered as system/GM candidates - so the roll selection stage's
"Other applicable owned tags" free-text field became a `PowerSelectMultiple` over real entries instead of
typed tag guessing. `soulRollSelect`'s contract didn't change (still just `tags: [...]`); only how those
tags get chosen did.

**Display polish:** Skill picker shows `Name (rating)` instead of `Name — rating N`; Difficulty picker
shows just the name, not `Name — target N`; the two now sit side-by-side (`col-6` each) now that neither
label is long. "Open Pending Rolls" section hidden entirely when there are none. Roll history in the
modal capped to the 5 most recent (`get_roll_history(enactor, limit: 5)` - the MUSH `+roll/history`
command keeps the full default limit, since that's an explicit on-demand lookup, not an always-visible
embedded list) and relabeled "Recent Rolls" to match.

---

### FR-018: Characters starting chargen default to R0 instead of showing "Unset"

**Status:** ✅ Done (`plugin/public/soul_resonance_api.rb`, `plugin/web/soul_chargen_web_handler.rb`, spec)

**Requested:** 2026-07-25, live testing: "Instead of saying unset, let's set all characters starting
chargen to R0, if possible."

`SoulResonanceApi.lock_at_approval` already defaulted an untouched Resonance to R0, but only at approval -
during chargen itself, a character who hadn't yet run `+soul/cg/resonance` or used the web picker saw
"Unset" the whole time. Added `SoulResonanceApi.default_at_chargen(character)`, called from
`SoulChargenWebHandler.status` (the single shared status method both `+soul/cg` and the web chargen tab
use) before `resonance_label` is computed: fills Resonance to R0 the first time chargen status is checked
for a character who hasn't set one, as long as Resonance is enabled and the character isn't already
approved. Not locked - the player can still change it right up until approval, same as any explicit
choice; `.lock_at_approval` still does the actual finalizing. A no-op if a value is already set, so it's
safe to call on every status check, and it retroactively fixes existing mid-chargen characters the next
time they check status, not just newly-created ones.

---

### FR-017: Admin page section renames, a config-editing note, and an "Award XP to Players" section with a character-picker dropdown

**Status:** ✅ Done (`webportal/routes/admin-soul.js`, `webportal/controllers/admin-soul.js`, `webportal/templates/admin-soul.hbs`)

**Requested:** 2026-07-25, live testing: "bnb requests is fine. Next section, 'View Available Aspects and
Skills' (add a note to the section that these need to be changed in the config section), BNB catalogue is
fine, 'Award XP to Scene' -- let's add an 'Award XP to Players' as well. Use a dropdown of player names
like we did for Inklings, anywhere that player names need to be entered manually."

**Renames:** "Framework and configuration" → "View Available Aspects and Skills" (added a note that
adding/removing/renaming an Aspect or Skill happens in the game's SOUL config, not on this page - this
section only ever showed the current list plus a config-validation button, it never edited anything).
"Scene Experience Award" → "Award XP to Scene". "Pending Boon/Bane Requests" and "Boon & Bane catalogue"
left as-is (confirmed fine).

**New:** "Award XP to Players" section - award/correct XP for any single character from the admin page,
without needing to be on that character's own profile first. Uses a `PowerSelect` character-picker
dropdown (`@options={{this.model.characters}}`, `@searchField="name"`) instead of a free-text character
field, matching Inklings' own admin-page pattern (`inkling-create-form.hbs`'s Main Character picker) -
verified against real AresMUSH source (`plugins/profile/web/characters_request_handler.rb`) that the
underlying `"characters"` command with `select: "all"` returns every character (not just approved ones)
sorted by name, exactly what a staff picker needs. The route's `model()` now fetches both the pending-
request queue and this character list via `RSVP.hash`, mirroring `admin-inklings.js`'s own route shape.

---

### FR-016: `manage_permission`'s default changed from `manage_jobs` to `manage_apps`

**Status:** ✅ Done (`game/config/soul.yml`, `plugin/soul.rb`, `plugin/help/en/manage_soul.md`,
`docs/reference/Default_Config.md`, `docs/reference/Permissions.md`, `custom-install/website_top_navbar.snippet.yml`, specs)

**Requested:** 2026-07-25, live testing: "Permissions for SOUL should be manage_apps not manage_jobs."

Changed `Soul.can_manage_soul?`'s fallback and `game/config/soul.yml`'s shipped default from `"manage_jobs"`
to `"manage_apps"`, and updated every doc/help/snippet example that illustrated the default value to match.
`manage_apps` is also Inklings' own `manage_permission` default (already the real precedent this project's
docs cite for the config key's own existence), so this makes SOUL's out-of-the-box staff permission match
its sibling plugin rather than borrowing Jobs'. Existing installs that haven't set `manage_permission`
explicitly in their own `game/config/soul.yml` need to either add `manage_permission: manage_jobs` to keep
the old behavior, or grant `manage_apps` to their SOUL staff role, before reloading config.

---

### FR-015: Profile tab rework — self-service B&B requests, "only what I've chosen," and a real admin page

**Status:** ✅ Done (backend: `plugin/models/bnb_request.rb`, `plugin/public/soul_bnb_api.rb`,
`plugin/web/soul_bnb_web_handler.rb`, `plugin/commands/soul_bnb_cmd.rb`, `plugin/locales/locale_en.yml`,
specs; frontend: `webportal/components/soul-bnb.js`/`.hbs`, `soul-sheet.js`/`.hbs`, `soul-staff.js`/`.hbs`,
new `webportal/routes/admin-soul.js`, `webportal/controllers/admin-soul.js`, `webportal/templates/admin-soul.hbs`;
install: `custom-install/custom-routes.snippet.js`, `custom-install/website_top_navbar.snippet.yml`,
updated `profile-custom.snippet.hbs`; docs: `README.md`, `docs/reference/Commands.md`, `plugin/help/en/soul_bnb.md`)

**Requested:** 2026-07-25, live testing. User's three-part request, verbatim:
1. "There is no way to add a new bnb from a profile."
2. "The catalogue of b&bs should be listed on the profile, only those the player has chosen. We will have
   a ? beside the spot for players to add new bnbs and that will open a modal that will show a paginated
   list. If pagination is not possible in modals, we can build a new page."
3. "We are going to need a staff page... for management tasks, such as adding new bnbs to the catalogue.
   On the profile tab, the staff commands should be ONLY for the player currently in question. The whole
   administration section can be moved to an admin-only page, that gets linked under admin, like Inklings.
   On the profile, staff should be able to award that player more XP and other things like that."

**Decisions confirmed with the user before implementing:**
- A player picking a Boon/Bane from the profile creates a **staff-reviewed pending request**, not an
  instant self-grant — `+bnb/grant` is staff-only everywhere else in this codebase, and this is the first
  player-initiated grant path outside chargen, so it gets the same oversight rather than becoming a silent
  exception.
- Staff split: character-scoped actions (XP award/correct, Resonance correction, B&B
  grant/progress/resolve/restore/delete, Culmination management, audit) stay on the profile, re-scoped to
  the character being viewed with no free-text character field. Global/catalogue-wide actions (config
  validation, catalogue creation and Skill-association edits, scene-wide XP award, and the pending-request
  review queue) move to the new `/admin-soul` page.

**Implementation:**
- New `BnbRequest` model (mirrors `Culmination`'s propose/approve/deny shape, not `CharacterBnbEntry`'s —
  nothing here is mechanically live until approved, so a pending request can never leak into roll
  suggestions, ratio checks, or the sheet). `SoulBnbApi.request`/`.approve_request`/`.deny_request`/
  `.get_requests` added; `.approve_request` converts to a real grant via the existing `.grant` path
  (`source: "[Player Request]"`).
- `SoulBnbApi.get_catalogue_page` added for the picker modal's pagination — reuses Inklings'
  `page`/`total_pages`/`total_count` convention (`admin-inklings.js`) rather than inventing a new shape,
  since research this session found no prior art for pagination inside `BsModalSimple` specifically and
  recommended treating it as a novel combination to test carefully, not a proven-safe pattern.
- `soul-bnb.js`/`.hbs` rewritten from a full-catalogue browser into a "my Boons & Banes" widget: lists
  only entries the viewed character owns plus their own pending/denied requests, with a "+" button
  (visible only when viewing your own profile, `isSelf`) opening a paginated catalogue picker → request
  form (level, Skill picker shown only when the chosen entry has no fixed Skills, explanation). Takes a
  `character` arg like every other profile widget (Sheet, Xp) so staff viewing another character's
  profile see *that* character's B&Bs, not their own — the web op (`soulBnbList`) defaults to the caller
  but accepts an explicit character, gated the same way Sheet gates private fields (self or manage_soul).
- Removed the now-duplicate B&B table + detail modal from `soul-sheet.hbs`/`.js` (`soul-bnb` is the one
  canonical home for B&B display now); this also retires BUG-012's `bnbModalOpen` fix along with the code
  it was fixing.
- `soul-staff.js`/`.hbs` trimmed to a `character`-scoped panel: every free-text "Character" input removed,
  every action implicit on the profile being viewed. Framework/config validation, B&B catalogue creation,
  and scene-wide XP award removed entirely (moved to admin).
- New `/admin-soul` page (`webportal/routes|controllers/admin-soul.js`, `templates/admin-soul.hbs`) —
  pending B&B request queue (approve/deny), framework view + config validation, catalogue creation +
  Skill-association edits (`soulBnbSetSkills`, previously MUSH-only via `+bnb/skills`), scene-wide XP
  award. Wired in via the same two-snippet pattern Inklings established (`custom-routes.snippet.js` for
  the Ember route, `website_top_navbar.snippet.yml` for the Admin dropdown entry) — confirmed against
  Inklings' real route/controller/template that the server-side permission check (`can_manage_soul?`,
  already enforced by `SoulStaffWebHandler`/`SoulBnbWebHandler`) is the actual gate, not the route itself
  or the nav link's visibility.
- MUSH parity: `+bnb/request`, `+bnb/requests`, `+bnb/approve`, `+bnb/deny` added alongside the web ops,
  matching this codebase's established every-API-method-has-both-surfaces convention.
- A real Handlebars bug caught by a brace-balance self-check before commit: `soul-bnb.hbs`'s Skill list
  used `{{unless @last}}...{{/unless}}` (missing the `#` block-helper prefix) — fixed to `{{#unless}}`.

**Not yet confirmed against the live game** — this is a large rework touching every layer; needs a full
pass through Step 12's updated verify checklist in `README.md` before it can be marked verified.

---

### FR-014: Web chargen no longer blocks already-approved characters (MUSH `+soul/cg` still does)

**Status:** ✅ Done (`plugin/web/soul_chargen_web_handler.rb`, spec)

**Requested:** 2026-07-25, live testing: user's initial premise was that this check is fully redundant since "AresMUSH already blocks chargen for those who are approved" — verified against real AresMUSH source and that's only true for the *ordinary* case (a non-approver's own approved-character chargen page redirects home before any SOUL component mounts, via `chargen_char_request_handler.rb`). Characters with approve permission are exempt from that core block and can still load their own already-approved chargen page.

**Accepted trade-off (explicitly chosen by the user over two safer alternatives):** `SoulChargenWebHandler` always operates on `request.enactor` (never a separately-targeted character), and neither `SoulCharacterApi.set_skill_rating`/`set_aspect_rating` nor `SoulBnbApi.grant` have any approval/lock check of their own (only `SoulResonanceApi.set_resonance` does). So an approver revisiting their own already-approved chargen page can grant themselves free Skill/Aspect points and Boons/Banes through the chargen budget, bypassing normal XP cost. This is a narrow, staff-only edge case, not reachable by ordinary players, and the user chose to accept it as-is rather than add lock checks to the underlying APIs.

**Fix:** removed the `return { error: t('soul.chargen_approved') } if character.is_approved?` gate from `SoulChargenWebHandler#handle`. `SoulChargenCmd#check_permission` (the `+soul/cg` MUSH command) keeps its own identical check — the user was explicit this should stay gated on the MUSH side; it isn't provably redundant there either (`+soul/cg` is a standalone command under `soul`, independent of core's own chargen command tree, so nothing upstream blocks it).

---

### FR-013: SOUL data doesn't appear in `+app`/`+app/review` — missing `custom_app_review` hook

**Status:** ✅ Done (`plugin/soul.rb`, `custom-install/custom_app_review.snippet.rb`, `README.md`)

**Requested:** 2026-07-25, live testing: user added `soul %{name}` to `app_review_commands` (per FR-008) and still didn't see SOUL data in review. Traced the actual cause together with the user rather than assuming the config change was wrong: **`+app <character>` and `+app/review <character>` are two separate core AresMUSH commands** (`AppCmd` vs. `AppReviewCmd`) — `app_review_commands` is only ever read by `+app/review`. The user had been running (and screenshotting) bare `+app`, whose output is the demographics/background/hooks completeness checklist, rendered by `AppTemplate`. `app_review_commands` has no effect on that view or on the web portal's own app-review page (both render the same `AppTemplate`), no matter what's in the list.

**Root cause of the actual gap:** `AppTemplate` has exactly one plugin extension point for arbitrary extra content — `Chargen.custom_app_review(char)`, a hook method in a game-side file (`plugins/chargen/custom_app_review.rb`, stock body `return nil`) — the same hook Inklings already uses on this game (confirmed by the user: *"We added Inklings to it, so it is doable"*). SOUL never shipped an install snippet for it, so nothing was ever wired up for the plain `+app` checklist or the web app-review view, regardless of the `app_review_commands` change.

**Done:**
- Added `Soul.app_review(char)` (`plugin/soul.rb`) — the single public entry point a game's `custom_app_review.rb` calls into. Returns `nil` (shows nothing) if SOUL is disabled or the character hasn't touched any SOUL chargen step yet (no Resonance set, no Skill/Aspect points spent, no B&B selected) — an application that hasn't reached `+soul/cg` yet shouldn't show a wall of "unspent points" warnings before the player has had a chance to visit it. Otherwise shows Resonance (if enabled), Skill/Aspect points spent vs. allowed, and whether the Boon/Bane ratio is currently satisfied — reusing `SoulChargenWebHandler.status` (the same data FR-009's `+soul/cg` readiness indicators already show) as the single source of truth, formatted with `Chargen.format_review_status`/`t('chargen.ok')`/`t('chargen.not_set')` to match the rest of the checklist's visual style exactly.
- New `custom-install/custom_app_review.snippet.rb`, matching this project's established two-option snippet pattern (method is stock-empty / method already has content from another plugin like Inklings, with a documented combine-instead-of-overwrite pattern since only one `return` can execute).
- README's Step 4 corrected: previously implied `app_review_commands` alone was sufficient ("show the SOUL sheet during app review... controls what staff's `app <character>` review command runs" — conflated the two commands, inherited from FR-008 not yet knowing about this distinction). Now explains both commands need separate changes, with the new snippet documented as the second one.
- Along the way, found and removed a real but harmless dead-code duplicate in `plugin/soul.rb#get_cmd_handler`: two identical `when "cg", "cg/resonance", ...` branches for `SoulChargenCmd` (the second, missing `cg/catalogue`, was unreachable — Ruby's `case` takes the first match) — leftover from an earlier merge, cleaned up while already editing this file.
- New `plugin/spec/soul_spec.rb` (this project's first direct coverage of the root `Soul` module) covers the disabled/no-data/nil-character/has-data/Resonance-enabled cases for `.app_review`.

**Correction (same day):** the OPTION B example in the first version of the snippet called a fabricated method, `AresMUSH::Inklings.app_review(char)` — invented as a "hypothetical" placeholder rather than verified against Inklings' real source, exactly the mistake this project's own Plugin Development Guide warns against ("Don't wire a hard integration against another plugin's event/field names you haven't verified"). The user pasted it as-is and hit `undefined method 'app_review' for module AresMUSH::Inklings`. With the actual `ares-inklings-plugin` repo available this session, verified the real method is `Inklings.get_app_review_issues(char)` (`plugin/inklings.rb`), and that Inklings' own real `custom_app_review.rb` snippet uses a `messages = []` / `messages.join("\n")` structure, not the invented `parts.compact.join("%r%r")` pattern the first draft used. Rewrote the snippet's OPTION B to build on Inklings' actual, verified structure instead of inventing an incompatible second pattern, and changed `Soul.app_review`'s own line-join from `"%r"` (SOUL's usual MUSH markup) to `"\n"`, matching `Inklings.get_app_review_issues`' real convention for this specific hook.

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

**Follow-up gap closed (2026-07-25):** the requirement above only guarded *creation* — a catalogue entry made before this fix (or on a game with existing data) still has empty `skill_associations`, and nothing stopped it from being granted to a character, including during chargen's `+soul/cg/bnb`. Found via user report: *"chargen bnb not requiring the skill switch"*. At the time, closed the loophole by making `SoulBnbApi.grant` refuse any catalogue entry with empty `skill_associations` — see the design correction immediately below, which changes where this actually lives.

**Design correction (2026-07-25, same day) — Skill association moved from the catalogue to the grant:** user's direct correction: *"You put the skill in the wrong place -- it doesn't go on the catalogue entry, but when the player picks it."* Right call, and `docs/reference/Default_BnBs.md` already said so before this feature ever touched it — the Cursed/Distracted examples were documented as **"Associated Skills: Configurable per instance"** from the start, and `CharacterBnbEntry` already had its own unused `associated_skills` attribute sitting in the model, never wired up. The catalogue-level requirement added above was the wrong layer for most B&Bs (a fixed catalogue property can't represent "this Bane affects different Skills for different characters").

Reworked to match the pre-existing intent:
- `SoulBnbApi.create_catalogue_entry`'s `skill_associations` is optional again — it's now only a *fixed default* for B&Bs that always affect the same Skill(s) (e.g. Ceremonial Attunement → Ceremonial Magic). Unknown-key validation still applies when one is given.
- `SoulBnbApi.grant` gained `associated_skills:` — the Skill(s) chosen by whoever is granting it (staff, or the player via chargen), falling back to the catalogue's fixed default when omitted. At least one Skill is required from either source; stored on the actual `CharacterBnbEntry#associated_skills` field (not the catalogue).
- `SoulRollApi.get_candidate_bnbs` now reads the *instance's* `associated_skills`, not the catalogue's — matches what a specific grant actually affects.
- Syntax: `+bnb/create <kind>/<tag>/<name>[/<skill1,skill2,...>]=<description>` (Skill segment now optional), `+bnb/grant <character>/<id or tag>/<level>/<skill1,skill2,...>=<explanation>` (new optional trailing Skill segment), `+soul/cg/bnb <id or tag>/<level>/<skill1,skill2,...>=<explanation>` (same). `+bnb/skills` (the catalogue-level editor from the follow-up above) is retained, now framed as setting the *fixed default* rather than repairing a required field.
- Reverted the incorrect examples this session had already put into `Default_BnBs.md`, `Migration_From_FS3.md`, and the README's starter-B&B step (which had forced fixed Skills onto "configurable per instance" B&Bs like Cursed) back in line with the original design.
- Specs updated throughout (`soul_bnb_api_spec.rb`, `soul_bnb_cmd_spec.rb`, `soul_chargen_cmd_spec.rb`, `soul_roll_api_spec.rb`) for the new optional-at-creation/required-at-grant shape and the instance-level `associated_skills` field.

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

## BUG-021: Chargen's `+soul/cg/bnb` rejected any multi-word Skill, and the underscored key it required was never shown to players

**Status:** ✅ Fixed (`plugin/public/soul_framework_api.rb`, `plugin/commands/soul_chargen_cmd.rb`)

**Reported:** 2026-07-25, live testing: "Trying to add a two-word skill in chargen to a bnb isn't working --
ceremonial doesn't work, ceremonial magic doesn't work. Only ceremonial_magic works, but we never show that
to the player. Let's do a drop down multi-select of skills instead."

**Root cause:** `+soul/cg/bnb <ref>/<level>/<skill1,skill2>=<explanation>` split its Skill argument on commas
and passed each token straight through as a raw config key (`soul_chargen_cmd.rb`'s `parse_args`, `"bnb"`
branch) - no resolution against display names at all. Every catalogue listing the player can actually see
(`+soul/cg/catalogue`, the profile B&B table) shows the Skill's display name ("Ceremonial Magic"), never its
underscored config key ("ceremonial_magic"), so a player typing exactly what they were shown got rejected,
and the only way to succeed required knowing an implementation detail never displayed anywhere.

**Fix:** Added `SoulFrameworkApi.resolve_skill_key(input)` - passes an already-valid key through unchanged,
otherwise matches case/whitespace-insensitively against every configured Skill's key or display name
(spaces-for-underscores), falling back to the original input untouched if nothing matches (so a genuinely
unknown Skill still surfaces `SoulBnbApi.grant`'s real "Unknown Skill(s)" error instead of being silently
swallowed). Wired into `+soul/cg/bnb`'s skill-association parsing only - the specific path reported.

**Not done:** the web chargen's own B&B picker already uses a real `PowerSelectMultiple` Skill dropdown (no
free text, added earlier in this same testing round), so "let's do a drop down multi-select" is already true
there - this fix covers the MUSH command, which can't have an actual dropdown widget. The same key-vs-name
mismatch risk exists in `+soul/cg/skill`, `+soul/cg/aspect`, `+xp/spend`, and the staff Skill/Aspect
correction command, none of which were reported broken and none of which were touched here - flagging as a
known, not-yet-hit follow-up rather than fixing speculatively.

---

## BUG-020: Lowering Resonance after spending chargen points left the player unable to change any Skill or Aspect at all

**Status:** ✅ Fixed (`plugin/web/soul_chargen_web_handler.rb`, `webportal/components/soul-chargen.js`,
`webportal/templates/components/soul-chargen.hbs`, `plugin/commands/soul_chargen_cmd.rb`)

**Reported:** 2026-07-25, live testing: "In chargen, if someone spends their points and then lowers their
resonance, they are now in the negative -- but they can't even lower skills because they get the error
message. Let's make that message a warning but still allow the skill changes to go through. We'll catch it
at approval/submit time."

**Root cause:** `SoulChargenWebHandler.set_skill`/`.set_aspect` hard-rejected any allocation whose *total*
would exceed the current Resonance-derived budget, or any single rating above the current starting cap.
Both budgets are computed fresh from whatever Resonance is selected *right now* - so lowering Resonance
after already spending points could put the character over a budget that used to be valid, and every
subsequent edit (including a *decrease*, since the proposed total was still computed as "spend N of a now-
smaller M" and N only shrinks by 1 per click) kept re-triggering the same hard block. There was no way to
ever get back under budget one step at a time. The web component's own client-side guard on the +/- Skill
buttons (`rating > this.status.starting_cap`) made this worse by silently no-opping without even reaching
the server, so the buttons looked simply broken rather than erroring.

**Fix:** `set_skill`/`set_aspect` now always apply the rating change (still enforcing the true hard bounds -
unknown Skill/Aspect, rating outside `SoulFrameworkApi`'s configured min/max) and return a non-blocking
`warning` instead of an `error` when the change is over the starting cap or the total budget. The web
handler merges `warning` into the refreshed `soulChargenStatus` response; `soul-chargen.hbs` shows it as a
dismissable-on-next-action `alert-warning` instead of blocking the change. Removed the client-side cap guard
in `adjustSkill` (kept only the `rating < 0` floor) so the +/- buttons always reach the server. The MUSH
`+soul/cg/skill`/`+soul/cg/aspect` commands show the same warning via `client.emit_ooc` after their normal
success message. Also fixed `status[:skill_points_fully_spent]`/`aspect_points_fully_spent` from `spent >=
allowance` to `spent == allowance`, so an over-budget character now correctly reads "not fully spent"
instead of falsely reading "OK" in the readiness indicators, `+soul/cg`'s status display, and
`Soul.app_review`'s staff checklist - the actual mechanism the player's own "we'll catch it at
approval/submit time" plan depends on to still work.

---

## BUG-019: "SOUL Scene Tools" just dimmed the screen and got stuck

**Status:** ✅ Fixed (`webportal/components/soul-scene-tools.js`, `webportal/templates/components/soul-scene-tools.hbs`)

**Reported:** 2026-07-25, live testing: "SOUL Scene Tools just dims the screen and gets stuck there."

**Root cause:** every other SOUL modal in this codebase uses ember-bootstrap's `<BsModalSimple @open={{...}}>`,
correctly integrated with Ember's rendering lifecycle. `soul-scene-tools.hbs` was the one exception - it
used raw Bootstrap 5 markup (`data-bs-toggle="modal" data-bs-target="#soul-scene-tools-modal"`), which
depends on Bootstrap's own vanilla JS auto-scanning the DOM for these attributes. That coordination is
unreliable in an Ember SPA where Ember, not Bootstrap, owns element insertion/removal - the classic
failure mode is exactly what was reported: the backdrop (dim overlay) appears but the modal itself never
properly shows or can't be dismissed.

**Fix:** converted to `<BsModalSimple>` matching every other SOUL modal, with an explicit `toolsOpen: false`
default (per BUG-012's lesson: an unset `@open` reads as open) and `openTools`/`closeTools` actions.

---

## BUG-018: Roll candidate B&Bs were never suggested — `get_candidate_bnbs` checked the wrong field

**Status:** ✅ Fixed (`plugin/public/soul_roll_api.rb`, `docs/architecture/API_and_Hooks.md`, spec)

**Reported:** 2026-07-25, live testing: "I don't think it's pulling in the BNBs properly either; my
artifact should impact these skills, but it's telling me there's none."

**Root cause:** `SoulRollApi.get_candidate_bnbs` required `catalogue.modifier_eligible == "true"` before
suggesting a B&B for a roll. `modifier_eligible` means something entirely unrelated - "whether this Bane
can satisfy the positive-Resonance chargen requirement" (`bnb_catalogue_entry.rb`'s own comment,
`docs/reference/Configuration.md`, `docs/reference/Default_BnBs.md`) - not "can this affect a roll."
FINAL REQ-028 step 2 ("identify candidate active B&Bs") never mentions this field at all. Compounding it:
`modifier_eligible` defaults to `"false"`, and neither `+bnb/create` nor `SoulBnbApi.create_catalogue_entry`
nor the admin page's catalogue form ever exposed a way to set it `true` - so this check silently excluded
every single B&B in the game, on every roll, regardless of Skill association.

**Fix:** removed the `modifier_eligible` check entirely. Candidacy is now exactly what REQ-028 specifies:
unresolved and Skill-associated with the rolled Skill.

---

## BUG-017: Profile B&B list showed a blank "Kind" column

**Status:** ✅ Fixed (`plugin/public/soul_bnb_api.rb`, spec)

**Reported:** 2026-07-25, live testing, with a screenshot showing a granted "Artifact" entry with an empty
Kind cell: "Getting a blank 'kind' after adding from chargen. If this means either boon or bane, that
should pull automatically from the catalogue."

**Root cause:** `SoulBnbApi.get_character_entry_public` — the shared "public view of a character's B&B
entry" serializer used by `soulBnbList` (the profile's B&B widget), `+bnb`'s scene lookup, and
`SoulRollApi`'s candidate data — never included `kind` at all, even though `soul-bnb.hbs`'s table has
always rendered `{{entry.kind}}`. Not new to this session's rework; a pre-existing gap in a method that
existed since Phase 3, just never surfaced until FR-015 added a UI that actually displays `kind` per row.

**Fix:** added `kind: entry.catalogue_entry.kind` to `get_character_entry_public`'s returned hash - it was
already reading everything else off the same `catalogue_entry`, `kind` was simply missing from the list.

---

## BUG-016: New B&B request web commands were never registered in the dispatch table — "Oops! Something went wrong..."

**Status:** ✅ Fixed (`plugin/soul.rb`, `plugin/spec/soul_spec.rb`)

**Reported:** 2026-07-25, live testing, right after FR-015's profile rework deployed: loading a profile
produced "Character not found." and "Oops! Something went wrong when the website talked to the game.
Please try again and alert staff is the problem persists." The profile still loaded and the SOUL tab still
opened, so this wasn't fatal, just noisy.

**Root cause:** `SoulBnbWebHandler#handle`'s own `case request.cmd` recognizes `soulBnbList`,
`soulBnbRequest`, `soulBnbRequestsList`, `soulBnbRequestApprove`, `soulBnbRequestDeny`, and
`soulBnbSetSkills` (all added for FR-015), but `Soul.get_web_request_handler` — the actual dispatch table
core AresMUSH's `Dispatcher#on_web_request` consults to decide which handler class even gets to run for a
given `cmd` — was never updated to route them there. An unrecognized `cmd` never reaches any handler at
all; core's dispatcher (`engine/aresmush/commands/dispatcher.rb`) falls through to its own generic
fallback, the exact "Oops! Something went wrong when the website talked to the game" string, instead of
ever reaching `SoulBnbWebHandler`'s real logic. `soul-bnb.js` calls `soulBnbList` on every profile-tab
mount, so this fired immediately on every profile page load. The registration list and a handler's own
internal `case` are two separate places that must be kept in sync by hand — nothing enforces it, and this
is exactly the kind of gap that's invisible until it's exercised live.

**Fix:** added the six missing command names to `Soul.get_web_request_handler`'s `soulBnb*` `when` clause.
Added a regression spec (`Soul.get_web_request_handler` describe block in `soul_spec.rb`) that asserts
every command string used anywhere in this plugin routes to its expected handler class, so a future
addition to a handler's own `case request.cmd` that forgets this step fails a test instead of shipping
silently.

**Still open:** the separate "Character not found." error reported alongside this was NOT reproduced from
this root cause (an unrouted command never reaches the code that returns that specific message) - it must
come from an already-correctly-routed handler (Sheet, History, Culminations, or Audit all return exactly
this string when `Character.find_one_by_name` fails). Plausibly a pre-existing transient race on initial
profile load that BUG-014's fix (no longer silently redirecting home on any error) simply made visible for
the first time, rather than a new bug - but not confirmed. Needs retesting after this fix and BUG-014 to
see if it still reproduces, and if so, exactly which action or component triggers it.

---

## BUG-015: Web chargen's "Add a Boon or Bane" form had no way to specify the affected Skill

**Status:** ✅ Fixed (`plugin/web/soul_chargen_web_handler.rb`, `webportal/components/soul-chargen.js`,
`webportal/templates/components/soul-chargen.hbs`, spec)

**Reported:** 2026-07-25, live testing: "bnbs do not have a spot to take an affected skill but won't save
without one."

**Root cause:** FR-011's design correction (2026-07-25, same day) moved Skill selection from the
catalogue entry to grant time for "configurable per instance" B&Bs (most of them) — `SoulBnbApi.grant`
requires at least one Skill from somewhere, either the catalogue's own fixed default or an explicit
`associated_skills:` argument. The MUSH side (`+soul/cg/bnb`) was updated for this in the same change. The
web chargen form was not: `soul-chargen.hbs`'s "Add a Boon or Bane" section had a catalogue picker, a
level selector, and an explanation field, but no Skill input at all, and `soul-chargen.js`'s `addBnb()`
never sent `associated_skills`. Selecting a catalogue entry with no fixed Skill and clicking Add always
hit `SoulBnbApi.grant`'s "has no fixed Skill configured" error.

**Fix:** `catalogue_hash` (used for `status.catalogue`) now includes `has_fixed_skills`. The template shows
a comma-separated Skill input (reusing the character's own Skill list, already present as `status.skills`)
only when the selected entry lacks a fixed default, and the Add button is disabled until one is given in
that case. `addBnb()` now sends `associated_skills`.

---

## BUG-014: Web chargen (and most of the SOUL web portal) redirected to the homepage on any validation error instead of showing it inline

**Status:** ✅ Fixed (`webportal/components/soul-chargen.js`, `soul-bnb.js`, `soul-staff.js`,
`soul-culmination.js`, `soul-history.js`, `soul-sheet.js`, `soul-scene-tools.js`, `soul-xp.js`)

**Reported:** 2026-07-25, live testing: "trying to spend too many points throws the user back to the
homepage with an error that it's too many -- just give them an inline warning."

**Root cause:** confirmed against the real `ares-webportal/app/services/game-api.js` (cloned during this
session's earlier investigation): `requestOne(cmd, args = {}, transitionToOnError = 'home')` always shows
a toast via `flashMessages.danger` on any `response.error`, **and**, unless the caller explicitly passes
`null` for the third argument, also calls `router.transitionTo('home')` — its own comment says exactly
this: "Pass null to transitionToOnError to stay on the page (so you can show a failure message)."
`soul-chargen.js`'s `request()` (used for every chargen mutation, including the Skill-spend budget check
the user hit) called `requestOne` with only two arguments, so every validation error — over-budget Skill
spend, invalid Resonance, a rejected B&B pick — redirected home instead of showing the inline `error`
property the surrounding code was clearly written to display. A grep across every `soul-*.js` component
found the same omission nearly everywhere: only `soul-roll.js` consistently passed `null`. This affected
`soul-xp.js`'s `previewSpend`/`confirmSpend` (XP spend errors on the profile), `soul-staff.js` (every staff
mutation), `soul-bnb.js`, `soul-scene-tools.js`, and the read-only fetches in `soul-culmination.js`/
`soul-history.js`/`soul-sheet.js` — not just chargen.

**Fix:** added the missing `null` third argument to every `requestOne` call across all `soul-*.js`
components (and the newly-added `soul-bnb.js`/`admin-soul.js` from FR-015, which already had it in most
but not all spots). Route-level model hooks (e.g. `admin-soul.js`'s route) correctly keep `'home'`,
matching Inklings' own `admin-inklings.js` route convention — only action-triggered component/controller
calls needed the fix.

---

## BUG-013: First click on the web chargen SOUL tab showed Inklings' content instead — not a SOUL bug

**Status:** ✅ Investigated, not a SOUL defect — root cause is in `ares-inklings-plugin`

**Reported:** 2026-07-25, live testing: "first time opening the soul tab, it shows inklings, then second open it is fine."

**Root cause (verified against real Bootstrap 5.3.3 `tab.js` and both plugins' actual install snippets):** Bootstrap's tab JS tracks which pane is "active" entirely via the `.active` class on the nav `<a data-bs-toggle="tab">` trigger element, not on the pane itself — `_getActiveElem()` scans triggers, never panes, and cascades activate/deactivate from there. Inklings' own `custom-install/chargen-custom.snippet.hbs` hardcodes `class="tab-pane fade active show"` directly on its pane (so it displays by default on page load), but its paired `chargen-custom-tabs.snippet.hbs` never marks Inklings' own `<a>` trigger `.active` to match. Bootstrap therefore never registers Inklings' pane as "the tracked active one," so it's never programmatically deactivated by anything — it just stays rendered from page load and visually shows through until something else (the second click, a reflow, SOUL's own async data load finally landing) pushes it out of view. SOUL's own snippets have no `active`/`show` anywhere and are not the cause.

**Fix:** none needed in this repo. The fix belongs in `ares-inklings-plugin`'s `custom-install/chargen-custom.snippet.hbs` — either drop the hardcoded `active show` from Inklings' pane and let the page's genuine default tab own that, or add matching `active` to Inklings' own nav trigger in `chargen-custom-tabs.snippet.hbs`. Not fixed here since it's outside this repo's scope; flagging for the user to patch directly in their own already-pasted `chargen-custom.hbs`, or in the Inklings repo if that's preferred.

---

## BUG-012: Blank Boon/Bane detail modal opened automatically on the profile page's initial load

**Status:** ✅ Fixed (`webportal/components/soul-sheet.js`)

**Reported:** 2026-07-25, live testing, after BUG-007's web portal fix finally got the SOUL tab rendering. User's report: "a blank boon/bane detail modal is opening on the profile's initial load."

**Root cause:** `soul-sheet.js`'s `bnbModalOpen` property, bound to `<BsModalSimple @open={{this.bnbModalOpen}}>` in `soul-sheet.hbs`, was never given an explicit default — it only ever got set (to `true`/`false`) by the `showBnbDetail`/`closeBnbDetail` actions. Left `undefined` on first render, `BsModalSimple` treats that as open. Every other modal-toggle flag in this same codebase (`catalogueOpen` in `soul-chargen.js`, `rollOpen`/`gmReviewOpen` in `soul-roll.js`) is explicitly defaulted to `false` on the component; this one was the one place that convention was missed, and with no `selectedBnb` set yet either, the modal opened showing nothing.

**Fix:** added `bnbModalOpen: false` alongside `isLoading: false` in `soul-sheet.js`.

---

## BUG-011: `+soul/cg/drop` only took a numeric entry ID, unlike every other B&B lookup

**Status:** ✅ Fixed (`plugin/public/soul_bnb_api.rb`, `plugin/commands/soul_chargen_cmd.rb`, docs)

**Reported:** 2026-07-25. User's exact report: *"soul/cg/drop is confusing for bnbs because it uses the # where everywhere else uses the tag."*

**Root cause:** `+soul/cg/bnb <id or tag>` (add) already accepts either the catalogue entry's numeric ID or its tag, via the same `get_catalogue_entry` dual-mode lookup every other B&B command uses (`+bnb <id or tag>`, `+bnb/grant`, etc.). `+soul/cg/drop`, alone among them, only ever accepted a bare integer — and that integer isn't even the catalogue entry's ID, it's the *character's own selection* (`CharacterBnbEntry.id`, a different ID space entirely from the catalogue's own ID/tag), which the player has no way to know except by reading it off `+soul/cg`'s status listing first.

**Fix:** `SoulBnbApi.drop_chargen_selection` now accepts either the entry ID (unchanged, backward compatible) or the catalogue entry's tag, resolved case-insensitively against the character's own still-selected chargen entries. `SoulChargenCmd`'s `entry_id` attribute renamed to `entry_ref` and its parsing no longer forces integer conversion. The web drop button is unaffected (it already sends the numeric entry ID from the rendered list, which still works). Updated `docs/reference/Commands.md` and `soul_chargen.md`; specs cover both lookup modes and case-insensitivity.

---

## BUG-010: `+xp/spend` confirmation was unusable — ambiguous preview wording, and any wrong switch silently did nothing

**Status:** ✅ Fixed (`plugin/commands/soul_xp_cmd.rb`, `plugin/locales/locale_en.yml`)

**Reported:** 2026-07-25. User's exact report: *"Advance Mind to 3 for 20 XP. Repeat with /confirm to commit. -- xp/commit, xp/spend/commit and xp/spend/aspect/commit all just do nothing."*

**Root cause, two compounding issues:** (1) The real confirmation syntax (already correct and documented in `docs/reference/Commands.md`) appends `/confirm` to the *arguments* of the exact same command — e.g. `+xp/spend/aspect mind=1/confirm` — not a separate switch. But the in-the-moment preview message players actually see (`xp_spend_preview`/`scene_xp_preview`) only said "Repeat with /confirm to commit," with no example and no indication `/confirm` belongs on the arguments, not the command. A player reasonably read that as "there's a `/confirm` (or `/commit`) switch" and tried `+xp/commit`, `+xp/spend/commit`, `+xp/spend/aspect/commit`. (2) None of those are real switches, and `SoulXpCmd#handle`'s `case cmd.switch` statement had no `else` branch — an unrecognized switch matched nothing and produced **zero output**, not even an error, which is what "just does nothing" was actually describing.

**Fix:** Added a `confirm_syntax` helper that builds the exact, copy-pasteable command from what was actually typed (`"+#{cmd.root_plus_switch} #{cmd.args}/confirm"`) and threaded it into both preview messages, which now read e.g. "Advance Mind to 3 for 20 XP. To confirm, type exactly: +xp/spend/aspect mind=3/confirm" — unambiguous and always in sync with the real required syntax (built from the live command, not a hardcoded example). Added an `else` branch to `#handle` so any unrecognized `+xp` switch now reports `dispatcher.invalid_syntax` (the same core AresMUSH message other unmatched-command cases use) instead of silently no-op'ing. New specs cover the fallback, the helper, and the preview message content.

**Not expanded to other SOUL commands:** the same `case cmd.switch` with no `else` pattern likely exists in other SOUL command files (not audited here, out of scope for this specific report) — worth a follow-up sweep if the same "wrong switch, zero feedback" complaint comes up elsewhere.

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

**Status:** ✅ Fixed (prior session's `this.`-prefix fix was real but incomplete; the actual remaining cause is fixed below)

**Reported:** 2026-07-24/25, `docs/development/mischief_bug_list.md` items 4 and 6. User's reports: the web chargen tab loaded nothing and the profile page threw `WeakMap key null must be an object or an unregistered symbol`; separately, navigating to any page after loading a profile threw `More context objects were passed than there are dynamic segments for the route`.

**Root cause:** two independent issues. (1) Every `soul/*` Ember template referenced component properties without the `this.` prefix (e.g. `{{rollOpen}}`, `{{selectedSkill}}`, `{{candidates}}`) — implicit unprefixed property lookup that this portal's Ember version no longer resolves reliably, so these properties read as `null`/`undefined` at points the framework's internals (a `WeakMap`) require a real object, throwing. (2) Chargen's permission gate incorrectly required `Soul.can_play?` in addition to `is_approved?` (the same class of bug as BUG-005, independently present in an earlier version of this code path), and the chargen component silently discarded any API error instead of surfacing it — so an unapproved character's chargen tab looked empty with zero diagnostic signal. The route-transition error was a cascading failure once the primary `WeakMap` exception put the router in a broken state.

**Fix (prior session, ~20 commits titled "Fix SOUL profile and chargen web UI"):** every `soul/*` template's component-property references were updated to the `this.`-prefixed form (`roll.hbs`, `staff.hbs`, `sheet.hbs`, `scene-tools.hbs`, `xp.hbs`, `history.hbs`, `culmination.hbs`, `chargen.hbs`, `bnb.hbs`); the redundant `can_play?` chargen gate was removed; `chargen.js`'s `refreshStatus` now surfaces a failed status fetch as a real error instead of a blank tab. **Verified with a full grep audit** of every `soul/*` `.hbs` file for any remaining unprefixed component-property reference (as opposed to a correctly-unprefixed `{{#each ... as |x|}}` block param) — none found, and this part of the fix is real and holding.

**This audit was necessary but not sufficient — the actual persisting cause (2026-07-25):** the user rebuilt and redeployed twice (`website/deploy` + a server reboot) after the above and still hit the *identical* error, profile page failing to load immediately, before ever touching the SOUL tab. The prior fix only ever touched SOUL's own component templates (`web-portal/app/templates/components/soul/*.hbs`) — it never touched the separate `custom-install/*.snippet.hbs` files that *mount* those components into the profile/chargen/live-scene pages, which the user pastes into files their game already owns (`profile-custom.hbs`, `chargen-custom.hbs`, `live-scene-custom-play.hbs`). Those snippets invoked SOUL's components with classic curly-brace, slash-namespaced syntax (`{{soul/sheet character=this.char.name}}`, `{{soul/chargen}}`, etc.). The user's own `profile-custom.hbs` (shared with a working Inklings integration) made the asymmetry visible directly: Inklings' component is invoked as `{{inklings-tab ...}}` — a flat, non-namespaced name — and works; every `{{soul/...}}` invocation, all namespaced with a slash, sat in the same file and crashed the page immediately on render (Bootstrap tab panes are all rendered on page load, not lazily per-tab, so this fires regardless of which tab is active).

**Fix (partial, insufficient on its own):** converted every `custom-install/*.snippet.hbs` mounting invocation from curly-brace slash syntax to angle-bracket syntax (`<Soul::Sheet @character={{this.char.name}} />`, `<Soul::Chargen />`, `<Soul::Roll @scene={{this.scene}} @custom={{this.custom}} />`, etc.). This did not fix the crash — it changed the error from `WeakMap key null must be an object or an unregistered symbol` to `resolvedDefinition is null`, then (after further live testing) to the real underlying error: `Attempted to resolve 'soul/sheet', which was expected to be a component, but nothing was found.` That message finally pointed at the actual problem: the component was never present in the built `ares-webportal` app at all.

**Actual root cause (found 2026-07-25 via source verification against `/workspace/aresmush`):** this repo's web portal component source lived at `web-portal/app/components/...` / `web-portal/app/templates/components/...`. AresMUSH's real `plugin/install` command (`PluginImporter#import_portal` in `plugins/manage/plugin_importer.rb`) looks for a directory literally named `webportal` (no hyphen) at the plugin repo root, and copies **its top-level contents directly** into `ares-webportal/app/` — it does not expect or strip an extra nested `app/` layer. SOUL's directory violated both rules: `Dir.exist?("webportal")` was false (the real folder was `web-portal`), so `import_portal` silently no-opped with a debug-level log line and zero files copied — no error surfaced anywhere the user would see it. Confirmed against a working reference (Inklings' `webportal/{components,templates/components,...}` matches the importer's expectations exactly, and its README correctly documents the copy as fully automatic) and a second broken reference (Grimoire has the same extra-`app/`-nesting mistake SOUL had, and its README works around it with a manual per-file copy table instead of relying on `plugin/install`). Every prior "fix" attempt in this bug entry (the `this.`-prefix pass, the angle-bracket conversion) was chasing symptoms of a component that was never deployed to the live game in the first place.

**Real fix:** renamed `web-portal/app/{components,templates}` to `webportal/{components,templates}` (dropped the hyphen and the extra `app/` nesting) so the layout matches what `PluginImporter#import_portal` actually expects, and updated `README.md`'s manual-copy fallback instructions to match. No component or snippet code changed — this was purely a source-tree layout bug preventing `plugin/install` from ever copying the files.

**Follow-up correction (same day, prompted by the user asking "these files don't belong in a soul subfolder, confirm?"):** SOUL's components also lived under a `soul/` subfolder (`webportal/components/soul/sheet.js`, invoked as `<Soul::Sheet />`), which is not this codebase's established convention. Both real sibling plugins (Inklings, Grimoire) use flat, hyphen-prefixed component filenames directly in `components/` (`inkling-detail-modal.js`, `grimoire-cast-spell.js`) with old-style curly-brace invocation (`{{inkling-detail-modal ...}}`), never a per-plugin subfolder — confirmed against both repos and against the Inklings dev guide, which states the expected resolver paths as flat `webportal/components/`/`webportal/templates/components/` and documents nesting mistakes as a repeat cause of portal-wide crashes. Renamed every SOUL component/template to a flat `soul-*` name (`soul-sheet.js`, `soul-xp.js`, `soul-bnb.js`, `soul-culmination.js`, `soul-history.js`, `soul-staff.js`, `soul-chargen.js`, `soul-roll.js`, `soul-scene-tools.js`) and reverted all three mounting snippets from angle-bracket `<Soul::X />` syntax back to flat curly-brace invocation (`{{soul-sheet character=this.char.name}}`, etc.) matching Inklings' proven, live-tested pattern exactly. The angle-bracket/`Soul::`-namespace detour earlier in this bug entry is fully superseded by this. **Not yet confirmed fixed against the live game** — the user needs to re-run `plugin/install` (or manually copy `webportal/`'s contents into `ares-webportal/app/`) and rebuild/redeploy the web portal before this can be marked verified.

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

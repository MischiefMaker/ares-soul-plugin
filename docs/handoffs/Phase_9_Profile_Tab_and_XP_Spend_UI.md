# Codex Handoff: Phase 9 Profile Tab and Web XP-Spend UI

**Prepared by:** Claude (project architect)
**Date:** 2026-07-24
**Workflow:** Follows the "SOUL Codex Handoff Instructions" in `docs/spec/Implementation_Specification_Addendum.md`.

---

## 1. Scope

CP-05 requires MUSH/web parity. Confirmed by direct inspection that two pieces of this are missing despite looking done at a glance — the Ember components exist and their backend web operations are correct, but neither is actually usable by a player yet:

1. **No profile tab exists.** `web-portal/app/components/soul/{sheet,xp,bnb,culmination,history}.js` and their templates are never mounted into the character profile page. There is no `custom-install/profile-custom-tabs.snippet.hbs`, no `profile-custom.snippet.hbs`, and no `custom_char_fields.rb` additions for SOUL — the three files Inklings ships for the identical purpose (verified against the real `ares-inklings-plugin` checkout). A player today cannot reach their SOUL sheet from their profile at all.
2. **The web XP-spend flow has no UI.** `web-portal/app/components/soul/xp.js` already has working `previewSpend(skillKey, amount)`/`confirmSpend(skillKey, amount)` actions calling the real `soulXpSpend` web operation (`plugin/web/soul_xp_web_handler.rb`'s `spend` method — confirmed correct and complete). But `web-portal/app/templates/components/soul/xp.hbs` has no skill picker, amount input, or button that ever calls these actions, and never displays `spendPreview`. The JS is done; the template is not.

**Also in scope (small, found in the same file while investigating #1):** `web-portal/app/templates/components/soul/sheet.hbs` never renders the `bnb` array `plugin/web/soul_sheet_web_handler.rb`'s `soulSheet` operation already returns — Boons/Banes are silently missing from the sheet view. Add the rendering; do not touch the backend, which is already correct.

**Explicitly out of scope:**
- Any change to `soulSheet`, `soulXp`, `soulXpSpend`, or any other existing web operation's Ruby logic — all are already correct and complete. This handoff is Ember template/component + profile-mounting work only.
- MUSH commands — `+soul`, `+xp/spend`, etc. are already done (Phase 6) and unaffected by this.
- Consolidating the five existing `soul/*` components into one mega-component. Keep them separate; just mount all five inside the new profile tab-pane, stacked, matching how a game with many plugin tabs already stacks multiple `tab-pane` divs.

## 2. Design Decisions Already Resolved (read before implementing)

### 2.1 Profile tab mounting — follow Inklings' exact three-file pattern

Verified directly against the real Inklings plugin (`/workspace/ares-inklings-plugin/custom-install/`), which solves this identical problem for its own profile tab. Add three new files to this repository, modeled closely on Inklings' own (read them for the full gotcha list — summarized below, but read the actual files, they're heavily commented for good reason):

1. **`custom-install/profile-custom-tabs.snippet.rb`** → instructs the game owner to paste a `<li class="nav-item"><a class="nav-link" data-bs-toggle="tab" href="#soul-tab-pane">SOUL</a></li>` block into their `ares-webportal/app/components/profile-custom-tabs.hbs`.
2. **`custom-install/profile-custom.snippet.hbs`** → instructs pasting a `<div class="tab-pane fade" id="soul-tab-pane">...</div>` block into `ares-webportal/app/components/profile-custom.hbs`, containing all five existing `soul/*` components stacked (sheet, xp, bnb, culmination, history), each passed `character=this.char.name` (or whatever the game's actual `profile-custom.hbs` calls its character argument — Inklings' own snippet has an extended comment on how to check this; copy that caution, don't assume `char`).
3. **`custom-install/custom_char_fields.snippet.rb`** → additions to `plugins/profile/custom_char_fields.rb`'s real `get_fields_for_viewing(char, viewer)` hook (confirmed real: `plugins/profile/web/character_request_handler.rb` calls `CustomCharFields.get_fields_for_viewing(char, enactor)` and sends the result as `custom:` in the profile payload). Add:
   ```ruby
   fields[:can_manage_soul] = Soul.can_manage_soul?(viewer)
   fields[:soul_is_approved] = char.is_approved?
   fields[:soul_viewer_id] = viewer ? viewer.id : nil
   ```
   **Follow Inklings' own documented caution exactly:** if the game already has Inklings (or any other plugin) installed and its snippet already sets an `is_approved`/`viewer_id` key via this same hook, do not add a second, differently-named field for the same value — reuse whichever key is already there rather than creating `soul_is_approved` alongside an existing `is_approved`. Write the installation comment to say so explicitly, the same way Inklings' own snippet does.

**Do not invent a different mounting mechanism.** This is the established, working pattern for exactly this problem in this plugin family — use it, don't redesign it.

### 2.2 Why `is_approved`/`viewer_id` must come through the same hook, not the base profile payload

Same reasoning Inklings' own snippet documents at length, re-verified here rather than assumed: the base character payload the web portal sends for a profile page has no `is_approved` field and no separate "viewer" character object — `char.is_approved` and `this.viewer.id` in a template would silently be `undefined` (not an error) for every character, always. `is_approved`/`viewer_id` must come through the custom `get_fields_for_viewing` hook (§2.1's step 3), referenced as `this.char.custom.soul_is_approved`/`this.char.custom.soul_viewer_id` (or whatever shared key name applies per the reuse rule above), not `this.char.is_approved`/`this.viewer.id`.

### 2.3 Gating the tab and the spend form

- Only render the SOUL tab at all when `Soul.enabled?`-equivalent is true client-side and the profile character is approved or the viewer manages SOUL — mirror Inklings' `isApproved=this.char.custom.is_approved` gating pattern exactly.
- The five stacked components already have correct server-side authorization (`soulSheet`'s `can_view?`, `soulHistory`, etc.) — do not duplicate that logic client-side, just don't render components that would obviously always error for a non-participant (e.g., a stranger viewing someone else's profile should still see what `can_view?` allows and nothing else; the existing handlers already enforce this, so simply always render the components and let the server responses (or their absence/error) speak for themselves, same as the MUSH commands already do).
- **XP-spend form scope decision:** `soulXp`/`soulXpSpend` (`plugin/web/soul_xp_web_handler.rb`) always operate on `request.enactor` — there is no `character:` parameter, unlike `soulSheet`. This is correct and intentional (XP spend is inherently self-service; staff corrections go through the separate `+xp/award`/`+xp/correct`/`soulXpAward`/`soulXpCorrect` paths, already done in Phase 6). **Therefore: only render the interactive spend form when the profile being viewed is the viewer's own** (`this.char.custom.soul_viewer_id === this.char.id`, i.e. "isSelf" exactly like Inklings' own `isSelf=(eq this.char.id this.char.custom.viewer_id)` pattern). On someone else's profile, the XP component should still show the read-only balance/history (`soulXp` already returns the *enactor's* data regardless of whose profile is open, so on someone else's profile the component would need to know not to fetch/display at all, or it would silently show the viewer's own XP mislabeled as the profile character's — **this is the one real thing to actually build, not just gate**: pass an `isSelf` argument into `soul/xp` and have `xp.js` skip `loadXp()` entirely, rendering nothing, when `isSelf` is false).

## 3. Repository Files Expected to Change

```
custom-install/profile-custom-tabs.snippet.hbs   # new
custom-install/profile-custom.snippet.hbs        # new
custom-install/custom_char_fields.snippet.rb     # new
web-portal/app/components/soul/xp.js             # add isSelf handling (see §2.3); no change to previewSpend/confirmSpend
web-portal/app/templates/components/soul/xp.hbs  # add skill picker, amount input, preview/confirm buttons, spendPreview display
web-portal/app/templates/components/soul/sheet.hbs  # add bnb rendering block (data already present in sheet.js's payload)
README.md or docs/development/Coding_Standards.md   # note the new custom-install step (check which already documents the existing custom_approval.snippet.rb step and follow the same place)
```

No Ruby web-handler changes — `soul_sheet_web_handler.rb` and `soul_xp_web_handler.rb` are both already correct.

## 4. The XP-Spend Form Specifically

`xp.js`'s existing actions expect `(skillKey, amount)` and already call the real backend correctly — build the template around them, not a new API:

- A `<select>` populated with the character's Skills and current ratings (the `soulXp` response doesn't include a skill list — check `soulSheet`'s `aspects[].skills[]` shape, already fetched by the sibling `sheet` component; either have `xp.js` fetch `SoulFrameworkApi`-equivalent skill data itself via a call to `soulFramework`/`soulSheet`, or accept the skill list as a passed-in argument from the profile snippet since `sheet` on the same page already has it — pick whichever avoids a duplicate fetch, and say which in your implementation notes).
- A numeric amount input (whole-Skill-point increments, matching `+xp/spend`'s MUSH semantics — `SoulXpApi.spend`'s `amount` parameter is a rating delta, not a target rating; verify against `plugin/public/soul_xp_api.rb` before assuming the sign/shape).
- A "Preview" button calling `previewSpend`, showing `spendPreview.cost`/`spendPreview.target_rating` once populated (matches `soul_xp_web_handler.rb`'s `spend` preview return shape: `{ preview: true, skill_key:, target_rating:, cost: }`).
- A "Confirm" button calling `confirmSpend`, shown only once a preview exists for that skill — mirror the MUSH `+xp/spend <skill>=<amount>` then `/confirm` two-step exactly (REQ-015's "cost shown before commitment").

## 5. Acceptance Criteria

- A player can open their own character profile on the web portal, see a "SOUL" tab, and view their Sheet (Aspects/Skills/Resonance/XP **and now Boons/Banes**), Culminations, and Narrative History.
- From that same tab, a player can pick a Skill, see the XP cost preview, and confirm the spend — mirroring `+xp/spend <skill>=<amount>` then `/confirm` exactly, calling the same real `soulXpSpend` operation already implemented.
- Viewing another character's profile (as staff, or as a scene participant per `soulSheet`'s existing reveal rules) shows their Sheet/Culminations/History per those handlers' existing authorization — and does **not** show an XP-spend form, and does not silently display the viewer's own XP mislabeled as the profile character's.
- The three new `custom-install/` files are cross-compatible with an existing Inklings installation on the same game (no duplicate `is_approved`/`viewer_id` field collision — see §2.1's reuse rule).

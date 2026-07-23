# Codex Handoff: Phase 9 Scene Page Roll Widget

**Prepared by:** Claude (project architect)
**Date:** 2026-07-24
**Workflow:** Follows the "SOUL Codex Handoff Instructions" in `docs/spec/Implementation_Specification_Addendum.md`.

---

## 1. Scope

The game owner asked whether players can make a SOUL roll directly from the scene page on the web portal, the way Grimoire's `cast` lets a player cast a spell from a scene. Confirmed: **no such component exists in this repository.** `web-portal/app/components/soul/` has no roll component and no scene-related code at all.

Build one. **No Ruby/backend changes are needed** — every web operation this requires already exists and is correct (`plugin/web/soul_roll_web_handler.rb`'s `soulRollStart`, `soulRollGm`, `soulRollSelect`, `soulRollAbort`, `soulRollPending`, `soulRollHistory`, `soulRollReview`, `soulRollMark`). This handoff is Ember component work plus locating and using the real scene-page mounting point.

**In scope:**
- A new `soul/roll` (or similarly named) Ember component: start a roll (Skill + difficulty), optionally request GM assistance, handle the pending-selection step (suggested/none/specific tags), show the resolved result privately, and — for an authorized scene-GM — review and mark pending GM-assisted rolls for that scene.
- Mounting it onto the actual scene page.

**Explicitly out of scope:**
- Any change to `soul_roll_web_handler.rb`, `SoulRollApi`, or any model. All correct and complete.
- Posting roll results into the scene transcript automatically. See §2.1 — this is a deliberate design decision, not an oversight.
- MUSH commands — `+roll` and its whole family are already done (Phase 6) and unaffected.

## 2. Design Decisions Already Resolved (read before implementing)

### 2.1 Do not auto-post the roll result to the scene, unlike Grimoire's `cast` or FS3's `+roll`

Verified directly: FS3Skills' own web roll handler (`plugins/fs3skills/web/add_scene_roll_handler.rb`) and its MUSH `+roll` command (`plugins/fs3skills/commands/roll_cmd.rb`) both call `FS3Skills.emit_results(message, ..., room, is_private)`, which posts the roll result straight into the scene transcript (`Scenes.add_to_scene`) unless the player explicitly marks it private. Grimoire's `grimoire-cast-spell` component follows the same pattern for casts.

**SOUL does not do this, and should not start now.** Checked SOUL's own existing `+roll` command (`plugin/commands/soul_roll_cmd.rb`) — it never posts to the room; every result goes back to the roller privately (`client.emit_success`/`client.emit_failure` only). This matches FINAL REQ-031 ("Notifications SHALL not reveal private explanations, GM notes, or another character's information") and the fact that GM-assisted rolls exist specifically to let a GM control what a roll's Boon/Bane context reveals before it happens — a public auto-echo of `applied_modifiers`/degree-of-success would risk exposing exactly the kind of thing REQ-031 protects, and would be inconsistent with the MUSH command's existing, correct behavior.

**Do this instead:** the new component shows the result to the roller only, exactly like `+roll` does today. If the player wants the outcome known in the scene, they pose it themselves — that's a deliberate, existing SOUL convention (CP-01, "Story First": narration is the player's job, not an automated mechanical echo), not a gap to fix.

### 2.2 Where this mounts: the real scene page, verified against core but not against a live `ares-webportal` checkout

Confirmed real and bundled in core: `plugins/scenes/web/custom_scene_data_handler.rb` calls `Scenes.custom_scene_data(viewer)` (game-owned, `plugins/scenes/custom_scene_data.rb`, empty/`nil` by default) — this is the actual, official per-scene custom-data extension point, parallel to `plugins/profile/custom_char_fields.rb` used for the profile tab (see `docs/handoffs/Phase_9_Profile_Tab_and_XP_Spend_UI.md`). **This handoff does not need to add anything there** — see §2.3 for why.

What is **not** confirmed, because no `ares-webportal` checkout is available in this project's research environment: the exact Ember template/component file that renders the scene page itself, and whether it has an established "custom tab" seam the way the profile page does (`profile-custom-tabs.hbs`/`profile-custom.hbs`, used by both Inklings and SOUL's own pending profile-tab handoff). Neither Grimoire nor Inklings' repositories reference a scene-page equivalent anywhere — this genuinely hasn't been established by prior work on this project, not something being withheld.

**Your first concrete step:** in a real `ares-webportal` checkout, locate the scene page's template (search for where the pose box / pose list renders — likely something like `scene-detail`, `live-scene`, or similar; do not assume a name, grep for it). Determine whether it already has a "custom" extension seam analogous to `profile-custom.hbs`. If it does, use it and document the exact mechanism you found, the same way `docs/handoffs/Phase_9_Profile_Tab_and_XP_Spend_UI.md` documents the profile page's. If it does not, the component will need a `custom-install/`-style snippet instructing the game owner to paste a block directly into their actual scene template — follow the same paste-at-a-marked-location convention Inklings uses for its chargen snippets (`custom-install/chargen-custom-tabs.snippet.hbs` etc.) rather than inventing a new convention.

### 2.3 Authorization: reuse the server-side checks that already exist; don't gate more than that client-side

`soulRollReview`/`soulRollMark` already correctly enforce scene-GM authorization server-side (`Soul.can_manage_soul?(enactor) || (Soul.can_review_rolls?(enactor) && scene.is_participant?(enactor))` — see `soul_roll_web_handler.rb`'s `review` method). The component does not need a new `custom_scene_data.rb` field to know whether to *show* the GM-review panel — follow the same pattern Grimoire's own `grimoire.js` route already uses for its staff-only tabs: call `soulRollReview` for the current scene on load, and show the panel only if it doesn't return a permission error. This avoids adding a new hook file for a purely cosmetic "should I show this panel" decision — the server call itself is the source of truth, same as it already is for the MUSH command.

### 2.4 Component behavior, tied to the real API responses

- **Starting a roll:** a Skill picker (reuse whatever the Sheet/XP components already use to enumerate Skills — check `soulSheet`'s `aspects[].skills[]` shape rather than adding a new endpoint) and a difficulty selector, calling `soulRollStart` (standard) or `soulRollGm` (GM-assisted) with `scene_id` set to the current scene's id (already a real page-model value wherever this mounts) and `skill_key`/`difficulty` from the form. Handle the `{ error: ... }` shape both already return.
- **Pending selection:** if `soulRollStart`/`soulRollGm`'s response's `pending_roll.status` is `"awaiting_selection"` or `"awaiting_gm"`, poll or refresh (matching whatever refresh pattern the sibling `soul/history` component already uses) until resolved, then present accept-suggested / none / pick-specific-tags options, calling `soulRollSelect` with `selection: "suggested"`, `selection: "none"`, or `tags: [...]` respectively — `soulRollSelect` already resolves the pending roll in the same call on success (see `select_and_resolve` in the handler), so a successful response's `roll` field is the final result; no separate "resolve" call is needed or exists.
- **Result display:** render `roll_hash`'s fields (`final_result`, `degree_of_success`, `extraordinary`, `applied_modifiers`) privately to the roller only, matching `+roll`'s own private notification — do not add any scene-echo (§2.1).
- **GM review panel (scene-GMs only, see §2.3):** list `soulRollReview`'s `pending_rolls` for the current scene, and for each, a mark form calling `soulRollMark` with `mandatory_tags`/`optional_tags` — mirror `soul_roll_cmd.rb`'s `+roll/mark <roll id>=<mandatory tags>/<optional tags>` shape.

## 3. Repository Files Expected to Change

```
web-portal/app/components/soul/roll.js         # new
web-portal/app/templates/components/soul/roll.hbs  # new
custom-install/*.snippet.*                      # new, exact name/count depends on what §2.2 finds
docs/reference/Commands.md or a new Web Portal doc  # note the new component, once mounted
```

No Ruby files change.

## 4. Acceptance Criteria

- A player on the scene page can pick a Skill and difficulty, start a roll (standard or GM-assisted), go through Boon/Bane selection, and see their private result — without leaving the scene page.
- A scene-GM viewing the scene page sees pending GM-assisted rolls for that scene and can mark mandatory/optional entries, using the same authorization the MUSH command already enforces.
- No roll result is ever posted into the scene transcript automatically.
- The mounting mechanism actually used is documented in this handoff's follow-up notes (or a new doc), the same level of detail `Phase_9_Profile_Tab_and_XP_Spend_UI.md` gives for the profile page, including whatever real scene-template extension point (or lack thereof) you found in an actual `ares-webportal` checkout.

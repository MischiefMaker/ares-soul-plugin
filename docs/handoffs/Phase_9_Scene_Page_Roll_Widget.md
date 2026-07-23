# Codex Handoff: Phase 9 Scene Page Roll Widget

**Prepared by:** Claude (project architect)
**Date:** 2026-07-24 (revised same day after Codex's review)
**Workflow:** Follows the "SOUL Codex Handoff Instructions" in `docs/spec/Implementation_Specification_Addendum.md`.

---

## Revision note

Codex reviewed the original version of this handoff and correctly refused to implement it as written, identifying three real backend gaps the original draft's "no Ruby changes needed" claim missed, plus a real UX problem with the originally-proposed authorization approach. All four are fixed below, and the real scene mounting point Codex found (`ares-webportal/app/components/live-scene-custom-play.hbs`) is now the confirmed target. This is exactly the review discipline this project expects in the other direction (Claude reviewing Codex) working correctly when Codex applied it back — verified each claim directly against the source rather than taking the correction on faith. Thank you.

## 1. Scope

The game owner asked whether players can make a SOUL roll directly from the scene page on the web portal, the way Grimoire's `cast` lets a player cast a spell from a scene. Confirmed: no such component exists in this repository.

Build one. **This now includes three small backend additions** (§2.2-§2.4 below) alongside the Ember component — the original claim that everything needed already existed was wrong in the three ways Codex identified. All three are implemented already; see §3.

**In scope:**
- A new `soul/roll` (or similarly named) Ember component: start a roll (Skill + difficulty), optionally request GM assistance, handle the pending-selection step (suggested/none/specific tags — now with real candidate data to show, see §2.2), show the resolved result privately, and — for an authorized scene-GM — review and mark pending GM-assisted rolls for that scene.
- Mounting it onto `ares-webportal/app/components/live-scene-custom-play.hbs` (confirmed real, see §2.5).

**Explicitly out of scope:**
- Any further change to `soul_roll_web_handler.rb`/`SoulRollApi` beyond what's already been added (§3) — review it, don't redesign it further, unless implementation surfaces a genuine new gap.
- Posting roll results into the scene transcript automatically. See §2.1 — deliberate, not an oversight.
- MUSH commands — already done (Phase 6), though `+roll`'s bare-status display was also extended to show candidates (§2.2) since the same underlying gap affected both interfaces equally.

## 2. Design Decisions Already Resolved (read before implementing)

### 2.1 Do not auto-post the roll result to the scene, unlike Grimoire's `cast` or FS3's `+roll`

Unchanged from the original handoff. FS3Skills' web roll handler and MUSH `+roll` command both post into the scene transcript by default; Grimoire's `cast` follows suit. SOUL's own `+roll` command never has — every result goes back to the roller privately, matching REQ-031 ("notifications SHALL not reveal private explanations, GM notes, or another character's information") and the reason GM-assisted rolls exist at all (controlling what a roll reveals). The widget matches this: private result only, no scene-echo. If the player wants it known in the scene, they pose it themselves (CP-01).

### 2.2 Fixed: no player-facing response exposed suggested Boon/Bane candidates

Codex's finding was correct and, on investigation, turned out to be a real gap in already-shipped functionality, not just a blocker for this widget: **FINAL REQ-028 step 4 ("Present concise suggestions or state that none matched") was never actually implemented for the player, on either interface.** `+roll`'s bare-status display and every player-facing web operation showed only `id`/`skill_key`/`status` — never which of the roller's own B&Bs the system or GM had suggested. Only the GM's own review view (`get_gm_candidate_view`) ever showed candidates, to the GM, not the player.

Fixed directly (not left for this handoff to work around):
- **New `SoulRollApi.get_player_candidate_view(pending_roll_id, character)`** (`plugin/public/soul_roll_api.rb`). Unlike the GM view, there's no privacy-category filtering — these are the roller's own entries, already fully visible to them via `+bnb`. Mirrors `select_entries`'s own branching exactly: a standard roll's candidates come from `system_suggested_entries`; a GM-assisted roll's (once GM-reviewed, status `awaiting_selection`) come from `gm_suggested_entries`/`gm_mandatory_entries` instead — never the original system suggestions the GM may have narrowed. Each candidate is `SoulBnbApi.get_character_entry_public`'s existing shape (`id`, `catalogue_id`, `tag`, `name`, `level_state`, `modifier`, `resolved`) plus a new `mandatory: true/false` flag, so the widget can render GM-mandatory entries as always-applied/non-toggleable and everything else as pick-or-skip.
- **New web operation `soulRollCandidates`** (`soul_roll_web_handler.rb`) → calls the above with `pending_roll_id`/`enactor`. Player-permission-gated like the other player ops.
- **`+roll`'s bare-status display extended** (`soul_roll_cmd.rb`'s `show_status`) to call the same method and list candidates whenever the pending roll is `awaiting_selection` — this was a real MUSH-side gap too, not web-only, so it's fixed on both interfaces together. New locale string `soul.roll_no_candidates` for the empty case, per REQ-028's explicit "state that none matched."

Call `soulRollCandidates` once the pending roll's status is `awaiting_selection` (whether reached directly from a standard roll or after GM review of a GM-assisted one) and render its `candidates` before presenting the suggested/none/pick-specific-tags choice.

### 2.3 Fixed: no player-accessible operation exposed configured difficulty names

Confirmed real: `game/config/soul.yml`'s `rolls.difficulties` was read only internally (`resolve_difficulty`) and never exposed anywhere — hardcoding the shipped defaults in the widget would have gone stale the moment a game customized them, exactly as flagged.

Fixed: **new `SoulRollApi.get_difficulty_options`** (trivial config passthrough, no privacy/authorization concern beyond ordinary play access) and **new web operation `soulRollDifficulties`** returning `{ difficulties: { "standard" => 13, ... } }`. Call this once to populate the difficulty selector; no need to re-fetch per roll.

### 2.4 Fixed: `soulRollReview`/pending-roll payloads omitted the rolling character

Confirmed real, and a genuine MUSH/web parity gap (not just a widget blocker): the MUSH `+roll/review` (no-argument form) already includes `pending.character.name` inline (`soul_roll_cmd.rb`'s `review_rolls`), but the shared web `pending_hash` helper never did, so `soulRollReview`'s pending-roll list was unusable for identifying whose roll each entry was.

Fixed: `pending_hash` in `soul_roll_web_handler.rb` now includes `character_id`/`character` on every pending-roll payload it produces (`soulRoll`, `soulRollStart`, `soulRollGm`, `soulRollPending`, `soulRollReview`, `soulRollMark`'s response — all share the one helper). Harmless where it's redundant (the player's own pending-roll views already know who they are); necessary for the GM review list.

### 2.5 Fixed: authorization-probe UX, and the real scene mounting point

Agreed the originally-proposed approach (call `soulRollReview` speculatively via the normal request path and treat a permission error as "hide the panel") was a real UX problem — it would flash a visible error to every ordinary player, not just silently gate a panel. Resolved with the cleaner mechanism the profile-tab handoff already established for exactly this kind of "should I render this panel at all" question:

**New `custom-install/custom_scene_data.snippet.rb`** — instructs the game owner to add to their real `plugins/scenes/custom_scene_data.rb` (confirmed real and bundled in core: `plugins/scenes/web/custom_scene_data_handler.rb` calls `Scenes.custom_scene_data(viewer)`, parallel to the profile tab's `custom_char_fields.rb`):

```ruby
def self.custom_scene_data(viewer)
  {
    soul_can_review_rolls: Soul.can_review_rolls?(viewer),
    soul_can_manage_soul: Soul.can_manage_soul?(viewer)
  }
end
```

This is viewer-level, not scene-specific — combine it client-side with the scene's own participant list (already part of the base scene payload) to decide whether to show the GM-review panel: `soul_can_manage_soul`, OR (`soul_can_review_rolls` AND the viewer is a participant in this scene) — matching `SoulRollApi.can_review_pending?`'s exact real logic. This is UI-gating only; the actual authorization remains entirely server-side and unchanged in `soulRollReview`/`soulRollMark` — a client that ignores or spoofs this flag still can't do anything the real check would reject.

**Confirmed real scene mounting point (Codex's finding, not independently re-verified in this environment but accepted — no `ares-webportal` checkout is available here):** `ares-webportal/app/components/live-scene-custom-play.hbs`, invoked inside the scene's Play menu. Mount `soul/roll` there via a single merge-safe `custom-install/` snippet, following the same paste-at-a-marked-location convention as every other snippet in this repository.

## 3. What's Already Done (this revision)

```
plugin/public/soul_roll_api.rb          # get_player_candidate_view, get_difficulty_options
plugin/web/soul_roll_web_handler.rb     # soulRollCandidates, soulRollDifficulties, pending_hash character fields
plugin/soul.rb                          # routes the two new web operations
plugin/commands/soul_roll_cmd.rb        # show_status now lists candidates (MUSH-side parity fix)
plugin/locales/locale_en.yml            # roll_no_candidates
plugin/spec/soul_roll_api_spec.rb       # new method specs
plugin/spec/soul_roll_web_handler_spec.rb  # new operation specs
custom-install/custom_scene_data.snippet.rb  # new
```

## 4. Repository Files Still Expected to Change (this handoff's actual remaining work)

```
web-portal/app/components/soul/roll.js         # new
web-portal/app/templates/components/soul/roll.hbs  # new
custom-install/live-scene-custom-play.snippet.hbs  # new (or equivalent name) — mounts soul/roll
docs/reference/Commands.md or a new Web Portal doc  # note the new component, once mounted
```

## 5. Component Behavior, Tied to the Real API Responses

- **Difficulty options:** fetch `soulRollDifficulties` once and populate the selector from its keys — do not hardcode the shipped defaults (§2.3).
- **Starting a roll:** Skill picker (reuse whatever the Sheet component already uses to enumerate Skills) + the difficulty selector above, calling `soulRollStart`/`soulRollGm` with `scene_id` set to the current scene's id, `skill_key`, `difficulty`. Handle `{ error: ... }`.
- **Pending selection:** once `pending_roll.status` is `awaiting_selection`, call `soulRollCandidates` and render its `candidates` (respecting each one's `mandatory` flag per §2.2), then let the player accept-suggested / none / pick-specific-tags via `soulRollSelect` — which already resolves the roll in the same call on success; there is no separate resolve step.
- **Result display:** render `roll_hash`'s fields privately to the roller only (§2.1) — `character`/`character_id` are now present on the pending-roll shape too (§2.4) if useful for display, though for the roller's own view they're redundant.
- **GM review panel:** gated client-side per §2.5's `soul_can_review_rolls`/`soul_can_manage_soul` + scene-participant check (no probe call); list `soulRollReview`'s `pending_rolls` (now including `character`) for the current scene, and for each, a mark form calling `soulRollMark` with `mandatory_tags`/`optional_tags`.

## 6. Acceptance Criteria

- A player on the scene page can pick a Skill and a real, currently-configured difficulty, start a roll (standard or GM-assisted), see actual candidate B&B suggestions (or a clear "none matched" state) before selecting, and see their private result — without leaving the scene page.
- A scene-GM viewing the scene page sees pending GM-assisted rolls for that scene — correctly identified by rolling character — and can mark mandatory/optional entries, using the same server-side authorization the MUSH command already enforces, with no permission-denied flash shown to ordinary players.
- No roll result is ever posted into the scene transcript automatically.
- `+roll`'s own bare-status display also now shows candidates (verify this didn't regress — it's a shared fix, not something to redo per-interface).

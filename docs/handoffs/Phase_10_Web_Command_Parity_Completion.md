# Codex Handoff: Phase 10 Web Command Parity Completion

**Prepared by:** Claude (project architect)
**Date:** 2026-07-24
**Workflow:** Follows the "SOUL Codex Handoff Instructions" in `docs/spec/Implementation_Specification_Addendum.md`.

---

## 1. Scope

Codex's own review of the merged Phase 9 web work (profile tab, XP-spend form, scene roll widget) went further than the specific handoffs it was implementing and audited MUSH/web parity across the whole plugin. That review is correct and verified here directly against the source before writing this handoff — every finding below was independently confirmed (grep/read, not just trusted): every major command family has a working web *operation*, but many of those operations have no Ember UI that ever calls them, so REQ-032/CP-05 ("a feature is incomplete until its MUSH and web paths are implemented... and tested for equivalent results") is not yet satisfied. `docs/reference/Commands.md`'s prior claim that "no workflow requires switching interfaces" has been corrected to say so plainly.

**Already fixed directly, before this handoff (small, mechanical, no design ambiguity — not left for Codex):**
- `+soul/reload` (MUSH) and `soulReload` (web) were both pure no-ops — they always reported success without checking anything. Both now call the real `Soul.check_config` (already existed, already used at plugin load, previously never invoked on demand) and report actual validation errors if any exist. See `plugin/commands/soul_staff_cmd.rb`, `plugin/web/soul_staff_web_handler.rb`.
- `+bnb/here <tag>` had **no web operation at all** (not just no UI) — added `soulBnbHere` (`plugin/web/soul_bnb_web_handler.rb`, registered in `plugin/soul.rb`), mirroring `soul_bnb_cmd.rb`'s `show_here` exactly: takes `scene_id`/`reference`, requires the enactor to be a participant in that scene, returns public-safe matches (`character`, `name`, `level_state`) for every participant who owns the referenced catalogue entry. Both changes have specs (`plugin/spec/soul_staff_web_handler_spec.rb`, `plugin/spec/soul_bnb_web_handler_spec.rb`).

**In scope for this handoff — the Ember work itself**, organized the same way Codex's own review grouped it:

### 1.1 A staff SOUL administration surface

No Ember component exists for any of: `soulFramework`, `soulResonance`, `soulReload` (now meaningful, see above), `soulAudit`, `soulXpAward`/`soulXpAward`-catchup/`soulXpScene`/`soulXpScene`-catchup/`soulXpCorrect`, or B&B's staff operations (`soulBnbCreate`/`soulBnbGrant`/`soulBnbProgress`/`soulBnbDelete`/`soulBnbResolve`/`soulBnbRestore`), or Culmination's staff operations (`soulCulminationPropose`/`soulCulminationApprove`/`soulCulminationDeny`/`soulCulminationRevoke`/`soulCulminationCorrect`). Build one staff-only page/tab (new `soul/staff` component, or however this game's admin area is conventionally organized — check for an existing admin-page pattern, e.g. Inklings' `/admin-inklings` route via `custom-install/custom-routes.snippet.js`, before inventing a new one) covering:
- Framework display (read-only: `soulFramework`).
- Resonance correction form (`soulResonance`).
- Reload/validate button showing `soulReload`'s real `errors` array.
- Audit log viewer for a named character (`soulAudit`).
- XP award/award-catchup/scene/scene-catchup/correct forms.
- B&B catalogue management forms (create/grant/progress/resolve/restore/delete) and Culmination management forms (propose/approve/deny/revoke/correct).

Gate this page's visibility the same way the scene widget's GM-review panel is gated (`custom_char_fields.rb`'s existing `can_manage_soul` field, already added in Phase 9 — reuse it, don't add a duplicate).

### 1.2 Roll modal additions

`web-portal/app/components/soul/roll.js`/`.hbs` (Phase 9) covers starting rolls, selection, and GM review, but never calls `soulRollAbort`, `soulRollForceAbort`, `soulRollHistory`, and only ever shows the single pending roll `soulRoll`/`get_open_pending_for_selection` returns — not the full list `soulRollPending` provides (relevant since GM-assisted rolls allow up to 2 concurrent pending rolls per player, `max_pending_rolls_per_player_gm`). Add:
- An abort action (with a required reason, matching `+roll/abort <id>=<reason>`) reachable from the pending-roll view.
- A force-abort action for authorized staff/scene-GMs (matching `+roll/forceabort`), likely alongside the existing GM-review panel.
- A pending-rolls list view using `soulRollPending` instead of assuming only one roll exists.
- A history view using `soulRollHistory`.

### 1.3 B&B detail, search, and scene lookup

`web-portal/app/components/soul/bnb.js`/`.hbs` (pre-Phase-9) only calls `soulBnbCatalogue` — it has no detail lookup (`soulBnb`), no scene lookup (the new `soulBnbHere`, see above), and no search (`soulBnbCatalogue` already accepts a `query` param for this — confirm and use it; do not assume a separate `soulBnbSearch` op exists, there isn't one). Add:
- A detail view for a single entry by id/tag, showing the caller's own `owned_entry` when present (matches `+bnb <id>`).
- A scene-scoped lookup by tag using the new `soulBnbHere` (matches `+bnb/here <tag>`) — this belongs on the scene page, not the profile page, likely alongside the roll widget in `live-scene-custom-play.hbs` (already an established mounting point from Phase 9 — reuse it).
- A search input using `soulBnbCatalogue`'s existing `query` param (matches `+bnb/search`).

### 1.4 Sheet scene-GM viewing

`soul_sheet_web_handler.rb`'s `can_view?` already supports a scene-GM viewing another participant's sheet (`Soul.can_review_rolls?(enactor) && scene.participants.include?(enactor) && scene.participants.include?(character)`, requires `scene_id`), but `web-portal/app/components/soul/sheet.js` only ever sends `character`, never `scene_id` — so this path is unreachable from the mounted profile component, which isn't scene-scoped in the first place. Do not try to thread `scene_id` through the profile tab (it has no scene context). Instead, add a scene-scoped "View Sheet" affordance to the same `live-scene-custom-play.hbs` mounting point as the roll widget and the new B&B scene lookup (§1.3) — a participant picker plus a call to `soulSheet` with both `character` and the current `scene_id`.

**Explicitly out of scope:**
- Any change to the read/write logic of existing web operations beyond what's already listed as done in this handoff's opening section. Every operation named above already exists and is correct — this is exclusively about building the Ember UI that calls them.
- Re-litigating the profile tab, XP-spend form, or roll widget from Phase 9 — those are done and merged (`e9cf65d`).

## 2. Design Notes

- Reuse `custom_char_fields.rb`'s `can_manage_soul` field (already shipped) for gating the staff admin surface — do not add a second, redundant permission-flag hook.
- Reuse `custom_scene_data.rb`'s `soul_can_review_rolls`/`soul_can_manage_soul` (already shipped) for gating the scene-page additions (§1.3's B&B lookup, §1.4's sheet viewing) exactly the way the roll widget's GM-review panel already does — no new probe, no new hook needed for authorization display; the real checks remain server-side and unchanged.
- `soulBnbCatalogue`'s existing `query` param already does search (`SoulBnbApi.search` under the hood) — confirmed in `soul_bnb_web_handler.rb`. Don't add a redundant `soulBnbSearch` operation.
- Follow the same "reads the shared `custom.*` fields, never guesses via a probe call" discipline the Phase 9 roll widget review established — it's cheap to get this wrong quietly (a permission-denied flash is invisible in casual testing but obvious to a real ordinary player).

## 3. Repository Files Expected to Change

```
web-portal/app/components/soul/staff.js            # new
web-portal/app/templates/components/soul/staff.hbs # new
web-portal/app/components/soul/roll.js              # extended (abort/forceabort/pending-list/history)
web-portal/app/templates/components/soul/roll.hbs   # extended
web-portal/app/components/soul/bnb.js               # extended (detail/search) or split into a scene-lookup component
web-portal/app/templates/components/soul/bnb.hbs    # extended
custom-install/profile-custom.snippet.hbs           # mount soul/staff, gated on can_manage_soul
custom-install/live-scene-custom-play.snippet.hbs   # extended: B&B scene lookup + sheet viewing alongside the roll widget
docs/reference/Commands.md                          # remove the "not yet true" caveat once each family is actually reachable
```

No further Ruby changes expected beyond what's already been made (§1's opening section) unless implementation surfaces a genuine new gap — flag it rather than working around it silently, per the Addendum's delegation rules.

## 4. Acceptance Criteria

- Every MUSH command family in `docs/reference/Commands.md` has a reachable web equivalent: B&B (detail/search/scene-lookup/all staff management), XP (all staff actions), Culminations (all staff actions), Rolls (abort/forceabort/pending-list/history in addition to what Phase 9 already covers), and the general staff commands (Framework/Resonance/Reload/Audit).
- `docs/reference/Commands.md`'s parity caveat (added in this handoff) is removed once verified true, not left stale.
- All new staff-only surfaces are gated on `can_manage_soul` (profile-page admin surface) or the existing `custom_scene_data` flags (scene-page additions) — no new permission-flag mechanism invented, no probe-based gating that could flash errors at ordinary players.

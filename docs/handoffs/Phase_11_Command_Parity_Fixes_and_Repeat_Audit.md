# Codex Handoff: Phase 11 Command Parity Fixes and Repeat Audit

**Prepared by:** Claude (project architect)
**Date:** 2026-07-24
**Workflow:** Follows the "SOUL Codex Handoff Instructions" in `docs/spec/Implementation_Specification_Addendum.md`.

---

## 1. Scope

Codex's own MUSH/web parity audit (run after the Phase 9/10 merge) found four substantive issues and one secondary gating inconsistency. All five were independently verified directly against the current source before writing this handoff — every one is real and confirmed, not assumed from the audit report. Fix all five, then run the audit itself again (both directions — MUSH-has-it-web-doesn't and web-has-it-MUSH-doesn't) and repeat until it comes back clean. Do not merge or declare parity complete until that repeat audit passes.

**In scope:**
1. B&B web search exposes staff-only and inactive-catalogue data to ordinary players (§2.1).
2. Web force-abort cannot reach every roll `+roll/forceabort` can (§2.2).
3. The staff Framework view renders nothing usable (§2.3).
4. Staff actions give incomplete feedback — partially fixed already, see §2.4 for exactly what remains.
5. Secondary: the scene participant-sheet control's client-side gating doesn't check scene participation (§2.5).
6. A repeat full command-parity audit after the above are fixed, iterated until no findings remain (§3).

**Explicitly out of scope:**
- Any change to `SoulBnbApi`, `SoulRollApi`, `SoulFrameworkApi`, or any other service API's business logic beyond what §2.1/§2.2 specifically call for. These are command/web-layer and Ember fixes.
- Re-litigating anything already marked "Complete" in the audit's parity matrix (Sheet's core mechanics, Narrative History, player XP, B&B catalogue/detail/here, standard/GM rolls, roll pending/history/abort, Character Generation). Don't touch working code while doing this pass — the repeat audit in §3 will catch it if something regresses.

## 2. Findings, Verified, With Resolution Direction

### 2.1 B&B web search exposes staff-only and inactive-catalogue data to players

Confirmed exactly as reported: `+bnb/search` is staff-only in `soul_bnb_cmd.rb` (`staff_switches` includes `"search"`). But `soulBnbCatalogue`'s web handler branches to `SoulBnbApi.search(request.args['query'])` whenever a `query` arg is present, and `soulBnbCatalogue` is **not** in `soul_bnb_web_handler.rb`'s `staff_commands` list — any character passing `Soul.can_play?` can supply `query` and reach it. `SoulBnbApi.search` itself scans `BnbCatalogueEntry.all.to_a` with no `active == "true"` filter (unlike `.get_catalogue`'s `active_only: true` default), so this also surfaces catalogue entries hidden from normal browsing.

**Resolution direction:** FINAL REQ-022 designates `+bnb/search` as staff/admin search specifically — there is no canonical player-facing search command. Match that: gate the `query` path of `soulBnbCatalogue` (or split it into its own operation) behind `Soul.can_manage_soul?`, exactly like `+bnb/search`'s real permission level. **Do not invent a new "player search" capability** as an alternative fix — FINAL doesn't specify one, and adding one would be scope creep beyond what this handoff or any prior one asked for. `soul/bnb`'s player-facing catalogue browse (no query) is unaffected and should keep working exactly as it does today.

### 2.2 Web force-abort cannot target every roll the MUSH command can

Confirmed exactly as reported: `+roll/forceabort <id>=<reason>` (MUSH) can target any authorized open roll regardless of status. The web button only appears next to `gmPendingRolls`, which comes from `soulRollReview`/`get_pending_gm_review` — filtered to `status: "awaiting_gm"` only (`plugin/public/soul_roll_api.rb`). So staff/scene-GMs currently cannot web-force-abort a standard roll awaiting player selection, a GM-assisted roll after the GM already submitted selections, or any other open roll not currently sitting in GM review.

**Resolution direction:** Add a way to force-abort by roll ID directly (matching the MUSH command's own `<id>=<reason>` shape) rather than only offering it next to the narrower `awaiting_gm` list — e.g. an explicit "Force-abort roll #___" form in the GM-review panel or staff surface, authorized the same way `+roll/forceabort` already is server-side (no new authorization logic needed, `soulRollForceAbort` already exists and already enforces this correctly — this is purely a missing UI path to reach it for rolls outside `awaiting_gm`).

### 2.3 Staff Framework response is not meaningfully rendered

Confirmed exactly as reported: `staff.hbs` renders `<pre>{{framework}}</pre>` — Ember will stringify the parent object, not its contents. The real `soulFramework` response shape (`plugin/web/soul_staff_web_handler.rb`) is:

```ruby
{
  aspects: SoulFrameworkApi.get_aspects,   # [{ key:, name:, description:, order: }, ...]
  skills: SoulFrameworkApi.get_skills,     # [{ key:, name:, aspect_key:, order: }, ...]
  min_rating: SoulFrameworkApi.skill_min_rating,
  max_rating: SoulFrameworkApi.skill_max_rating
}
```

**Resolution direction:** Replace `<pre>{{framework}}</pre>` with a real iteration — list each Aspect (`name` `[key]`, `description`), and under each, the Skills whose `aspect_key` matches it (`name` `[key]`), plus display `min_rating`/`max_rating` once. This is the same aspect-then-nested-skills shape `soul/chargen`'s own template already renders (`status.aspects`/`status.skills` grouped by `aspect_key`) — reuse that structure rather than inventing a new layout.

### 2.4 Staff actions: partially fixed already, here's exactly what remains

A prior direct fix (commit `89ea8ab`, same day) already added a generic `error`/`successMessage` banner to `staff.js`/`staff.hbs`, so this is **not** a full "zero feedback" gap anymore — every action now shows either the real error message or a generic `"Done."` on success. What the audit correctly still flags, re-verified against the current code:

- **Success messages are generic, not specific.** `"Done."` doesn't tell staff *what* happened (which character got XP, what the corrected Resonance value now is, etc.). Make `successMessage` reflect the actual result where the response has something worth stating (e.g. `SoulResonanceApi.correct`'s response, `SoulXpApi.award`'s response) rather than a single constant string for every action.
- **Nothing refreshes after a mutation.** E.g. correcting Resonance doesn't refresh the audit log if it's currently displayed; awarding XP doesn't refresh anything either. Where a currently-displayed read view (`auditResult`, `framework`) would plausibly be stale after a related action, re-fetch it — don't require the staff member to manually click the read button again to confirm their own change landed.

### 2.5 Secondary: scene participant-sheet control's gating doesn't check scene participation

Confirmed exactly as reported: `scene-tools.hbs` shows the "View Participant Sheet" control based only on `custom.soul_can_review_rolls`/`custom.soul_can_manage_soul`, unlike `roll.js`'s own `updateReviewPermission` (reproduced above in §2, for reference), which additionally checks `scene.participants` for the logged-in viewer's id via `session.data.authenticated.id`. Not a security hole (`soulSheet`'s server-side `can_view?` still independently enforces real participation), but it reintroduces exactly the permission-denied-click UX the Phase 9 roll widget design was written to avoid.

**Resolution direction:** Give `scene-tools.js` the identical `isParticipant` check `roll.js` already has (same `session.data.authenticated.id` / `scene.participants` comparison) and combine it with `soul_can_review_rolls` the same way `updateReviewPermission` does, rather than duplicating slightly different logic — extracting a small shared helper is fine if that's cleaner than copy-pasting, but isn't required.

## 3. Repeat Audit Requirement

After fixing §2.1–§2.5, run a fresh full command-parity audit covering **both directions**:
- Every MUSH command family has a reachable, correctly-scoped web equivalent (the direction this handoff's findings came from).
- Every web-only capability has a MUSH equivalent (the audit already checked this once and found none missing — re-check it isn't reintroduced by these fixes).

If the audit finds anything else — including a new issue introduced by fixing §2.1–§2.5, or something the first audit missed — fix it and audit again. Repeat until an audit pass finds nothing. Do not report this handoff as complete, and do not merge, until a repeat audit comes back clean. If something in the audit itself seems to require a design decision rather than a mechanical fix (an actual ambiguity, not just more implementation work), stop and flag it back rather than guessing, per the Addendum's delegation rules — the same judgment call that correctly paused the Character Generation UI handoff earlier in this project.

## 4. Acceptance Criteria

- `+bnb/search`'s data (including inactive entries) is no more reachable from the web by an ordinary player than it is by an ordinary player on the MUSH today (i.e. not reachable at all).
- Staff/scene-GMs can force-abort any roll `+roll/forceabort` can reach from the web, not only ones awaiting GM review.
- The staff Framework view displays Aspects, their Skills, and the rating range in a form a staff member can actually read and use.
- Every staff web action shows a specific, meaningful confirmation (not just a generic "Done."), and any currently-displayed read view that the action would affect refreshes automatically.
- The scene participant-sheet control's visibility matches the roll widget's own scene-participation-aware gating.
- A full repeat command-parity audit (both directions) passes clean — attach or summarize its result when reporting this handoff done.

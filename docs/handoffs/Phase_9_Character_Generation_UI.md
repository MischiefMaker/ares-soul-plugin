# Codex Handoff: Phase 9 Character Generation UI

**Prepared by:** Claude (project architect)
**Date:** 2026-07-24
**Workflow:** Follows the "SOUL Codex Handoff Instructions" in `docs/spec/Implementation_Specification_Addendum.md`.

---

## 1. Scope

FINAL REQ-011 (Character Generation) requires that players be able to select their Aspects/Skills, Resonance, and starting Boons/Banes during chargen, before their character is approved. Every Phase 2/3 checklist entry deferred this with the same note: "the underlying API exists; commands are separate work." That work was never scheduled a home phase and remains genuinely open as of the 2026-07-24 checklist review. This handoff is that work.

**In scope — commands and web forms reachable only pre-approval:**
1. Resonance selection: `SoulResonanceApi.set_resonance(character, value, enactor)` / `.chargen_allowance(resonance)`.
2. Skill/Aspect allocation within the chargen point budget `chargen_allowance` returns: `SoulCharacterApi.set_skill_rating`/`.set_aspect_rating`.
3. Chargen B&B selection: `SoulBnbApi.grant(character, catalogue_ref, level_state:, source: "chargen", enactor: nil)` against the `chargen_available` catalogue (`SoulBnbApi.get_catalogue` already supports filtering — check its `active_only`/`kind`/`category` kwargs and add a `chargen_available` filter there if it doesn't already exist).
4. A read-only chargen-time Framework display (Aspects/Skills/current allocation), reusing `SoulFrameworkApi.get_aspects`/`get_skill_for_grimoire_branch`'s sibling read methods — do not duplicate `+soul/framework`'s existing display logic; extract a shared serialization helper if that's cleaner.

**Explicitly out of scope:**
- Any change to `SoulResonanceApi`, `SoulCharacterApi`, `SoulBnbApi`, or any other existing service API's business logic. Every method this handoff needs already exists and already does the right thing (budget/limit validation, ratio checks, locking). This handoff is command/web/chargen-integration layer only.
- Post-approval Skill advancement (`+xp/spend`) — already done (Phase 6). Do not touch it.
- The Inklings-style "draft" pattern (see §2.3) — SOUL does not need it.

## 2. Design Decisions Already Resolved (read before implementing)

### 2.1 Pre-approval gating

`Character#is_approved?` (`plugins/chargen/public/chargen_char.rb`, real core) is the actual gate: `true` for admins or characters with the `"approved"` role, `false` otherwise. Every command/web operation in this handoff must check `!character.is_approved?` (or the inverse, as appropriate) and refuse otherwise with an actionable error — a character who already locked their Resonance, for instance, will already get `SoulResonanceApi.set_resonance`'s own `"Resonance is already locked..."` error from the service layer, but the Skill/B&B commands have no equivalent built-in lock and need the check added explicitly here.

### 2.2 How players reach these commands: a chargen stage, same mechanism as Inklings

AresMUSH's chargen flow is config-driven: `game/config/chargen.yml`'s `stages:` block lists ordered stages, each with a `help:` topic. This is not something SOUL's plugin code can register automatically — it's the game owner's own `chargen.yml`, analogous to the Resonance-locking hook this plugin already requires a `custom-install/` snippet for. Verified against the real Inklings plugin, which uses exactly this pattern for its own optional chargen integration (`custom-install/chargen_stage.snippet.yml`, `plugin/hooks/chargen_hook.rb`, `plugin/commands/inkling_chargen_draft_cmd.rb`): add a `custom-install/chargen_stage.snippet.yml` to this repository (new file) documenting how to add a "Character Framework" or "Resonance & Skills" stage pointing at a new help topic (e.g. `plugin/help/en/soul_chargen.md`, new file), and reference it from the installation docs. Follow Inklings' snippet's structure and comments closely — it's the established convention for this exact kind of optional chargen-stage integration.

The commands themselves (see §3) are ordinary `CommandHandler` classes gated by `!character.is_approved?`, exactly like `InklingChargenDraftCmd` is gated in Inklings — there is no special "chargen command" dispatch mechanism in real AresMUSH core; the gating is just a permission check like any other.

### 2.3 No draft/conversion step needed (unlike Inklings)

Inklings' chargen integration writes to *draft* character attributes pre-approval and converts them to real `Inkling` records only at approval (via the same `custom_approval.snippet.rb` hook SOUL already uses for Resonance locking). **SOUL does not need this pattern.** Resonance already works exactly this way today: `SoulResonanceApi.set_resonance` writes the real `character.resonance` field immediately, pre-lock, and `lock_at_approval` (already implemented) just freezes it at approval — there is no separate "draft resonance" field. Skills, Aspects, and B&Bs should follow the identical shape: `set_skill_rating`/`set_aspect_rating`/`.grant(..., source: "chargen")` write the real records immediately when the player selects them during chargen. Nothing needs to wait for or be converted at approval — approval only locks Resonance (already implemented) and, for B&Bs, nothing further at all (chargen-sourced grants are already permanent the moment they're granted, same as any other grant). Do not add a draft-attribute layer; it would be a duplicate mechanism for something Resonance already proves works without one (CP-09).

### 2.4 Budget enforcement lives in the command layer, not a new service method

`SoulCharacterApi.set_skill_rating`/`.set_aspect_rating` intentionally do not enforce a chargen point budget — they're the same "direct rating set" primitive staff corrections also use. The chargen command/web layer is responsible for: (1) reading `SoulResonanceApi.chargen_allowance(resonance)` → `{ skill_points:, starting_cap: }`, (2) summing the character's current `CharacterSkill`/`CharacterAspect` ratings' point cost against that budget before calling `set_skill_rating`, and (3) rejecting any single rating above `starting_cap` pre-approval. If the exact point-cost-per-rating formula for chargen allocation (as opposed to post-approval XP cost, which is `SoulXpApi.calculate_cost` and does NOT apply here — chargen allocation is point-buy, not XP-spend) isn't already specified somewhere in FINAL/the Addendum, treat "1 point per rating level" as the default (i.e. `skill_points` is a flat budget spent 1-for-1 raising ratings from their configured minimum) and flag this assumption explicitly in your implementation notes for review — do not silently invent a different formula.

## 3. Repository Files Expected to Change

```
plugin/commands/soul_chargen_cmd.rb           # new — Resonance/Skill/Aspect/B&B chargen selection
plugin/web/soul_chargen_web_handler.rb        # new
plugin/help/en/soul_chargen.md                # new
custom-install/chargen_stage.snippet.yml      # new
plugin/soul.rb                                # register the new command/web handler
plugin/locales/locale_en.yml                  # new locale strings
web-portal/app/components/soul/chargen.js     # new
web-portal/app/templates/components/soul/chargen.hbs  # new
docs/reference/Commands.md                    # new Chargen section
plugin/spec/soul_chargen_cmd_spec.rb          # new
plugin/spec/soul_chargen_web_handler_spec.rb  # new
```

Check whether `SoulBnbApi.get_catalogue` already supports a `chargen_available:` filter kwarg before adding one — Phase 3's catalogue model has a `chargen_available` field (`docs/architecture/Data_Model.md`), but confirm the query method actually filters on it.

## 4. Acceptance Criteria

- None of this handoff's commands/web operations are reachable for an already-approved character (verify against `is_approved?`, not against `resonance_locked_at` alone — a game with Resonance disabled must still gate Skill/B&B chargen selection on approval status).
- Resonance selection before approval works exactly as `SoulResonanceApi.set_resonance` already implements it (out of the box); this handoff just exposes it.
- Skill/Aspect allocation respects the `chargen_allowance` budget and per-rating `starting_cap`, with an actionable error when a selection would exceed either.
- B&B chargen selection calls `.grant(..., source: "chargen")` and surfaces `validate_chargen_limits`'/`ratio_satisfied_after_boon?`'s existing error messages verbatim — do not re-implement or duplicate that validation client-side only.
- Both MUSH and web interfaces exist for all three (CP-05).
- Specs cover: post-approval rejection, budget overrun rejection, and a successful full chargen allocation sequence (Resonance → Skills/Aspects within budget → at least one chargen B&B).

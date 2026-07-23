# Codex Handoff: Phase 9 Character Generation UI

**Prepared by:** Claude (project architect)
**Date:** 2026-07-24 (revised same day after Codex correctly paused on three real architectural gaps in the original version)
**Workflow:** Follows the "SOUL Codex Handoff Instructions" in `docs/spec/Implementation_Specification_Addendum.md`.

---

## Revision note

Codex reviewed the original version of this handoff and correctly stopped rather than inventing contracts for three real gaps: (1) no chargen-time B&B *removal* path existed anywhere — only the staff-only destructive `.delete` workflow, wrong for routine chargen editing; (2) no canonical MUSH syntax was specified for any of the four chargen actions; (3) the handoff gestured at "a chargen stage" without identifying the actual real web chargen data-flow mechanism. All three are resolved below. Investigating (1) surfaced a fourth, deeper problem the original handoff's own reasoning had missed: `SoulBnbApi.grant` unconditionally writes Narrative History and fires an event on every call, which — now that this handoff proposes calling it during chargen — would violate FINAL REQ-011's explicit "Incomplete or rejected chargen SHALL NOT create Narrative History" rule the moment `source: "chargen"` grants actually started happening. Fixed directly (not left for Codex), since it's a correctness fix to already-shipped, security/data-integrity-adjacent behavior, not new command/web surface.

## 1. Scope

FINAL REQ-011 (Character Generation) requires that players be able to select Resonance and Skills, and select/correct starting Boons/Banes, during chargen, before approval. This handoff builds the command/web/chargen-integration layer; per §2 below, three of the four underlying service APIs needed real changes first, and those are now done.

**In scope — commands and web forms reachable only pre-approval:**
1. Resonance selection: `SoulResonanceApi.set_resonance(character, value, enactor)` / `.chargen_allowance(resonance)`.
2. Skill allocation within the chargen point budget `chargen_allowance` returns: `SoulCharacterApi.set_skill_rating`.
3. Chargen B&B selection and removal: `SoulBnbApi.grant(character, catalogue_ref, level_state:, source: "chargen", enactor: nil)` to add, `SoulBnbApi.drop_chargen_selection(entry_id, character)` to remove (both already implemented, see §2.2) against the `chargen_available` catalogue (`SoulBnbApi.get_catalogue(chargen_available: true)` — the filter kwarg now exists, see §2.3).
4. A read-only chargen-time Framework display (Aspects/Skills/current allocation/selected B&Bs), reusing `SoulFrameworkApi.get_aspects`/`SoulBnbApi.get_character_entries` — do not duplicate `+soul/framework`'s existing display logic; extract a shared serialization helper if that's cleaner.

**Explicitly removed from scope (real correction, not an oversight to flag back):** Aspect allocation. Re-checked FINAL REQ-011's canonical chargen flow (§5.4) — it lists "Allocate Skills within the allowance and starting cap" as step 3 and never mentions Aspects anywhere in the chargen flow. FINAL REQ-009 describes Aspects as config-driven, secondary to Skills (CP-03), and "changed only through SOUL services" — but assigns no chargen-time player budget. The original version of this handoff incorrectly bundled `SoulCharacterApi.set_aspect_rating` into chargen scope; that was scope creep beyond what FINAL actually specifies, not a real requirement. Do not build an Aspect allocation UI. If a game wants Aspects set to something other than their default at chargen, that remains a staff/story decision via existing correction tools, out of scope here.

**Explicitly out of scope:**
- Any further change to `SoulResonanceApi`, `SoulCharacterApi`, `SoulBnbApi` beyond what's already been made (§2.2/§2.3). Everything else these need already exists and already does the right thing (budget/limit validation, ratio checks, locking).
- Post-approval Skill advancement (`+xp/spend`) — already done (Phase 6). Do not touch it.
- The Inklings-style draft/conversion pattern (see §2.4) — SOUL does not need it.

## 2. Design Decisions Already Resolved (read before implementing)

### 2.1 Pre-approval gating

`Character#is_approved?` (`plugins/chargen/public/chargen_char.rb`, real core) is the actual gate: `true` for admins or characters with the `"approved"` role, `false` otherwise. Every command/web operation in this handoff must check `!character.is_approved?` and refuse otherwise with an actionable error.

### 2.2 Fixed directly: B&B chargen add/remove and the Narrative-History-timing bug it exposed

`SoulBnbApi.grant`/`.drop_chargen_selection`/`.finalize_chargen_grants` (`plugin/public/soul_bnb_api.rb`) are now implemented and specced — this handoff calls them, does not build them:

- **`.grant(character, catalogue_ref, level_state:, source: "chargen", ...)`** — unchanged externally, but now **defers** Narrative History creation and the `SoulBnbTransitionedEvent` when `source == "chargen"` on a not-yet-approved character (was previously unconditional on every call, which would have violated REQ-011's "no Narrative History before approval" rule the moment this handoff started actually calling it with real player-facing selections instead of just tests).
- **`.drop_chargen_selection(entry_id, character)`** — new. The "remove a B&B I picked during chargen" action Codex correctly identified as missing. Hard-deletes the entry, restricted to `source == "chargen"` entries owned by the caller, only before approval. Deliberately distinct from the staff-only, 2-confirmation, audit-trailed `.delete` (permanent post-story record, wrong tool for routine chargen editing) and from `.resolve`/`.restore` (designed for a narrative transition on an entry that already has real history — a chargen selection doesn't yet, by design, until approval).
- **`.finalize_chargen_grants(character)`** — new. Called once, at approval, from the same `custom_approval.snippet.rb` hook that already calls `SoulResonanceApi.lock_at_approval` (both lines are now in that snippet — re-copy it if you already installed the old version). Creates the "Gained `<B&B>`" Narrative History entry for every chargen selection that survived to approval, mirroring exactly how `lock_at_approval` creates the "Starting Resonance approved" entry — satisfying REQ-011 rule 8 ("create only the feature-specific starting history entries required" at approval). Safe to call on every approval including a re-approval (skips any entry that already has a matching history record).

**What this means for your command/web layer:** call `.grant(character, ref, level_state:, source: "chargen", explanation:)` to add a chargen B&B, `.drop_chargen_selection(entry_id, character)` to remove one, and nothing else — no draft state, no manual Narrative History handling, no event handling. Both already return the same `{ success:, entry: }` / `{ error: }` shapes every other B&B command already handles.

### 2.3 Fixed directly: `SoulBnbApi.get_catalogue` now supports `chargen_available:`

Added a `chargen_available: nil` kwarg (unfiltered when `nil`, matching the method's existing style for `kind:`/`category:`). Use `SoulBnbApi.get_catalogue(chargen_available: true)` to list the selectable catalogue — do not add a second query method.

### 2.4 No draft/conversion step needed (unlike Inklings)

Inklings' chargen integration writes to *draft* attributes pre-approval and converts them to real records only at approval. **SOUL does not need this pattern for any of the three actions here.** Resonance already works this way today (`set_resonance` writes the real field immediately, pre-lock). Skills follow the identical shape: `set_skill_rating` writes the real rating immediately. B&Bs now do too, exactly (§2.2): `.grant(..., source: "chargen")` creates the real `CharacterBnbEntry` immediately; `.drop_chargen_selection` is the real, immediate undo. Nothing waits for or gets converted at approval except Resonance's lock and the now-implemented B&B history finalization. Do not add a draft-attribute layer (CP-09).

### 2.5 Canonical command syntax (resolved — FINAL leaves this open, so this is Claude's call per CI-05/REQ-045, same framework used for every other "Proposed" command in this project)

New top-level command word `+chargen` (confirmed unclaimed: real core's own chargen plugin uses `app`/`bg`/`cg`/`hook` as root words, never `chargen` itself — verified against `/workspace/aresmush/plugins/chargen/chargen.rb`'s `get_cmd_handler`).

| Command | Purpose |
|---|---|
| `+chargen` | Show current framework/allocation: Resonance (if enabled), Skill points spent/remaining, current ratings, selected chargen B&Bs |
| `+chargen/resonance <value>` | Select/change Resonance (delegates to `set_resonance`) |
| `+chargen/skill <key>=<rating>` | Set a Skill to an absolute target rating within budget (point-buy, not a delta — see §2.6) |
| `+chargen/bnb <id or tag>[/<level>]=<explanation>` | Select a chargen-available B&B (mirrors `+bnb/grant`'s existing shape minus the `<character>` segment, since it's always self); `<level>` defaults to `minor` |
| `+chargen/drop <entry id>` | Remove a previously chargen-selected B&B |

All five require `!character.is_approved?`; all five operate on `enactor` only (no `<character>` argument — a player can only edit their own chargen selections, staff corrections are a separate, already-existing path). Web operations: `soulChargenStatus`, `soulChargenResonance`, `soulChargenSkill`, `soulChargenBnb`, `soulChargenDrop` — new `SoulChargenWebHandler`, registered in `plugin/soul.rb` like every other web handler.

### 2.6 Skill budget enforcement lives in the command/web layer, not a new service method

`SoulCharacterApi.set_skill_rating` intentionally does not enforce a chargen point budget — it's the same "direct rating set" primitive staff corrections use. The command/web layer must: (1) read `SoulResonanceApi.chargen_allowance(resonance)` → `{ skill_points:, starting_cap: }`, (2) sum the character's current `CharacterSkill` ratings' point cost against that budget before calling `set_skill_rating`, (3) reject any single rating above `starting_cap`. If no exact point-cost-per-rating formula for chargen allocation is specified elsewhere in FINAL/the Addendum, treat "1 point per rating level, spent from 0" as the default and flag this assumption explicitly in your implementation notes — do not silently invent a different formula. (This is unchanged from the original handoff — Codex did not flag it, and re-checking FINAL confirms nothing more specific is written down.)

### 2.7 The real web chargen mechanism, and why this handoff doesn't use the generic one

Confirmed directly against the real AresMUSH engine and the real Inklings plugin (which already integrates with chargen this way): the web chargen page's **tab UI** is added via a real, established snippet pair — `ares-webportal/app/components/chargen-custom-tabs.hbs` (the tab `<li>`) and `ares-webportal/app/components/chargen-custom.hbs` (the tab-pane `<div>`) — mirroring `custom-install/chargen-custom-tabs.snippet.hbs`/`chargen-custom.snippet.hbs` from the real Inklings repository exactly. Add the equivalent `custom-install/chargen-custom-tabs.snippet.hbs`/`chargen-custom.snippet.hbs` pair to this repository for the tab UI only.

**Do not use the generic chargen *data* mechanism for anything beyond mounting the tab.** Real core also provides `plugins/profile/custom_char_fields.rb`'s `get_fields_for_chargen(char)` (read) / `save_fields_from_chargen(char, chargen_data)` (write, called from `Chargen.save_char` via the `chargenSave` web operation) plus a `chargen-custom.js` `onUpdate()` hook that batches simple field values into one big save call — this is what Inklings uses for its Secret/Goal text drafts, and it fits that shape (a couple of plain text fields, saved together with the rest of the chargen form). **It does not fit SOUL's data** (a Skill-rating list and a growing/shrinking list of B&B selections, each requiring its own validation, budget check, and error path). Using it here would mean silently swallowing per-action errors until the player hits one big "Save" button, which is a worse UX than the existing profile-tab/scene-widget precedent already established for every other SOUL web interaction. Instead: the mounted `soul/chargen` component makes its own direct, real-time calls to the new `soulChargenSkill`/`soulChargenBnb`/`soulChargenDrop`/`soulChargenResonance` operations (§2.5) as the player acts — same pattern as every other SOUL web component (`soul/xp`, `soul/roll`, etc.), not the generic chargen-save batching. `get_fields_for_chargen`/`save_fields_from_chargen` are not touched by this handoff at all.

The MUSH-side chargen stage question from the original handoff (a `custom-install/chargen_stage.snippet.yml` adding a `game/config/chargen.yml` stage with a `help:` topic) is unaffected by this revision and still applies — add it so `+chargen` has a natural point in the MUSH chargen flow to be introduced, exactly as Inklings does for its own MUSH commands.

## 3. Repository Files Expected to Change

```
plugin/commands/soul_chargen_cmd.rb                 # new — +chargen family
plugin/web/soul_chargen_web_handler.rb              # new
plugin/help/en/soul_chargen.md                      # new
custom-install/chargen_stage.snippet.yml            # new (MUSH stage pointer)
custom-install/chargen-custom-tabs.snippet.hbs      # new (web tab)
custom-install/chargen-custom.snippet.hbs           # new (web tab-pane)
plugin/soul.rb                                      # register the new command/web handler
plugin/locales/locale_en.yml                        # new locale strings
web-portal/app/components/soul/chargen.js           # new
web-portal/app/templates/components/soul/chargen.hbs  # new
docs/reference/Commands.md                          # new Chargen section
plugin/spec/soul_chargen_cmd_spec.rb                # new
plugin/spec/soul_chargen_web_handler_spec.rb        # new
```

No further `SoulBnbApi`/`SoulResonanceApi`/`SoulCharacterApi` changes expected — §2.2/§2.3's additions are already implemented and specced (`plugin/spec/soul_bnb_api_spec.rb`).

## 4. Acceptance Criteria

- None of this handoff's commands/web operations are reachable for an already-approved character.
- Resonance selection before approval works exactly as `SoulResonanceApi.set_resonance` already implements it.
- Skill allocation respects the `chargen_allowance` budget and per-rating `starting_cap`, with an actionable error when a selection would exceed either. No Aspect allocation UI.
- B&B chargen selection calls `.grant(..., source: "chargen")`; removal calls `.drop_chargen_selection`; both surface the underlying API's error messages verbatim.
- A full add-then-remove-then-re-add B&B sequence during chargen creates **no** Narrative History until approval, and exactly one entry per surviving selection once `finalize_chargen_grants` runs.
- Both MUSH and web interfaces exist for all four actions plus the status view (CP-05); the web tab is mounted via the new `chargen-custom-tabs`/`chargen-custom` snippet pair, not the generic `get_fields_for_chargen`/`save_fields_from_chargen` mechanism.
- Specs cover: post-approval rejection, Skill budget overrun rejection, a successful full chargen sequence (Resonance → Skills within budget → B&B select → B&B drop → B&B re-select), and confirm zero Narrative History entries exist for the character until `finalize_chargen_grants` is called.

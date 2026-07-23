# SOUL Testing Guide

Testing standards for SOUL, grounded in `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") Appendix C (Testing and Acceptance).

## Required Coverage (FINAL Appendix C)

Tests SHALL verify:

- service-level authorization and privacy;
- MUSH/web equivalence (CP-05);
- chargen validation and approval locking;
- stable Aspect–Skill mapping (by key, not display name);
- Resonance calculations, including asymmetric positive/negative configuration;
- XP idempotency, catch-up counters, caps, spending, and correction;
- B&B visibility, tags, level/state transitions, deletion safeguards, and equivalent integrated/manual paths;
- Narrative History versus audit separation (CP-07, GL-16/17);
- pending-roll limits, suggestions, GM mandatory selections, abort, expiry, and privacy-safe output;
- monotonic Skill effectiveness, non-decreasing XP cost, bounded modifiers, deterministic rounding, and identical math across interfaces (REQ-030 invariants);
- optional plugin absence and integration failure isolation (REQ-007, REQ-038);
- startup configuration validation and backward-compatible defaults (REQ-042);
- actionable errors carrying relevant identifiers (CI-07);
- help/documentation parity, including the `manage soul` topic name (CI-08).

Every item above has real, existing spec coverage as of Phase 7 — see `plugin/spec/*.rb`, one file per API/command/handler, following the `Test Structure` layout below. The examples in this document quote actual method signatures from the shipped code, not illustrative/aspirational ones — if a signature here ever drifts from the real file, the real file wins (CP-09).

## Test Structure

Tests live in a single flat `plugin/spec/` directory — verified against Inklings' own test suite (`plugin/spec/approve_inkling_spec.rb`, `submit_inkling_spec.rb`, `format_inkling_summary_spec.rb`, etc.), which uses no subdirectories at all. `PluginManager#code_files` explicitly skips any directory named `spec`/`specs` when loading plugin code, so this directory is safe from being accidentally loaded as runtime code regardless of where it sits under `plugin/`.

```
plugin/spec/
  soul_config_validator_spec.rb
  soul_framework_api_spec.rb
  soul_character_api_spec.rb
  soul_resonance_api_spec.rb
  soul_xp_api_spec.rb
  soul_bnb_api_spec.rb
  soul_culmination_api_spec.rb
  soul_narrative_history_api_spec.rb
  soul_dice_engine_spec.rb
  soul_roll_api_spec.rb
  soul_inklings_hook_spec.rb
  roll_spec.rb                        # Roll/PendingRoll model specs
  soul_sheet_cmd_spec.rb / _web_handler_spec.rb
  soul_bnb_cmd_spec.rb / _web_handler_spec.rb
  soul_xp_cmd_spec.rb / _web_handler_spec.rb
  soul_culmination_cmd_spec.rb / _web_handler_spec.rb
  soul_history_cmd_spec.rb / _web_handler_spec.rb
  soul_staff_cmd_spec.rb / _web_handler_spec.rb
  soul_roll_cmd_spec.rb / _web_handler_spec.rb
```

Every spec file starts with `require_relative 'spec_helper'` and wraps its examples in `module AresMUSH ... end`, matching the convention in every existing Inklings spec.

### About `plugin/spec/spec_helper.rb`

**No `spec_helper.rb` file is committed to this repository, and that is correct, not a gap.** Verified against the real AresMUSH engine (`.rspec`: `--require spec_helper` resolved via `-I .` against the engine's own top-level `spec/spec_helper.rb`, with `--pattern spec/**/*_spec*.rb,plugins/**/*_spec*.rb` picking up plugin specs from wherever the engine repo root is) and against the real Inklings plugin repository, which **also commits no `plugin/spec/spec_helper.rb` of its own** despite every one of its specs `require_relative`-ing it. AresMUSH plugins are designed to be tested from inside a full game installation — engine, plugins, and a shared `Gemfile`/`.rspec`/`spec_helper.rb` all in one checkout — not as a standalone repository with its own independent test runner. Running SOUL's suite requires installing this plugin into such a game checkout (see `docs/development/Release_Process.md`), at which point `require_relative 'spec_helper'` resolves the same way every other plugin's specs already do.

Earlier phases' implementation notes repeatedly flagged this as "RSpec remains unavailable, spec_helper.rb missing" — that phrasing is corrected here after checking the real engine and Inklings repositories directly (Phase 8 documentation-currency review, 2026-07-24): every spec file in this repository is syntax-valid (`ruby -c`) and has been reviewed for correctness against its target API's actual behavior, but none has been *executed*, because this repository was never going to be able to execute them standalone in the first place — not because anything is missing from it.

## Test Patterns

### XP Cost and Idempotency (REQ-013, REQ-015, Addendum §3)

Quoted from the real `plugin/spec/soul_xp_api_spec.rb`:

```ruby
describe SoulXpApi do
  describe ".calculate_cost" do
    it "matches the Addendum §3 worked example at rating 5, 0 XP spent, R0" do
      expect(SoulXpApi.calculate_cost(character, "blade", 5)).to eq(13)
    end

    it "never decreases as rating rises (REQ-015 invariant)" do
      costs = (1..10).map { |r| SoulXpApi.calculate_cost(character, "blade", r) }
      expect(costs).to eq(costs.sort)
    end
  end

  describe ".award" do
    it "does not double-award on a repeated idempotency key" do
      SoulXpApi.award(character, 10, source: "scene:1", idempotency_key: "scene:1:#{character.id}", apply_catchup: false)
      SoulXpApi.award(character, 10, source: "scene:1", idempotency_key: "scene:1:#{character.id}", apply_catchup: false)
      expect(SoulXpApi.get_lifetime_earned_xp(character)).to eq(10)
    end

    it "caps the catch-up bonus at the median gap (Addendum §8 Example B.4)" do
      allow(SoulXpApi).to receive(:catchup_eligible?).and_return(true)
      allow(SoulXpApi).to receive(:median_earned_xp).and_return(1)
      result = SoulXpApi.award(character, 2, source: "weekly", apply_catchup: true)
      expect(result[:awarded]).to eq(3)   # 2 base + 1 capped catch-up, not 4
    end
  end
end
```

### B&B Transitions and Non-Destructive Resolution (REQ-018 through REQ-021)

Real signatures: `SoulBnbApi.resolve(entry_id, reason:, enactor:)`, `SoulBnbApi.delete(entry_id, enactor:, confirmations:, reason:)` — both return `{ error: }` or `{ success: true, ... }`, never raise for an ordinary validation failure.

```ruby
describe SoulBnbApi do
  describe ".resolve" do
    it "preserves the entry and its prior level rather than deleting it" do
      entry = CharacterBnbEntry.create(character: character, catalogue_entry: catalogue_entry, level_state: "major")
      SoulBnbApi.resolve(entry.id, reason: "Story resolved", enactor: staff)

      expect(entry.resolved).to eq("true")
      expect(entry.preserved_level_state).to eq("major")   # preserved, not zeroed destructively
    end
  end

  describe ".delete" do
    it "requires two confirmations and an audit snapshot" do
      result = SoulBnbApi.delete(entry.id, enactor: staff, confirmations: 1, reason: "Duplicate entry")
      expect(result[:error]).to match(/confirmation/i)

      result = SoulBnbApi.delete(entry.id, enactor: staff, confirmations: 2, reason: "Duplicate entry")
      expect(result[:success]).to be true
      expect(SoulAuditEntry.find(action: "bnb_delete").to_a).not_to be_empty
    end
  end
end
```

### Dice Engine and Roll Resolution Invariants (Addendum §2, REQ-030)

Real signatures: `SoulDiceEngine.roll(net_modifier)` (RNG-based live resolution), `SoulDiceEngine.success_probability(net_modifier, required_dice_total)` (pure/deterministic, no RNG — REQ-030's "identical math across interfaces" requirement is why this is a separate, non-random method rather than derived from a live roll).

```ruby
describe Soul::SoulDiceEngine do
  describe ".success_probability" do
    it "increases with a positive (Boon) modifier relative to no modifier" do
      baseline = Soul::SoulDiceEngine.success_probability(0, 20)
      boosted = Soul::SoulDiceEngine.success_probability(5, 20)
      expect(boosted).to be > baseline
    end

    it "is deterministic across repeated calls with identical inputs" do
      a = Soul::SoulDiceEngine.success_probability(2, 20)
      b = Soul::SoulDiceEngine.success_probability(2, 20)
      expect(a).to eq(b)
    end
  end
end
```

### Pending Roll Limits and Expiry (CI-04, REQ-027, Addendum §6)

Real signatures: `SoulRollApi.start_roll(character, skill_key, context: {}, gm_requested: false)`, `SoulRollApi.expire_stale_pending_rolls(now = Time.now)`. Standard and GM-assisted pending-roll limits are two independent per-player caps (Phase 5), not a shared pool.

```ruby
describe SoulRollApi do
  describe ".start_roll" do
    it "enforces the pending-roll limit" do
      SoulRollApi.start_roll(character, "strength", context: { difficulty: "standard" })
      result = SoulRollApi.start_roll(character, "strength", context: { difficulty: "standard" })
      expect(result[:error]).to match(/maximum number/i)
    end
  end

  describe ".expire_stale_pending_rolls" do
    it "expires stale open rolls without creating completed rolls" do
      stale = PendingRoll.create(player: character, character: character, status: "awaiting_selection", expires_at: Time.now - 60)
      count = SoulRollApi.expire_stale_pending_rolls(Time.now)
      expect(count).to eq(1)
      expect(stale.status).to eq("expired")
      expect(Roll.all.to_a).to be_empty   # no auto-resolution, per Addendum §6
    end
  end
end
```

### Narrative History vs. Audit Separation (CP-07, GL-16/17)

Real signatures: `SoulNarrativeHistoryApi.get_history(character, viewer, limit: 50)` (owner or staff), `SoulAuditApi.get_audit(character, viewer, limit: 50)` (staff-only, even for the character it concerns).

```ruby
describe "Narrative History vs audit" do
  it "does not create Narrative History for a failed validation" do
    SoulBnbApi.grant(character, "nonexistent-tag", level_state: "minor", source: "test")
    expect(character.narrative_history_entries.to_a).to be_empty
  end

  it "creates Narrative History for a resolved B&B entry" do
    SoulBnbApi.resolve(entry.id, reason: "Story resolved", enactor: staff)
    expect(character.narrative_history_entries.to_a.map(&:event_type)).to include("bnb_resolved")
  end

  it "keeps the audit log staff-only, even for the subject character" do
    expect(SoulAuditApi.get_audit(character, character)).to eq([])   # character is not staff
    expect(SoulAuditApi.get_audit(character, staff)).not_to be_empty
  end
end
```

### Optional Plugin Absence (REQ-007, REQ-038)

```ruby
describe "SOUL without Inklings" do
  it "still resolves rolls and B&B transitions" do
    expect(defined?(AresMUSH::Inklings)).to be_nil
    result = SoulRollApi.start_roll(character, "strength", context: { difficulty: "standard" })
    expect(result[:success]).to be true
  end
end
```

## Test Fixtures

AresMUSH's own test suite uses the **Fabrication** gem, not FactoryBot — `Fabricate(:character)` and `Fabricate(:job)` (verified against real usage in Inklings' own spec files, e.g. `plugin/spec/approve_inkling_spec.rb`) construct pre-defined core models. Neither the AresMUSH core checkout nor Inklings defines new Fabricators for plugin-specific models, even where the plugin adds its own persistent models — specs instead construct those directly via `.create(...)`. Follow that same pattern for SOUL's own models rather than introducing a new fixture framework:

```ruby
describe SoulCharacterApi do
  let(:character) { Fabricate(:character) }
  let(:catalogue_entry) { BnbCatalogueEntry.create(name: "Test", description: "...", tag: "test", kind: "boon") }

  # ... use character, catalogue_entry as needed
end
```

If a helper reduces enough duplication to be worth extracting, put it in `plugin/spec/spec_helper.rb` (loaded via `require_relative 'spec_helper'` at the top of every spec file, matching Inklings' convention) rather than introducing a factory library the rest of the codebase doesn't use — see "About `plugin/spec/spec_helper.rb`" above for why this file isn't committed here.

## Configuration in Tests

Real config keys are flat, top-level `soul.yml` settings — not a nested `permissions:` hash (confirmed against Inklings' own `manage_permission` precedent, see `docs/reference/Permissions.md`):

```ruby
before do
  allow(Global).to receive(:read_config).and_call_original
  allow(Global).to receive(:read_config).with("soul", "framework", "skill_max_rating").and_return(10)
  allow(Global).to receive(:read_config).with("soul", "aspect", "weight").and_return(0.20)
  allow(Global).to receive(:read_config).with("soul", "play_permission").and_return("play")
end
```

`Global.read_config` is always stubbed with `.and_call_original` first, then specific `.with(...)` stubs layered on top — this lets a spec override only the keys it cares about while leaving everything else to the real config loader (or a further, more general stub), matching every existing spec file's `before` block.

## Coverage Targets

- **Overall:** 80%+
- **APIs:** 90%+ (business logic is critical)
- **Models:** 85%+ (include validations)
- **Commands:** 75%+
- **Web Handlers:** 80%+ (privacy filtering lives here — high stakes)

Coverage cannot currently be measured in this repository (no standalone execution — see above); it must be measured from within the full game installation this plugin is deployed into, using that installation's own `Gemfile`'s coverage tooling (e.g. SimpleCov, if the target game's `Gemfile` includes it — check before assuming it's available).

## Integration Tests

Real signatures: `SoulInklingsHook.validate_outcome(outcome_type:, character:, proposed_transition:, requester: nil, inkling_reference:)`, `SoulInklingsHook.apply_outcome(payload, source:)`.

```ruby
describe "Inklings + SOUL integration" do
  it "applies an approved Boon-progression outcome via the two-hook handoff" do
    payload = SoulInklingsHook.validate_outcome(
      outcome_type: :boon_progression,
      character: character,
      proposed_transition: { catalogue_id: catalogue_entry.id, from: "minor", to: "major" },
      requester: player,
      inkling_reference: "inkling:1"
    )
    expect(payload[:error]).to be_nil

    result = SoulInklingsHook.apply_outcome(payload, source: "inkling:1")
    expect(result[:success]).to be true
    expect(result[:soul_references][:character_bnb_entry_id]).to be_present
  end
end
```

## Testing Best Practices

1. One assertion per test (or a tightly related group).
2. Descriptive names — `"returns error when rating exceeds maximum"`, not `"tests validation"`.
3. Build test data directly (`Fabricate`/`.create`), not via a factory library the codebase doesn't otherwise use.
4. Stub external dependencies (Ares core methods, filesystem, `Login.notify`).
5. Test both success and failure paths — every documented `{ error: }` needs a test.
6. Don't test Ares internals — assume the core framework works; test SOUL's logic.

## Related Documents

- `docs/development/Coding_Standards.md` — Code style and structure
- `docs/development/Release_Process.md` — Test requirements for releases
- `docs/spec/IMPLEMENTATION_CHECKLIST.md` — Subsystems requiring test coverage

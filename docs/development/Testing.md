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

## Test Structure

Tests live in a single flat `plugin/spec/` directory — verified against Inklings' own test suite (`plugin/spec/approve_inkling_spec.rb`, `submit_inkling_spec.rb`, `format_inkling_summary_spec.rb`, etc.), which uses no subdirectories at all. `PluginManager#code_files` explicitly skips any directory named `spec`/`specs` when loading plugin code, so this directory is safe from being accidentally loaded as runtime code regardless of where it sits under `plugin/`.

```
plugin/
  spec/
    spec_helper.rb                    # or require_relative into the core's own spec_helper
    soul_config_validator_spec.rb
    framework_api_spec.rb
    xp_api_spec.rb
    bnb_api_spec.rb
    culmination_api_spec.rb
    roll_api_spec.rb
    soul_sheet_cmd_spec.rb
    soul_roll_cmd_spec.rb
    skill_spec.rb
    character_skill_spec.rb
    bnb_catalogue_entry_spec.rb
```

Every spec file starts with `require_relative 'spec_helper'` and wraps its examples in `module AresMUSH ... end`, matching the convention in every existing Inklings spec.

## Test Patterns

### XP Cost and Idempotency (REQ-013, REQ-015, Addendum §3)

```ruby
describe SoulXpApi do
  describe ".calculate_cost" do
    it "matches the algebraic formula exactly" do
      # rating 5: ceil(25/2) = 13; xp_spent 0 → dev modifier 1.0; resonance 0 → 1.0
      cost = SoulXpApi.calculate_cost(character_with(xp_spent: 0, resonance: 0), "blade", 5)
      expect(cost).to eq(13)
    end

    it "increases cost for positive Resonance" do
      base = SoulXpApi.calculate_cost(character_with(resonance: 0), "blade", 5)
      boosted = SoulXpApi.calculate_cost(character_with(resonance: 3), "blade", 5)
      expect(boosted).to be > base
    end

    it "never decreases as rating rises (REQ-015 invariant)" do
      costs = (1..10).map { |r| SoulXpApi.calculate_cost(character, "blade", r) }
      expect(costs).to eq(costs.sort)
    end
  end

  describe ".award" do
    it "does not double-award on duplicate idempotency key" do
      SoulXpApi.award(character, 10, source: "scene:1", idempotency_key: "scene:1:#{character.id}")
      SoulXpApi.award(character, 10, source: "scene:1", idempotency_key: "scene:1:#{character.id}")
      expect(SoulCharacterApi.get_lifetime_earned_xp(character)).to eq(10)
    end

    it "separates base award from catch-up bonus" do
      allow(SoulXpApi).to receive(:median_earned_xp).and_return(100)
      result = SoulXpApi.award(character_with(xp_earned: 0), 2, source: "weekly", idempotency_key: "week:1")
      expect(result[:catchup_portion]).to eq(2)  # 2 base × 2.0 multiplier - 2 base
    end

    it "caps catch-up bonus at the median gap" do
      allow(SoulXpApi).to receive(:median_earned_xp).and_return(1)
      result = SoulXpApi.award(character_with(xp_earned: 0), 2, source: "weekly", idempotency_key: "week:2")
      expect(result[:awarded]).to eq(3)  # 2 base + 1 capped catch-up, not 4
    end
  end
end
```

### B&B Transitions and Non-Destructive Resolution (REQ-018 through REQ-021)

```ruby
describe SoulBnbApi do
  describe ".resolve" do
    it "preserves the entry and its prior level rather than deleting it" do
      entry = AresMUSH::CharacterBnbEntry.create(character_id: character.id, catalogue_id: catalogue_entry.id, level_state: "major")
      SoulBnbApi.resolve(character, entry.id, reason: "Story resolved", enactor: staff)

      entry.reload
      expect(entry.resolved).to be true
      expect(entry.level_state).to eq("major")   # preserved, not zeroed destructively
    end
  end

  describe ".delete" do
    it "requires two confirmations and an audit snapshot" do
      expect {
        SoulBnbApi.delete(entry.id, enactor: staff, confirmations: 1)
      }.to raise_error(/confirmation/i)

      expect {
        SoulBnbApi.delete(entry.id, enactor: staff, confirmations: 2, reason: "Duplicate entry")
      }.not_to raise_error
      expect(AuditLog.where(target_id: entry.id)).to be_present
    end
  end
end
```

### Roll Resolution Invariants (REQ-030)

```ruby
describe "roll resolution invariants" do
  it "never lets higher Skill reduce expected effectiveness" do
    low = SoulRollApi.effective_rating(character_with(skill: 3), "blade")
    high = SoulRollApi.effective_rating(character_with(skill: 7), "blade")
    expect(high).to be > low
  end

  it "never lets greater difficulty increase success probability" do
    easy_prob = SoulRollApi.success_probability(character, "blade", difficulty: 13)
    hard_prob = SoulRollApi.success_probability(character, "blade", difficulty: 25)
    expect(hard_prob).to be < easy_prob
  end

  it "produces identical rounding across interfaces" do
    mush_result = SoulRollApi.aspect_contribution(rating: 3)
    web_result = SoulRollApi.aspect_contribution(rating: 3)   # same service call, no separate web math
    expect(mush_result).to eq(web_result)
  end
end
```

### Pending Roll Limits and Expiry (CI-04, REQ-027, Addendum §6)

```ruby
describe "pending roll limits" do
  it "enforces the standard limit of 1 open roll" do
    SoulRollApi.start_roll(character, "blade")
    result = SoulRollApi.start_roll(character, "reflexes")
    expect(result[:error]).to match(/pending roll/i)
  end

  it "expires after 720 hours without auto-resolving" do
    pending = AresMUSH::PendingRoll.create(character_id: character.id, status: "waiting", created_at: 721.hours.ago)
    SoulRollApi.sweep_expired_rolls
    expect(pending.reload.status).to eq("expired")
    expect(pending.result).to be_nil   # no auto-resolution
  end
end
```

### Narrative History vs. Audit Separation (CP-07, GL-16/17)

```ruby
describe "Narrative History vs audit" do
  it "does not create Narrative History for a failed validation" do
    SoulBnbApi.apply_transition(character, 999, "major", source: "test")  # invalid catalogue id
    expect(NarrativeHistory.where(character_id: character.id)).to be_empty
    expect(AuditLog.where(character_id: character.id)).to be_present
  end

  it "creates Narrative History for an approved Culmination" do
    SoulCulminationApi.approve(culmination.id, staff)
    expect(NarrativeHistory.where(soul_record_reference: culmination.id)).to be_present
  end
end
```

### Optional Plugin Absence (REQ-007, REQ-038)

```ruby
describe "SOUL without Inklings" do
  it "still resolves rolls and B&B transitions" do
    expect(defined?(AresMUSH::Inklings)).to be_nil
    result = SoulRollApi.start_roll(character, "blade")
    expect(result[:error]).to be_nil
  end
end
```

## Test Fixtures

AresMUSH's own test suite uses the **Fabrication** gem, not FactoryBot — `Fabricate(:character)` and `Fabricate(:job)` (verified against real usage in Inklings' own spec files, e.g. `plugin/spec/approve_inkling_spec.rb`) construct pre-defined core models. Neither the AresMUSH core checkout nor Inklings defines new Fabricators for plugin-specific models, even where the plugin adds its own persistent models — specs instead construct those directly via `.create(...)`. Follow that same pattern for SOUL's own models rather than introducing a new fixture framework:

```ruby
describe Soul::SoulSkillsApi do
  let(:character) { Fabricate(:character) }

  let(:aspect) { AresMUSH::Aspect.create(key: "body", name: "Body", order: 1) }
  let(:skill) { AresMUSH::Skill.create(key: "blade", name: "Blade", aspect_key: "body", order: 1) }
  let(:character_skill) { AresMUSH::CharacterSkill.create(character_id: character.id, skill_key: "blade", rating: 0) }

  # ... use character, aspect, skill, character_skill as needed
end
```

If a helper reduces enough duplication to be worth extracting, put it in `plugin/spec/spec_helper.rb` (loaded via `require_relative 'spec_helper'` at the top of every spec file, matching Inklings' convention) rather than introducing a factory library the rest of the codebase doesn't use.

## Configuration in Tests

```ruby
# spec/support/soul_config.rb
module SoulTestConfig
  def self.setup
    allow(Global).to receive(:read_config).and_call_original
    allow(Global).to receive(:read_config).with("soul", "framework", "skill_max_rating").and_return(10)
    allow(Global).to receive(:read_config).with("soul", "aspect", "weight").and_return(0.20)
    allow(Global).to receive(:read_config).with("soul", "permissions", "play").and_return("play")
  end
end

RSpec.configure { |config| config.before(:each) { SoulTestConfig.setup } }
```

## Coverage Targets

- **Overall:** 80%+
- **APIs:** 90%+ (business logic is critical)
- **Models:** 85%+ (include validations)
- **Commands:** 75%+
- **Formatters/Serializers:** 80%+ (privacy filtering lives here — high stakes)

```bash
COVERAGE=true rspec spec/
```

## Integration Tests

```ruby
describe "Inklings + SOUL integration" do
  it "applies an approved Boon-progression outcome via the two-hook handoff" do
    payload = SoulInklingsHook.validate_outcome(
      outcome_type: :boon_progression,
      character: character,
      proposed_transition: { catalogue_id: bnb_entry.catalogue_id, from: "minor", to: "major" },
      requester: player,
      inkling_reference: "inkling:1"
    )
    expect(payload[:error]).to be_nil

    result = SoulInklingsHook.apply_outcome(payload, source: "inkling:1")
    expect(result[:success]).to be true
    expect(NarrativeHistory.where(external_reference: "inkling:1")).to be_present
  end
end
```

## Testing Best Practices

1. One assertion per test (or a tightly related group).
2. Descriptive names — `"returns error when rating exceeds maximum"`, not `"tests validation"`.
3. Build test data in factories, not inline.
4. Stub external dependencies (Ares core methods, filesystem).
5. Test both success and failure paths — every documented `{ error: }` needs a test.
6. Don't test Ares internals — assume the core framework works; test SOUL's logic.

## Related Documents

- `docs/development/Coding_Standards.md` — Code style and structure
- `docs/development/Release_Process.md` — Test requirements for releases
- `docs/spec/IMPLEMENTATION_CHECKLIST.md` — Subsystems requiring test coverage

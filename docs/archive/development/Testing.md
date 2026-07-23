# SOUL Testing Guide

Testing standards and practices for SOUL development. Tests ensure correctness, catch regressions, and document expected behavior.

## Test Structure

Tests live in `spec/` directory, mirroring the plugin structure:

```
spec/
  api/
    skill_api_spec.rb
    xp_api_spec.rb
    boon_api_spec.rb
    roll_api_spec.rb
  commands/
    soul_advance_spec.rb
    soul_boon_spec.rb
  models/
    skill_spec.rb
    character_skill_spec.rb
  hooks/
    chargen_hook_spec.rb
  helpers/
    factories.rb              # Test data builders
    permissions_helper.rb     # Permission setup
```

## Running Tests

```bash
# All SOUL tests
rspec spec/

# Specific test file
rspec spec/api/skill_api_spec.rb

# Specific test
rspec spec/api/skill_api_spec.rb:42
```

## Test Patterns

### API Testing (Business Logic)

Test happy path, error paths, and edge cases:

```ruby
describe SoulSkillsApi do
  describe ".advance_skill" do
    let!(:character) { create(:character) }
    let!(:skill) { create(:skill, name: "Blade") }
    let!(:char_skill) { create(:character_skill, character: character, skill: skill, rating: 2) }
    
    context "when character advances a skill" do
      it "increases the skill rating" do
        result = SoulSkillsApi.advance_skill(character, "Blade", 1, character)
        
        expect(result[:success]).to be true
        expect(result[:new_rating]).to eq(3)
        expect(char_skill.reload.rating).to eq(3)
      end
      
      it "deducts XP from character" do
        char_data = { xp_available: 50 }
        SoulCharacterApi.update_character_data(character, char_data)
        
        result = SoulSkillsApi.advance_skill(character, "Blade", 1, character)
        
        xp_cost = Global.read_config("soul", "advancement_cost")[2]  # index = current rating
        expect(SoulCharacterApi.get_available_xp(character)).to eq(50 - xp_cost)
      end
    end
    
    context "when character lacks XP" do
      it "returns an error" do
        SoulCharacterApi.update_character_data(character, { xp_available: 5 })
        
        result = SoulSkillsApi.advance_skill(character, "Blade", 1, character)
        
        expect(result[:error]).to match(/insufficient/i)
      end
    end
    
    context "when rating would exceed maximum" do
      it "returns an error" do
        char_skill.update(rating: 5)  # Already maxed
        
        result = SoulSkillsApi.advance_skill(character, "Blade", 1, character)
        
        expect(result[:error]).to match(/exceed.*maximum/i)
      end
    end
    
    context "when skill doesn't exist" do
      it "returns an error" do
        result = SoulSkillsApi.advance_skill(character, "Nonexistent", 1, character)
        
        expect(result[:error]).to match(/does not exist/i)
      end
    end
  end
end
```

### Command Testing

Test argument parsing, permission checks, and outcomes:

```ruby
describe SoulAdvanceSkillCmd do
  let!(:character) { create(:character) }
  let!(:player) { character.player }
  
  before { allow_any_instance_of(Object).to receive(:client).and_return(double) }
  
  context "when player has permission and sufficient XP" do
    it "advances the skill" do
      client = double
      enactor = player
      
      cmd = SoulAdvanceSkillCmd.new(
        client,
        "soul/advance blade=1",
        enactor,
        character
      )
      
      expect(client).to receive(:emit_success).with(/advanced/i)
      cmd.handle
    end
  end
  
  context "when player lacks permission" do
    it "returns an error" do
      restricted_player = create(:player)
      restricted_player.permissions.delete("play")
      
      cmd = SoulAdvanceSkillCmd.new(
        double,
        "soul/advance blade=1",
        restricted_player,
        restricted_player.character
      )
      
      expect(double).to receive(:emit_failure).with(/permission/i)
      cmd.handle
    end
  end
end
```

### Model Testing

Test validations, relationships, and business logic:

```ruby
describe AresMUSH::Skill do
  describe "validations" do
    it "requires a name" do
      skill = AresMUSH::Skill.new(description: "Test")
      expect(skill.valid?).to be false
      expect(skill.errors[:name]).to be_present
    end
    
    it "requires a unique name" do
      create(:skill, name: "Blade")
      skill = build(:skill, name: "Blade")
      
      expect(skill.valid?).to be false
    end
  end
  
  describe "relationships" do
    it "belongs to an aspect" do
      aspect = create(:aspect)
      skill = create(:skill, aspect: aspect)
      
      expect(skill.aspect).to eq(aspect)
    end
  end
end
```

### Permission Testing

Test that permission checks work correctly:

```ruby
describe "SOUL permissions" do
  let!(:admin) { create(:player, permissions: ["manage_jobs"]) }
  let!(:player) { create(:player, permissions: ["play"]) }
  let!(:guest) { create(:player, permissions: []) }
  
  it "allows admins to grant XP" do
    expect(Permissions.can_manage_soul?(admin)).to be true
  end
  
  it "allows players to advance skills" do
    expect(Permissions.can_advance_skill?(player)).to be true
  end
  
  it "denies guests all SOUL operations" do
    expect(Permissions.can_manage_soul?(guest)).to be false
    expect(Permissions.can_advance_skill?(guest)).to be false
  end
end
```

### Event Testing

Test that events fire with correct data:

```ruby
describe "SoulXpGrantedEvent" do
  it "fires when XP is granted" do
    character = create(:character)
    event_data = nil
    
    allow(AresMUSH.dispatcher).to receive(:dispatch) do |event_name, data|
      event_data = data if event_name == "SoulXpGrantedEvent"
    end
    
    SoulXpApi.grant_xp(character, 50, "admin", character)
    
    expect(event_data[:character_id]).to eq(character.id)
    expect(event_data[:amount]).to eq(50)
    expect(event_data[:source]).to eq("admin")
  end
end
```

## Test Fixtures (Factories)

Define reusable test data builders:

```ruby
# spec/helpers/factories.rb

FactoryBot.define do
  factory :aspect, class: AresMUSH::Aspect do
    name { "Combat" }
    description { "Martial prowess" }
    order { 1 }
    active { true }
  end
  
  factory :skill, class: AresMUSH::Skill do
    name { "Blade" }
    description { "Swords and bladed weapons" }
    aspect { create(:aspect) }
    order { 1 }
    active { true }
  end
  
  factory :character_skill, class: AresMUSH::CharacterSkill do
    character { create(:character) }
    skill { create(:skill) }
    rating { 0 }
    xp_spent { 0 }
  end
  
  factory :boon, class: AresMUSH::Boon do
    name { "Lucky" }
    description { "Good fortune" }
    category { "boon" }
    active { true }
  end
end
```

## Configuration in Tests

Tests should use a test configuration:

```ruby
# spec/support/soul_config.rb

module SoulTestConfig
  def self.setup
    allow(Global).to receive(:read_config).and_call_original
    
    # Default test config
    allow(Global).to receive(:read_config).with("soul", "skill_max_rating").and_return(5)
    allow(Global).to receive(:read_config).with("soul", "advancement_cost").and_return([10, 20, 30, 40, 50])
    allow(Global).to receive(:read_config).with("soul", "advance_skill_permission").and_return("play")
  end
end

RSpec.configure do |config|
  config.before(:each) { SoulTestConfig.setup }
end
```

## Coverage Targets

- **Overall:** Aim for 80%+ code coverage
- **APIs:** 90%+ (business logic is critical)
- **Models:** 85%+ (include validations)
- **Commands:** 75%+ (harder to test UI interaction)
- **Helpers/Formatters:** 80%+ (easy to test)

Check coverage:

```bash
COVERAGE=true rspec spec/
# Reports to coverage/index.html
```

## Integration Tests

Test workflows across multiple systems:

```ruby
describe "Inkling + SOUL integration" do
  let!(:character) { create(:character) }
  let!(:inkling) { create(:inkling, character: character) }
  
  it "awards XP and Boons when inkling completes" do
    # Simulate inkling completion
    InklingApi.complete_inkling(inkling)
    
    # Verify SOUL was updated
    expect(SoulCharacterApi.get_total_xp(character)).to be > 0
    expect(SoulBoonApi.get_active_boons(character).count).to be > 0
  end
end
```

## Testing Best Practices

1. **One assertion per test** (or tightly related group)
2. **Descriptive test names** - `"returns error when rating exceeds maximum"` not `"tests validation"`
3. **Setup data in factories** - not inline in tests
4. **Stub external dependencies** - Mock Ares core methods, filesystem, etc.
5. **Test both success and failure** - Every error return path needs a test
6. **Use context blocks** for grouping related scenarios
7. **Don't test Ares internals** - Assume core framework works; test SOUL's logic

## Continuous Testing

Run tests before committing:

```bash
# Run all tests
rspec spec/

# Run with coverage
COVERAGE=true rspec spec/

# Run only changed files (faster feedback)
rspec spec/ --only-failures
```

## Related Documents

- `docs/development/Coding_Standards.md` - Code style and structure
- `docs/development/Release_Process.md` - Test requirements for releases
- `docs/spec/IMPLEMENTATION_CHECKLIST.md` - Features requiring testing

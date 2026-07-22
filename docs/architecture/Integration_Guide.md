# SOUL Integration Guide

How to integrate other AresMUSH plugins with SOUL. This guide covers common integration patterns and best practices.

## Before You Integrate

1. **Check SOUL's Availability** - Guard all SOUL integration behind a check:
   ```ruby
   if defined?(AresMUSH::Soul)
     # SOUL is installed, safe to integrate
   end
   ```

2. **Document the Dependency** - In your plugin's README:
   - Note that SOUL is optional or required
   - Describe what features depend on SOUL
   - Explain graceful degradation if SOUL is absent

3. **Test Both Paths** - Test your plugin with and without SOUL installed

## Common Integration Patterns

### Pattern 1: Using SOUL Skills in Your Plugin

**Scenario:** Your system (e.g., Grimoire) wants to use SOUL's skill resolution.

**Implementation:**

```ruby
# In your command or handler
if defined?(AresMUSH::Soul)
  # Use SOUL for resolution
  skill = SoulSkillsApi.get_skill_rating(character, "Spellcasting")
  pool = skill.rating + modifiers
  result = SoulRollApi.create_roll(character, skill.id, pool, "Casting spell")
  success = result[:result] > difficulty
else
  # Fall back to your own mechanics
  result = character_roll_custom_logic(character)
end
```

### Pattern 2: Granting Rewards via SOUL

**Scenario:** Your system (e.g., Inklings) awards XP or Boons when players complete content.

**Implementation:**

```ruby
# When granting a reward
if defined?(AresMUSH::Soul)
  # Use SOUL for XP and B&B rewards
  SoulXpApi.grant_xp(character, xp_amount, "inkling:#{inkling_id}", enactor)
  boon_name = "Inspired by #{inkling_name}"
  SoulBoonApi.grant_boon(character, boon_name, { source: "inkling:#{inkling_id}" })
else
  # Fall back to your own reward system
  grant_reward_custom_logic(character, reward)
end
```

### Pattern 3: Subscribing to SOUL Events

**Scenario:** Your system wants to react when a character advances in skills or gains Boons.

**Implementation:**

1. Register an event handler in your plugin module:
   ```ruby
   def self.get_event_handler(event_name)
     case event_name
     when "SoulSkillAdvancedEvent"
       return MyPluginSkillAdvancedHandler
     when "SoulBoonActivatedEvent"
       return MyPluginBoonActivatedHandler
     end
     nil
   end
   ```

2. Implement your handler:
   ```ruby
   class MyPluginSkillAdvancedHandler
     def self.on_event(event)
       character = Character.find_one_by_id(event.character_id)
       # React to the skill advancement
       # e.g., grant related achievement, trigger narrative event
     end
   end
   ```

### Pattern 4: Providing Roll Modifiers

**Scenario:** Your system (e.g., equipment, magic) wants to modify SOUL rolls.

**Implementation:**

1. Register a modifier hook:
   ```ruby
   def self.get_hooks(plugin_symbol, hook_name)
     if plugin_symbol == :soul
       case hook_name
       when :soul_roll_modifiers
         return [MyPluginModifierHandler]
       end
     end
     nil
   end
   ```

2. Implement the handler:
   ```ruby
   class MyPluginModifierHandler
     def self.get_modifiers(character, skill, context)
       modifiers = []
       
       # Check for equipment bonuses
       if character.has_magical_staff?
         modifiers << { 
           source: "Magical Staff", 
           value: 3, 
           description: "Staff bonus to arcane skills" 
         }
       end
       
       modifiers
     end
   end
   ```

## Handling SOUL Absence

### Graceful Degradation

If your core functionality depends on SOUL, document what doesn't work:

```ruby
# In your README's "Known Limitations" section:
# - Skill-based mechanics: Requires SOUL. Without it, uses fallback mechanics.
# - Boon/Bane integration: Requires SOUL. Without it, B&Bs are not awarded.
```

### Fallback Implementations

Provide basic implementations for when SOUL is absent:

```ruby
def self.get_character_power(character)
  if defined?(AresMUSH::Soul)
    skill = SoulSkillsApi.get_skill_rating(character, "Sorcery")
    skill.rating + 2  # SOUL-based calculation
  else
    character.FS3_rating("Sorcery")  # Fallback to FS3 or simple calculation
  end
end
```

## Testing SOUL Integration

### Unit Test Pattern

```ruby
describe "My Plugin with SOUL" do
  context "when SOUL is available" do
    it "uses SOUL skills for rolls" do
      # Setup: character with SOUL data
      # Action: trigger roll
      # Verify: roll used SOUL skill rating
    end
  end
  
  context "when SOUL is absent" do
    it "falls back to custom logic" do
      # Setup: SOUL not loaded
      # Action: trigger roll
      # Verify: fallback logic was used
    end
  end
end
```

### Integration Test Pattern

```ruby
# Test Grimoire + SOUL together
setup do
  load_plugin(:soul)
  load_plugin(:grimoire)
end

it "resolves spellcasting using SOUL skills" do
  # Create character with SOUL skills
  # Cast a spell
  # Verify SOUL roll was used and modifiers applied
end
```

## Configuration Compatibility

### Plugin-Specific Config in SOUL

Plugins should store their SOUL-related config in their own config file, not SOUL's:

```yaml
# game/config/my_plugin.yml
soul_integration:
  use_soul_skills: true
  skill_mapping:
    "Spellcasting": "Arcane"
  reward_amounts:
    xp_per_completion: 50
```

### SOUL Config References

Plugins can read SOUL config if needed:

```ruby
soul_config = Global.read_config("soul", "some_setting")
if soul_config
  # Use SOUL's setting
end
```

## Performance Considerations

### Avoid Repeated API Calls

Cache SOUL data during a command/handler execution:

```ruby
def handle(enactor)
  # Cache the skill once
  skill = SoulSkillsApi.get_skill_rating(character, "Combat")
  
  # Reuse the cached value
  pool1 = skill.rating + modifier1
  pool2 = skill.rating + modifier2
end
```

### Batch Operations

When granting multiple rewards:

```ruby
# Good: batch grant
characters.each do |char|
  SoulXpApi.grant_xp(char, amount, "scene:#{scene_id}", enactor)
end

# Avoid: separate transaction per character if possible
```

### Lazy Integration

If your plugin only uses SOUL optionally, check availability at load time:

```ruby
class MyPlugin
  SOUL_AVAILABLE = defined?(AresMUSH::Soul)
  
  def initialize
    if SOUL_AVAILABLE
      setup_soul_integration
    end
  end
end
```

## Troubleshooting

### "Undefined method" for SOUL APIs

**Cause:** SOUL not installed or loaded before your plugin.

**Solution:** Wrap in conditional check:
```ruby
if defined?(SoulXpApi)
  # Safe to call SOUL APIs
end
```

### Event handler not firing

**Cause:** Event handler not registered, or SOUL event not fired.

**Solution:** 
1. Verify hook is registered in `get_hooks`
2. Check SOUL's event documentation for exact event name
3. Add debugging to your handler to verify it's called

### Modified rolls not applying

**Cause:** Modifier hook not returning the right format.

**Solution:** Verify modifier format:
```ruby
{ source: "string", value: number, description: "string" }
```

## Further Reading

- `docs/architecture/API_and_Hooks.md` - Full API reference
- `docs/architecture/Event_Flow.md` - Detailed workflow examples
- Implementation Specification - `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md`

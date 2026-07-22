# SOUL API and Hooks

Public interfaces that other plugins use to integrate with SOUL. This document covers both APIs and hooks provided by SOUL.

## Public APIs

All public APIs live in `plugin/public/*_api.rb` and are callable from commands, web handlers, and other plugins.

### SoulCharacterApi

Core character data management.

```ruby
# Get a character's SOUL data
SoulCharacterApi.get_character_data(character)

# Update SOUL data on a character
SoulCharacterApi.update_character_data(character, updates_hash)

# Get character's total accumulated XP
SoulCharacterApi.get_total_xp(character)

# Get character's spent XP
SoulCharacterApi.get_spent_xp(character)

# Get character's current Resonance
SoulCharacterApi.get_resonance(character)
```

### SoulSkillsApi

Skill management and resolution.

```ruby
# Get character's rating in a skill
SoulSkillsApi.get_skill_rating(character, skill_name)

# Advance a character's skill
SoulSkillsApi.advance_skill(character, skill_name, amount, enactor)
  # Returns { error: "..." } on failure, { success: true } on success

# Resolve a skill roll (applying modifiers)
SoulSkillsApi.resolve_skill(character, skill_name, pool_size, options = {})
  # Returns { result: final_value, modifiers: [...] }

# Get all active skills for a character
SoulSkillsApi.get_character_skills(character)

# Get aspect details
SoulSkillsApi.get_aspect(aspect_name)
```

### SoulXpApi

XP earning, spending, and management.

```ruby
# Grant XP to a character
SoulXpApi.grant_xp(character, amount, source, enactor)
  # source: "admin", "scene:42", "inklings", etc.

# Spend XP for advancement
SoulXpApi.spend_xp(character, amount, purpose, enactor)

# Get XP transaction history
SoulXpApi.get_xp_history(character, limit: 50)

# Check if character has catch-up XP available
SoulXpApi.has_catchup_xp?(character)

# Get catch-up XP rate
SoulXpApi.get_catchup_rate(character)
```

### SoulBoonApi

Boon and Bane management.

```ruby
# Grant a Boon/Bane to a character
SoulBoonApi.grant_boon(character, boon_name, options = {})
  # options: { source: "...", custom_name: "...", custom_desc: "..." }

# Resolve an active B&B on a character
SoulBoonApi.resolve_boon(character, boon_id, reason, enactor)

# Get active Boons/Banes for a character
SoulBoonApi.get_active_boons(character)

# Get resolved Boons/Banes (history)
SoulBoonApi.get_resolved_boons(character, limit: 50)

# Check if character has a specific B&B active
SoulBoonApi.has_boon?(character, boon_name)

# Get mechanical effect of a B&B
SoulBoonApi.get_boon_effect(boon_name)

# Create a new Boon/Bane template
SoulBoonApi.create_boon(name, description, category, options = {})
  # options: { tags: [...], mechanical_effect: {...} }
```

### SoulRollApi

Roll creation and resolution.

```ruby
# Create a basic roll
SoulRollApi.create_roll(character, skill_id, pool_size, description, options = {})
  # options: { scene_id: "...", source: "..." }
  # Returns { result: final_value, roll_id: "...", modifiers: [...] }

# Create a roll pending GM review
SoulRollApi.create_pending_roll(character, skill_id, pool_size, description)

# Resolve a pending roll (GM action)
SoulRollApi.resolve_pending_roll(roll_id, action, gm, options = {})
  # action: "approve", "reject", "modify"
  # options: { modified_result: value, notes: "..." }

# Get roll history for a character
SoulRollApi.get_roll_history(character, limit: 50, options = {})
  # options: { skill_id: "...", scene_id: "...", since: timestamp }

# Get pending rolls (for queue)
SoulRollApi.get_pending_rolls(filters = {})
  # filters: { character_id: "...", assigned_to: "...", status: "..." }
```

## Hooks

SOUL provides hooks for other plugins to extend behavior. Hooks are registered via `get_hooks`:

```ruby
def self.get_hooks(plugin_symbol, hook_name)
  case hook_name
  when :soul_roll_modifiers
    return [MyModifierHandler]
  when :soul_xp_rewards
    return [MyRewardHandler]
  end
  nil
end
```

### `:soul_roll_modifiers`

Called when a roll is being resolved. Allows plugins to contribute modifiers (e.g., spell effects, equipment bonuses).

**Handler interface:**
```ruby
class MyModifierHandler
  def self.get_modifiers(character, skill, context)
    # Return array of { source: "...", value: +5, description: "..." }
  end
end
```

**Used by:** Grimoire (spell effects), Equipment systems, Magical buffs

### `:soul_xp_rewards`

Called when XP is awarded. Allows plugins to define custom reward types or conditions.

**Handler interface:**
```ruby
class MyRewardHandler
  def self.handle_reward(character, reward_type, amount, options)
    # Process custom reward, return { success: true } or { error: "..." }
  end
end
```

**Used by:** Inklings (thread rewards), Scene systems, Admin tools

### `:soul_boon_effects`

Called when a Boon/Bane effect needs to be evaluated. Allows plugins to define complex conditional effects.

**Handler interface:**
```ruby
class MyBoonEffectHandler
  def self.evaluate_effect(character, boon, context)
    # Return numerical effect value, or nil if not applicable
  end
end
```

**Used by:** Combat systems, Mechanical effects evaluation

## Events

SOUL fires events for other plugins to listen to. Plugins subscribe via `get_event_handler`.

### `SoulXpGrantedEvent`

**Fired when:** XP is awarded to a character

**Data:**
```ruby
event.character_id
event.amount
event.source          # "admin", "scene:42", "inklings", etc.
event.total_xp        # Character's new total
event.granted_at
```

### `SoulSkillAdvancedEvent`

**Fired when:** A character advances in a skill

**Data:**
```ruby
event.character_id
event.skill_id
event.old_rating
event.new_rating
event.xp_spent
event.advanced_at
```

### `SoulBoonActivatedEvent`

**Fired when:** A Boon/Bane is granted to a character

**Data:**
```ruby
event.character_id
event.boon_id
event.custom_name     # If overridden
event.source
event.granted_at
```

### `SoulBoonResolvedEvent`

**Fired when:** A Boon/Bane is resolved

**Data:**
```ruby
event.character_id
event.boon_id
event.reason
event.resolved_at
```

### `SoulRollResolvedEvent`

**Fired when:** A roll is completed (basic or GM-assisted)

**Data:**
```ruby
event.character_id
event.roll_id
event.skill_id        # May be nil
event.base_roll
event.final_result
event.modifiers       # Array of applied modifiers
event.gm_verified
event.resolved_at
```

## Integration Patterns

### Grimoire Using SOUL Rolls

```ruby
# Grimoire spell cast
spell_skill = SoulSkillsApi.get_aspect("Arcane").skills.find { |s| s.name == "Spellcasting" }
result = SoulRollApi.create_roll(caster, spell_skill.id, pool_size, "Casting #{spell.name}")
# Use result.result to determine spell success
```

### Inklings Awarding Rewards

```ruby
# When inkling completes
SoulXpApi.grant_xp(character, 50, "inkling:#{inkling_id}", system)
SoulBoonApi.grant_boon(character, "Inspired", { source: "inkling:#{inkling_id}" })
```

### Custom System Listening for Events

```ruby
def self.get_event_handler(event_name)
  case event_name
  when "SoulXpGrantedEvent"
    return MyCustomReactionHandler
  end
  nil
end
```

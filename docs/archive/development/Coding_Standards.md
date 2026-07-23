# SOUL Coding Standards

Conventions for developing SOUL and integrating with it. These standards ensure consistency across SOUL and its integrations, and follow AresMUSH best practices.

## Ruby Conventions

### File Organization

Follow the standard AresMUSH plugin structure:

```
plugin/
  soul.rb                         # Module registration
  commands/                       # One class per MUSH command
  web/                            # Thin web handler adapters
  public/                         # Business logic APIs (shared)
  models/                         # Ohm::Model classes
  hooks/                          # Lifecycle hooks
  events/                         # Event handlers
  locales/                        # User-facing strings (locale_en.yml)
  help/                           # Help files
```

### Naming Conventions

**Classes:**
- Commands: `SoulAdvanceSkillCmd`, `SoulBoonCreateCmd`
- APIs: `SoulSkillsApi`, `SoulXpApi`, `SoulBoonApi`
- Models: `AresMUSH::Skill`, `AresMUSH::CharacterSkill`, `AresMUSH::Roll`
- Web Handlers: `SoulAdvanceSkillWebHandler`, `SoulCheckXpWebHandler`
- Event Handlers: `SoulXpGrantedHandler`, `SoulBoonActivatedHandler`
- Hooks: `SoulChargenHook`, `SoulAppReviewHook`

**Methods:**
- Permission checks: `can_manage_soul?(enactor)`, `can_advance_skill?(enactor)`
- Getters: `get_character_data(character)`, `get_skill_rating(character, skill_name)`
- Formatters: `format_character_sheet(character)`, `format_skill_list(character)`
- Validators: `validate_skill_rating(rating)`, `validate_boon_name(name)`

**Constants:**
- Config keys: `ADVANCE_SKILL_PERMISSION`, `XP_BASE_PER_SCENE`
- Use `Global.read_config` at runtime instead of memoizing constants

### Code Style

Follow Ruby conventions from AresMUSH:

- 2-space indentation (not tabs)
- Snake_case for variables and methods
- SCREAMING_SNAKE_CASE for constants (rarely used; prefer config)
- Meaningful variable names (`character_skill` not `cs`)
- Single quotes for strings unless interpolation needed
- No extraneous comments; let code speak for itself

### Example Method

```ruby
class SoulSkillsApi
  def self.advance_skill(character, skill_name, amount, enactor)
    return { error: "Character not found" } if !character
    return { error: "Invalid skill name" } if !skill_name
    
    skill = Skill.find_one_by_name(skill_name)
    return { error: "Skill does not exist" } if !skill
    
    char_skill = CharacterSkill.find_one(character_id: character.id, skill_id: skill.id)
    return { error: "Character does not have that skill" } if !char_skill
    
    new_rating = char_skill.rating + amount
    return { error: "Rating would exceed maximum" } if new_rating > max_rating
    
    xp_needed = advancement_cost(char_skill.rating)
    char_data = get_character_data(character)
    available_xp = char_data['xp_available'] || 0
    return { error: "Insufficient XP" } if available_xp < xp_needed
    
    char_skill.rating = new_rating
    char_skill.xp_spent += xp_needed
    char_skill.last_advanced_at = Time.now
    char_skill.save
    
    update_character_data(character, { xp_spent: char_data['xp_spent'] + xp_needed })
    
    AresMUSH.dispatcher.dispatch("SoulSkillAdvancedEvent", {
      character_id: character.id,
      skill_id: skill.id,
      old_rating: char_skill.rating - amount,
      new_rating: new_rating,
      xp_spent: xp_needed
    })
    
    { success: true, new_rating: new_rating, xp_remaining: available_xp - xp_needed }
  end
end
```

## Web/Ember Conventions

### Component Structure

Components (in `webportal/components/`) follow Ares patterns:

```javascript
import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',  // No wrapper element for profile tabs
  
  classNameBindings: ['isLoading'],
  
  api: service('game-api'),
  flashMessages: service(),
  
  isLoading: false,
  characterSkills: null,
  
  didReceiveAttrs() {
    this._super(...arguments);
    // Load data if needed (rare for profile tabs)
  },
  
  actions: {
    async advanceSkill(skillId) {
      this.set('isLoading', true);
      try {
        const response = await this.api.requestOne('soul_advance_skill', { skill_id: skillId });
        if (response.error) {
          return;  // API already flashed error
        }
        this.send('reloadModel');  // Reload parent component
      } finally {
        this.set('isLoading', false);
      }
    }
  }
});
```

### API Contracts

**Always check the Ruby handler's actual return value before writing the `.then()`:**

```javascript
// BAD: Assuming response shape
api.requestOne('soul_advance_skill', {...}).then(response => {
  this.set('newRating', response.new_rating);  // Crashes if response = { error: "..." }
});

// GOOD: Guard on error and unwrap if needed
api.requestOne('soul_advance_skill', {...}).then(response => {
  if (response.error) { return; }
  this.set('newRating', response.new_rating);
});
```

### Template Conventions

- Use `{{#if}}` for simple branching, computed properties for complex logic
- Avoid `{{#with}}` on dynamically-loaded data (known to cause crashes; use direct references)
- Bind data passed from parent, don't self-fetch in profile/chargen tabs
- Use Bootstrap 5 classes (`.btn`, `.badge`, `.alert`) — don't hand-roll styling

## Localization (Strings)

All user-facing strings go in `plugin/locales/locale_en.yml`:

```yaml
soul:
  skill_advanced: "Skill advanced to %{new_rating}!"
  insufficient_xp: "You don't have enough XP. Need %{cost}, have %{available}."
  boon_granted: "You have gained: %{boon_name}"
  permission_denied: "You don't have permission to do that."
  
  commands:
    advance:
      help: "Usage: soul/advance <skill>=<amount>"
      desc: "Spend XP to advance a skill."
```

Reference via `t('soul.skill_advanced', new_rating: 5)` in commands/handlers.

## Database Models

**Models live in the `AresMUSH` module, not the plugin module:**

```ruby
module AresMUSH
  class Skill < Ohm::Model
    include ObjectModel
    
    attribute :name
    attribute :description
    attribute :aspect_id
    attribute :order, :integer, default: 0
    attribute :active, :boolean, default: true
    
    index :name
    index :aspect_id
    
    def aspect
      Aspect.find_one_by_id(aspect_id)
    end
  end
end
```

## Error Handling

APIs always return hashes on both success and failure:

**Failure path:**
```ruby
return { error: "Human-readable error message" }
```

**Success path:**
```ruby
return { success: true, new_rating: 5, xp_remaining: 25 }
```

Web handlers and commands use these consistently:
```ruby
result = SoulSkillsApi.advance_skill(character, skill, amount, enactor)
if result[:error]
  client.emit_failure result[:error]
  return
end
client.emit_success "Skill advanced to #{result[:new_rating]}!"
```

## Configuration Access

Always read config live, never memoize:

```ruby
def self.can_advance_skill?(enactor)
  permission = Global.read_config("soul", "advance_skill_permission") || "play"
  enactor.has_permission?(permission)
end
```

## Testing

See `docs/development/Testing.md` for detailed testing standards.

**At minimum:**
- Unit test business logic APIs
- Test permission checks
- Test command dispatching
- Test error cases (invalid input, insufficient resources)

## Git Conventions

**Commit messages:**
- First line: imperative, present tense ("Add skill advancement" not "Added skill")
- Reference implementation spec or decision docs if relevant
- Keep diffs focused (one logical change per commit)

**Branches:**
- `feature/skill-system`, `fix/b&b-grant-bug`, `docs/integration-guide`
- Keep feature branches short-lived; merge to main when stable

## Related Standards

- `ARES_PLUGIN_DEVELOPMENT_GUIDE.md` - Broader AresMUSH plugin standards
- `docs/architecture/Data_Model.md` - Database schema and relationships
- `docs/reference/Configuration.md` - Config structure and reading patterns

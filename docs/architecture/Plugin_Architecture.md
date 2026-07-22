# SOUL Plugin Architecture

Overview of SOUL's structure as an AresMUSH plugin. This document describes how SOUL is organized, how it integrates with Ares core, and how other plugins can extend it.

## Directory Structure

```
plugin/
  soul.rb                    # Module registration and plugin hooks
  commands/                  # MUSH command handlers
  web/                       # Web request handlers
  public/                    # Business logic APIs (shared by MUSH and web)
  models/                    # Ohm::Model database classes
  hooks/                     # Lifecycle hooks (chargen, profile, app review, etc.)
  events/                    # Event handlers
  locales/                   # User-facing strings
  help/                      # Help files
```

## Plugin Initialization

SOUL loads via Ares's standard plugin system:
1. Plugin module registers command/event/web-handler dispatchers
2. `init_plugin` hook called on plugin load (reserved for future use)
3. Event handlers subscribe to Ares lifecycle events
4. Configuration loaded from `game/config/soul.yml`

## Command & Event Dispatch

Commands are dispatched by name through `get_cmd_handler`:
```ruby
def self.get_cmd_handler(cmd)
  case cmd.name
  when "soul"
    return SoulCharacterCmd
  # ... other commands
  end
  nil
end
```

Events follow the same pattern via `get_event_handler`.

## Web Handler Pattern

Web handlers are thin adapters that:
1. Check login and permissions
2. Unpack request arguments
3. Delegate to business logic in `public/*_api.rb`
4. Return a hash (success or `{ error: "..." }`)

Example:
```ruby
def self.get_web_request_handler(request)
  case request.cmd
  when "soul_advance_skill"
    return SoulAdvanceSkillWebHandler
  end
  nil
end
```

## Data Model

SOUL defines Ohm::Model classes in the `AresMUSH` namespace (not the plugin's own module):

- `AresMUSH::Aspect` - Aspect definitions
- `AresMUSH::Skill` - Skill definitions
- `AresMUSH::CharacterSkill` - Character's skill ratings and XP
- `AresMUSH::Boon` - Boon/Bane definitions
- `AresMUSH::CharacterBoon` - Character-specific B&B instances
- `AresMUSH::Roll` - Roll history
- `AresMUSH::PendingRoll` - GM-assisted roll queue

## Integration Points

### Character Custom Fields

SOUL integrates with the Character profile via `custom_char_fields.rb` hooks:
- Returns SOUL-managed data as `char.custom.soul_*` on profile display
- Allows editing SOUL fields through character profile edit
- Supports chargen integration for character creation

### Permissions

All permission checks use configurable permission names via:
```ruby
Global.read_config("soul", "permission_name")
```

Defaults to existing Ares permissions (e.g., "manage_soul" → "manage_jobs").

### Configuration

Configuration is read live (not memoized):
```ruby
Global.read_config("soul", "key_name")
```

This allows admins to edit `game/config/soul.yml` without restarting the plugin.

## Extensibility

### Hooks for Other Plugins

SOUL will eventually provide hooks for other plugins:

```ruby
def self.get_hooks(plugin_symbol, hook_name)
  case hook_name
  when :soul_roll_modifiers
    # Return array of modifier handlers
  when :soul_xp_rewards
    # Return array of reward handlers
  end
  nil
end
```

### Public APIs

Business logic APIs in `public/*_api.rb` are the primary extension point:
- Grimoire can call skill resolution via `SoulSkillsApi.resolve_skill`
- Inklings can award XP via `SoulXpApi.grant_xp`
- Other plugins can check B&B effects via `SoulBoonApi.get_active_boons`

### Events

SOUL fires custom events for integrating plugins:

- `SoulXpGrantedEvent` - when XP is awarded
- `SoulSkillAdvancedEvent` - when a skill is improved
- `SoulBoonActivatedEvent` - when a B&B is gained
- `SoulRollResolvedEvent` - when a roll completes

## Configuration Structure

See `docs/reference/Configuration.md` for detailed configuration reference.

Key areas:
- Aspect definitions
- Skill configuration
- XP rates and advancement
- B&B mechanics
- Roll mechanics
- Permissions

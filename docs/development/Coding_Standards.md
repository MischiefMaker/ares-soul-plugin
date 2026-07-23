# SOUL Coding Standards

Conventions for developing SOUL and integrating with it, grounded in `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") Core Principles (CP-01 through CP-09) and the AresMUSH Plugin Development Guide (`https://github.com/MischiefMaker/ares-inklings-plugin/blob/main/ARES_PLUGIN_DEVELOPMENT_GUIDE.md`).

## Governing Principles (FINAL §1)

- **CP-04 (Plugin Ownership):** A plugin owns its own data, workflow, validation, business rules, and history. Integrations use published hooks/APIs/services and never mutate another plugin's domain directly.
- **CP-08 (AresMUSH First):** Use established AresMUSH helpers, APIs, plugin layout, permissions, Jobs, scenes, chargen, localization, and UI patterns. New infrastructure only when existing mechanisms cannot cleanly satisfy the requirement.
- **CP-09 (One Rule, One Home):** Each concept has one canonical definition. Other code may reference or demonstrate a rule but never restate it.
- **CP-06 (Configuration over Hard-Coding):** Anything a game is reasonably likely to rename, tune, limit, enable, or disable should be configurable, with safe defaults.
- **CP-07 (Preserve History):** Meaningful character changes and staff interventions remain traceable — prefer state transitions and corrections over silent deletion.

Before writing code, verify assumptions against actual AresMUSH source (`aresmush/aresmush`, `ares-webportal`) rather than tutorials or memory — tutorials may describe stale API versions.

## Ruby Conventions

### File Organization

```
plugin/
  soul.rb                         # Module registration
  commands/                       # One class per MUSH command
  web/                             # Thin web handler adapters
  public/                          # Business logic APIs (shared)
  models/                          # Ohm::Model classes
  hooks/                           # Lifecycle hooks
  events/                          # Event handlers
  locales/                         # User-facing strings (locale_en.yml)
  help/{admin,en}/                 # Help file markdown
```

### Naming Conventions

**Classes:**
- Commands: `SoulSheetCmd`, `SoulRollCmd`, `SoulBnbCmd`, `SoulXpCmd`
- APIs: `SoulFrameworkApi`, `SoulCharacterApi`, `SoulResonanceApi`, `SoulXpApi`, `SoulBnbApi`, `SoulCulminationApi`, `SoulRollApi`, `SoulNarrativeHistoryApi`
- Models (in the base `AresMUSH` module, not the plugin module — see below): `AresMUSH::Aspect`, `AresMUSH::Skill`, `AresMUSH::CharacterSkill`, `AresMUSH::BnbCatalogueEntry`, `AresMUSH::CharacterBnbEntry`, `AresMUSH::Culmination`, `AresMUSH::Roll`, `AresMUSH::PendingRoll`
- Web Handlers: `SoulRollWebHandler`, `SoulXpAwardWebHandler`
- Event Handlers: `SoulXpAwardedHandler`, `SoulBnbTransitionedHandler`
- Hooks: `SoulChargenHook`, `SoulCustomApprovalHook`

**Methods:**
- Permission checks: `can_manage_soul?(enactor)`, `can_advance_skill?(enactor)`
- Getters: `get_skill_rating(character, skill_key)`, `get_resonance(character)`
- Formatters: `format_sheet(character, viewer)`, `format_bnb_entry(entry, viewer)`
- Validators: `validate_bnb_transition(character, catalogue_id, target_level)`

**Constants:**
- Prefer `Global.read_config` at runtime over memoized constants (CP-06).

### Code Style

- 2-space indentation (not tabs)
- Snake_case for variables and methods
- Meaningful variable names (`character_skill`, not `cs`)
- Single quotes for strings unless interpolation is needed
- No extraneous comments; let code speak for itself

### Example Method

```ruby
class SoulXpApi
  def self.spend(character, skill_key, amount, enactor)
    return { error: "Character not found" } unless character
    return { error: "Invalid skill" } unless (skill = SoulFrameworkApi.get_skill(skill_key))

    char_skill = CharacterSkill.find_one(character_id: character.id, skill_key: skill_key)
    new_rating = (char_skill&.rating || 0) + amount
    max_rating = Global.read_config("soul", "framework", "skill_max_rating") || 10
    return { error: "Rating would exceed the maximum of #{max_rating}" } if new_rating > max_rating

    cost = calculate_cost(character, skill_key, new_rating)
    available = SoulCharacterApi.get_available_xp(character)
    return { error: "Insufficient XP: need #{cost}, have #{available}" } if available < cost

    # Atomic per REQ-007: deduct and advance together, or not at all
    char_skill ||= CharacterSkill.create(character_id: character.id, skill_key: skill_key, rating: 0)
    char_skill.update(rating: new_rating, last_advanced_at: Time.now)
    SoulCharacterApi.deduct_available_xp(character, cost)
    SoulCharacterApi.increment_lifetime_spent_xp(character, cost)

    AresMUSH.dispatcher.dispatch("SoulSkillAdvancedEvent", {
      character_id: character.id,
      skill_key: skill_key,
      old_rating: new_rating - amount,
      new_rating: new_rating,
      xp_spent: cost
    })

    { success: true, new_rating: new_rating, xp_remaining: available - cost }
  end
end
```

## Web/Ember Conventions

### Component Structure

```javascript
import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',   // No wrapper element for profile tabs

  api: service('game-api'),
  flashMessages: service(),

  isLoading: false,

  actions: {
    async advanceSkill(skillKey, amount) {
      this.set('isLoading', true);
      try {
        const response = await this.api.requestOne('soul_xp_spend', { skill_key: skillKey, amount });
        if (response.error) { return; }   // API already flashed the error
        this.send('reloadModel');
      } finally {
        this.set('isLoading', false);
      }
    }
  }
});
```

### GameApi Contract

- `requestOne(cmd, args)` — for a single object or composite hash; wraps the response in `EmberObject.create()`. If Ruby returns `{ entry: {...} }`, reference `response.entry`, not `response`.
- `requestMany(cmd, args)` — only for handlers whose success response is a **bare JSON array**. Using it against `{ items: [...] }` fails silently.
- Both call `flashMessages.danger(response.error)` and redirect automatically on error. Callers only need `if (response.error) { return; }` before success-path code.

**Always check the Ruby handler's actual return shape before writing `.then()`** — do not assume.

### Template Conventions

- Use `{{#if}}` for simple branching, computed properties for complex logic.
- Avoid `{{#with}}` on asynchronously-set properties — reference the property directly instead (it crashes with a null-resolution error when the wrapped value is set after an async fetch resolves).
- Bind data passed from parent; don't self-fetch in profile/chargen tabs unless no route-level hook exists.
- Use Bootstrap 5 classes — don't hand-roll styling.
- Give key elements semantic, namespaced CSS classes (e.g. `soul-sheet-row`) so game admins can customize without `!important` hacks.

## Localization (Strings)

All user-facing strings in `plugin/locales/locale_en.yml`, namespaced under `soul`:

```yaml
soul:
  skill_advanced: "%{skill_name} advanced to %{new_rating}!"
  insufficient_xp: "You don't have enough XP. Need %{cost}, have %{available}."
  bnb_granted: "You have gained: %{bnb_name}"
  permission_denied: "You don't have permission to do that."

  commands:
    xp_spend:
      help: "Usage: +xp/spend <skill>=<amount>"
      desc: "Spend XP to advance a skill."
```

Reference via `t('soul.skill_advanced', new_rating: 5)` — note `t()` only resolves from `CommandHandler` classes; plain module code needs its own text helper.

## Database Models

Models live in the `AresMUSH` module, not the plugin's own module, even though the files live under the plugin's folder:

```ruby
module AresMUSH
  class Skill < Ohm::Model
    include ObjectModel

    attribute :key
    attribute :name
    attribute :description
    attribute :aspect_key
    attribute :order, :integer, default: 0

    index :key
    index :aspect_key

    def aspect
      Aspect.find_one_by_key(aspect_key)
    end
  end
end
```

## Error Handling

APIs always return hashes on both paths (this is the contract `CommandHandler` and `GameApi` are built around):

```ruby
return { error: "Human-readable error message" }        # failure
return { success: true, new_rating: 5, xp_remaining: 25 }  # success
```

```ruby
result = SoulXpApi.spend(character, skill_key, amount, enactor)
if result[:error]
  client.emit_failure result[:error]
  return
end
client.emit_success "Advanced to #{result[:new_rating]}!"
```

## Configuration Access

Always call `Global.read_config` fresh, never memoize the result:

```ruby
def self.can_play?(enactor)
  permission = Global.read_config("soul", "play_permission") || "play"
  enactor.has_permission?(permission)
end
```

## Testing

See `docs/development/Testing.md`. At minimum: unit test business logic APIs, permission checks, command dispatching, and error paths.

## Git Conventions

**Commit messages:** First line imperative, present tense ("Add skill advancement," not "Added skill"). Reference the relevant FINAL REQ-* or Addendum section when the change implements a specific requirement. Keep diffs focused — one logical change per commit.

**Branches:** `feature/skill-advancement`, `fix/bnb-transition-bug`, `docs/integration-guide`. Keep feature branches short-lived; merge to main when stable.

## Related Standards

- `ARES_PLUGIN_DEVELOPMENT_GUIDE.md` — Broader AresMUSH plugin standards (linked from `CLAUDE.md`)
- `docs/architecture/Data_Model.md` — Database schema and relationships
- `docs/reference/Configuration.md` — Config structure and reading patterns
- `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` — CP-01 through CP-09 (authoritative)

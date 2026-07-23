# SOUL API and Hooks

Public interfaces that other plugins use to integrate with SOUL, derived from `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") §10 (Extension Points, REQ-046 through REQ-049) and §8 (Integration, REQ-038 through REQ-041).

Exact class and method names are an implementation decision (FINAL REQ-004, REQ-046) — the signatures below illustrate the required coverage, not literal mandated names. All public APIs live in `plugin/public/*_api.rb` per `docs/architecture/Plugin_Architecture.md`.

## Public Service APIs (FINAL REQ-046)

SOUL SHALL expose documented service-level entry points for authorized reads and transitions **without permitting direct model mutation** by callers. Required coverage:

### Framework Lookup

```ruby
# Read the configured Character Framework
SoulFrameworkApi.get_aspects                       # => [Aspect, ...] (default: Body, Mind, Spirit)
SoulFrameworkApi.get_skills(aspect_key: nil)        # => [Skill, ...]
SoulFrameworkApi.get_skill(skill_key)
```

### Character Ratings

```ruby
SoulCharacterApi.get_skill_rating(character, skill_key)     # => 0-10
SoulCharacterApi.get_aspect_rating(character, aspect_key)
SoulCharacterApi.get_effective_base(character, skill_key)   # skill_rating + aspect contribution
```

### Resonance Reads

```ruby
SoulResonanceApi.get_resonance(character)          # => -3..3, or nil if not yet locked
SoulResonanceApi.get_chargen_allowance(resonance)   # => { skill_points:, starting_cap: }
```

Resonance is read-only to integrations — only SOUL's own chargen/staff-correction services may write it (REQ-012).

### XP Awards / Spends

```ruby
# Award (validates idempotency, applies catch-up only if eligible and not a manual grant)
SoulXpApi.award(character, amount, source:, idempotency_key:)
  # Returns { success: true, awarded: n, catchup_portion: n } or { error: "..." }

# Spend (advancement)
SoulXpApi.calculate_cost(character, skill_key, target_rating)  # Addendum §3 formula
SoulXpApi.spend(character, skill_key, amount, enactor)
  # Returns { error: "..." } or { success: true, new_rating:, xp_remaining: }

SoulXpApi.get_available_xp(character)
SoulXpApi.get_lifetime_earned_xp(character)
SoulXpApi.get_lifetime_spent_xp(character)
```

### B&B Validation / Transitions

```ruby
SoulBnbApi.get_catalogue(category: nil)
SoulBnbApi.get_catalogue_entry(id_or_tag)
SoulBnbApi.get_character_entries(character)          # Owner/authorized-staff view
SoulBnbApi.get_character_entry_public(character, id) # Public-safe view (no explanation/GM notes)

# Validate a proposed transition without applying it (used by Inklings' validation hook)
SoulBnbApi.validate_transition(character, catalogue_id, target_level, options = {})

# Apply a transition (chargen, staff, or approved Inklings outcome)
SoulBnbApi.apply_transition(character, catalogue_id, target_level, source:, explanation: nil)
  # Returns { error: "..." } or { success: true, entry_id: }

SoulBnbApi.resolve(character, entry_id, reason:, enactor:)   # Non-destructive resolve/negate
```

### Culmination Proposals

```ruby
SoulCulminationApi.propose(character, title, description, source:, requires_approval: true)
SoulCulminationApi.approve(culmination_id, enactor)
SoulCulminationApi.get_culminations(character)
```

Per REQ-023, an integrating plugin MAY propose a Culmination but SHALL NOT create the record directly — SOUL always owns creation after validation/approval.

### Roll Initiation / Completion

```ruby
SoulRollApi.start_roll(character, skill_key, context = {})
  # Returns pending-roll state (REQ-027) or an immediate result if no GM-assist policy applies

SoulRollApi.resolve_pending(pending_roll_id, selections)
  # selections: { tags: [...], accept_suggested: bool, decline: bool }

SoulRollApi.get_roll_history(character, limit: 50, options = {})
```

### Authorized History Queries

```ruby
SoulNarrativeHistoryApi.get_history(character, viewer)   # Privacy-filtered per REQ-005
SoulAuditApi.get_audit(character, viewer)                # Staff-only
```

## Hooks

SOUL provides hooks for other plugins to extend behavior, registered via `get_hooks` (FINAL REQ-047 — stable names, versioned payload contracts, idempotent under duplicate delivery, expose only authorized data).

```ruby
def self.get_hooks(plugin_symbol, hook_name)
  case hook_name
  when :soul_roll_modifiers
    return [MyModifierHandler]
  end
  nil
end
```

### `:soul_roll_modifiers`

Called while resolving a roll. Allows plugins to contribute modifiers (e.g. spell effects, equipment). Contributed modifiers are subject to the same global modifier bounds as B&B modifiers (REQ-030).

**Handler interface:**
```ruby
class MyModifierHandler
  def self.get_modifiers(character, skill_key, context)
    # Return array of { source: "...", value: n, description: "..." }
  end
end
```

## Events

SOUL fires events for other plugins to subscribe to via `get_event_handler`. All events carry stable identifiers and only the context their documented consumers are authorized to see (REQ-047).

### `SoulXpAwardedEvent`

**Fired when:** XP is awarded.

```ruby
event.character_id
event.amount               # post-multiplier total
event.base_award
event.catchup_portion
event.source
event.awarded_at
```

### `SoulSkillAdvancedEvent`

```ruby
event.character_id
event.skill_key
event.old_rating
event.new_rating
event.xp_spent
event.advanced_at
```

### `SoulBnbTransitionedEvent`

**Fired when:** A character B&B entry is granted, progresses, is resolved, or is negated.

```ruby
event.character_id
event.entry_id
event.catalogue_id
event.old_level_state       # nil on initial grant
event.new_level_state
event.source
event.transitioned_at
```

### `SoulCulminationApprovedEvent`

```ruby
event.character_id
event.culmination_id
event.source
event.approved_at
```

### `SoulRollResolvedEvent`

```ruby
event.character_id
event.roll_id
event.skill_key
event.final_result
event.degree_of_success
event.extraordinary
event.gm_assisted
event.resolved_at
```

## Integration Contracts (FINAL REQ-039, REQ-040)

### Inklings: Validation Hook

```ruby
# Inklings calls this before staff approval, to get a normalized payload without mutating state
SoulInklingsHook.validate_outcome(
  outcome_type:,        # :xp, :boon_progression, :bane_progression, :culmination, ...
  character:,
  proposed_transition:,
  requester:,
  inkling_reference:
)
# Returns a validated payload or actionable errors; never mutates SOUL state.
```

### Inklings: Application Hook

```ruby
# Inklings calls this after approval, with the validated payload from above
SoulInklingsHook.apply_outcome(payload, source: "inkling:234")
# Revalidates current state + idempotency, atomically applies, creates
# Narrative History/audit, returns { success:, soul_references: } or { error: }
```

### Grimoire: Read-Only Capability Exchange

```ruby
# Grimoire reads Skills/Aspects/Resonance through documented read APIs only
SoulFrameworkApi.get_skill_rating(caster, "Ceremonial Magic")
# SOUL never receives or stores Grimoire spell history (REQ-040).
```

## Compatibility Contract (FINAL REQ-049)

Public APIs, hooks, event payloads, configuration keys, and stored stable identifiers are documented and versioned. Breaking changes require migration guidance and an explicit version bump — see `docs/development/Release_Process.md`.

## Related Documents

- `docs/architecture/Plugin_Architecture.md` — Where these APIs live in the plugin structure
- `docs/architecture/Event_Flow.md` — Full workflow context for each API call
- `docs/architecture/Integration_Guide.md` — Step-by-step integration patterns for Inklings/Grimoire and other plugins

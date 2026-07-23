# SOUL Integration Guide

How to integrate other AresMUSH plugins with SOUL, derived from `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") §8 (Integration, REQ-038 through REQ-041) and CP-04 (Plugin Ownership).

## Common Rules (FINAL REQ-038)

All integrations SHALL:

- Detect SOUL by capability, not assumption: `defined?(AresMUSH::Soul)`.
- Call only documented public hooks/APIs/services (see `docs/architecture/API_and_Hooks.md`) — never reach into SOUL's models directly.
- Validate permissions in both plugins where applicable.
- Isolate and audit integration failures — a failed integration call SHALL NOT partially mutate SOUL state.
- Carry stable identifiers in every event/hook payload and consume them idempotently where duplicate delivery is possible.
- Provide MUSH/web parity for every supported integrated workflow.
- Provide an equivalent standalone staff path for every integration-triggered SOUL transition — Inklings (or any other integration) is always optional.

## Before You Integrate

1. **Check SOUL's availability** — guard all integration behind a capability check:
   ```ruby
   if defined?(AresMUSH::Soul)
     # Safe to call SOUL APIs
   end
   ```
2. **Document the dependency** in your plugin's README — what depends on SOUL, and what happens if it's absent.
3. **Test both paths** — with and without SOUL installed.

## Pattern: Inklings Outcome Validation and Application (FINAL REQ-039)

Inklings owns the request, narrative content, approval workflow, status, and complete Inkling-side audit/history. SOUL owns validation and application of any resulting SOUL state change. This is a two-step handoff — Inklings never mutates SOUL state itself, and SOUL never stores Inkling narrative content.

**Step 1 — Submission/Validation (before staff approval):**
```ruby
if defined?(AresMUSH::Soul)
  result = SoulInklingsHook.validate_outcome(
    outcome_type: :boon_progression,
    character: character,
    proposed_transition: { catalogue_id: 22, from: "Minor", to: "Major" },
    requester: player,
    inkling_reference: "inkling:234"
  )
  # result is a normalized payload or actionable errors; SOUL has not mutated anything yet.
  # Store the payload with the Inkling record — Inklings owns it until approval.
end
```

**Step 2 — Approval/Application (after staff approves the Inkling):**
```ruby
if defined?(AresMUSH::Soul)
  result = SoulInklingsHook.apply_outcome(stored_payload, source: "inkling:234")
  if result[:error]
    # Surface to staff; Inkling stays in its current state until retried
  else
    # SOUL created the transition + Narrative History; record result[:soul_references] on the Inkling
  end
end
```

Supported outcome types include XP, Boon progression, Bane progression/resolution, and Culmination proposals. Inkling XP applies **only** through this explicit approved-outcome path — never as a side effect of narrative approval alone. Every outcome type SHALL have an equivalent manual staff command (e.g. `+xp/award`, `+bnb` staff transitions) for games not running Inklings.

## Pattern: Grimoire Reading SOUL Skills (FINAL REQ-040)

Grimoire owns its spell catalogue, branch definitions, casting lifecycle, and all spell history. SOUL never stores or reads Grimoire spell data — the relationship is read-only in one direction only.

```ruby
if defined?(AresMUSH::Soul)
  # Grimoire branches MAY map to Spirit Skills; SOUL does not require a separate Arcana Skill
  skill_rating = SoulCharacterApi.get_skill_rating(caster, "ceremonial_magic")
  aspect_rating = SoulCharacterApi.get_aspect_rating(caster, "spirit")
  # Grimoire uses these values in its own casting resolution — SOUL is not asked to resolve the spell roll
  # unless Grimoire explicitly chooses to route a roll through SoulRollApi.start_roll
else
  # Fall back to Grimoire's own resolution mechanics
end
```

If Grimoire wants SOUL to resolve the actual dice roll for a spell (optional, not required):
```ruby
pending = SoulRollApi.start_roll(caster, "ceremonial_magic", { source: "grimoire:spell:#{spell.id}" })
# Grimoire interprets the eventual SoulRollResolvedEvent to determine spell success —
# SOUL still owns the roll record; Grimoire never creates its own parallel roll history for it.
```

SOUL SHALL NOT copy spell data/history or reimplement Grimoire's rules. Missing Grimoire SHALL NOT affect non-magical SOUL functionality (REQ-040).

## Pattern: Subscribing to SOUL Events

```ruby
def self.get_event_handler(event_name)
  case event_name
  when "SoulSkillAdvancedEvent"
    return MyPluginSkillAdvancedHandler
  when "SoulBnbTransitionedEvent"
    return MyPluginBnbHandler
  end
  nil
end
```

```ruby
class MyPluginSkillAdvancedHandler
  def self.on_event(event)
    character = Character.find_one_by_id(event.character_id)
    # React to the advancement — e.g. unlock related content
  end
end
```

Handlers SHALL be idempotent — SOUL documents whether a given event may be delivered more than once for the same logical change.

## Pattern: Providing Roll Modifiers

```ruby
def self.get_hooks(plugin_symbol, hook_name)
  return nil unless plugin_symbol == :soul
  case hook_name
  when :soul_roll_modifiers
    return [MyPluginModifierHandler]
  end
  nil
end
```

```ruby
class MyPluginModifierHandler
  def self.get_modifiers(character, skill_key, context)
    modifiers = []
    if character.has_magical_staff?
      modifiers << { source: "Magical Staff", value: 3, description: "Staff bonus to arcane skills" }
    end
    modifiers
  end
end
```

Contributed modifiers are combined with B&B modifiers and subject to the same global bounds (FINAL REQ-030) — Skill investment SHALL remain meaningful regardless of how many plugins contribute modifiers.

## Handling SOUL Absence

### Graceful Degradation

Document what doesn't work without SOUL, in your own README's "Known Limitations":
```
- Skill-based mechanics: Requires SOUL. Without it, uses fallback mechanics.
- Boon/Bane integration: Requires SOUL. Without it, outcomes are not applied.
```

### Fallback Implementations

```ruby
def self.get_character_power(character)
  if defined?(AresMUSH::Soul)
    SoulCharacterApi.get_skill_rating(character, "sorcery") + 2
  else
    character.legacy_rating("Sorcery")
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
      # Verify: roll used SOUL skill rating and modifiers
    end
  end

  context "when SOUL is absent" do
    it "falls back to custom logic" do
      # Setup: SOUL not loaded
      # Action: trigger roll
      # Verify: fallback logic was used, no error raised
    end
  end
end
```

### Integration Test Pattern

```ruby
setup do
  load_plugin(:soul)
  load_plugin(:inklings)
end

it "applies an Inkling's approved Boon outcome through SOUL" do
  # Create character, propose outcome, approve Inkling
  # Verify SOUL created the B&B transition and Narrative History entry
  # Verify the Inkling stores only the SOUL reference, not a copy of the transition
end
```

## Performance Considerations

### Avoid Repeated API Calls

Cache SOUL reads within a single command/handler execution:
```ruby
def handle(enactor)
  skill_rating = SoulCharacterApi.get_skill_rating(character, "combat")
  # Reuse skill_rating for both checks below instead of calling the API twice
end
```

### Batch Operations

```ruby
# Good: one batch ID, per-recipient idempotency
characters.each do |char|
  SoulXpApi.award(char, amount, source: "scene:#{scene_id}", idempotency_key: "scene:#{scene_id}:#{char.id}")
end
```

### Lazy Integration

```ruby
class MyPlugin
  SOUL_AVAILABLE = defined?(AresMUSH::Soul)
end
```

## Troubleshooting

### "Undefined method" for SOUL APIs

**Cause:** SOUL not installed, or loaded after your plugin.
**Fix:** Wrap every call in `if defined?(AresMUSH::Soul)`.

### Event handler not firing

**Cause:** Hook not registered in `get_hooks`/`get_event_handler`, or wrong event name.
**Fix:** Verify against `docs/architecture/API_and_Hooks.md`, and confirm your handler is registered for the exact event name SOUL fires.

### Modified rolls not applying

**Cause:** Modifier hook returned the wrong shape.
**Fix:** Verify the exact format: `{ source: "string", value: number, description: "string" }`.

## Related Documents

- `docs/architecture/API_and_Hooks.md` — Full API and hook reference
- `docs/architecture/Event_Flow.md` — Detailed workflow sequences, including the Inklings validate/apply handoff
- `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` — REQ-038 through REQ-041 (authoritative)

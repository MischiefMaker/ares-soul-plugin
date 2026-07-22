# SOUL Event Flow

Description of major workflows and event sequences in SOUL. This document captures the typical flow of operations through the system.

## XP Granting Flow

**Initiated by:** Inklings, admin commands, or other plugins via `SoulXpApi.grant_xp`

**Flow:**
1. API method validates character and amount
2. Permission check (admin only, configurable)
3. XP record created and added to character
4. Character's total XP updated
5. `SoulXpGrantedEvent` fired for other plugins
6. Result returned to caller

**Outcome:** Character has new XP available to spend

## Skill Advancement Flow

**Initiated by:** Player via `soul/advance skill` command or web interface

**Flow:**
1. Command/handler unpacks skill and amount
2. Permission check (player owns character or staff override)
3. Skill advancement API called
4. Validation:
   - Character exists and has the skill
   - Enough XP available
   - New rating within valid range
   - Advancement rules met (catch-up, cooldown, etc.)
5. XP deducted, skill rating updated
6. `SoulSkillAdvancedEvent` fired
7. Success message sent to player

**Outcome:** Skill is improved, XP is spent

## Roll Workflow

### Basic Roll (Immediate Resolution)

**Initiated by:** Player via `roll` command or web interface

**Flow:**
1. Player specifies skill, pool size, and description
2. Roll permission check
3. Base roll executed
4. B&B modifiers collected via `soul_roll_modifiers` hook
5. Modifiers applied to result
6. Roll record created with full history
7. Result displayed to player and observers
8. `SoulRollResolvedEvent` fired

**Outcome:** Roll is completed and logged

### GM-Assisted Roll (Asynchronous Workflow)

**Initiated by:** Player flags roll for GM review, or system auto-queues based on policy

**Flow:**

**Player Phase:**
1. Player makes a roll or specifies they want GM review
2. Roll created with `status: "pending"`
3. PendingRoll created, queued for review
4. Player receives acknowledgment

**GM Phase:**
1. GM checks `@pending-rolls` or web queue
2. GM can:
   - **Approve:** Final result accepted, roll resolved
   - **Reject:** Player re-rolls, PendingRoll cleared
   - **Modify:** GM adjusts result within valid range
   - **Ask Questions:** GM adds notes, requests details

**Resolution Phase:**
1. If GM approved/modified: Roll marked resolved
2. If GM rejected: Player re-rolls, new roll created
3. `SoulRollResolvedEvent` fired with final result
4. Player and observer notifications sent

**Outcome:** Roll is resolved with GM oversight

## Boon & Bane Lifecycle

### Creation

**Initiated by:** Admin via `boon/create` command

**Flow:**
1. Parse command arguments (name, description, category, effects)
2. Validate inputs
3. Create Boon record
4. Return success to admin

**Outcome:** New Boon/Bane template exists

### Granting to Character

**Initiated by:** Admin command, Inklings reward, or scene event

**Flow:**
1. Validate character and Boon exist
2. Create CharacterBoon instance
3. Record source (admin, scene, plugin, etc.)
4. Set status to "active"
5. `SoulBoonActivatedEvent` fired
6. Notify character
7. Update character sheet

**Outcome:** Character now has the Boon/Bane

### Resolution

**Initiated by:** Admin, character, or system (based on conditions)

**Flow:**
1. Validate CharacterBoon exists and is active
2. Record resolution reason and timestamp
3. Set status to "resolved"
4. Update character data (remove from active list, archive to history)
5. `SoulBoonResolvedEvent` fired
6. Notify character
7. Update character sheet

**Outcome:** B&B is archived, no longer mechanically active

## Permission-Gated Operations

All mutations (create, edit, delete, advance, etc.) follow this pattern:

1. Check login (player logged in or connection is trusted)
2. Check permission (configurable permission name)
3. Check validity (resource exists, target character is valid, etc.)
4. Execute mutation
5. Return `{ error: "..." }` on failure, success hash on success

**Example:**
```ruby
def self.can_advance_skill?(enactor)
  return false if !enactor
  permission = Global.read_config("soul", "advance_skill_permission") || "play"
  enactor.has_permission?(permission)
end
```

## Integration Points

### Grimoire Integration

When Grimoire needs to resolve a spell cast via SOUL:

1. Grimoire calls `SoulRollApi.create_roll` with skill ID
2. SOUL creates roll with Grimoire as source
3. SOUL applies B&B modifiers
4. SOUL returns final result
5. Grimoire processes spell effect based on result

### Inklings Integration

When Inklings awards XP or Boons based on thread resolution:

1. Inklings determines reward amount and type
2. Inklings calls `SoulXpApi.grant_xp` or `SoulBoonApi.grant_boon`
3. SOUL validates and applies reward
4. Inklings receives confirmation and updates Inkling record
5. Character sees reward notification and updated sheet

### Other Plugins

Similar pattern via public APIs and event subscriptions.

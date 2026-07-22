# SOUL Data Model

Database schema and data structures for SOUL. This document describes the core models and their relationships.

## Core Models

### Aspect

Represents a category or focus area for character development (e.g., "Combat", "Social", "Arcane").

**Purpose:** Organizes skills and provides context for character progression.

**Key Attributes:**
- `name` - Display name
- `description` - Brief description
- `order` - Display order
- `active` - Whether this Aspect is available for new characters

**Relationships:**
- Has many Skills

### Skill

Represents a learnable ability within an Aspect.

**Purpose:** Core unit of character advancement and capability.

**Key Attributes:**
- `name` - Skill name
- `description` - What the skill represents
- `aspect_id` - Parent Aspect
- `order` - Display order
- `min_rating` / `max_rating` - Valid rating range
- `active` - Whether this skill is available

**Relationships:**
- Belongs to Aspect
- Has many CharacterSkills

### CharacterSkill

Represents a character's rating and progress in a specific skill.

**Purpose:** Tracks individual character advancement.

**Key Attributes:**
- `character_id` - Character who has the skill
- `skill_id` - The Skill
- `rating` - Current rating (0-5 or configured range)
- `xp_spent` - Total XP invested
- `last_advanced_at` - Timestamp of last rating increase
- `notes` - Admin/player notes about this skill

**Relationships:**
- Belongs to Character
- Belongs to Skill

### Boon / Bane

Reusable templates for mechanical and narrative effects that modify character capabilities.

**Purpose:** Define the types of Boons and Banes available in the game.

**Key Attributes:**
- `name` - Template name
- `description` - What this B&B represents
- `category` - "boon" or "bane"
- `mechanical_effect` - How it modifies rolls/mechanics
- `tags` - Categorization (e.g., "combat", "social", "magical")
- `active` - Whether characters can gain new instances

**Relationships:**
- Has many CharacterBoons

### CharacterBoon

Character-specific instance of a Boon or Bane, including state and history.

**Purpose:** Track active and resolved B&Bs on individual characters, with lifecycle.

**Key Attributes:**
- `character_id` - Character who has this B&B
- `boon_id` - The template (Boon/Bane definition)
- `status` - "active", "resolved", or "expired"
- `source` - Origin (e.g., "scene_id:42", "reward:inklings", "admin")
- `granted_at` - When the character gained this B&B
- `resolved_at` - When it was resolved (if applicable)
- `resolution_reason` - Why it was resolved
- `custom_name` - Override template name for this instance
- `custom_description` - Character-specific details
- `mechanical_value` - Current numerical effect
- `notes` - History and context

**Relationships:**
- Belongs to Character
- Belongs to Boon (template)

### Roll

Record of a character roll, including outcome and modifiers applied.

**Purpose:** Track roll history and enable GM review workflows.

**Key Attributes:**
- `character_id` - Who made the roll
- `skill_id` - Skill used (if any)
- `scene_id` - Scene context (if any)
- `base_roll` - Unmodified result
- `modifiers_applied` - Array of modifier sources (skill, B&Bs, etc.)
- `final_result` - Result after modifiers
- `rolled_at` - Timestamp
- `description` - What the roll was for
- `gm_verified` - Whether a GM reviewed it
- `status` - "pending", "resolved", "disputed"

**Relationships:**
- Belongs to Character
- Belongs to Skill (optional)
- Belongs to Scene (optional)

### PendingRoll

Represents a roll awaiting GM approval in an asynchronous workflow.

**Purpose:** Queue rolls for GM review without blocking gameplay.

**Key Attributes:**
- `roll_id` - The Roll being reviewed
- `requested_at` - When review was requested
- `gm_assigned_to` - GM staff member (if assigned)
- `gm_notes` - GM review comments
- `status` - "waiting", "approved", "rejected", "modified", "expired"
- `expires_at` - When auto-reject occurs if not reviewed
- `resolved_at` - When the review completed

**Relationships:**
- Belongs to Roll
- Belongs to Character (through Roll)

## Character Integration

SOUL attaches to Ares Characters via custom fields:

**Stored as:**
- `char.custom.soul_data` - JSON blob or serialized hash containing:
  - Total XP earned and spent
  - Total Resonance earned and spent
  - Catch-up XP status
  - Character-specific configuration

**Accessed via:**
- `SoulCharacterApi.get_character_data(character)`
- `SoulCharacterApi.update_character_data(character, updates)`

## Relationship Diagram

```
Character
  ├─→ CharacterSkill → Skill → Aspect
  ├─→ CharacterBoon → Boon
  ├─→ Roll → Scene
  ├─→ PendingRoll → Roll
  └─→ custom.soul_data (XP, Resonance, etc.)
```

## Data Integrity

- Skills and Boons/Banes can be marked inactive but not deleted (preserve history)
- Character skills maintain immutable history of ratings and advancement
- Rolls are append-only (cannot be modified after creation; disputes go to GM)
- B&B lifecycle is recorded (when granted, by whom, when resolved, why)

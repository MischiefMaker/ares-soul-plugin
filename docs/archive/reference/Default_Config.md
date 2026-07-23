# Default Configuration (game/config/soul.yml)

Complete default configuration file for SOUL. Copy this to your game's `game/config/soul.yml` directory as a starting point.

```yaml
# SOUL Configuration
# This file defines all gameplay settings for the SOUL plugin.
# Changes take effect immediately without restarting the plugin.

enabled: true

# ============================================================================
# Skill System
# ============================================================================

skill_max_rating: 5
skill_min_rating: 0

# ============================================================================
# XP System
# ============================================================================

xp:
  # Base XP awarded per completed scene
  base_per_scene: 10
  
  # XP cost to advance each skill rating (indexed by current rating)
  # Index 0 = cost to go from 0→1, Index 1 = 1→2, etc.
  advancement_cost:
    - 10   # 0 → 1
    - 20   # 1 → 2
    - 30   # 2 → 3
    - 40   # 3 → 4
    - 50   # 4 → 5
  
  # Multiplier for catch-up XP (XP earned by characters behind average)
  catchup_multiplier: 1.5
  
  # How far behind average rating triggers catch-up (negative = below average)
  catchup_threshold: -5
  
  # Optional: maximum XP per calendar month (null = unlimited)
  max_per_month: null

# ============================================================================
# Resonance System
# ============================================================================

resonance:
  # Resonance earned per 1 XP spent on skill advancement
  earn_per_xp: 0.2
  
  # Maximum Resonance a character can accumulate
  max_pool: 100
  
  # Per-week Resonance loss (0 = no decay, 1 = lose 1 per week, etc.)
  decay_rate: 0

# ============================================================================
# Boons & Banes System
# ============================================================================

boons:
  # Maximum concurrent active Boons/Banes a character can have
  max_active: 10
  
  # Default duration in days before a B&B expires (0 = indefinite)
  default_duration: 0
  
  # Whether a character can have multiple instances of the same B&B type
  allow_duplicates: false

# ============================================================================
# Roll System
# ============================================================================

rolls:
  # Default difficulty for rolls (adjust for your game's scale)
  default_difficulty: 7
  
  # Roll result that's an automatic critical success (null = none)
  critical_success: 10
  
  # Roll result that's an automatic critical failure (null = none)
  critical_failure: 1
  
  # Whether GM-assisted roll workflow is enabled
  gm_review_enabled: true
  
  # Auto-queue rolls at/above this difficulty for GM review (null = off)
  gm_auto_queue_threshold: null
  
  # Seconds before pending roll auto-resolves if not reviewed (0 = no timeout)
  gm_review_timeout: 3600

# ============================================================================
# Permissions (configurable permission names)
# ============================================================================

permissions:
  # Permission to advance skills via XP spending
  advance_skill: "play"
  
  # Permission to make/request rolls
  create_roll: "play"
  
  # Permission to request GM review for a roll
  request_gm_review: "play"
  
  # Permission for admin SOUL operations (grant XP, manage B&Bs, etc.)
  manage_soul: "manage_jobs"
  
  # Permission to review and approve pending rolls
  gm_review: "gm"

# ============================================================================
# Aspects & Skills
# ============================================================================

# Aspects organize skills into meaningful categories.
# Each aspect contains a list of skills available within that aspect.

aspects:
  combat:
    name: "Combat"
    description: "Martial prowess and combat ability"
    order: 1
    skills:
      blade:
        name: "Blade"
        description: "Proficiency with swords and bladed weapons"
        order: 1
      ranged:
        name: "Ranged"
        description: "Proficiency with bows, firearms, and projectiles"
        order: 2
      unarmed:
        name: "Unarmed"
        description: "Hand-to-hand combat without weapons"
        order: 3
      endurance:
        name: "Endurance"
        description: "Physical stamina and resistance to harm"
        order: 4
  
  social:
    name: "Social"
    description: "Charm, persuasion, and interpersonal skills"
    order: 2
    skills:
      empathy:
        name: "Empathy"
        description: "Understanding and connecting emotionally with others"
        order: 1
      persuasion:
        name: "Persuasion"
        description: "Convincing others to your viewpoint"
        order: 2
      deception:
        name: "Deception"
        description: "Lying, misdirection, and creating false impressions"
        order: 3
      leadership:
        name: "Leadership"
        description: "Inspiring and directing others"
        order: 4
  
  mental:
    name: "Mental"
    description: "Intelligence, perception, and problem-solving"
    order: 3
    skills:
      investigation:
        name: "Investigation"
        description: "Analyzing clues and solving puzzles"
        order: 1
      academics:
        name: "Academics"
        description: "Knowledge and learning in formalized subjects"
        order: 2
      intuition:
        name: "Intuition"
        description: "Reading situations and people by instinct"
        order: 3
      craft:
        name: "Craft"
        description: "Building, repairing, and creating with skill"
        order: 4
  
  arcane:
    name: "Arcane"
    description: "Magical knowledge and power"
    order: 4
    skills:
      spellcasting:
        name: "Spellcasting"
        description: "The ability to cast and control magical effects"
        order: 1
      rituals:
        name: "Rituals"
        description: "Complex magical procedures and ceremonial magic"
        order: 2
      magical_defense:
        name: "Magical Defense"
        description: "Protecting against magical harm and effects"
        order: 3
      magical_knowledge:
        name: "Magical Knowledge"
        description: "Understanding the nature and theory of magic"
        order: 4

# ============================================================================
# End of Configuration
# ============================================================================
# For detailed documentation, see:
# - docs/reference/Configuration.md
# - docs/reference/Commands.md
# - docs/architecture/Integration_Guide.md
```

## Customization Guide

### Adjusting XP Progression

To make advancement faster:
```yaml
xp:
  advancement_cost: [5, 10, 15, 20, 25]    # Cheaper advancement
  base_per_scene: 15                        # More XP per scene
```

To make advancement slower:
```yaml
xp:
  advancement_cost: [15, 30, 45, 60, 75]   # Costlier advancement
  base_per_scene: 5                         # Less XP per scene
```

### Adding Custom Aspects

Add a new aspect and its skills:
```yaml
aspects:
  custom:
    name: "My Custom Aspect"
    description: "What this aspect represents"
    order: 5
    skills:
      my_skill:
        name: "My Skill"
        description: "What this skill does"
        order: 1
```

### Adjusting Difficulty

For d10 systems (1-10 scale):
```yaml
rolls:
  default_difficulty: 6  # Easy
  default_difficulty: 7  # Medium (default)
  default_difficulty: 8  # Hard
  default_difficulty: 9  # Very Hard
```

For d20 systems (1-20 scale):
```yaml
rolls:
  default_difficulty: 10   # Easy
  default_difficulty: 15   # Medium
  default_difficulty: 18   # Hard
  critical_success: 20
  critical_failure: 1
```

### Restricting Features

To disable GM-assisted rolls:
```yaml
rolls:
  gm_review_enabled: false
```

To require staff approval for skill advancement:
```yaml
permissions:
  advance_skill: "manage_jobs"
```

## Notes

- All configuration values are read live; no plugin reload required
- Skill costs are indexed by current rating (so index 0 is the cost to advance *to* rating 1)
- Permission names should exist in your Ares role configuration
- Aspects and skills can be customized to fit your game's setting and power level

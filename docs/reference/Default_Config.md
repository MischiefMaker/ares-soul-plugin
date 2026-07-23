# Default Configuration (game/config/soul.yml)

Complete default configuration file for SOUL, matching the canonical defaults in `docs/reference/Configuration.md` (derived from `SOUL_LLM_Implementation_Specification_FINAL.md` and `Implementation_Specification_Addendum.md`). Copy this to your game's `game/config/soul.yml` as a starting point.

```yaml
# SOUL Configuration
# Changes take effect immediately without restarting the plugin.

# ============================================================================
# Character Framework
# ============================================================================

framework:
  skill_min_rating: 0
  skill_max_rating: 10   # Ultimate cap at every Resonance tier

  aspects:
    body:
      name: "Body"
      description: "Physical capability and endurance"
      order: 1
    mind:
      name: "Mind"
      description: "Intellect, perception, and reason"
      order: 2
    spirit:
      name: "Spirit"
      description: "Willpower, emotional depth, and the arcane"
      order: 3

  # Skills map to exactly one Aspect by stable key. Example starter set:
  skills:
    strength:
      name: "Strength"
      aspect: "body"
      order: 1
    reflexes:
      name: "Reflexes"
      aspect: "body"
      order: 2
    stamina:
      name: "Stamina"
      aspect: "body"
      order: 3
    investigation:
      name: "Investigation"
      aspect: "mind"
      order: 1
    empathy:
      name: "Empathy"
      aspect: "mind"
      order: 2
    academics:
      name: "Academics"
      aspect: "mind"
      order: 3
    resolve:
      name: "Resolve"
      aspect: "spirit"
      order: 1
    ceremonial_magic:
      name: "Ceremonial Magic"
      aspect: "spirit"
      order: 2
    presence:
      name: "Presence"
      aspect: "spirit"
      order: 3

# ============================================================================
# Aspect Roll Contribution
# ============================================================================

aspect:
  weight: 0.20
  contribution_rounding: "nearest"

# ============================================================================
# Resonance
# ============================================================================

resonance:
  enabled: true
  min: -3
  max: 3
  r0_skill_points: 15
  r0_starting_cap: 7
  positive_skill_points_per_level: 2
  negative_skill_points_per_level: 2
  positive_starting_cap_per_level: 1
  negative_starting_cap_per_level: 1
  review_flag_at_extremes: true

# ============================================================================
# XP
# ============================================================================

xp:
  weekly_award: 1
  scene_sharer_award: 2
  scene_participant_award: 1
  forum_award: 1

  cost:
    skill_curve_numerator: 1
    skill_curve_denominator: 2
    development_base: 1
    development_scale: 250
    development_exponent: 1.25
    negative_resonance_rate: 0.12
    positive_resonance_rate: 0.22
    positive_resonance_surcharge: 1

  catchup:
    enabled: true
    schedule: "weekly"
    multiplier: 2.0
    grace_period_weeks: 0
    sources_excluded:
      - manual_grant

# ============================================================================
# Boons & Banes
# ============================================================================

bnb:
  categories:
    - "Arcane"
    - "Mundane"

  level_definitions:
    minor:
      modifier: 1
      chargen_available: true
    major:
      modifier: 2
      chargen_available: true
    legendary:
      modifier: 3
      chargen_available: true
    negated:
      modifier: 0
      chargen_available: false
    epic:
      modifier: null   # SHALL be explicitly configured per-entry; no implied value
      chargen_available: false

  definition_defaults:
    chargen_available: true
    flag_for_review: false
    modifier_eligible: false

  chargen_ratio: 2            # 1 qualifying Bane required per 2 Boons
  ratio_rounding: "floor"

  resonance_levels:
    r_minus_3:
      boons: { max_count: 0, max_at_level_2: 0, max_at_level_3: 0 }
      banes: { max_count: null, max_at_level_2: 3, max_at_level_3: 3 }
    r_minus_2:
      boons: { max_count: 0, max_at_level_2: 0, max_at_level_3: 0 }
      banes: { max_count: null, max_at_level_2: 2, max_at_level_3: 2 }
    r_minus_1:
      boons: { max_count: 1, max_at_level_2: 0, max_at_level_3: 0 }
      banes: { max_count: null, max_at_level_2: 2, max_at_level_3: 1 }
    r_0:
      boons: { max_count: 2, max_at_level_2: 1, max_at_level_3: 0 }
      banes: { max_count: null, max_at_level_2: 1, max_at_level_3: 0 }
    r_1:
      boons: { max_count: 3, max_at_level_2: 2, max_at_level_3: 0 }
      banes: { max_count: null, max_at_level_2: 2, max_at_level_3: 1 }
    r_2:
      boons: { max_count: 3, max_at_level_2: 3, max_at_level_3: 1 }
      banes: { max_count: null, max_at_level_2: 3, max_at_level_3: 2 }
    r_3:
      boons: { max_count: 4, max_at_level_2: 3, max_at_level_3: 2 }
      banes: { max_count: null, max_at_level_2: 3, max_at_level_3: 3 }

# ============================================================================
# Rolls
# ============================================================================

rolls:
  random_model: "d20_open_ended"

  difficulties:
    trivial: 11
    easy: 12
    standard: 13
    difficult: 17
    hard: 21
    extreme: 25
    legendary: 34
    mythic: 40

  explosion:
    enabled: true
    trigger: "double_20"

  implosion:
    enabled: true
    trigger: "double_1"

  boon_bane:
    max_positive_modifier: null   # No cap; intentional
    max_negative_modifier: null   # No cap; intentional

  extraordinary_result_threshold: 0.0001
  extraordinary_result_good: "In a shocking display of good luck"
  extraordinary_result_bad: "In a fit of bad luck"

  degrees_of_success:
    exceptional_success_min: 10
    success_min: 0
    complicated_success_min: -5
    lucky_failure_min: -10
    catastrophic_failure_min: null

  output_mode: "gm_led"   # alternatives: "gm_less", "hybrid"

  pending_roll_timeout_hours: 720
  auto_failure_on_expiry: false
  max_pending_rolls_per_player: 1
  max_pending_rolls_per_player_gm: 2

  gm_scene_policy: "optional"   # "required", "optional", or "unavailable"

# ============================================================================
# Privacy
# ============================================================================

privacy:
  gm_reveal_categories:
    - "name"
    - "public_description"
  warn_on_broader_reveal: true

# ============================================================================
# Culminations
# ============================================================================

culminations:
  approval_required: true

# ============================================================================
# Notifications
# ============================================================================

notifications:
  character_facing_success: true

# ============================================================================
# Permissions (configurable permission names)
# ============================================================================

permissions:
  play: "play"                       # Baseline: sheet, rolls, XP spend, B&B lookup
  gm_review: "gm"                    # Scene-GM authority for GM-assisted rolls
  manage_soul: "manage_jobs"          # Staff: framework, Resonance, B&Bs, XP awards, Culminations

# ============================================================================
# Integrations
# ============================================================================

integrations:
  inklings:
    enabled: true
    inspiration_cost: 0
  grimoire:
    enabled: true

# ============================================================================
# End of Configuration
# ============================================================================
# For detailed documentation, see:
# - docs/reference/Configuration.md
# - docs/reference/Commands.md
# - docs/reference/Permissions.md
# - docs/architecture/Integration_Guide.md
```

## Customization Guide

### Adjusting XP Pacing

Slower advancement (steeper development curve):
```yaml
xp:
  cost:
    development_scale: 150      # Ramps up faster than the 250 default
```

Faster advancement:
```yaml
xp:
  weekly_award: 2
  scene_sharer_award: 3
```

### Adding Custom Aspects or Skills

Aspects and Skills are fully configurable, but changing the default three Aspects (Body/Mind/Spirit) is a significant deviation from FINAL's default framework — document the change in your game's own design notes.

```yaml
framework:
  skills:
    my_skill:
      name: "My Skill"
      aspect: "mind"     # Must reference an existing Aspect key
      order: 5
```

### Adjusting Difficulty

Difficulty values are fixed to the 8-level scale in `rolls.difficulties` by default (Addendum §1), but every value is independently configurable:
```yaml
rolls:
  difficulties:
    standard: 15   # Raise the baseline difficulty for a grittier game
```

### Restricting Features

Require staff approval for XP spending:
```yaml
permissions:
  play: "manage_jobs"   # Not recommended; overrides baseline play permission broadly
```

Disable GM-assisted rolls entirely:
```yaml
rolls:
  gm_scene_policy: "unavailable"
```

## Notes

- All configuration values are read live; no plugin reload required.
- `null` represents "no configured cap" only where explicitly documented (e.g. `banes.max_count`, `bnb.level_definitions.epic.modifier`).
- Permission names should exist in your Ares role configuration.
- Changing interconnected defaults (e.g. `aspect.weight` alongside `xp.cost.*`) may affect pacing, probability, and staff workload — see `docs/spec/Implementation_Specification_Addendum.md` for the rationale behind each default.

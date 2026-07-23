# SOUL Configuration Reference

All configuration options for SOUL in `game/config/soul.yml`. All values are read live; changes take effect immediately after editing.

## Core Settings

| Key | Default | Description |
|-----|---------|-------------|
| `enabled` | `true` | Whether SOUL system is active |
| `skill_max_rating` | `5` | Maximum skill rating a character can achieve |
| `skill_min_rating` | `0` | Minimum skill rating (typically 0 or 1) |

## XP Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `xp.base_per_scene` | `10` | Base XP awarded per completed scene |
| `xp.advancement_cost` | `[10, 20, 30, 40, 50]` | XP cost to advance each rating (index = current rating) |
| `xp.catchup_multiplier` | `1.5` | XP earning multiplier for catch-up XP |
| `xp.catchup_threshold` | `-5` | Ratings below group average that trigger catch-up (negative = behind average) |
| `xp.max_per_month` | `100` | Maximum XP a character can earn in a month (optional, for balance) |

## Resonance Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `resonance.earn_per_xp` | `0.2` | Resonance earned per XP spent |
| `resonance.max_pool` | `100` | Maximum Resonance a character can accumulate |
| `resonance.decay_rate` | `0` | Per-week Resonance loss (0 = no decay) |

## Boons & Banes Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `boons.max_active` | `10` | Maximum concurrent Boons/Banes a character can have |
| `boons.default_duration` | `0` | Default time in days before B&B expires (0 = indefinite) |
| `boons.allow_duplicates` | `false` | Whether a character can have multiple instances of same B&B |

## Roll Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `rolls.default_difficulty` | `7` | Standard difficulty for rolls (typically 6-8 in d10 systems) |
| `rolls.critical_success` | `10` | Roll result that's always a critical success (or null) |
| `rolls.critical_failure` | `1` | Roll result that's always a critical failure (or null) |
| `rolls.gm_review_enabled` | `true` | Whether GM-assisted rolls are available |
| `rolls.gm_auto_queue_threshold` | `null` | If set, rolls at/above this difficulty auto-queue for GM review |
| `rolls.gm_review_timeout` | `3600` | Seconds before pending roll auto-resolves (0 = no timeout) |

## Aspects

Configuration section defining available Aspects. Each Aspect contains skills.

```yaml
aspects:
  combat:
    name: "Combat"
    description: "Martial and physical prowess"
    order: 1
  social:
    name: "Social"
    description: "Charm, persuasion, manipulation"
    order: 2
  arcane:
    name: "Arcane"
    description: "Magical knowledge and power"
    order: 3
```

**Per-Aspect Fields:**
- `name` - Display name
- `description` - What this aspect represents
- `order` - Display order
- `skills` - Nested list of skills (see Skills section)

## Skills

Configuration section defining skills within Aspects.

```yaml
aspects:
  combat:
    skills:
      blade:
        name: "Blade"
        description: "Proficiency with swords and bladed weapons"
        order: 1
      ranged:
        name: "Ranged"
        description: "Proficiency with bows and ranged weapons"
        order: 2
```

**Per-Skill Fields:**
- `name` - Display name
- `description` - What the skill represents
- `order` - Display order

## Permissions

Configuration section defining permission names for various operations.

| Key | Default | Description |
|-----|---------|-------------|
| `permissions.advance_skill` | `"play"` | Permission to spend XP and advance skills |
| `permissions.create_roll` | `"play"` | Permission to make rolls |
| `permissions.request_gm_review` | `"play"` | Permission to request GM review for a roll |
| `permissions.manage_soul` | `"manage_jobs"` | Permission for admin SOUL commands |
| `permissions.gm_review` | `"gm"` | Permission to review/approve pending rolls |

## Example Configuration

```yaml
# game/config/soul.yml

enabled: true

skill_max_rating: 5
skill_min_rating: 0

xp:
  base_per_scene: 10
  advancement_cost: [10, 20, 30, 40, 50]
  catchup_multiplier: 1.5
  catchup_threshold: -5
  max_per_month: null

resonance:
  earn_per_xp: 0.2
  max_pool: 100
  decay_rate: 0

boons:
  max_active: 10
  default_duration: 0
  allow_duplicates: false

rolls:
  default_difficulty: 7
  critical_success: 10
  critical_failure: 1
  gm_review_enabled: true
  gm_auto_queue_threshold: null
  gm_review_timeout: 3600

permissions:
  advance_skill: "play"
  create_roll: "play"
  request_gm_review: "play"
  manage_soul: "manage_jobs"
  gm_review: "gm"

aspects:
  combat:
    name: "Combat"
    description: "Martial and physical prowess"
    order: 1
    skills:
      blade:
        name: "Blade"
        description: "Swords and bladed weapons"
        order: 1
      ranged:
        name: "Ranged"
        description: "Bows and projectiles"
        order: 2
  social:
    name: "Social"
    description: "Charm, persuasion, deception"
    order: 2
    skills:
      empathy:
        name: "Empathy"
        description: "Understanding and connecting with others"
        order: 1
      persuasion:
        name: "Persuasion"
        description: "Convincing others to your viewpoint"
        order: 2
```

## Configuration Notes

- All changes to `soul.yml` take effect immediately (no plugin reload needed)
- Permission defaults assume existing Ares permission structure; customize for your game
- XP advancement costs are indexed by current rating (index 0 = rating 1→2, etc.)
- Catch-up XP activates when a character is N ratings behind the group average
- Difficulty values should match your game's scale (typically d10: 6-8, d20: 12-15)
- Setting `gm_review_timeout` to 0 disables automatic expiration

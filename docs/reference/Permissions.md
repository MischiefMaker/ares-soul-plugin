# SOUL Permissions Reference

Permission model for SOUL operations. All permissions are configurable in `game/config/soul.yml`.

## Permission Overview

SOUL uses Ares's existing permission system with configurable permission names. This allows games to use existing permissions or define new ones as needed.

## Core Permissions

| Permission | Default | Purpose |
|-----------|---------|---------|
| `play` | All approved characters | Basic character operations (view sheet, check status) |
| `play` | All approved characters | Advance skills via XP spending |
| `play` | All approved characters | Create/request rolls |
| `gm` | GM staff | Review and approve pending rolls |
| `manage_jobs` | Admin/wizards | Manage SOUL system, grant XP, edit skills, create/resolve B&Bs |

## Configuration

Permissions are configured in `game/config/soul.yml` under the `permissions` section:

```yaml
permissions:
  advance_skill: "play"              # Who can spend XP to advance
  create_roll: "play"                # Who can make rolls
  request_gm_review: "play"          # Who can request GM review
  manage_soul: "manage_jobs"         # Who can admin SOUL (grant XP, etc.)
  gm_review: "gm"                    # Who can approve pending rolls
```

## Permission-Gated Operations

### Player Operations (default: "play")

- View own character sheet (`soul` command)
- List own skills (`soul/skills` command)
- Check own XP and Resonance
- Spend XP to advance skills
- Make basic rolls
- Request GM review for rolls
- Accept/decline roll requests from others

**Override:** To restrict player operations (e.g., only staff can advance skills):
```yaml
permissions:
  advance_skill: "manage_jobs"       # Only staff can advance
```

### Staff Operations (default: "manage_jobs")

- Grant XP to characters
- Directly set skill ratings
- Create new Boon/Bane templates
- Grant/resolve B&Bs on characters
- Reset character SOUL data (admin recovery)
- Reload configuration

**Override:** To create a dedicated SOUL admin role:
```yaml
permissions:
  manage_soul: "manage_soul"         # Separate permission for SOUL admins
```

Then add "manage_soul" to the desired roles.

### GM Operations (default: "gm")

- Review pending rolls
- Approve/reject/modify rolls
- Add notes to rolls
- Assign rolls to themselves
- Override roll decisions

**Override:** To require a specific GM role:
```yaml
permissions:
  gm_review: "story_admin"           # Specific role for roll oversight
```

## Typical Permission Setups

### Default (Most Permissive)

Uses existing Ares permissions with minimal customization:

```yaml
permissions:
  advance_skill: "play"              # All players
  create_roll: "play"                # All players
  request_gm_review: "play"          # All players
  manage_soul: "manage_jobs"         # Admins (existing)
  gm_review: "gm"                    # GMs (existing)
```

### Strict (Staff-Controlled)

Only staff can do most things:

```yaml
permissions:
  advance_skill: "manage_jobs"       # Staff only advance skills
  create_roll: "manage_jobs"         # Staff only roll
  request_gm_review: "manage_jobs"   # Staff only request review
  manage_soul: "manage_jobs"         # Admins
  gm_review: "gm"                    # GMs
```

### Hybrid (Delegated GM Authority)

GMs have more power; split admin duties:

```yaml
permissions:
  advance_skill: "play"              # All players
  create_roll: "play"                # All players
  request_gm_review: "play"          # All players
  manage_soul: "story_admin"         # Story admins (separate from regular admins)
  gm_review: "story_admin"           # Same group reviews and manages
```

## Permission Checks in Code

### In Commands

```ruby
def check_can_manage
  return nil if Permissions.can_manage_soul?(enactor)
  "You don't have permission to manage SOUL."
end
```

### In Web Handlers

```ruby
def handle(request)
  if !Permissions.can_manage_soul?(request.enactor)
    return { error: "You don't have permission." }
  end
  # ... proceed with operation
end
```

### In APIs

```ruby
def self.grant_xp(character, amount, source, enactor)
  if !Permissions.can_manage_soul?(enactor)
    return { error: "You don't have permission." }
  end
  # ... grant XP
end
```

## Default Ares Roles

For reference, Ares ships with these roles:

| Role | Permissions |
|------|------------|
| `everyone` | No special permissions |
| `approved` | `play` (can have characters) |
| `builder` | `build` (can edit rooms/exits) |
| `coder` | `code` (can edit code) |
| `wizard` | `manage_jobs`, `manage_ares`, `manage_mail`, etc. (admin) |
| `admin` | All permissions |
| `guest` | Guest account permissions |

**Note:** SOUL defaults assume "play" and "manage_jobs" exist. If your game uses different role names, configure accordingly.

## Implementing Custom Permissions

To create a custom permission specific to SOUL:

1. In `game/config/soul.yml`:
```yaml
permissions:
  manage_soul: "manage_soul"         # New permission
```

2. Add the permission to your desired role(s) via core Ares config (`game/config/ares.yml` or admin interface)

3. Verify it works:
```
@permissions
```

## FAQ

**Q: Can I restrict XP advancement to admins only?**

A: Yes. Set `advance_skill: "manage_jobs"` (or a more restrictive permission).

**Q: Can players request GM review but not make basic rolls?**

A: No. Both default to the same permission. You'd need to refactor to separate them or accept both together.

**Q: What if I don't have a "gm" permission defined?**

A: Create one in your role configuration, or use an existing permission like "manage_jobs" for GMs.

**Q: Can non-admins create new Boons & Banes?**

A: Only if you override `manage_soul` to a less restrictive permission. Not recommended; reserve creation for admins.

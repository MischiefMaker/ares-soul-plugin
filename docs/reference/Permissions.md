# SOUL Permissions Reference

Permission and privacy model for SOUL, derived from `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") §4.5 (REQ-005). All permission names are configurable in `game/config/soul.yml`.

## Permission Tiers (FINAL REQ-005)

FINAL defines four tiers of capability. The final permission matrix — exact commands/handlers mapped to each tier — is enumerated in `docs/reference/Commands.md`.

| Tier | Scope | Default Permission |
|---|---|---|
| **Player** | Own character only | `play` |
| **Scene-GM** | Active scene only, bounded by configured reveal policy | `gm` |
| **Staff/Admin** | Global; requires explicit permission | `manage_soul` (→ `manage_jobs` by default) |

### Player Operations (default: `play`)

Players MAY perform supported actions for their own characters:
- View own SOUL Sheet (`+soul`)
- View own XP, Resonance, roll history
- Spend XP to advance Skills
- Start rolls (`+roll`), select suggested/tagged/none B&Bs
- View/search the public B&B catalogue
- View own Narrative History

**Override example** — restrict XP spending to staff:
```yaml
permissions:
  play: "manage_jobs"   # Not recommended for normal play
```

### Scene-GM Operations (default: `gm`)

Scene-GM authority is **limited to the active scene** and the configured reveal policy — a GM does not gain global visibility into a character's private B&B explanations or GM notes by virtue of being a GM.

- Mark candidate B&Bs mandatory/optional during a GM-assisted roll (`+roll/gm`)
- See only the fields the reveal policy permits (see Privacy below)
- Force-abort an erroneous pending roll in their scene (requires reason + audit)

### Staff/Admin Operations (default: `manage_soul` → `manage_jobs`)

Staff administration SHALL require explicit permission — never inferred from scene-GM status:
- Grant/correct XP (`+xp/award`, `+xp/award/catchup`, `+xp/scene`, `+xp/correct`)
- Create/manage the B&B catalogue (`+bnb/create`)
- Grant/progress/resolve character B&B entries (`+bnb/grant`, `+bnb/progress`)
- Approve Culminations
- Correct Resonance (with recorded actor + reason)
- Review Character Framework state, permitted Narrative History, and audit
- Force-abort/adjudicate pending rolls
- Reload live configuration

Overrides (e.g. correcting Resonance or reversing an XP award) SHALL record the acting staff member and a reason (REQ-005, CP-07).

### Destructive Actions

Destructive operations — actual deletion of a B&B entry rather than resolution/negation — SHALL require **two-step confirmation** and an **audit snapshot** before proceeding (REQ-005, REQ-021, FINAL Appendix A.10). Staff tools SHALL NOT require direct database manipulation (REQ-036).

## Privacy Model

Privacy-sensitive fields require explicit authorization — no permission SHALL expose broader private data than its documented purpose requires (REQ-005).

**Privacy-sensitive fields include:**
- Character-specific B&B explanations
- GM notes on B&B entries or rolls
- Unrevealed pending-roll candidate details (before GM/player selection)

**Configurable GM reveal categories** (what a scene-GM may see about a character's B&Bs during a GM-assisted roll):
- B&B name
- Public description
- Mechanical effect
- Character explanation
- GM notes

Defaults are conservative (name + public description + mechanical effect only). Enabling a broader reveal (character explanation or GM notes) SHOULD produce an operator-facing warning when configured.

```yaml
privacy:
  gm_reveal_categories:
    - "name"
    - "public_description"
    - "mechanical_effect"
    # - "character_explanation"   # broader reveal; triggers operator warning
    # - "gm_notes"                # broadest reveal; triggers operator warning
  warn_on_broader_reveal: true
```

## Configuration

```yaml
permissions:
  play: "play"                # Baseline player actions
  gm_review: "gm"              # Scene-GM authority for GM-assisted rolls
  manage_soul: "manage_jobs"   # Staff administration
```

### Typical Setups

**Default (most permissive within safe bounds):**
```yaml
permissions:
  play: "play"
  gm_review: "gm"
  manage_soul: "manage_jobs"
```

**Dedicated SOUL admin role** (separate from general wizard permissions):
```yaml
permissions:
  manage_soul: "manage_soul"
```
Then add `manage_soul` to the desired staff role(s) via Ares's own role configuration.

**Hybrid (story-admins handle both GM review and SOUL admin):**
```yaml
permissions:
  gm_review: "story_admin"
  manage_soul: "story_admin"
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
  return { error: "You don't have permission." } unless Permissions.can_manage_soul?(request.enactor)
  # ... proceed with operation
end
```

### In APIs

Per REQ-002, handlers SHALL NOT trust client-supplied permissions — the API layer re-checks:
```ruby
def self.award(character, amount, source:, enactor:)
  return { error: "You don't have permission." } unless Permissions.can_manage_soul?(enactor)
  # ... apply award
end
```

## Admin Help Topic Naming (CI-08)

The staff/admin help topic SHALL be named `manage soul` — not "managing soul" or any other variant.

## Default Ares Roles (Reference)

| Role | Permissions |
|---|---|
| `everyone` | No special permissions |
| `approved` | `play` |
| `wizard` | `manage_jobs`, `manage_ares`, etc. (admin) |
| `admin` | All permissions |

SOUL's defaults assume `play` and `manage_jobs` exist. Configure to match your game's actual role names.

## Related Documents

- `docs/reference/Commands.md` — Full command-to-permission mapping
- `docs/reference/Configuration.md` — Privacy and permission configuration keys
- `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` — REQ-005 (authoritative)

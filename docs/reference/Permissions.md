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
- Browse the active public B&B catalogue
- View own Narrative History

**Override example** — restrict XP spending to staff:
```yaml
play_permission: "manage_jobs"   # Not recommended for normal play
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

Defaults are conservative (name + public description only). Enabling mechanical
effects, character explanations, or GM notes SHOULD produce an operator-facing
warning when configured.

```yaml
privacy:
  gm_reveal_categories:
    - "name"
    - "public_description"
    # - "mechanical_effect"       # broader reveal; triggers operator warning
    # - "character_explanation"   # broader reveal; triggers operator warning
    # - "gm_notes"                # broadest reveal; triggers operator warning
  warn_on_broader_reveal: true
```

## Configuration

Permission names are flat, top-level `soul.yml` keys — not a nested hash. This matches the one real precedent in the AresMUSH ecosystem for a configurable permission name: the Inklings plugin's own `manage_permission` setting (`plugin/inklings.rb`), not an invented `permissions:` block.

```yaml
play_permission: "play"                # Baseline player actions
gm_review_permission: "gm"              # Scene-GM authority for GM-assisted rolls
manage_permission: "manage_jobs"        # Staff administration
```

### Typical Setups

**Default (most permissive within safe bounds):**
```yaml
play_permission: "play"
gm_review_permission: "gm"
manage_permission: "manage_jobs"
```

**Dedicated SOUL admin role** (separate from general wizard permissions):
```yaml
manage_permission: "manage_soul"
```
Then add `manage_soul` to the desired staff role(s) via Ares's own role configuration.

**Hybrid (story-admins handle both GM review and SOUL admin):**
```yaml
gm_review_permission: "story_admin"
manage_permission: "story_admin"
```

## Permission Checks in Code

Permission checks are plain module methods on `Soul` itself (`Soul.can_manage_soul?`, `Soul.can_play?`, `Soul.can_review_rolls?` — see `plugin/soul.rb`), matching the verified convention from Inklings' own `Inklings.can_manage_inklings?` — not a separate `Permissions` class.

### In Commands
```ruby
def check_can_manage
  return nil if Soul.can_manage_soul?(enactor)
  t('soul.permission_denied')
end
```

### In Web Handlers
```ruby
def handle(request)
  return { error: t('soul.permission_denied') } unless Soul.can_manage_soul?(request.enactor)
  # ... proceed with operation
end
```

### In Shared Services

Commands and web handlers both authorize the acting character before calling the
same shared service methods. Services revalidate the target, requested transition,
cost, and state; serializers and privacy-filtered query methods independently
enforce what data a viewer may receive. Callers must not invoke mutation services
directly without first applying the documented permission check.

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

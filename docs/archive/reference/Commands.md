# SOUL Commands Reference

Complete list of MUSH commands for SOUL. Commands are available to players and staff based on permissions.

## Character Commands

| Command | Purpose | Permission | Notes |
|---------|---------|-----------|-------|
| `soul` | Display your character's SOUL sheet | play | Shows Aspects, Skills, XP, Resonance, active B&Bs |
| `soul/skills` | List your skills by aspect | play | Organized by Aspect with ratings |
| `soul/skills <aspect>` | List skills in a specific aspect | play | Shows skill names and descriptions |
| `soul/xp` | Check your current XP | play | Shows earned, spent, and available |
| `soul/xp/history` | View XP transaction history | play | Last 50 transactions with sources |
| `soul/resonance` | Check your current Resonance | play | Shows earned, spent, and available |
| `soul/boons` | List your active Boons and Banes | play | Shows active B&Bs with effects |
| `soul/boons/history` | View resolved Boons and Banes | play | Shows history with resolution reasons |

## Advancement Commands

| Command | Purpose | Permission | Notes |
|---------|---------|-----------|-------|
| `soul/advance <skill>=<amount>` | Spend XP to advance a skill | play | Requires sufficient XP and valid rating range |
| `soul/pending` | Check pending GM-assisted rolls | play | Shows rolls awaiting GM review |

## Admin Commands

| Command | Purpose | Permission | Notes |
|---------|---------|-----------|-------|
| `soul/admin/grant <char>=<amount>` | Grant XP to a character | manage_soul | Specifies source as "admin" |
| `soul/admin/setskill <char>/<skill>=<rating>` | Set a character's skill rating directly | manage_soul | Bypasses XP cost |
| `soul/admin/boon/create <name>=<desc>` | Create a new Boon/Bane template | manage_soul | Interactive creation wizard |
| `soul/admin/boon/grant <char>/<boon>=<reason>` | Grant a B&B to a character | manage_soul | Records source as "admin" |
| `soul/admin/boon/resolve <char>/<boon>=<reason>` | Resolve a B&B on a character | manage_soul | Archives B&B, updates character sheet |
| `soul/admin/reset <char>` | Clear all SOUL data for a character | manage_soul | Use for troubleshooting only |
| `soul/admin/reload` | Reload SOUL configuration | manage_soul | Picks up changes to soul.yml |

## GM Commands

| Command | Purpose | Permission | Notes |
|---------|---------|-----------|-------|
| `soul/gm/pending` | List all pending rolls awaiting review | gm | Shows pending queue with details |
| `soul/gm/approve <roll>` | Approve a pending roll | gm | Roll is marked resolved, player notified |
| `soul/gm/reject <roll>` | Reject a pending roll, player re-rolls | gm | Clears queue, player gets new attempt |
| `soul/gm/modify <roll>=<result>` | Modify a pending roll result | gm | Allows GM to adjust within valid range |
| `soul/gm/note <roll>=<note>` | Add GM notes to a pending roll | gm | Notes visible to player in final result |

## Roll Commands

| Command | Purpose | Permission | Notes |
|---------|---------|-----------|-------|
| `roll <pool>=<difficulty>:<description>` | Make a basic roll with modifiers | play | Auto-applies B&B and other modifiers |
| `roll/pending <pool>=<difficulty>:<description>` | Request GM review for this roll | play | Roll queued for asynchronous GM approval |
| `roll/request <target>=<pool>:<description>` | Request another character make a roll | play | Requires permission; target can accept/decline |

## Configuration Commands

| Command | Purpose | Permission | Notes |
|---------|---------|-----------|-------|
| `soul/config` | View current SOUL configuration | admin | Shows key settings and values |
| `soul/config <key>` | View specific configuration value | admin | Detailed info for single setting |

## Help Files

- `help soul` - Overview of SOUL system
- `help soul_commands` - This reference
- `help soul_advancement` - How to advance skills
- `help soul_rolls` - How to use SOUL rolls
- `help soul_boons` - Boons and Banes system
- `help soul_gm` - GM-assisted rolls workflow
- `help soul_config` - Configuration for admins

## Notes

- All player commands are permission-gated (configurable via `game/config/soul.yml`)
- Staff commands require appropriate permissions (e.g., "manage_soul")
- XP and Resonance are tracked per-character in SOUL-specific data
- Rolls automatically apply Boon/Bane modifiers (no manual +/- needed)
- GM-assisted rolls are asynchronous; GM review happens in their own time

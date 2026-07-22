# Migrating from FS3 to SOUL

Guide for games considering migration from FS3 (AresMUSH's default skill system) to SOUL. This document covers the conceptual differences, mechanical changes, and practical migration steps.

## SOUL vs FS3: Quick Comparison

| Aspect | FS3 | SOUL |
|--------|-----|------|
| **Progression** | Rated skills (1-5) with XP advancement | Aspects organize skills; XP-driven advancement |
| **XP Earning** | Scene-based (fixed per scene) | Configurable, includes catch-up mechanics |
| **XP Spending** | Advance skills; one path | Multiple paths (skills, resonance) |
| **Rolls** | Built-in dice system | Configurable; supports GM-assisted workflow |
| **Boons & Banes** | Static YAML list | Managed instances with lifecycle |
| **Resonance** | N/A | New resource earned via XP spending |
| **GM Control** | Limited | Extensive (config-driven, event hooks) |
| **Customization** | Moderate (YAML-based) | High (config + hooks) |

## Key Mechanical Differences

### Aspect System (New in SOUL)

FS3 has flat skill lists. SOUL organizes skills into Aspects (categories like "Combat", "Social", "Arcane").

**Migration step:** Group existing FS3 skills into Aspects matching your game's narrative.

Example mapping:
```yaml
# FS3 skills
- Melee Weapons
- Ranged Weapons
- Unarmed
- Dodge
- Firearms

# Become (SOUL Aspect: Combat)
combat:
  - Blade
  - Ranged
  - Unarmed
  - Endurance
```

### Catch-Up XP (New in SOUL)

Characters significantly behind their peers earn XP faster. FS3 has no built-in catch-up mechanism.

**Migration step:** Enable catch-up in `soul.yml`:
```yaml
xp:
  catchup_multiplier: 1.5
  catchup_threshold: -5  # Activates when 5+ ratings behind
```

### Resonance (New in SOUL)

SOUL introduces Resonance as a secondary resource earned when spending XP. FS3 has no equivalent.

**Migration step:** Configure resonance earning in `soul.yml`:
```yaml
resonance:
  earn_per_xp: 0.2      # Earn 0.2 resonance per 1 XP spent
  max_pool: 100
  decay_rate: 0
```

Existing characters: Award initial Resonance based on their total XP spent, or start fresh.

### Managed B&B Instances

FS3 treats Boons/Banes as a static list. SOUL manages them as lifecycle-tracked instances.

**Migration step:**
1. Export FS3 B&B list
2. Create equivalent SOUL B&B templates using admin commands
3. Optionally grant characters' existing B&Bs via `soul/admin/boon/grant`

### Roll System

FS3 has its own roll mechanics. SOUL provides configurable rolls with B&B modifiers.

**Migration step:** Configure SOUL rolls to match FS3's difficulty scale:
```yaml
rolls:
  default_difficulty: 7      # Adjust to your scale
  critical_success: 10
  critical_failure: 1
```

## Pre-Migration Checklist

- [ ] Backup entire database
- [ ] Backup FS3 config files
- [ ] Test migration on a copy of the database first
- [ ] Notify players of maintenance window
- [ ] Have rollback plan if issues arise

## Migration Steps

### Step 1: Prepare Character Data Export

```bash
# In your Ares installation, export FS3 character data
rake db:dump  # Creates database snapshot
```

Export character skills (you may need custom script):
```ruby
# Script to export FS3 data
characters = Character.all
output = characters.map { |c|
  {
    name: c.name,
    skills: c.fs3_skills  # Adjust accessor based on FS3 version
  }
}
File.write("fs3_export.json", output.to_json)
```

### Step 2: Install SOUL

Follow the README installation steps:
1. Clone plugin to `plugins/soul/`
2. Copy web portal files (if using web)
3. Add custom-install snippets (if using web)
4. Restart or reload plugins

### Step 3: Configure SOUL

1. Copy default config: `docs/reference/Default_Config.md`
2. Adapt Aspects & Skills to match your FS3 structure
3. Configure XP rates, resonance, permissions
4. Test with a test character before proceeding

```yaml
# Example: Mapping FS3 skills to SOUL Aspects
aspects:
  combat:
    skills:
      blade:
        name: "Blade"
        # Corresponds to FS3 "Melee Weapons"
```

### Step 4: Migrate Skill Data

Create a migration script to transfer FS3 skills to SOUL:

```ruby
# Custom migration script
fs3_data = JSON.parse(File.read("fs3_export.json"))

fs3_data.each do |char_data|
  character = Character.find_one_by_name(char_data[:name])
  next unless character
  
  char_data[:skills].each do |skill_name, rating|
    # Map FS3 skill name to SOUL skill
    soul_skill_name = map_fs3_to_soul(skill_name)
    next unless soul_skill_name
    
    skill = Skill.find_one_by_name(soul_skill_name)
    next unless skill
    
    # Create CharacterSkill
    char_skill = CharacterSkill.create(
      character_id: character.id,
      skill_id: skill.id,
      rating: rating
    )
  end
  
  puts "Migrated #{character.name}"
end

def map_fs3_to_soul(fs3_name)
  mapping = {
    "Melee Weapons" => "Blade",
    "Ranged Weapons" => "Ranged",
    "Unarmed" => "Unarmed",
    "Dodge" => "Endurance",
    "Firearms" => "Ranged",
    # ... add all mappings
  }
  mapping[fs3_name]
end
```

### Step 5: Migrate XP and Resonance

```ruby
# After migrating skills, calculate and award resonance
characters = Character.all

characters.each do |character|
  # Calculate total XP character spent in FS3
  total_xp_spent = character.fs3_skills.sum { |skill| skill.xp_spent }
  
  # Award initial Resonance (optional)
  initial_resonance = (total_xp_spent * 0.2).round  # Match your config
  
  SoulCharacterApi.update_character_data(character, {
    xp_earned: total_xp_spent,
    xp_spent: total_xp_spent,
    resonance: initial_resonance
  })
  
  puts "Migrated #{character.name}: #{total_xp_spent} XP, #{initial_resonance} Resonance"
end
```

### Step 6: Migrate Boons & Banes

Option A: **Manual (Recommended)**
```
@admin
boon/create Lucky=You have uncanny good fortune
boon/create Resilient=You bounce back quickly
bane/create Cursed=Bad luck dogs your heels
```

Then selectively grant characters their prior B&Bs:
```
soul/admin/boon/grant Alice/Lucky=Migration from FS3
```

Option B: **Scripted**
```ruby
# If you stored FS3 B&Bs data
fs3_boons = JSON.parse(File.read("fs3_boons.json"))

fs3_boons.each do |boon_name|
  Boon.create(
    name: boon_name,
    category: "boon",
    active: true
  )
end

# Then grant to characters
Character.all.each do |character|
  character.fs3_boons.each do |boon_name|
    SoulBoonApi.grant_boon(character, boon_name, { source: "migration" })
  end
end
```

### Step 7: Test Migration

- [ ] Create test character in SOUL; verify sheet displays
- [ ] Test skill advancement (XP cost, rating increase)
- [ ] Test rolls with modifiers
- [ ] Test admin commands
- [ ] Test web portal if applicable

```
@admin
soul/admin/grant TestChar=50
soul/admin/setskill TestChar/blade=3
soul
```

### Step 8: Announce to Players

```
GAME ANNOUNCEMENT
=================
The game has migrated from FS3 to SOUL!

Key changes:
- Skills now organized by Aspect (Combat, Social, etc.)
- New Resonance resource (earned as you spend XP)
- XP advancement costs have changed
- Boons & Banes are now managed instances

Your character data has been preserved. Type SOUL to see your sheet.
Questions? Email admin@example.com or see: help soul
```

## Post-Migration Validation

### Check Character Data

```ruby
# Verify all characters migrated correctly
Character.all.each do |character|
  soul_data = SoulCharacterApi.get_character_data(character)
  
  if soul_data.empty?
    puts "WARNING: #{character.name} has no SOUL data!"
  end
end
```

### Verify Skills Accessible

```
@admin

# Check a character can use SOUL commands
soul TestChar

# Verify skills show up
soul/skills TestChar

# Test advancement
soul/advance TestChar/blade=1
```

### Performance Check

- Monitor CPU/memory during and after migration
- Run tests to ensure no regressions
- Monitor game performance for 24-48 hours post-launch

## Rollback Plan

If major issues arise:

1. Restore database backup: `rake db:restore`
2. Remove SOUL plugin: `rm -rf plugins/soul/`
3. Restart server
4. Notify players of rollback
5. Investigate root cause before re-attempting

## Troubleshooting

### "Character has no SOUL data"

**Cause:** Migration script didn't run for that character, or ran but didn't create the SOUL entry.

**Fix:** Manually create SOUL entry:
```ruby
SoulCharacterApi.update_character_data(character, {
  xp_earned: 0,
  xp_spent: 0,
  resonance: 0
})
```

### "Skill not found" during migration

**Cause:** FS3 skill doesn't have a SOUL equivalent, or naming mismatch.

**Fix:** Verify mapping in `map_fs3_to_soul`. Update mapping or create missing SOUL skill.

### "XP advancement cost mismatch"

**Cause:** Migrated characters have XP totals that don't match new advancement costs.

**Fix:** Recalculate XP spent based on ratings + new cost table. Script example:

```ruby
character.character_skills.each do |char_skill|
  # Recalculate XP spent based on new advancement costs
  advancement_cost = Global.read_config("soul", "advancement_cost")
  recalc_xp = (0...char_skill.rating).sum { |i| advancement_cost[i] }
  char_skill.update(xp_spent: recalc_xp)
end
```

## Long-Term Considerations

### FS3 Commands Deprecated

Once migrated, FS3 commands should be disabled or removed:
- Remove or hide `+skills`, `+skill`, `fs3 rating`, etc.
- Redirect players to SOUL help

### Player Training

- Provide help files explaining new system
- Host optional tutorial scene
- Answer questions in-game and via email

### Tuning & Iteration

- Monitor XP earning/spending rates
- Adjust advancement costs if too fast/slow
- Gather player feedback

## References

- `docs/reference/Configuration.md` - SOUL config structure
- `docs/reference/Default_Config.md` - Default configuration to start from
- `docs/development/Testing.md` - Testing the migrated system
- `docs/architecture/Data_Model.md` - SOUL data structures

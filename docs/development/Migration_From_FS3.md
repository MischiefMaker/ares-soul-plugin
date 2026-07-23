# Migrating from FS3 to SOUL

Guide for games moving from FS3 (AresMUSH's default skill system) to SOUL. Per `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") REQ-001, **SOUL SHALL replace FS3 entirely** — it is not designed to run alongside FS3 as a parallel system.

## SOUL vs FS3: Quick Comparison

| Aspect | FS3 | SOUL |
|---|---|---|
| **Skill organization** | Flat skill list | Skills grouped under Aspects (default: Body, Mind, Spirit) |
| **Skill range** | Typically 1-5 | 0-10 (REQ-010) |
| **Progression currency** | XP only | XP, plus optional Resonance-driven chargen scaling, Boons, Banes, Culminations (kept distinct per CP-02) |
| **XP cost** | Static per-rating table | Algebraic model: skill curve × development curve × Resonance modifier (Addendum §3) |
| **Rolls** | Built-in FS3 dice | 2d20 open-ended with explosion/implosion and Boon/Bane die rerolls (Addendum §2) |
| **Boons & Banes** | Static list, no lifecycle | Two-layer catalogue/instance model with numeric IDs, tags, levels, and full history (REQ-016 through REQ-022) |
| **Resonance** | N/A | Chargen-only setting-relative measure, R-3 to R3 (REQ-012) |
| **GM Control** | Limited | Extensive: GM-assisted roll workflow, configurable scene policy, staff correction paths |

## Key Mechanical Differences

### Aspect System (New in SOUL)

FS3 has a flat skill list. SOUL groups skills under Aspects — Body, Mind, Spirit by default (REQ-008).

**Migration step:** Map each FS3 skill to exactly one Aspect.

```yaml
# Example mapping
framework:
  skills:
    melee:
      name: "Melee"
      aspect: "body"     # was a flat FS3 skill; now under Body
    investigation:
      name: "Investigation"
      aspect: "mind"
    ceremonial_magic:
      name: "Ceremonial Magic"
      aspect: "spirit"
```

### Skill Rating Range (0-10, not FS3's typical 1-5)

**Migration step:** Decide a conversion rule and apply it consistently. A common approach is to double the FS3 rating (FS3 3 → SOUL 6), but choose whatever preserves your game's relative skill spread. Document the chosen rule before migrating character data.

### Resonance (New in SOUL)

SOUL introduces Resonance as an optional, chargen-only measure of setting-relative starting position (GL-06). FS3 has no equivalent.

**Migration step:** Either start all migrated characters at R0 (the neutral default), or run a staff review pass to assign initial Resonance based on existing character concept/history. Resonance locks at approval and should not be treated as an ongoing power dial.

```yaml
resonance:
  enabled: true
  min: -3
  max: 3
```

### XP Advancement Cost (Algebraic, not a Flat Table)

FS3 typically uses a static per-rating cost table. SOUL uses the algebraic formula in Addendum §3:
```
final_cost = ceil(ceil(new_rating²/2) × development_modifier × resonance_modifier)
```

**Migration step:** Do not attempt to preserve FS3's exact cost table — recompute each migrated character's `xp_spent` using SOUL's formula, working up from rating 0, so `xp_spent` stays internally consistent with the new advancement costs (see the recalculation script below).

### Managed B&B Instances (Two-Layer Model)

FS3 treats Boons/Banes as a static list with no per-instance lifecycle. SOUL splits this into a site-wide catalogue (numeric ID, tag, category, level definitions) and character-owned instances (level/state, private explanation, source, progression history) — see `docs/architecture/Data_Model.md`.

**Migration step:**
1. Export the FS3 B&B list.
2. Create equivalent SOUL catalogue entries via `+bnb/create` (see `docs/reference/Default_BnBs.md` for the model).
3. Grant each character's existing B&Bs as character-owned entries via `+bnb/grant`, with `source: "migration"`.

### Roll System (2d20 Open-Ended, not FS3's Dice)

FS3 has its own roll mechanics. SOUL uses the 2d20 open-ended model with an 8-level difficulty scale (Trivial 11 through Mythic 40 — Addendum §1-§2).

**Migration step:** There is no direct numeric translation from FS3's difficulty scale to SOUL's. Reacquaint your GMs and players with the new scale rather than trying to force a 1:1 mapping — the six degrees of success (Addendum §8.1) also replace any FS3 success-tier concept.

## Pre-Migration Checklist

- [ ] Backup entire database
- [ ] Backup FS3 config files
- [ ] Decide and document the FS3→SOUL skill rating conversion rule
- [ ] Test migration on a copy of the database first
- [ ] Notify players of the maintenance window
- [ ] Have a rollback plan

## Migration Steps

### Step 1: Export FS3 Character Data

```bash
rake db:dump   # Creates a database snapshot
```

```ruby
# Script to export FS3 data — adjust accessor to your FS3 version
characters = Character.all
output = characters.map { |c| { name: c.name, skills: c.fs3_skills } }
File.write("fs3_export.json", output.to_json)
```

### Step 2: Install SOUL

Follow the README installation steps: clone the plugin, copy web portal files, apply the custom-install snippets (`custom_char_fields.rb`, `chargen-custom.hbs`/`.js` insertions), restart.

### Step 3: Configure SOUL

1. Copy `docs/reference/Default_Config.md` to `game/config/soul.yml`.
2. Map your FS3 skills into SOUL's Aspect/Skill framework.
3. Set your chosen skill-rating conversion rule and Resonance defaults.
4. Test with one character before proceeding to bulk migration.

### Step 4: Migrate Skill Data

```ruby
fs3_data = JSON.parse(File.read("fs3_export.json"))

fs3_data.each do |char_data|
  character = Character.find_one_by_name(char_data["name"])
  next unless character

  char_data["skills"].each do |fs3_name, fs3_rating|
    soul_skill_key = map_fs3_to_soul(fs3_name)
    next unless soul_skill_key

    soul_rating = [fs3_rating * 2, 10].min   # example conversion rule; document yours
    CharacterSkill.create(character_id: character.id, skill_key: soul_skill_key, rating: soul_rating)
  end

  puts "Migrated #{character.name}"
end

def map_fs3_to_soul(fs3_name)
  {
    "Melee Weapons" => "melee",
    "Investigation"  => "investigation",
    "Sorcery"        => "ceremonial_magic",
    # ... complete this mapping for every FS3 skill in use
  }[fs3_name]
end
```

### Step 5: Recalculate XP Spent Under SOUL's Formula

Do not copy FS3's `xp_spent` directly — recompute it bottom-up so future advancement costs stay consistent:

```ruby
Character.all.each do |character|
  total_spent = 0
  character.character_skills.each do |char_skill|
    (1..char_skill.rating).each do |rating|
      total_spent += SoulXpApi.calculate_cost(character_at_spend_time(character, total_spent), char_skill.skill_key, rating)
    end
  end
  SoulCharacterApi.set_lifetime_spent_xp(character, total_spent)
  puts "#{character.name}: recalculated xp_spent = #{total_spent}"
end
```

### Step 6: Migrate Boons & Banes

**Option A — Manual (recommended for small catalogues):**
```
+bnb/create Lucky=You have uncanny good fortune.
+bnb/create Cursed=Bad luck dogs your heels.
```
Then grant existing character B&Bs:
```
+bnb/grant Alice/cursed=Migrated from FS3; originally granted for the Ashford incident.
```

**Option B — Scripted (for large catalogues):**
```ruby
fs3_boons = JSON.parse(File.read("fs3_boons.json"))

fs3_boons.each do |boon_name|
  BnbCatalogueEntry.create(tag: boon_name.downcase.gsub(/\s+/, "_"), name: boon_name, category: "Mundane")
end

Character.all.each do |character|
  character.fs3_boons.each do |boon_name|
    catalogue_entry = BnbCatalogueEntry.find_one_by_name(boon_name)
    SoulBnbApi.apply_transition(character, catalogue_entry.id, "minor", source: "migration")
  end
end
```

### Step 7: Test Migration

- [ ] Create a test character in SOUL; verify the Sheet displays (`+soul`)
- [ ] Test skill advancement (`+xp/spend`) — cost matches the algebraic formula
- [ ] Test a roll with modifiers (`+roll`)
- [ ] Test staff commands (`+xp/award`, `+bnb/grant`)
- [ ] Test web portal parity for each of the above

### Step 8: Announce to Players

```
GAME ANNOUNCEMENT
=================
The game has migrated from FS3 to SOUL!

Key changes:
- Skills are now organized under Body, Mind, and Spirit
- Skill ratings now run 0-10 instead of the old FS3 scale
- New optional Resonance setting, locked at chargen approval
- XP advancement costs now follow a curved formula, not a flat table
- Boons & Banes are now tracked with full history and levels

Type +soul to see your Sheet. Questions? See help soul.
```

## Post-Migration Validation

```ruby
Character.all.each do |character|
  skills = SoulCharacterApi.get_skill_ratings(character)
  puts "WARNING: #{character.name} has no SOUL skill data!" if skills.empty?
end
```

```
+admin
+soul TestChar
+xp TestChar
+bnb/search TestChar
```

## Rollback Plan

1. Restore the database backup.
2. Remove the SOUL plugin.
3. Restart the server (`shutdown` in-game, then `bin/startares` — never `sudo reboot`).
4. Notify players.
5. Investigate the root cause before re-attempting.

## Troubleshooting

### "Character has no SOUL data"

**Fix:**
```ruby
SoulCharacterApi.initialize_character(character)
```

### "Skill not found" during migration

**Fix:** Verify `map_fs3_to_soul` covers every FS3 skill actually in use; add the missing mapping or create the corresponding SOUL Skill first.

### "XP advancement cost mismatch"

**Fix:** Re-run Step 5's recalculation script — `xp_spent` must be derived from SOUL's own formula, not copied from FS3.

## Long-Term Considerations

- Remove or hide FS3 commands (`+skills`, `+skill`, etc.) once migration is validated.
- Provide help files and an optional tutorial scene for the new system.
- Monitor XP pacing and B&B usage; tune `xp.cost.*` and `bnb.*` config as needed (see `docs/reference/Configuration.md`).

## References

- `docs/reference/Configuration.md` — SOUL config structure
- `docs/reference/Default_Config.md` — Starting configuration template
- `docs/development/Testing.md` — Testing the migrated system
- `docs/architecture/Data_Model.md` — SOUL data structures

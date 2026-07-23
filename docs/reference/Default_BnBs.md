# Default Boons & Banes Examples

Example Boon/Bane catalogue entries for new games, matching the two-layer model in `docs/architecture/Data_Model.md` (catalogue entry + character-owned instance), per `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") §6.1 (REQ-016 through REQ-022) and DD-02 (`docs/spec/SOUL_Design_Decisions.md`): B&Bs are created via in-game commands post-install, not pre-seeded into the database. These examples are inspiration for admins to create with `+bnb/create`, not a database migration.

## How to Use This File

1. Read through these examples to understand the catalogue model: numeric ID, stable tag, category, level definitions, and chargen flags.
2. Install SOUL (see README).
3. Create catalogue entries in-game with `+bnb/create` (see `docs/reference/Commands.md`).
4. Adapt the descriptions below, or write your own.

## Catalogue Entry Anatomy

Every entry needs (REQ-017):
- A unique numeric **ID** (assigned automatically on creation)
- A unique short **tag** (chosen by the creator, used in commands like `+bnb/here <tag>`)
- A **name** and **public description**
- A **category** — default choices are **Arcane** and **Mundane** (CI-01)
- **Level definitions** — by default: Minor (+1), Major (+2), Legendary (+3), Negated (no modifier), Epic (explicitly configured per entry, no implied value)
- **Chargen flags**: `chargen.available` (default `true`), `chargen.flag_for_review` (default `false`), `chargen.modifier_eligible` (default `false` — whether this Bane can satisfy the positive-Resonance requirement)

## Example Boons (Mundane)

### Keen Observer

**Tag:** `observer` · **Category:** Mundane

**Public description:** You notice details others miss.

**Levels:** Minor (+1 to Investigation-related rolls), Major (+2), Legendary (+3)

**Character-specific explanation (private, per instance):** e.g. "Morgan studies rooms before speaking and remembers small inconsistencies."

**Associated Skills:** Investigation

### Resilient

**Tag:** `resilient` · **Category:** Mundane

**Public description:** You bounce back from adversity faster than most.

**Levels:** Minor (+1 to Stamina-related recovery rolls), Major (+2), Legendary (+3)

**Associated Skills:** Stamina

### Connected

**Tag:** `connected` · **Category:** Mundane

**Public description:** You have reliable allies, contacts, or resources in useful places.

**Levels:** Minor (+1 to social rolls calling in a favor), Major (+2), Legendary (+3)

**Associated Skills:** Empathy, Presence

## Example Banes (Mundane)

### Cursed

**Tag:** `cursed` · **Category:** Mundane

**Public description:** Your character carries some sort of curse.

**Levels:** Minor (-1), Major (-2), Legendary (-3)

**Chargen flag:** `modifier_eligible: true` — this Bane can satisfy the positive-Resonance requirement (REQ-012)

**Associated Skills:** Configurable per instance — e.g. Strength, Reflexes

**Character-specific explanation example:** "A small curse causes clumsiness and weakness."

### Distracted

**Tag:** `distracted` · **Category:** Mundane

**Public description:** Your focus is shaky — internal doubts or emotional turmoil keep pulling your attention.

**Levels:** Minor (-1), Major (-2), Legendary (-3)

**Associated Skills:** Configurable per instance — often Investigation, Empathy, or Resolve

### Isolated

**Tag:** `isolated` · **Category:** Mundane

**Public description:** You're cut off from your usual support systems.

**Levels:** Minor (-1 to social favors), Major (cannot call in favors this scene), Legendary (cannot call in favors this arc)

**Associated Skills:** Presence, Empathy

## Example Arcane Category Entries

### Ceremonial Attunement

**Tag:** `attuned` · **Category:** Arcane

**Public description:** You have a deep, practiced connection to ceremonial magic.

**Levels:** Minor (+1 to Ceremonial Magic), Major (+2), Legendary (+3)

**Associated Skills:** Ceremonial Magic

**Chargen flag:** `modifier_eligible: false` (Boon, not eligible to satisfy the positive-Resonance Bane requirement)

### Warded

**Tag:** `warded` · **Category:** Arcane

**Public description:** Something binds or limits your arcane potential.

**Levels:** Minor (-1 to Ceremonial Magic), Major (-2), Legendary (-3)

**Associated Skills:** Ceremonial Magic

**Chargen flag:** `modifier_eligible: true`

## Epic-Level Example

### Beyond Reckoning

**Tag:** `beyond` · **Category:** Arcane

**Public description:** Your power has grown past what the ordinary catalogue scale measures.

**Level:** Epic only — chargen unavailable by default (REQ-020). Requires a documented source (staff-approved Culmination or extended narrative arc) and an explicitly configured mechanical effect per instance. The "Epic" label alone never implies an uncapped modifier.

## B&B Creation Guidelines

When creating your own entries, consider:

1. **Is the public description clear without revealing the private explanation?** Public data (name, description, mechanical effect) is visible to everyone; the character-specific explanation and GM notes are owner/staff-only (REQ-018).
2. **Are level effects globally bounded?** Modifier effects SHALL be bounded so Skill investment remains meaningful (REQ-017).
3. **Should this entry be chargen-available?** Most Minor/Major/Legendary entries default to available; Negated and Epic default to unavailable.
4. **Is it `modifier_eligible`?** Only set this `true` on Banes intended to satisfy the positive-Resonance Bane requirement.
5. **What category?** Arcane vs. Mundane by default, or your game's own configured categories.

## Setup Instructions

Once SOUL is installed, create these examples using:

```
+bnb/create Keen Observer=You notice details others miss.
+bnb/create Cursed=Your character carries some sort of curse.
```

Follow-up prompts set category, level definitions, chargen flags, and Skill associations. See `docs/reference/Commands.md` for full command syntax.

## See Also

- `docs/architecture/Data_Model.md` — Full catalogue/instance data structure
- `docs/reference/Commands.md` — `+bnb` command family
- `docs/reference/Configuration.md` — B&B configuration (categories, level definitions, chargen ratio/limits)

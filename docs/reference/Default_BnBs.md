# Default Boons & Banes Examples

Example Boons and Banes for new games. These are provided as inspiration and setup guidance. Admins should create B&Bs in-game using commands once SOUL is installed.

## How to Use This File

1. Read through these examples to understand what B&Bs can look like
2. Install SOUL (see README)
3. Create B&Bs in-game using the `boon/create` admin command (see `help soul_commands`)
4. Copy the descriptions and examples below as needed, or create your own

## Boons (Positive Traits)

### Lucky

**Description:** You have an uncanny knack for good fortune. The odds often seem to break in your favor at crucial moments.

**Mechanical Effect:** +2 to rolls once per scene, or auto-reroll one failed roll per session

**Tags:** `luck`, `general`

### Resilient

**Description:** You bounce back from adversity faster than most. Pain, exhaustion, and emotional turmoil don't keep you down for long.

**Mechanical Effect:** Reduce damage/harm by 1, or gain extra healing/recovery action once per scene

**Tags:** `defensive`, `endurance`, `general`

### Inspired

**Description:** You're riding high on creative or emotional energy. Your actions have momentum behind them.

**Mechanical Effect:** +1 to social or creative rolls for the next 3 scenes, or automatic success on one skill roll

**Tags:** `social`, `creative`, `temporary`

### Sharp-Witted

**Description:** Your mind is sharp and quick. You notice details others miss and think on your feet.

**Mechanical Effect:** +2 to perception/investigation rolls, or ask GM for additional clue in mystery/investigation scenes

**Tags:** `mental`, `perception`, `general`

### Connected

**Description:** You have reliable allies, contacts, or resources in useful places.

**Mechanical Effect:** Once per session, call in a favor to gain information, supplies, or assistance

**Tags:** `social`, `resources`, `general`

## Banes (Negative Traits)

### Cursed

**Description:** Bad luck dogs your heels. Important moments seem to conspire against you.

**Mechanical Effect:** -2 to rolls once per scene, or auto-fail one roll per session

**Tags:** `luck`, `harmful`, `general`

### Fragile

**Description:** You're more vulnerable than most to harm. Whether from weakness, damage, or stress—pain hits harder.

**Mechanical Effect:** Take +1 damage/additional harm per scene, or suffer reduced healing/recovery

**Tags:** `defensive`, `vulnerability`, `general`

### Distracted

**Description:** Your focus is shaky. Internal doubts, personal concerns, or emotional turmoil keep pulling your attention.

**Mechanical Effect:** -1 to all rolls for 2-3 scenes, or automatic failure on one important roll

**Tags:** `mental`, `social`, `temporary`

### Isolated

**Description:** You're cut off from your usual support systems. Allies are unavailable, resources are scarce.

**Mechanical Effect:** Cannot call in favors or use contacts this scene/session. Reduced resources for duration.

**Tags:** `social`, `resources`, `harmful`

### Scarred

**Description:** You carry physical or emotional scars from a past trauma. It affects how you move, interact, and trust.

**Mechanical Effect:** -1 to one specific type of roll (combat, social, mental) for duration, or one automatic failure when triggered

**Tags:** `trauma`, `harmful`, `persistent`

## Narrative Boons

These B&Bs are primarily narrative/roleplay-focused with minimal mechanical impact:

### Renowned

**Description:** You have a positive reputation in certain circles. People know your name and respect your accomplishments.

**Mechanical Effect:** NPCs react more favorably. GM may offer better deals, information, or cooperation from relevant factions.

**Tags:** `social`, `reputation`, `narrative`

### Mysterious

**Description:** There's something unknowable about you. People are intrigued, uncertain, sometimes wary.

**Mechanical Effect:** Narratively useful for intrigue, deception, or avoiding recognition. No direct mechanical bonus.

**Tags:** `social`, `narrative`, `intrigue`

## Mechanical Boons

These B&Bs are purely mechanical with less roleplay component:

### Skilled

**Description:** Represents training or natural talent in a specific area (e.g., "Skilled at Climbing", "Skilled at Deception").

**Mechanical Effect:** +3 to a specific skill, or guaranteed success (at GM discretion) for that skill once per session

**Tags:** `skill`, `mechanical`, `specific`

### Resistance

**Description:** Your body or mind resists a specific type of harm (magical, emotional, physical, etc.).

**Mechanical Effect:** Reduce damage of that type by half, or gain advantage on rolls resisting that harm

**Tags:** `defensive`, `mechanical`, `specific`

## B&B Creation Guidelines

When creating your own, consider:

1. **Is it clear?** Can players understand what it does?
2. **Is it balanced?** Does +2 bonus seem fair? Is -2 penalty too harsh?
3. **Is it interesting?** Does it create roleplay opportunities, or is it purely mechanical?
4. **How long should it last?** Permanent, session-based, or scene-based?
5. **Can it stack?** Can one character have multiple instances? Typically no (prevent overflow).

## Setup Instructions

Once SOUL is installed, create these examples using:

```
boon/create Lucky=You have an uncanny knack for good fortune. +2 to rolls once per scene.
boon/create Resilient=You bounce back quickly. Reduce damage by 1 per scene.
bane/create Cursed=Bad luck dogs your heels. -2 to rolls once per scene.
bane/create Fragile=You're more vulnerable. Take +1 damage per scene.
```

Or use the web admin panel once it's available.

## See Also

- `help soul_boons` - In-game help on Boons & Banes
- `docs/reference/Configuration.md` - B&B configuration options
- `docs/architecture/Data_Model.md` - B&B data structure

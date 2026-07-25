---
toc: true
summary: Choose your SOUL traits during character generation.
aliases:
- chargen soul
---
# SOUL Character Generation

Before approval, choose your Resonance, allocate Skill and Aspect points, and
select your starting Boons and Banes.

`+soul/cg` - Review your current choices and remaining Skill/Aspect points.

`+soul/cg/resonance <value>` - Select your Resonance.

`+soul/cg/skill <key>=<rating>` - Set a Skill to an absolute rating.

`+soul/cg/aspect <key>=<rating>` - Set an Aspect (Body/Mind/Spirit) to an
absolute rating.

`+soul/cg/catalogue` - List every active Boon and Bane available during
character generation, including the ID and tag used by `+soul/cg/bnb`.

`+soul/cg/bnb <id or tag>[/<level>]=<explanation>` - Select a starting
Boon or Bane. The level defaults to `minor`.

`+soul/cg/drop <entry id or tag>` - Remove one of your chargen selections.
The entry ID is shown in `+soul/cg`'s own status listing, or use the
catalogue tag directly (same as `+soul/cg/bnb`'s "id or tag" convention).

These commands stop working after approval. Skill ratings cost one point per
rating level and cannot exceed the starting cap shown by `+soul/cg`. Aspect
ratings cost one point per rating level and cannot exceed the configured
Aspect max rating shown by `+soul/cg`. After approval, both Skills and
Aspects can be advanced by spending XP (see `help soul_xp`). Resonance is
the only choice that locks permanently at approval and cannot be changed
afterward except by staff correction.

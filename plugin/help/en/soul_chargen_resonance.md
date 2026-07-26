---
toc: true
summary: Choose your Resonance and allocate Skill/Aspect points during character generation.
aliases:
- chargen soul resonance
---
# SOUL Character Generation: Resonance & Skills

Resonance is a measure of your character's connection to this world.
Characters with higher Resonance start with more Skill points and a higher
starting cap in chargen, but advancing further later costs more XP.
Characters with negative Resonance start with fewer Skill points and a lower
starting cap, but advancing later costs less XP. Especially high or low
Resonance may require staff approval. (Staff: this wording is the default -
see `soul.resonance.description` in the game's SOUL configuration if it's
been customized.)

`+soul/cg` - Review your current choices and remaining Skill/Aspect points.

`+soul/cg/resonance <value>` - Select your Resonance.

`+soul/cg/skill <key>=<rating>` - Set a Skill to an absolute rating.

`+soul/cg/aspect <key>=<rating>` - Set an Aspect (Body/Mind/Spirit) to an
absolute rating.

Skill ratings cost one point per rating level and cannot exceed the starting
cap shown by `+soul/cg`. Aspect ratings cost one point per rating level and
cannot exceed the configured Aspect max rating shown by `+soul/cg`. After
approval, both Skills and Aspects can be advanced by spending XP (see
`help soul_xp`). Resonance is the only choice that locks permanently at
approval and cannot be changed afterward except by staff correction.

Once Resonance is chosen and your Skill/Aspect points are spent, move on to
`help soul_chargen_bnb` to select your starting Boons and Banes.

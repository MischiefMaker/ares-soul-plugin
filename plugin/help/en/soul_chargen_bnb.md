---
toc: true
summary: Select your starting Boons and Banes during character generation.
aliases:
- chargen soul bnb
- chargen soul boons
- chargen soul banes
---
# SOUL Character Generation: Boons & Banes

Boons and Banes are special qualities, circumstances, possessions, or
connections that help define your character. They may affect SOUL rolls,
attract GM attention, provide plot hooks, or simply add depth to your
character. (Staff: this wording is the default - see `soul.bnb.description`
in the game's SOUL configuration if it's been customized.)

`+soul/cg/catalogue` - List every active Boon and Bane available during
character generation, including the ID and tag used by `+soul/cg/bnb`.

`+soul/cg/bnb <id or tag>[/<level>[/<skill1,skill2,...>]]=<explanation>` -
Select a starting Boon or Bane. The level defaults to `minor`. Skills only
need to be specified if the entry has no fixed default.

`+soul/cg/drop <entry id or tag>` - Remove one of your chargen selections.
The entry ID is shown in `+soul/cg`'s own status listing, or use the
catalogue tag directly (same as `+soul/cg/bnb`'s "id or tag" convention).

`+soul/cg` - Review your current choices, including your selected Boons and
Banes and whether your Boon-to-Bane ratio is satisfied.

These commands stop working after approval. If you haven't set your
Resonance or spent your Skill/Aspect points yet, see `help soul_chargen_resonance`.

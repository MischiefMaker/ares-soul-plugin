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

`+soul/cg/bnb <id or tag>[/<level>]=<explanation>` - Select a starting
Boon or Bane. The level defaults to `minor`.

`+soul/cg/drop <entry id>` - Remove one of your chargen selections.

These commands stop working after approval. Skill ratings cost one point per
rating level and cannot exceed the starting cap shown by `+soul/cg`. Aspect
ratings cost one point per rating level and cannot exceed the configured
Aspect max rating (default 5) shown by `+soul/cg`. Unlike Skills, Aspects
have no post-chargen advancement path, so choose carefully.

A bare `+chargen` won't reach these commands — core AresMUSH's own chargen
system claims that word (it's shorthand for the `+cg` review command). SOUL's
chargen commands live under `+soul/cg` specifically to avoid that collision.

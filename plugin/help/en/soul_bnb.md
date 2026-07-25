---
title: SOUL Boons and Banes
aliases:
  - soul_bnb
---

# Boons and Banes

`+bnb` — List all of your own Boons and Banes: ID, name, tag, level, and
your private explanation for each.

`+bnb <id or tag>` — View a catalogue entry and your private explanation.

`+bnb/here <tag>` — Show public-safe matches among participants in your scene.

`+bnb/catalogue` — Browse the public catalogue.

`+bnb/search <query>` — Staff catalogue search.

`+bnb/create <kind>/<tag>/<name>[/<skill1,skill2,...>]=<description>` — Create
a catalogue entry. The Skill segment is optional and only for entries that
always affect the same fixed Skill(s); most B&Bs pick their Skill(s) at
grant time instead.

`+bnb/skills <id or tag>=<skill1,skill2,...>` — Set an existing entry's fixed
default Skill(s). The only field editable after creation.

`+bnb/grant <character>/<id or tag>/<level>[/<skill1,skill2,...>]=<explanation>`
— Grant an entry. The level defaults to `minor`; Skills default to the
entry's own fixed default if it has one, otherwise specify them here.

`+bnb/progress <character>/<entry id>=<new level>` — Progress an entry.

`+bnb/resolve <character>/<entry id>=<reason>` — Resolve/negate an entry,
preserving its level for later restoration. Preferred over deletion.

`+bnb/restore <character>/<entry id>` — Restore a resolved/negated entry.

`+bnb/delete <entry id>/<reason>/confirm/confirm` — Permanently delete an
entry. Both explicit confirmations and a reason are required.

`+bnb/detail <character>[=<id or tag>]` — Staff: view a character's own
entries, or one entry in full, including their private explanation.

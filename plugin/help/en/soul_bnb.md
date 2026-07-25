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

`+bnb/create <kind>/<tag>/<name>/<skill1,skill2,...>=<description>` — Create a
catalogue entry. At least one associated Skill key is required.

`+bnb/skills <id or tag>=<skill1,skill2,...>` — Set an existing entry's
associated Skills. The only field editable after creation; use it to fix an
entry made before Skills were required.

`+bnb/grant <character>/<id or tag>/<level>=<explanation>` — Grant an entry.
The level defaults to `minor` when omitted.

`+bnb/progress <character>/<entry id>=<new level>` — Progress an entry.

`+bnb/resolve <character>/<entry id>=<reason>` — Resolve/negate an entry,
preserving its level for later restoration. Preferred over deletion.

`+bnb/restore <character>/<entry id>` — Restore a resolved/negated entry.

`+bnb/delete <entry id>/<reason>/confirm/confirm` — Permanently delete an
entry. Both explicit confirmations and a reason are required.

`+bnb/detail <character>[=<id or tag>]` — Staff: view a character's own
entries, or one entry in full, including their private explanation.

---
title: Manage SOUL
---

> Permission Required: These commands require the permission configured as
> `manage_permission` in `game/config/soul.yml` (defaults to `manage_jobs`).

# Manage SOUL

Staff administration for the SOUL system: awarding and correcting XP,
managing the Boon & Bane catalogue and Culminations, correcting Resonance,
and reviewing Character Framework state and the audit log.

See `docs/reference/Commands.md` in the plugin repository for the full
command surface, including player-facing commands.

## Configuration

SOUL's settings live in `game/config/soul.yml`. Changes take effect after
reloading game config - no plugin restart needed. See
`docs/reference/Configuration.md` for the full reference.

## Framework and Resonance

`+soul/framework` — Review configured Aspects and Skills.

`+soul/framework/skill <character>=<key>/<rating>/<reason>` — Correct a
character's Skill rating.

`+soul/framework/aspect <character>=<key>/<rating>/<reason>` — Correct a
character's Aspect rating.

`+soul/resonance <character>=<value>/<reason>` — Correct locked Resonance.

`+soul/reload` — Validate the live SOUL configuration and report errors.

`+soul/audit <character>` — View the staff-only technical audit log for a
character (distinct from their player-facing Narrative History).

## Boons and Banes

`+bnb/create <kind>/<tag>/<name>=<description>` — Create a catalogue entry.

`+bnb/grant <character>/<id or tag>[/<level>]=<explanation>` — Grant an
entry. `level` defaults to `minor`.

`+bnb/progress <character>/<entry id>=<new level>` — Progress or retreat an
entry's level.

`+bnb/resolve <character>/<entry id>=<reason>` — Resolve/negate an entry,
preserving its level for later restoration. Preferred over deletion for
ordinary play.

`+bnb/restore <character>/<entry id>` — Restore a resolved/negated entry.

`+bnb/delete <entry id>/<reason>/confirm/confirm` — Permanently delete an
entry. Both explicit confirmations and a reason are required.

`+bnb/search <tag>` — Staff catalogue search.

## XP

`+xp/award <character>=<amount>/<reason>` — Award XP without catch-up.

`+xp/award/catchup <character>=<amount>/<reason>` — Award with catch-up.

`+xp/correct <character>=<amount>/<reason>` — Add XP through a linked
correction ledger entry.

`+xp/reverse <character>=<amount>/<reason>` — Subtract available XP through
a linked reversal ledger entry. This does not undo a Skill advance.

`+xp/scene [scene id=]<amount>/<reason>` — Preview a scene award. Repeat with
`/confirm` to commit. Use `+xp/scene/catchup` to apply catch-up.

## Culminations

`+culmination/propose <character>=<title>/<description>` — Propose a milestone.

`+culmination/approve <id>` — Approve a proposed milestone.

`+culmination/deny <id>=<reason>` — Deny a proposed milestone.

`+culmination/revoke <id>=<reason>` — Revoke an already-approved milestone,
preserving the original record.

`+culmination/correct <id>=<title>/<description>/<reason>` — Correct a
milestone's title and/or description. Leave `title` or `description` blank
to keep its current value; `reason` is always required.

## Rolls

`+roll/review`, `+roll/mark`, `+roll/forceabort` — Scene-GM and staff roll
review tools. See `help soul_rolls` for the full Rolls command family.

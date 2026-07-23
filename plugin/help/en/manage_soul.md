---
title: Manage SOUL
---

> Permission Required: These commands require the permission configured as
> `manage_permission` in `game/config/soul.yml` (defaults to `manage_jobs`).

# Manage SOUL

Staff administration for the SOUL system: awarding and correcting XP,
managing the Boon & Bane catalogue, correcting Resonance, and reviewing
Character Framework state.

SOUL is under active development - staff commands will be documented here as
each subsystem is implemented. See `docs/reference/Commands.md` in the
plugin repository for the full planned command surface.

## Configuration

SOUL's settings live in `game/config/soul.yml`. Changes take effect after
reloading game config - no plugin restart needed. See
`docs/reference/Configuration.md` for the full reference.

## Commands

`+soul/framework` — Review configured Aspects and Skills. Rating correction
syntax is not yet specified.

`+soul/resonance <character>=<value>/<reason>` — Correct locked Resonance.

`+soul/reload` — Confirm that SOUL configuration is read live.

`+xp/award <character>=<amount>/<reason>` — Award XP without catch-up.

`+xp/award/catchup <character>=<amount>/<reason>` — Award with catch-up.

`+xp/correct <character>=<amount>/<reason>` — Add a correction ledger entry.

`+xp/scene [scene id=]<amount>/<reason>` — Preview a scene award. Repeat with
`/confirm` to commit. Use `+xp/scene/catchup` to apply catch-up.

`+culmination/propose <character>=<title>/<description>` — Propose a milestone.

`+culmination/approve <id>` — Approve a proposed milestone.

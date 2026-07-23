# SOUL for AresMUSH

SOUL is a story-first character system for AresMUSH games. It provides a configurable
character sheet, experience and advancement, Boons and Banes, open-ended 2d20 rolls,
GM-assisted roll conversations, character milestones, and a readable history of how
each character has changed.

The system is designed for games that want character abilities to matter without
turning every scene into a tactical exercise. Most of the rules can be described in
setting language, while the plugin handles the records, permissions, rolls, and staff
oversight behind them.

SOUL is intended to replace FS3 as a game's primary skill, advancement, and roll
system. It is not designed to run beside FS3 as a second active rules system.

## Status

SOUL is under active development and should currently be treated as a pre-release
plugin.

The core framework, character records, XP, Boons and Banes, rolls, GM-assisted rolls,
staff audit tools, and optional integration points are implemented. Final migration
testing, installation polish, documentation review, and release validation are still
in progress.

Game-runners interested in trying SOUL should install it on a development or staging
game first, keep a current backup, and test their chosen configuration before opening
it to players.

## Overview

SOUL brings the following parts of character play together:

- A configurable set of Aspects and Skills.
- Optional Resonance, representing how naturally a character fits the game's central
  supernatural or thematic framework.
- A complete XP ledger with spending previews, confirmations, corrections, and
  catch-up awards.
- Boons and Banes that record meaningful advantages, complications, relationships,
  conditions, obligations, and other story-facing traits.
- Open-ended 2d20 rolls with clearly named difficulty levels and degrees of success.
- GM-assisted rolls that let players and GMs agree on relevant Boons and Banes before
  dice are rolled.
- Culminations for proposing and approving important character milestones.
- Narrative history for players and staff, plus a separate staff-only audit trail.
- Optional connections to the Inklings and Grimoire plugins.

### Aspects and Skills

Aspects are the broad foundations of a character. A game might use Body, Mind, and
Spirit, but those names are only defaults. Game-runners can rename them or define a
different set that suits their setting.

Skills describe what characters can actually do. Every Skill belongs to an Aspect and
is rated from 0 to 10. The game-runner controls the Skill list, display names,
descriptions, categories, and associated Aspects.

This makes SOUL suitable for more than one genre. A modern supernatural game, a
political fantasy game, and a science-fiction game can all use the same plugin while
presenting very different character sheets.

### Resonance

Resonance is optional. When enabled, it records a character's starting relationship to
the game's central spiritual, magical, or thematic force.

It ranges from R-3 to R3. A character chooses Resonance during character creation, and
that choice affects starting Skill points and the character's starting limits.
Resonance is locked when the character is approved.

Resonance is not intended to become a constantly increasing power score. It describes
where the character began within the setting's framework. Staff can correct it when
necessary, but ordinary advancement happens through Skills, Boons and Banes, and
story milestones.

Games that do not need Resonance can turn it off.

### Experience and Advancement

SOUL maintains a complete record of earned and spent XP. Players can:

- See their current XP balance.
- Review where XP came from and how it was spent.
- Preview a Skill increase before committing to it.
- Confirm the purchase only after seeing the cost and result.

Staff can award XP, issue catch-up XP, correct mistakes, and review the ledger. The
configuration controls weekly awards, spending costs, catch-up limits, and related
advancement policies.

Corrections are recorded rather than silently erasing history. This leaves both the
player and staff with a clear explanation of what changed.

### Boons and Banes

Boons and Banes are named story traits attached to a character.

A Boon may describe an ally, trusted position, rare resource, supernatural gift, or
other advantage. A Bane may describe a rival, debt, injury, obligation, curse, or
other complication. The game-runner defines a shared catalogue so that commonly used
traits have consistent names and descriptions.

Each character-owned entry can have:

- A level, such as Minor, Major, Legendary, or Epic.
- A character-specific explanation.
- A history of grants, progress, resolution, restoration, or staff correction.
- Privacy controls for information that should not be shown broadly.

SOUL preserves resolved and negated entries instead of deleting their history. This
allows a character's sheet to reflect the story as it changes over time.

The default framework also supports a two-to-one Boon-to-Bane balance rule. A
game-runner can adjust the available levels and related policies in configuration.

### Rolls

SOUL uses two twenty-sided dice. The character's Skill, applicable Boons and Banes,
and the chosen difficulty all contribute to the result.

The dice are open-ended:

- Two natural 20s can produce an exceptional upward result.
- Two natural 1s can produce an exceptional downward result.
- Relevant Boons and Banes can affect the roll through rerolls.

Difficulties use readable names:

| Difficulty | Target |
| --- | ---: |
| Trivial | 11 |
| Easy | 12 |
| Standard | 13 |
| Difficult | 17 |
| Hard | 21 |
| Extreme | 25 |
| Legendary | 34 |
| Mythic | 40 |

Results are described in degrees rather than only as pass or fail. The outcome tells
players how strongly the action succeeded or failed, making it easier to carry the
result into the scene.

Game-runners may customize difficulty settings, limits, privacy, and GM review policy.

### GM-Assisted Rolls

A player can ask for a GM-assisted roll instead of rolling immediately. This starts a
short conversation around the pending roll.

The GM can review the proposed action and identify which Boons or Banes are:

- Mandatory for the roll.
- Optional for the player to accept.
- Not relevant to the action.

The player can accept suggestions, decline optional ones, or decide to roll without
them. The completed roll keeps a record of what was considered and what was actually
used.

This workflow is particularly useful when a character trait has private context or
when the stakes of a roll deserve a shared ruling before the dice land.

### Culminations and History

Culminations record important character milestones. A player and staff member can use
them to describe a major turning point, completed arc, lasting transformation, or
other significant development.

SOUL also maintains two kinds of history:

- Narrative history presents character-facing changes in a readable form.
- The staff audit trail records administrative actions and corrections for oversight.

This separation lets the character's history remain useful to players without
exposing staff-only details.

## Web Portal

SOUL includes web portal components for:

- The SOUL character sheet.
- Boons and Banes.
- XP and advancement history.
- Culminations.
- Narrative history.

These components give players a readable overview of their character and give
authorized staff the additional information needed for review.

Web portal layouts vary significantly between Ares games, so the supplied components
must be placed into your game's profile pages or a SOUL-specific route. SOUL does not
currently provide a universal drop-in placement that will suit every portal theme.

A ready-made web roll page is not included at this stage. Rolls and GM-assisted roll
conversations are fully available through in-game commands.

## Requirements

Before installing SOUL, you should have:

- A working AresMUSH game and access to its server files.
- Staff access sufficient to install plugins and reload or restart the game.
- Access to the separate `ares-webportal` checkout if you want to use the optional
  web portal components.
- A backup of your game and database.
- A clear plan for your Aspects, Skills, advancement pace, and Boon/Bane catalogue.

SOUL is a replacement rules framework. If your game currently uses FS3, read
[Migration from FS3](docs/development/Migration_From_FS3.md) and test the transition
on a copy of your game. The migration process is still awaiting final release
validation.

Inklings and Grimoire are optional integrations, not required dependencies.

## Installation

An Ares game usually has two separate checkouts:

- `aresmush` runs the game server and contains the plugins and game configuration.
- `ares-webportal` runs the website and contains the portal pages and components.

The server plugin is required. The web portal additions are optional.

### 1. Install the Server Plugin

From the game, run:

```text
plugin/install https://github.com/MischiefMaker/ares-soul-plugin
```

After installation, confirm that the SOUL plugin is present in `plugins/soul` and
that `game/config/soul.yml` exists.

If you prefer a manual installation:

1. Copy the repository's `plugin` folder into your game as `plugins/soul`.
2. Copy `game/config/soul.yml` into your game's `game/config` folder.
3. Restart the game.

Do not open SOUL to players immediately. Configure and test the framework first.

### 2. Configure Your Framework

Open `game/config/soul.yml` and review every section. At minimum, decide:

- Whether SOUL is enabled.
- The names and descriptions of your Aspects.
- The complete Skill list and the Aspect associated with each Skill.
- Whether Resonance is used.
- Starting Skill points and advancement costs.
- Weekly and catch-up XP policies.
- The available Boon and Bane levels and categories.
- Roll difficulties and GM-assisted roll policy.
- Privacy defaults.
- Staff permissions.
- Whether either optional integration is enabled.

Skill and Aspect keys are permanent identifiers. Choose clear keys and avoid changing
them casually after characters begin using the system.

Reload your game configuration using your game's normal config reload procedure, or
restart the game. SOUL checks the framework configuration and reports invalid
references, such as a Skill assigned to an Aspect that does not exist.

See [Configuration](docs/reference/Configuration.md) for a complete setting-by-setting
reference.

### 3. Add the Approval Hook

This step is required if your game uses Resonance. It ensures that a character's
Resonance is locked when the character is approved.

Open:

```text
aresmush/plugins/chargen/custom_approval.rb
```

Inside the `custom_approval` method, add:

```ruby
AresMUSH::Soul::SoulResonanceApi.lock_at_approval(char)
```

Then reload Chargen:

```text
load chargen
```

The approval call is safe if a character is approved again. It does nothing when
Resonance is disabled or already locked.

An example is provided in
[`custom-install/custom_approval.snippet.rb`](custom-install/custom_approval.snippet.rb).

### 4. Install the Optional Web Portal Components

If the plugin installer did not copy the web files automatically, copy the contents
of:

```text
web-portal/app
```

into the corresponding `app` folder in your `ares-webportal` checkout. Keep the
component and template folders together.

Next, add the desired SOUL components to your character profile or to a dedicated
SOUL route. The supplied component names are:

- `soul/sheet`
- `soul/bnb`
- `soul/xp`
- `soul/culmination`
- `soul/history`

The exact placement depends on your portal theme and the way your game organizes
character pages. If you are not comfortable editing the portal layout, the plugin can
still be used entirely through in-game commands.

After adding the components, rebuild and deploy the portal:

```text
website/deploy
```

### 5. Perform Initial Staff Setup

Before inviting players to use SOUL:

1. Test the character sheet with a staff or test character.
2. Confirm that every configured Skill appears under the expected Aspect.
3. If using Resonance, approve a test character and confirm that Resonance locks.
4. Create several common Boons and Banes in the catalogue.
5. Award and spend test XP.
6. Make a normal roll and a GM-assisted roll.
7. Review player-visible history and the staff audit view.
8. Check privacy using both a player account and a staff account.
9. If using the web portal, verify every mounted component at desktop and mobile
   sizes.

Only enable the system for general play after these checks match your game's policy.

## Upgrading

Back up your game and save a copy of your current `game/config/soul.yml` before
upgrading.

Re-run the installer:

```text
plugin/install https://github.com/MischiefMaker/ares-soul-plugin
```

Then:

1. Compare the newly supplied configuration with your saved configuration.
2. Add any new settings without replacing your game's framework choices.
3. Confirm that the Chargen approval hook is still present.
4. Copy any updated portal components and run `website/deploy`.
5. Reload or restart the game.
6. Repeat the initial staff checks on a test character.

Upgrade notes will be added as SOUL approaches its first release.

## Configuration Guide

The main configuration file is `game/config/soul.yml`.

### Permissions

SOUL separates ordinary use, GM roll review, and full system management. The default
permission mapping is:

| Purpose | Default permission |
| --- | --- |
| Use ordinary SOUL features | `play` |
| Review GM-assisted rolls | `gm` |
| Manage framework and staff actions | `manage_jobs` |

Change these to match your game's permission structure. Staff should test commands
with an account that has only the intended permission, not only with a fully
privileged admin account.

### Privacy

SOUL can restrict sensitive information in Boons, Banes, rolls, histories, and staff
audit records.

Before launch, decide:

- What a character may see about themselves.
- What other players may see.
- What a scene participant may see.
- What GMs may see while reviewing a roll.
- What remains staff-only.

Private explanations should be written with the expectation that authorized GMs may
need enough context to make a fair ruling.

### Boon and Bane Catalogue

The catalogue is maintained in-game by staff. Create entries with stable, memorable
tags because players and staff use those tags when viewing traits and making rolls.

A good catalogue entry explains:

- What the trait represents in the setting.
- Whether it is a Boon or a Bane.
- When it is normally relevant.
- Any limits staff should apply consistently.

Character-specific information belongs on the character's granted entry, not in the
shared catalogue description.

### Optional Inklings Integration

SOUL includes an integration point for turning an approved Inkling outcome into a
SOUL Boon or Bane grant or progression.

Enable it under the `integrations.inklings` section of `soul.yml`. The operation
rechecks the character's current SOUL state before applying an outcome and safely
recognizes an outcome that has already been applied.

The Inklings plugin must also be updated to call this integration point when staff
approve the appropriate outcome. Until that companion update is present, enabling
the SOUL setting alone will not connect the two workflows.

### Optional Grimoire Integration

SOUL can map Grimoire branches to existing Spirit Skills. This avoids creating a
separate Arcana Skill when the game's magical branches already belong within the SOUL
framework.

Enable the Grimoire integration and configure each branch-to-Skill mapping in
`soul.yml`. Every mapped Skill must already exist in the SOUL Skill list.

Grimoire reads this mapping from SOUL; it does not change a character's SOUL records.

## Commands

The tables below are a practical overview. See
[SOUL Commands](docs/reference/Commands.md) and the in-game help files for the full
syntax and permission rules.

### Character Sheet and History

| Command | Purpose |
| --- | --- |
| `+soul` | View your SOUL sheet. |
| `+soul <character>` | View a character's sheet when permitted. |
| `+soul/history` | View your narrative SOUL history. |
| `+soul/history <character>` | View another character's history when permitted. |
| `+culmination` | View your culmination information. |

### Boons and Banes

| Command | Purpose |
| --- | --- |
| `+bnb/catalogue` | Browse the shared Boon and Bane catalogue. |
| `+bnb <id or tag>` | View one of your entries. |
| `+bnb/here <tag>` | View a relevant entry in the current scene context. |
| `+bnb/search <text>` | Search entries when permitted. |
| `+bnb/create <kind>/<tag>/<name>=<description>` | Create a catalogue entry as staff. |
| `+bnb/grant <character>/<id or tag>/<level>=<explanation>` | Grant a character entry. |
| `+bnb/progress <character>/<entry id>=<level>` | Change an entry's level. |

Additional staff commands resolve, negate, restore, and—when absolutely necessary—
delete entries. Destructive actions require explicit confirmation and leave an audit
record.

### XP

| Command | Purpose |
| --- | --- |
| `+xp` | View your balance and advancement summary. |
| `+xp/history` | Review earned and spent XP. |
| `+xp/spend <skill>=<amount>` | Preview an XP purchase. |
| `+xp/spend <skill>=<amount>/confirm` | Confirm the previewed purchase. |

Staff commands are also available for awards, catch-up grants, corrections, and
scene-related XP.

### Rolls

| Command | Purpose |
| --- | --- |
| `+roll <skill>` | Make a standard roll. |
| `+roll <skill>=<difficulty>` | Roll against a named or numeric difficulty. |
| `+roll/gm <skill>=<difficulty>` | Request a GM-assisted roll. |
| `+roll suggested` | Review GM suggestions for your pending roll. |
| `+roll <tag> [<tag>...]` | Accept optional suggested traits. |
| `+roll none` | Roll without optional suggestions. |
| `+roll/abort <id>=<reason>` | Cancel your pending roll. |
| `+roll/pending` | View pending GM-assisted rolls. |
| `+roll/history` | Review roll history. |

Authorized GMs have commands to review, mark, resolve, or force-abort pending rolls.

### Staff Administration

| Command | Purpose |
| --- | --- |
| `+soul/framework` | Review the active framework. |
| `+soul/reload` | Confirm the currently loaded SOUL configuration. |
| `+soul/audit <character>` | Review staff audit records for a character. |

Staff can also correct Resonance, manage Culminations, administer XP, and manage
character Boons and Banes. These actions are permission-controlled and audited.

## Suggested Player Workflow

A typical character's SOUL journey looks like this:

1. During character creation, the player chooses or receives starting Skills and, if
   enabled, Resonance.
2. Approval locks the starting Resonance choice.
3. The character earns XP through the game's configured award policy.
4. The player previews and confirms Skill advancement.
5. Story developments grant, progress, resolve, or transform Boons and Banes.
6. The player makes ordinary rolls directly and asks for GM assistance when a ruling
   is needed.
7. Important turning points are recorded as Culminations.
8. The character sheet and narrative history preserve the result of that journey.

## Known Limitations

- SOUL is pre-release and has not completed final production migration validation.
- There is not yet a complete SOUL character-generation interface. Games must decide
  how starting choices are entered and reviewed during their onboarding process.
- Web portal components require manual placement in the host game's layout.
- A ready-made web portal roll interface is not yet included.
- The Inklings integration requires a companion change in Inklings before approved
  outcomes flow automatically into SOUL.
- The migration guidance from FS3 should be tested on a staging copy before use on a
  live game.

See the [Roadmap](docs/spec/ROADMAP.md) for current development phases.

## Further Reading

- [Configuration Reference](docs/reference/Configuration.md)
- [Command Reference](docs/reference/Commands.md)
- [Integration Guide](docs/architecture/Integration_Guide.md)
- [Migration from FS3](docs/development/Migration_From_FS3.md)
- [Roadmap](docs/spec/ROADMAP.md)

## Support and Feedback

SOUL is being developed in the open. Please report defects, unclear documentation,
and game-runner feedback through the repository's GitHub issue tracker. When
reporting a problem, include the command or workflow involved, what you expected,
what happened instead, and whether the issue occurred in-game or on the web portal.

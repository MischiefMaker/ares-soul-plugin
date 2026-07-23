# SOUL for AresMUSH

SOUL is a character system for AresMUSH games: a configurable character sheet, XP and
advancement, Boons and Banes, open-ended 2d20 rolls (including GM-assisted rolls),
character milestones, and a player-facing history of how each character has changed.

SOUL is intended to replace FS3 as a game's primary skill, advancement, and roll
system, not run alongside it.

## Status

SOUL is under active development and should currently be treated as a pre-release
plugin. Install it on a development or staging game first, keep a current backup, and
test your configuration before opening it to players.

## Overview

### For Players

- View your character sheet: Aspects, Skills, Resonance, XP, and Boons/Banes
- Spend XP on Skill advancement, with a cost preview before you confirm
- Track Boons and Banes — advantages, complications, relationships, and conditions
  attached to your character
- Make standard rolls, or ask for a GM-assisted roll when a scene calls for it
- Propose Culminations for major character milestones
- Read your own Narrative History — a plain-language record of how your character
  has changed

### For Staff

- Manage the shared Boon and Bane catalogue and grant/progress/resolve entries
- Award, correct, and audit XP, including catch-up awards
- Review and approve Culminations
- Review and mark GM-assisted rolls in scenes you're running
- A staff-only audit trail, separate from player-facing history
- Configure Aspects, Skills, Resonance, difficulty levels, and permissions entirely
  through `game/config/soul.yml` — no code changes needed

### Key Features

- Fully configurable Aspects and Skills — no fixed genre or setting assumptions
- Optional Resonance, locked at character approval
- A full XP ledger with previews, confirmations, corrections, and catch-up awards
- Boons and Banes with levels, history, and non-destructive resolution
- Open-ended 2d20 rolls with named difficulty levels and degrees of success
- GM-assisted rolls for scenes that need a shared ruling before dice are rolled
- Optional integrations with the Inklings and Grimoire plugins

## Web Portal

SOUL includes web portal components for the character sheet, Boons and Banes, XP,
Culminations, and Narrative History. These install automatically with the plugin.

Mounting them onto your game's character profile page still requires manual setup
(see Installation below) — SOUL doesn't yet ship a ready-made snippet for this the
way some other plugins do. Until that's done, everything in SOUL is fully usable
through in-game commands.

## Installation

An Ares game usually has two separate checkouts: **`aresmush`** (the game server —
plugins and `game/config/`) and **`ares-webportal`** (the website). Each step below
says which one to open.

### Step 1: Install the Plugin

From the MUSH, run:

```
plugin/install https://github.com/MischiefMaker/ares-soul-plugin
```

This installs the plugin to `plugins/soul/`, adds `game/config/soul.yml`, and copies
the web portal components into your `ares-webportal` checkout.

**If `plugin/install` is unavailable:** copy this repository's `plugin/` folder to
`plugins/soul/`, copy `game/config/soul.yml` into your game's `game/config/` folder,
then restart the MUSH server.

Don't open SOUL to players yet — configure and test it first.

### Step 2: Configure Your Framework

Open `game/config/soul.yml` and set up your Aspects, Skills, Resonance (if used), XP
and catch-up policy, Boon/Bane levels, roll difficulties, and staff permissions. See
[Configuration](docs/reference/Configuration.md) for the full reference.

Reload your game's configuration (or restart) once you're done. SOUL will report any
invalid references, such as a Skill assigned to an Aspect that doesn't exist.

### Step 3: Add the Approval Hook (Required if you use Resonance)

This locks a character's Resonance when they're approved.

1. Open `plugins/chargen/custom_approval.rb` in your **aresmush** folder
2. Inside the `custom_approval` method, add:
   ```ruby
   AresMUSH::Soul::SoulResonanceApi.lock_at_approval(char)
   ```
3. From the MUSH, run: `load chargen`

An example is provided in
[`custom-install/custom_approval.snippet.rb`](custom-install/custom_approval.snippet.rb).
This step does nothing if Resonance is disabled, and is safe to run on every approval.

### Step 4: Mount the Web Portal Components (Optional)

The components (`soul/sheet`, `soul/bnb`, `soul/xp`, `soul/culmination`,
`soul/history`) are copied into your `ares-webportal` checkout by Step 1. Install
the three merge-safe profile snippets to make them reachable:

1. Add `custom-install/profile-custom-tabs.snippet.hbs` to the matching
   `profile-custom-tabs.hbs` file in your web portal.
2. Add `custom-install/profile-custom.snippet.hbs` to the matching
   `profile-custom.hbs` file in your web portal.
3. Merge `custom-install/custom_char_fields.snippet.rb` into
   `aresmush/plugins/profile/custom_char_fields.rb`, then restart the game.
4. Add `custom-install/live-scene-custom-play.snippet.hbs` to the matching
   web portal file to put SOUL rolls in a live scene's **Play** menu.
5. Merge `custom-install/custom_scene_data.snippet.rb` into
   `aresmush/plugins/scenes/custom_scene_data.rb`, then restart the game.

Read the comments at the top of each snippet before copying it. They explain how to
coexist with other profile plugins, including Inklings, without duplicating the
shared approval-status and viewer-ID fields.

The scene widget opens rolls in a private modal. Players select suggested
Boons and Banes with checkboxes, and authorized scene GMs use a similar modal
to mark entries mandatory or optional. Results are not automatically posted
to the scene transcript.

If your game uses different profile property names or shared custom-field keys,
adjust the snippets as their comments describe. If you skip this optional step,
SOUL remains usable through in-game commands.

After adding the components, rebuild and deploy the portal:

```
website/deploy
```

### Step 5: Try It Before Opening to Players

With a staff or test character: view the sheet, confirm Skills appear under the
right Aspects, approve a test character and confirm Resonance locks, create a few
Boons and Banes, award and spend some XP, and make both a standard and a
GM-assisted roll.

## Upgrading

Back up your game and your current `game/config/soul.yml` first. Then:

```
plugin/install https://github.com/MischiefMaker/ares-soul-plugin
```

Compare the newly supplied config against your saved copy and merge in anything new,
confirm the approval hook (Step 3) is still in place, redeploy the web portal if you
use it, and reload or restart the game.

## Further Reading

- [Command Reference](docs/reference/Commands.md)
- [Configuration Reference](docs/reference/Configuration.md)
- [Migration from FS3](docs/development/Migration_From_FS3.md)
- [Roadmap](docs/spec/ROADMAP.md)

## Known Limitations

- Pre-release: migration from FS3 hasn't completed final production validation
- No dedicated character-generation UI yet for Resonance/Skill/Boon selection during
  chargen — games must decide how starting choices are entered for now
- The web portal profile tab requires manual placement (see Step 4 above)
- The Inklings integration needs a companion update in Inklings before approved
  outcomes flow automatically into SOUL

See the [Roadmap](docs/spec/ROADMAP.md) for current development status.

## Support and Feedback

SOUL is being developed in the open. Please report issues or feedback through the
repository's GitHub issue tracker, including what you expected, what happened
instead, and whether it was in-game or on the web portal.

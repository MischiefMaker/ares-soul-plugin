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

- Choose your Resonance, allocate starting Skills, and select starting Boons and
  Banes during character generation
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
- A dedicated character generation stage for Resonance, Skills, and starting B&Bs
- Optional Resonance, locked at character approval
- A full XP ledger with previews, confirmations, corrections, and catch-up awards
- Boons and Banes with levels, history, and non-destructive resolution
- Open-ended 2d20 rolls with named difficulty levels and degrees of success
- GM-assisted rolls for scenes that need a shared ruling before dice are rolled
- Optional integrations with the Inklings and Grimoire plugins

## Web Portal

SOUL includes web portal components for the character sheet, Boons and Banes, XP,
Culminations, and Narrative History. These install automatically with the plugin.

Mounting them onto your game's profile, chargen, and live-scene pages requires the
supplied merge-safe snippets described below. Everything is also usable through
in-game commands.

## Installation

An Ares game usually has two separate checkouts: **`aresmush`** (the game server —
plugins and `game/config/`) and **`ares-webportal`** (the website). Each step below
says which checkout and file to use.

Install on a development or staging game first. Back up your game configuration and
any existing custom extension files before merging the snippets. The snippets are
examples to merge into game-owned files; do not replace other plugins' custom code.

### Step 1: Install the Plugin

From the MUSH, run:

```
plugin/install https://github.com/MischiefMaker/ares-soul-plugin
```

This installs the plugin to `plugins/soul/`, adds `game/config/soul.yml`, and copies
the web portal components into your `ares-webportal` checkout.

**If `plugin/install` is unavailable:** copy this repository's `plugin/` folder to
`plugins/soul/`, copy `game/config/soul.yml` into your game's `game/config/` folder,
and copy `web-portal/app/` into the matching `ares-webportal/app/` directories. Then
restart the MUSH server.

The files under `custom-install/` are not automatic replacements for your game's
custom files. Merge them manually in the steps below.

### Step 2: Configure Your Framework

Open `game/config/soul.yml` and set up your Aspects, Skills, Resonance (if used), XP
and catch-up policy, Boon/Bane levels, roll difficulties, and staff permissions. See
[Configuration](docs/reference/Configuration.md) for the full reference.

Reload the game configuration, then run:

```
+soul/reload
```

This validates the live SOUL configuration and reports invalid references, such as
a Skill assigned to an Aspect that does not exist. Correct all reported errors
before continuing.

### Step 3: Install the Required Approval Hook

This server-side hook locks Resonance and creates Narrative History for the starting
Boons and Banes that survive chargen. Install it even if Resonance is disabled.

1. In **aresmush**, open `plugins/chargen/custom_approval.rb`.
2. Find `custom_approval(char)` and add these lines inside the method:

   ```ruby
   AresMUSH::Soul::SoulResonanceApi.lock_at_approval(char)
   AresMUSH::Soul::SoulBnbApi.finalize_chargen_grants(char)
   ```
3. Preserve any approval hooks already present for other plugins.
4. From the MUSH, run:

   ```
   load chargen
   ```

The complete annotated example is
[`custom-install/custom_approval.snippet.rb`](custom-install/custom_approval.snippet.rb).
Both calls are idempotent and safe on re-approval.

### Step 4: Add the MUSH Chargen Stage

The `+chargen` command family works once the plugin is installed, but adding a stage
introduces it at the correct point in the normal character-generation flow.

1. In **aresmush**, open `game/config/chargen.yml`.
2. Under the existing `stages:` section, add the entry from
   [`custom-install/chargen_stage.snippet.yml`](custom-install/chargen_stage.snippet.yml)
   at the desired point in the stage order.
3. Keep the indentation consistent with the surrounding stages.
4. Run `load chargen`.

The stage points players to `help soul_chargen`, which documents Resonance, Skill,
and starting Boon/Bane selection.

### Step 5: Add Profile Data for the Web Portal

The profile tab and staff administration panel need viewer-specific fields from the
game server.

1. In **aresmush**, open `plugins/profile/custom_char_fields.rb`.
2. Merge
   [`custom-install/custom_char_fields.snippet.rb`](custom-install/custom_char_fields.snippet.rb)
   into `get_fields_for_viewing(char, viewer)`.
3. If Inklings or another plugin already supplies `is_approved` or `viewer_id`,
   reuse those fields instead of defining duplicates.
4. Restart the game server.

These fields only control what the portal displays. Every web operation still
performs its own server-side permission check.

### Step 6: Mount the Profile and Staff Interface

In **ares-webportal**:

1. Merge
   [`custom-install/profile-custom-tabs.snippet.hbs`](custom-install/profile-custom-tabs.snippet.hbs)
   into `app/components/profile-custom-tabs.hbs`.
2. Merge
   [`custom-install/profile-custom.snippet.hbs`](custom-install/profile-custom.snippet.hbs)
   into `app/components/profile-custom.hbs`.
3. Keep `href="#soul-tab-pane"` and `id="soul-tab-pane"` unchanged so the tab and
   pane remain connected.

This mounts the character Sheet, XP spending, B&B catalogue and staff search,
Culminations, Narrative History, and the staff administration panel.

### Step 7: Mount the Web Chargen Interface

In **ares-webportal**:

1. Merge
   [`custom-install/chargen-custom-tabs.snippet.hbs`](custom-install/chargen-custom-tabs.snippet.hbs)
   into `app/components/chargen-custom-tabs.hbs`.
2. Merge
   [`custom-install/chargen-custom.snippet.hbs`](custom-install/chargen-custom.snippet.hbs)
   into `app/components/chargen-custom.hbs`.
3. Keep `href="#soul-chargen-tab"` and `id="soul-chargen-tab"` unchanged.

The new tab lets unapproved players select Resonance, allocate starting Skill
ratings, and add or remove chargen-available Boons and Banes. Each choice is
validated and saved immediately.

### Step 8: Add Scene Permission Data

GM-assisted roll review and scene-GM sheet viewing need two viewer permission flags.

1. In **aresmush**, open `plugins/scenes/custom_scene_data.rb`.
2. Merge
   [`custom-install/custom_scene_data.snippet.rb`](custom-install/custom_scene_data.snippet.rb)
   into `custom_scene_data(viewer)`.
3. If the method already returns a hash for another plugin, add the two SOUL fields
   to that hash rather than replacing it.
4. Restart the game server.

These flags are for interface visibility only. Roll and Sheet handlers independently
verify staff/GM authority and scene participation.

### Step 9: Mount the Live-Scene Tools

In **ares-webportal**, merge
[`custom-install/live-scene-custom-play.snippet.hbs`](custom-install/live-scene-custom-play.snippet.hbs)
into `app/components/live-scene-custom-play.hbs`.

This adds the following to a live scene's **Play** menu:

- Standard and GM-assisted SOUL rolls.
- Pending-roll management, roll history, abort, and authorized force-abort.
- GM candidate review and mandatory/optional B&B selection.
- Scene-scoped B&B lookup.
- Authorized participant Sheet viewing.

Roll results remain private to the roller and are never automatically posted to the
scene transcript.

### Step 10: Build and Deploy the Portal

After merging all web snippets, rebuild and deploy from the game:

```
website/deploy
```

If your installation uses a separate web deployment process, run its normal build
and deployment commands instead. A server restart alone does not publish Ember
template changes.

### Step 11: Verify the Installation

Use an unapproved test character, an approved player, and a staff/GM character:

- Confirm the SOUL chargen stage and web tab appear before approval.
- Select Resonance, allocate Skills, add and remove a starting B&B, then approve the
  test character.
- Confirm Resonance locks and each surviving starting B&B receives exactly one
  Narrative History entry.
- Open an approved character profile and verify Sheet, XP, B&B, Culmination, and
  History sections.
- Spend XP through both `+xp/spend` and the web form.
- As staff, validate configuration, search and manage B&Bs, award/correct/reverse
  XP, correct Skill and Aspect ratings, manage Culminations, correct Resonance,
  and view the audit log. Test each staff workflow in-game and on the web.
- In a live scene, complete a standard roll and a GM-assisted roll; verify pending,
  history, abort, force-abort, scene lookup, and participant Sheet controls.
- Confirm an ordinary player cannot see staff-only controls or inactive B&B search
  results.

Do not open SOUL to players until these checks pass.

## Upgrading

Back up your game and your current `game/config/soul.yml` first. Then:

```
plugin/install https://github.com/MischiefMaker/ares-soul-plugin
```

Compare the newly supplied config against your saved copy and merge in anything new,
then compare every file under `custom-install/` with the version you previously
merged. In particular:

- Keep both approval-hook calls from Step 3.
- Keep the SOUL entry in `game/config/chargen.yml`.
- Merge any new profile or scene custom-data fields.
- Re-merge changed profile, chargen, and live-scene templates.

Reload or restart the affected server plugins and redeploy the web portal after every
upgrade that changes Ember components or snippets.

## Further Reading

- [Command Reference](docs/reference/Commands.md)
- [Configuration Reference](docs/reference/Configuration.md)
- [Migration from FS3](docs/development/Migration_From_FS3.md)
- [Roadmap](docs/spec/ROADMAP.md)

## Known Limitations

- Pre-release: migration from FS3 hasn't completed final production validation
- The web portal's profile, chargen, and live-scene interfaces all require manual
  snippet placement (see Steps 5-9 above) — none of them mount automatically
- The Inklings integration needs a companion update in Inklings before approved
  outcomes flow automatically into SOUL; SOUL's own side of that contract
  (`SoulInklingsHook`) is complete and ready for Inklings to call into

See the [Roadmap](docs/spec/ROADMAP.md) for current development status.

## Support and Feedback

SOUL is being developed in the open. Please report issues or feedback through the
repository's GitHub issue tracker, including what you expected, what happened
instead, and whether it was in-game or on the web portal.

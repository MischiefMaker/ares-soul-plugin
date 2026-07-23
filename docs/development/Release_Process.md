# SOUL Release Process

Steps for releasing a new version of SOUL. Grounded in `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") REQ-049 (Compatibility Contract): public APIs, hooks, event payloads, configuration keys, and stored stable identifiers are documented, and breaking changes require migration guidance and an explicit version change.

## Pre-Release Checklist

### Code Quality

- [ ] All tests passing (`rspec spec/`)
- [ ] No outstanding linting warnings (`rubocop plugin/`)
- [ ] Coverage at or above 80% (`COVERAGE=true rspec spec/`)
- [ ] No security vulnerabilities (`brakeman` if running with web)
- [ ] Code review completed

### Documentation

- [ ] README updated with new features/changes
- [ ] `docs/spec/CLAUDE_ADR.md` updated with session notes
- [ ] `docs/spec/IMPLEMENTATION_CHECKLIST.md` updated (completed items checked)
- [ ] `docs/reference/Commands.md` updated if commands changed
- [ ] `docs/reference/Configuration.md` updated if config changed
- [ ] `docs/architecture/*.md` updated if architecture changed
- [ ] Help files updated (`plugin/help/`), including `manage soul` (CI-08)
- [ ] Locale strings added/updated (`plugin/locales/locale_en.yml`)
- [ ] Any change to FINAL.md or `SOUL_Design_Decisions.md` was explicitly approved by the project owner — these files are creator-built and protected (see the banner in each file)

### Changelog

- [ ] CHANGELOG.md entry created for this version
- [ ] Format: `## [X.Y.Z] - YYYY-MM-DD`
- [ ] Include: features, bug fixes, breaking changes, deprecations
- [ ] Link to the implementation PR if available

### Migration & Compatibility (FINAL REQ-049)

- [ ] Backward compatibility verified, or breaking changes documented
- [ ] New configuration keys have safe defaults (REQ-042); deprecated keys remain temporarily recognized where safe and warn
- [ ] Database migration scripts created if schema changed
- [ ] Upgrade path tested (old version → new version)
- [ ] `docs/development/Migration_From_FS3.md` updated if the migration path changed

### Integration Testing

- [ ] Tested with Inklings, if integrated (validation/application hook contract per REQ-039)
- [ ] Tested with Grimoire, if integrated (read-only capability exchange per REQ-040)
- [ ] Tested permission system changes
- [ ] Tested all new command/handler paths (MUSH and web, per CP-05)
- [ ] Tested error paths (invalid input, missing data)

## Release Steps

### 1. Update Version Number

```ruby
# plugin/soul.rb
module AresMUSH::Soul
  VERSION = "1.2.0"
end
```

### 2. Commit Pre-Release Work

```bash
git add CHANGELOG.md plugin/ docs/
git commit -m "Release SOUL v1.2.0

- Add skill advancement feature
- Fix B&B transition bug
- Improve GM-assisted roll workflow

See CHANGELOG.md for full details."
```

### 3. Create Release Tag

```bash
git tag -a v1.2.0 -m "Release SOUL v1.2.0

Breaking changes:
- XP advancement cost formula constants changed

New features:
- Skill advancement now includes catch-up mechanics
- GM-assisted rolls support mandatory selections

Bug fixes:
- Fixed pending roll timeout handling
- Fixed B&B duplicate tag checking

See CHANGELOG.md for details."

git push origin v1.2.0
```

### 4. Build Release Artifacts

```bash
git clone --depth 1 https://github.com/MischiefMaker/ares-soul-plugin.git soul-v1.2.0
cd soul-v1.2.0
rm -rf .git
tar czf soul-v1.2.0.tar.gz .
```

### 5. Create Release on GitHub

Via GitHub web UI: Releases → New Release → tag `v1.2.0` → paste RELEASE_NOTES.md → attach the tarball → Publish.

## Release Notes Template

```markdown
# SOUL v1.2.0

**Release Date:** YYYY-MM-DD

## New Features
- **Skill Advancement:** Spend XP to improve Skills, with the algebraic cost formula
- **Catch-Up XP:** Characters behind the group median automatically earn XP faster
- **GM-Assisted Rolls:** Optional per-scene GM workflow for reviewing rolls

## Bug Fixes
- Fixed pending roll timeout calculation
- Fixed B&B catalogue tag collisions
- Fixed Resonance-based XP cost not applying correctly at negative Resonance

## Breaking Changes
- XP advancement cost constants have changed (see Migration_From_FS3.md if relevant)
- Removed `+soul/set-skill` (use `+xp/spend` or staff `+xp/award` + rating correction instead)

## Deprecations
- `resonance.decay_rate` is deprecated (Resonance does not decay by design); remove it from your `soul.yml`

## Configuration Changes
See `docs/reference/Configuration.md` for the current schema.

## Known Issues
- Web portal GM-assisted roll queue not yet implemented (MUSH commands only)

## Installation & Upgrade
See README.md. To upgrade: back up your database, replace plugin files, run any new migrations, review `docs/development/Migration_From_FS3.md` for config changes, update `game/config/soul.yml`.
```

## Post-Release

- Announce in your game's usual channels; link release notes and docs.
- Watch for bug reports in the first 24-48 hours; be ready to patch.
- Update `docs/spec/CLAUDE_ADR.md` with release notes and `docs/spec/ROADMAP.md` if priorities shifted.

## Patch Releases (v1.2.1, etc.)

1. `git checkout -b hotfix/1.2.1 v1.2.0`
2. Apply fix commits, test thoroughly
3. Tag `v1.2.1`, push, announce
4. Merge back to main for the next release

## Major Version Bumps (v2.0.0)

- [ ] Extensive testing across all workflows
- [ ] Beta period if possible
- [ ] Long changelog with a migration path
- [ ] Migration guide updated prominently
- [ ] Clear communication about compatibility breaks

## Versioning Scheme

Semantic Versioning: `MAJOR.MINOR.PATCH`. **MAJOR** — breaking changes; **MINOR** — new features, backward compatible; **PATCH** — bug fixes only.

## Related Documents

- README.md — Installation and usage
- CHANGELOG.md — Release history
- `docs/development/Migration_From_FS3.md` — Upgrade/migration guide
- `docs/spec/CLAUDE_ADR.md` — Development notes
- `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` — REQ-049 Compatibility Contract (authoritative)

# SOUL Release Process

Steps for releasing a new version of SOUL. This process ensures quality, consistency, and smooth deployments.

## Pre-Release Checklist

### Code Quality

- [ ] All tests passing (`rspec spec/`)
- [ ] No outstanding linting warnings (`rubocop plugin/`)
- [ ] Coverage at or above 80% (`COVERAGE=true rspec spec/`)
- [ ] No security vulnerabilities (`brakeman` if running with web)
- [ ] Code review completed (peer review preferred)

### Documentation

- [ ] README updated with new features/changes
- [ ] `docs/spec/CLAUDE_ADR.md` updated with session notes
- [ ] `docs/spec/IMPLEMENTATION_CHECKLIST.md` updated (completed items checked)
- [ ] `docs/reference/Commands.md` updated if commands changed
- [ ] `docs/reference/Configuration.md` updated if config changed
- [ ] `docs/architecture/*.md` updated if architecture changed
- [ ] Help files updated (`plugin/help/`)
- [ ] Locale strings added/updated (`plugin/locales/locale_en.yml`)

### Changelog

- [ ] CHANGELOG.md entry created for this version (or committed during development)
- [ ] Format: `## [X.Y.Z] - YYYY-MM-DD`
- [ ] Include: features, bug fixes, breaking changes, deprecations
- [ ] Link to implementation PR if available

### Migration & Compatibility

- [ ] Backward compatibility verified (or breaking changes documented)
- [ ] Database migration scripts created if schema changed
- [ ] Migration documented in `docs/development/Migration_From_FS3.md` if applicable
- [ ] Upgrade path tested (old version → new version)

### Integration Testing

- [ ] Tested with Grimoire (if integrated)
- [ ] Tested with Inklings (if integrated)
- [ ] Tested permission system changes
- [ ] Tested all new command/handler paths
- [ ] Tested error paths (invalid input, missing data, etc.)

## Release Steps

### 1. Update Version Number

```ruby
# plugin/soul.rb (or wherever version is defined)
module AresMUSH::Soul
  VERSION = "1.2.0"
end
```

Or update in `VERSION` file if using one.

### 2. Commit Pre-Release Work

```bash
git add CHANGELOG.md plugin/ docs/
git commit -m "Release SOUL v1.2.0

- Add skill advancement feature
- Fix B&B granting bug
- Improve GM-assisted roll workflow

See CHANGELOG.md for full details."
```

### 3. Create Release Tag

```bash
git tag -a v1.2.0 -m "Release SOUL v1.2.0

Breaking changes:
- XP advancement costs have been rebalanced

New features:
- Skill advancement now includes catch-up mechanics
- GM-assisted rolls support modification

Bug fixes:
- Fixed pending roll timeout handling
- Fixed B&B duplicate checking

See docs/spec/CHANGELOG.md for details."

git push origin v1.2.0
```

### 4. Build Release Artifacts

```bash
# Create a clean export (no .git folder)
git clone --depth 1 https://github.com/MischiefMaker/ares-soul-plugin.git soul-v1.2.0
cd soul-v1.2.0
rm -rf .git
tar czf soul-v1.2.0.tar.gz .
```

### 5. Create Release on GitHub

```bash
gh release create v1.2.0 \
  --title "SOUL v1.2.0" \
  --notes-file RELEASE_NOTES.md \
  soul-v1.2.0.tar.gz
```

Or via GitHub web UI:
1. Go to Releases → New Release
2. Tag: `v1.2.0`
3. Title: "SOUL v1.2.0"
4. Description: Paste RELEASE_NOTES.md content
5. Attach `soul-v1.2.0.tar.gz`
6. Publish Release

## Release Notes Template

```markdown
# SOUL v1.2.0

**Release Date:** 2026-07-22

## New Features

- **Skill Advancement:** Characters can now spend XP to improve skills, with configurable costs
- **Catch-Up XP:** Characters behind the average automatically earn XP at an accelerated rate
- **GM-Assisted Rolls:** Optional GM workflow for reviewing rolls asynchronously

## Bug Fixes

- Fixed pending roll timeout calculation
- Fixed B&B instances not respecting the "no duplicates" setting
- Fixed Resonance earning not triggering on all XP spends

## Breaking Changes

- XP advancement costs have been restructured (see Migration_From_FS3.md)
- Removed `soul/set-skill` command (use `soul/advance` instead)

## Deprecations

- The `base_xp_per_scene` config key is now just `base_per_scene` under `xp:`
- Updated your `soul.yml` when you upgrade

## Configuration Changes

The `soul.yml` structure has been simplified. See `docs/reference/Configuration.md` for the new schema.

## Known Issues

- Web portal roll interface not yet implemented (MUSH commands only)
- GM-assisted roll history is not visible in web UI

## Installation & Upgrade

See README.md for installation instructions.

To upgrade from v1.1.0:
1. Back up your database
2. Replace plugin files
3. Run any new database migrations (if applicable)
4. Review `docs/development/Migration_From_FS3.md` for config changes
5. Update `game/config/soul.yml` with new structure

## Contributors

Thank you to all who contributed to this release!
```

## Post-Release

### Announce Release

- Post in game Discord/Slack if applicable
- Update community forums if applicable
- Link to release notes and documentation

### Monitor for Issues

- Watch for bug reports in first 24-48 hours
- Be ready to release a patch if critical issues emerge
- Collect feedback for next version

### Update Development Docs

- Update `docs/spec/CLAUDE_ADR.md` with release notes
- Update `docs/spec/ROADMAP.md` if priorities have shifted
- Archive session notes for this release cycle

## Patch Releases (v1.2.1, etc.)

For urgent bug fixes:

1. Create a branch from the release tag: `git checkout -b hotfix/1.2.1 v1.2.0`
2. Apply fix commits
3. Test thoroughly
4. Create new tag `v1.2.1`
5. Push tag and announce patch
6. Merge back to main for next release

## Major Version Bumps (v2.0.0)

For major rewrites or breaking changes:

- [ ] Extensive testing (all workflows)
- [ ] Beta period (if possible)
- [ ] Long changelog documenting migration path
- [ ] Migration guide updated prominently
- [ ] Clear communication about compatibility breaks

## Versioning Scheme

SOUL uses Semantic Versioning: `MAJOR.MINOR.PATCH`

- **MAJOR** - Breaking changes (incompatible API changes)
- **MINOR** - New features (backward compatible)
- **PATCH** - Bug fixes (no new features)

Example progression:
- v1.0.0 - Initial release
- v1.1.0 - Add catch-up XP system
- v1.1.1 - Fix timeout bug
- v1.2.0 - Add GM-assisted rolls
- v2.0.0 - Complete rewrite, breaking API changes

## Related Documents

- README.md - Installation and usage
- CHANGELOG.md - Release history
- docs/development/Migration_From_FS3.md - Upgrade guide
- docs/spec/CLAUDE_ADR.md - Development notes

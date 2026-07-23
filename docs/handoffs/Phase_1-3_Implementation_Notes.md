# Phase 1–3 Adapter Implementation Notes

Implemented on `feature/phase-1-3-command-web-handlers`.

## Assumptions required to complete the handoff

1. `+xp/spend <skill>=<amount>` previews the calculated cost. The identical
   command with `/confirm` commits the spend.
2. Scene XP awards preview approved recipients. Appending `/confirm` commits.
3. `+bnb/create` uses
   `+bnb/create <kind>/<tag>/<name>=<description>` because the existing API
   requires `kind` and `tag`.
4. `+bnb/delete` uses
   `+bnb/delete <entry id>/<reason>/confirm/confirm` because the API requires
   a reason and two explicit confirmations.
5. `+bnb/grant` optionally accepts a level between the character and
   explanation; it defaults to `minor`.
6. `+soul/framework` is read-only. The handoff describes correction, but
   supplies no command syntax identifying character, Aspect/Skill, or rating.

## Incorrect or missing upstream material

- The handoff's XP API section still labels `SoulXpApi.correct` as a blocking
  gap even though its “Known Gaps” section and implementation say it is
  resolved.
- `SoulXpApi.get_scene_participants` documents a `.characters`/`.people`
  assumption. Current AresMUSH uses `Scene#participants`; the helper therefore
  returns an empty list against current core and must be corrected in the API
  layer (outside this adapter handoff).
- `SoulXpApi.correct` accepts positive amounts only and always adds to
  available XP. It therefore does not implement the handoff's stated
  “reverse a prior award or spend” behavior.
- The required staff Framework correction workflow is not expressible by the
  specified `+soul/framework` syntax.
- `+bnb/progress` is described as also resolving/negating entries, but its
  syntax provides no required reason for `SoulBnbApi.resolve`. The adapter
  implements level progression only rather than silently bypassing the audit
  requirements of the dedicated resolve API.
- The repository's specs require `plugin/spec/spec_helper.rb`, but that file is
  not present. This is also true of the referenced Inklings repository and
  implies an external test-harness setup that is not documented here.
- Existing API specs refer to constants such as `Soul::SoulXpApi`, while the
  implementation defines `AresMUSH::SoulXpApi`. This namespace mismatch
  predates this handoff.
- No web route/profile-tab integration point is listed. Components and
  templates are provided, but the host game must mount them in its profile or
  SOUL route.
- The scope mentions Audit viewing and requires an Audit privacy test, but no
  Audit command, web-handler file, or command syntax appears in the command
  surface or expected-file list.

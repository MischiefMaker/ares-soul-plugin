# SOUL Configuration Reference

Configuration structure for SOUL in `game/config/soul.yml`. All values are read fresh via `Global.read_config` on every use (never cached in a plugin-level constant or variable), per CP-06 — this is what lets a staff config reload (not a plugin restart) pick up changes immediately. `Global.read_config` itself reads from an in-memory hash parsed once at boot or reload, not the YAML file on disk on every call.

Sources: `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") §9 (REQ-042 through REQ-045) for configurable areas and canonical defaults, and `docs/spec/Implementation_Specification_Addendum.md` ("Addendum") for the mechanics FINAL's REQ-045 left open (dice model, XP cost formula, chargen B&B ratio, degrees of success, extraordinary luck, pending roll expiry, aspect rounding).

## Precedence and Validation (FINAL REQ-042)

Precedence order:
1. Valid game configuration in `soul.yml`.
2. Canonical defaults documented here.
3. Safe implementation fallback matching those defaults.

At startup, SOUL validates YAML structure, required keys, supported values, references, duplicate keys/tags/IDs, Aspect–Skill mappings, ranges, dependency consistency, and unsafe combinations.

- Invalid but recoverable values warn and fall back to the documented safe default, only when interpretation is unambiguous.
- Unsafe, destructive, or ambiguous configuration fails the affected feature safely rather than guessing.
- Fatal plugin load failure is reserved for conditions that would prevent safe core operation.

## Terminology / Framework

| Key | Type | Default | Description |
|---|---|---|---|
| `enabled` | bool | `true` | Plugin-wide switch; when false, SOUL command and web routes are not registered |
| `framework.aspects` | map | Body, Mind, Spirit | Stable Aspect keys mapped to names, descriptions, and ordering |
| `framework.skills` | map | starter set in `soul.yml` | Stable Skill keys mapped to names, ordering, and exactly one Aspect |
| `framework.skill_min_rating` | int | `0` | Minimum Skill rating |
| `framework.skill_max_rating` | int | `10` | Ultimate Skill cap, all Resonance tiers (REQ-010) |

## Aspect Roll Contribution

| Key | Type | Default | Description |
|---|---|---|---|
| `aspect.weight` | decimal | `0.20` | Multiplier applied to Aspect rating when contributing to a roll's effective base (DD-06, REQ-009) |
| `aspect.contribution_rounding` | enum | `"nearest"` | Rounding rule for fractional Aspect contribution (Addendum §7 — standard rounding, 0.5 rounds up) |

```
Aspect Contribution = round_nearest(Aspect Rating × aspect.weight)
```
CP-03 invariant: equivalent Skill investment SHALL matter substantially more than Aspect investment regardless of how `aspect.weight` is tuned.

## Resonance

| Key | Type | Default | Description |
|---|---|---|---|
| `resonance.enabled` | bool | `true` | Whether Resonance is used (optional per GL-06) |
| `resonance.min` | int | `-3` | Lower bound of Resonance range |
| `resonance.max` | int | `3` | Upper bound of Resonance range |
| `resonance.r0_skill_points` | int | `15` | Chargen Skill allowance at R0 |
| `resonance.r0_starting_cap` | int | `7` | Starting Skill cap at R0 |
| `resonance.positive_skill_points_per_level` | int | `2` | Additional chargen points per positive Resonance level |
| `resonance.negative_skill_points_per_level` | int | `2` | Reduced chargen points per negative Resonance level |
| `resonance.positive_starting_cap_per_level` | int | `1` | Additional starting cap per positive Resonance level |
| `resonance.negative_starting_cap_per_level` | int | `1` | Reduced starting cap per negative Resonance level |
| `resonance.review_flag_at_extremes` | bool | `true` | R3/R-3 require strong justification and heightened review |

Canonical symmetric table (REQ-012):

| Resonance | Skill points | Chargen cap |
|---:|---:|---:|
| R-3 | 9 | 4 |
| R-2 | 11 | 5 |
| R-1 | 13 | 6 |
| R0 | 15 | 7 |
| R1 | 17 | 8 |
| R2 | 19 | 9 |
| R3 | 21 | 10 |

## XP

| Key | Type | Default | Description |
|---|---|---|---|
| `xp.weekly_award` | int | `1` | Weekly award per approved character (no login/activity required) |
| `xp.weekly_award_cron` | cron map | Sunday 00:00 | Schedule for automatic weekly and forum reconciliation awards |
| `xp.scene_sharer_award` | int | `2` | Award to the scene sharer, once per scene/recipient/award-type |
| `xp.scene_participant_award` | int | `1` | Award to each other approved participant |
| `xp.forum_award` | int | `1` | First qualifying player-authored forum topic/reply per week (later contributions that week award 0) |
| `xp.cost.skill_curve_numerator` | int | `1` | Numerator of the skill rating curve (`rating² / denominator`) |
| `xp.cost.skill_curve_denominator` | int | `2` | Denominator of the skill rating curve |
| `xp.cost.development_base` | int | `1` | Baseline development multiplier |
| `xp.cost.development_scale` | int | `250` | XP-spent threshold in the development curve |
| `xp.cost.development_exponent` | decimal | `1.25` | Development curve shape |
| `xp.cost.negative_resonance_rate` | decimal | `0.12` | Multiplier per negative Resonance level |
| `xp.cost.positive_resonance_rate` | decimal | `0.22` | Multiplier per positive Resonance level |
| `xp.cost.positive_resonance_surcharge` | int | `1` | Flat +1 XP surcharge per positive Resonance level |

Cost formula (Addendum §3 — resolves FINAL REQ-045's open cost-table item):
```
base_cost = ceil(new_rating² / xp.cost.skill_curve_denominator)
development_modifier = xp.cost.development_base + (xp_spent / xp.cost.development_scale)^xp.cost.development_exponent
resonance_modifier = (resonance > 0)
  ? 1 + xp.cost.positive_resonance_rate × resonance + xp.cost.positive_resonance_surcharge × resonance
  : 1 + xp.cost.negative_resonance_rate × resonance
final_cost = ceil(base_cost × development_modifier × resonance_modifier)
```

### Catch-Up XP (Addendum §8, resolves REQ-014's schedule/multiplier)

| Key | Type | Default | Description |
|---|---|---|---|
| `xp.catchup.enabled` | bool | `true` | Whether catch-up XP is active |
| `xp.catchup.multiplier` | decimal | `2.0` | Multiplier applied to eligible automatic awards |
| `xp.catchup.grace_period_weeks` | int | `0` | New-character grace period (none by default) |
| `xp.catchup.sources_excluded` | list | `[manual_grant]` | Sources exempt from catch-up (manual staff awards use `+xp/award/catchup` explicitly instead) |

Eligibility target is the median `xp_earned` across approved characters; progress is measured as `xp_earned + catchup_xp_earned`; the bonus is capped at the current median gap.

## Boons & Banes

| Key | Type | Default | Description |
|---|---|---|---|
| `bnb.categories` | list | Arcane, Mundane | Configurable catalogue categories (CI-01) |
| `bnb.level_definitions` | map | Minor +1, Major +2, Legendary +3, Negated no modifier, Epic explicitly configured | Per-level mechanical effect and ordering (REQ-017) |
| `bnb.level_chargen_availability` | map | Minor/Major/Legendary: configurable (default true); Negated: `false`; Epic: `false` | Per-level chargen availability |
| `bnb.definition_defaults.chargen_available` | bool | `true` | New catalogue entries default to chargen-available |
| `bnb.definition_defaults.flag_for_review` | bool | `false` | New catalogue entries default to not requiring review |
| `bnb.definition_defaults.modifier_eligible` | bool | `false` | Whether this B&B can satisfy the positive-Resonance Bane requirement |
| `bnb.chargen_ratio` | int | `2` | Boon-to-Bane ratio: every N Boons require at least 1 qualifying Bane (Addendum §5) |
| `bnb.ratio_rounding` | enum | `"floor"` | Rounding rule for the ratio calculation |
| `bnb.resonance_levels.<r>.boons.max_count` | int | See Addendum §5.2 table | Max chargen Boons at this Resonance level |
| `bnb.resonance_levels.<r>.boons.max_at_level_2` | int | See Addendum §5.2 table | Max Boons at level 2 (Major) |
| `bnb.resonance_levels.<r>.boons.max_at_level_3` | int | See Addendum §5.2 table | Max Boons at level 3 (Legendary) |
| `bnb.resonance_levels.<r>.banes.max_count` | int/null | `null` (unlimited) | Max chargen Banes at this Resonance level |
| `bnb.resonance_levels.<r>.banes.max_at_level_2` | int | See Addendum §5.3 table | Max Banes at level 2 |
| `bnb.resonance_levels.<r>.banes.max_at_level_3` | int | See Addendum §5.3 table | Max Banes at level 3 |

Full per-Resonance-level values are in `docs/spec/Implementation_Specification_Addendum.md` §5.2–§5.3.

## Rolls

| Key | Type | Default | Description |
|---|---|---|---|
| `rolls.random_model` | string | `"d20_open_ended"` | 2d20 open-ended dice model (Addendum §2) |
| `rolls.difficulties.trivial` | int | `11` | See Addendum §1 for the full 8-level scale |
| `rolls.difficulties.easy` | int | `12` | |
| `rolls.difficulties.standard` | int | `13` | |
| `rolls.difficulties.difficult` | int | `17` | |
| `rolls.difficulties.hard` | int | `21` | |
| `rolls.difficulties.extreme` | int | `25` | |
| `rolls.difficulties.legendary` | int | `34` | |
| `rolls.difficulties.mythic` | int | `40` | |
| `rolls.explosion.enabled` | bool | `true` | Explode on double-20 |
| `rolls.implosion.enabled` | bool | `true` | Implode on double-1 |
| `rolls.boon_bane.max_positive_modifier` | int/null | `null` | No cap; intentional (FINAL REQ-030 requires bounds be "meaningful," not necessarily fixed — see Addendum §4 rationale) |
| `rolls.boon_bane.max_negative_modifier` | int/null | `null` | No cap; intentional |
| `rolls.extraordinary_result_threshold` | decimal | `0.0001` | Probability (0.01%, 1-in-10,000) below which a roll is marked extraordinary (Addendum §9) |
| `rolls.extraordinary_result_good` | string | `"In a shocking display of good luck"` | Message prefix template |
| `rolls.extraordinary_result_bad` | string | `"In a fit of bad luck"` | Message prefix template |
| `rolls.degrees_of_success.exceptional_success_min` | int | `10` | Margin ≥ this value (Addendum §8.1) |
| `rolls.degrees_of_success.success_min` | int | `0` | |
| `rolls.degrees_of_success.complicated_success_min` | int | `-5` | |
| `rolls.degrees_of_success.lucky_failure_min` | int | `-10` | |
| `rolls.degrees_of_success.failure_min` | int | `-20` | Failure begins at this margin |
| `rolls.degrees_of_success.catastrophic_failure_min` | int | `-20` | Margins below this value are catastrophic failures |
| `rolls.output_mode` | enum | `"gm_led"` | `"gm_less"`, `"gm_led"`, or `"hybrid"` |
| `rolls.pending_roll_timeout_hours` | int | `720` | ~30 days wall-clock expiry (Addendum §6) |
| `rolls.auto_failure_on_expiry` | bool | `false` | Expired rolls never auto-resolve |
| `rolls.max_pending_rolls_per_player` | int | `1` | Standard roll pending limit (CI-04) |
| `rolls.max_pending_rolls_per_player_gm` | int | `2` | GM-assisted roll pending limit (CI-04) |
| `rolls.gm_scene_policy` | enum | `"optional"` | Game-wide default: `"required"`, `"optional"`, or `"unavailable"` |

## Privacy

| Key | Type | Default | Description |
|---|---|---|---|
| `privacy.gm_reveal_categories` | list | conservative default (name, public description only) | Configurable GM reveal categories: B&B name, public description, mechanical effects, character explanation, GM notes (REQ-005) |
| `privacy.warn_on_broader_reveal` | bool | `true` | Operator-facing warning when reveal policy is widened |

## Culminations

| Key | Type | Default | Description |
|---|---|---|---|
| `culminations.approval_required` | bool | `true` | Staff approval required unless automation explicitly enabled (REQ-044) |

## Notifications / History

| Key | Type | Default | Description |
|---|---|---|---|
| `notifications.character_facing_success` | bool | `true` | Notify players of awards, purchases, corrections (REQ-044) |

## Permissions

See `docs/reference/Permissions.md` for the full permission matrix (REQ-005).

## Integrations

| Key | Type | Default | Description |
|---|---|---|---|
| `integrations.inklings.enabled` | bool | `true` | Auto-detected via `defined?`; this flag allows explicit opt-out |
| `integrations.inklings.inspiration_cost` | int | `0` | Default Inkling submission cost (REQ-044) |
| `integrations.grimoire.enabled` | bool | `true` | Auto-detected via `defined?` |
| `integrations.grimoire.branch_skill_map` | map | `{}` | Grimoire branch keys mapped to configured SOUL Skill keys |

## Open Configuration Decisions Now Resolved

FINAL §9.4 (REQ-045) listed these as unresolved pending owner approval; all are now resolved in `docs/spec/Implementation_Specification_Addendum.md` and reflected above:

| Item | Resolved in |
|---|---|
| XP advancement cost table/equation | Addendum §3 |
| Chargen Boon/Bane limits and ratio | Addendum §5 |
| Random distribution and success equation | Addendum §2 |
| Difficulty scale | Addendum §1 |
| Global roll modifier bounds | Addendum §4 (bounds removed by design — see rationale) |
| Deterministic rounding rule | Addendum §7 |

Any global XP balance cap and final command syntax not already canonical in FINAL remain open per REQ-045 and REQ-037 — see `docs/reference/Commands.md`.

## Related Documents

- `docs/reference/Default_Config.md` — Complete `soul.yml` template
- `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` — Authoritative requirements
- `docs/spec/Implementation_Specification_Addendum.md` — Resolved mechanics

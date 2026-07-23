# SOUL API and Hooks

Public interfaces that other plugins use to integrate with SOUL, derived from `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") §10 (Extension Points, REQ-046 through REQ-049) and §8 (Integration, REQ-038 through REQ-041).

Exact class and method names are an implementation decision (FINAL REQ-004, REQ-046) — the signatures below illustrate the required coverage, not literal mandated names. All public APIs live in `plugin/public/*_api.rb` per `docs/architecture/Plugin_Architecture.md`.

## Public Service APIs (FINAL REQ-046)

SOUL SHALL expose documented service-level entry points for authorized reads and transitions **without permitting direct model mutation** by callers. Required coverage:

### Framework Lookup

Aspects and Skills are a configured catalogue (`game/config/soul.yml`'s `framework.aspects`/`framework.skills`), not separate DB models — `SoulFrameworkApi` reads `Global.read_config` directly and returns plain hashes, matching the verified real convention from FS3Skills (ability definitions are config; only per-character ratings are DB-backed). See `docs/architecture/Data_Model.md`.

```ruby
SoulFrameworkApi.get_aspects                       # => [{key:, name:, description:, order:}, ...] (default: Body, Mind, Spirit)
SoulFrameworkApi.get_aspect(aspect_key)             # => hash or nil
SoulFrameworkApi.get_skills(aspect_key: nil)        # => [{key:, name:, aspect_key:, order:}, ...]
SoulFrameworkApi.get_skill(skill_key)               # => hash or nil
SoulFrameworkApi.skill_min_rating / skill_max_rating
```

### Character Ratings

```ruby
SoulCharacterApi.get_skill_rating(character, skill_key)     # => 0-10
SoulCharacterApi.get_aspect_rating(character, aspect_key)
SoulCharacterApi.get_effective_base(character, skill_key)   # skill_rating + round_nearest(aspect_rating * weight)
SoulCharacterApi.set_skill_rating(character, skill_key, rating, enactor)   # direct set, bypasses XP - chargen/staff only
SoulCharacterApi.set_aspect_rating(character, aspect_key, rating, enactor)
```

### Resonance Reads

```ruby
SoulResonanceApi.get_resonance(character)           # => -3..3, or nil if not yet chosen
SoulResonanceApi.chargen_allowance(resonance)        # => { skill_points:, starting_cap: }
SoulResonanceApi.locked?(character)
```

Resonance is read-only to integrations — only SOUL's own chargen/staff-correction services (`set_resonance` pre-lock, `lock_at_approval`, `correct` post-lock) may write it (REQ-012).

### XP Awards / Spends

```ruby
# Award (validates idempotency; applies catch-up only if apply_catchup: true and the character is currently eligible)
SoulXpApi.award(character, amount, source:, idempotency_key: nil, apply_catchup: true)
  # Returns { success: true, awarded: n, base_award:, catchup_portion: n } or { error: "..." }

# Spend (advancement)
SoulXpApi.calculate_cost(character, skill_key, target_rating)  # Addendum §3 formula
SoulXpApi.spend(character, skill_key, amount, enactor)
  # Returns { error: "..." } or { success: true, new_rating:, cost:, xp_remaining: }

SoulXpApi.get_available_xp(character)
SoulXpApi.get_lifetime_earned_xp(character)
SoulXpApi.get_lifetime_spent_xp(character)
SoulXpApi.get_catchup_xp_earned(character)
SoulXpApi.median_earned_xp                          # Live-computed across Chargen.approved_chars
SoulXpApi.get_history(character, limit: 50)

# Correction/reversal (staff only)
SoulXpApi.correct(character, amount, reason:, actor:, direction: "correction")
  # direction: "correction" (default) adds to available XP
  # direction: "reversal" subtracts from available XP
  # Creates ledger correction entry, audit trail, and Narrative History entry
  # Does not undo prior skill advances (full rollback out of scope)

# Scene utilities
SoulXpApi.get_scene_participants(scene = nil)      # => [Character, ...] approved/active only
  # Returns approved characters currently in the scene
  # Used by +xp/scene command to preview and list recipients
```

### B&B Validation / Transitions

```ruby
SoulBnbApi.create_catalogue_entry(name:, description:, kind:, tag:, enactor:, category: nil, epic_modifier: nil, ...)
SoulBnbApi.get_catalogue(kind: nil, category: nil, active_only: true)
SoulBnbApi.get_catalogue_entry(id_or_tag)          # Numeric ID or tag, case-insensitive
SoulBnbApi.search(query)                           # Tag/name substring match

SoulBnbApi.get_character_entries(character)          # Owner/authorized-staff view
SoulBnbApi.get_character_entry_public(character, id) # Public-safe view (no explanation/GM notes)

# Grant, progress, resolve/restore (non-destructive), delete (destructive)
SoulBnbApi.grant(character, catalogue_ref, level_state:, source:, explanation: nil, enactor: nil)
  # Validates the continuous 2:1 Boon ratio (any source) and, when source: "chargen",
  # the Resonance-level count/level limits (Addendum §5). Returns { error: } or { success:, entry: }
SoulBnbApi.progress(entry_id, new_level_state, source:, explanation: nil, enactor: nil)
SoulBnbApi.resolve(entry_id, reason:, enactor:)     # Non-destructive; preserves prior level (REQ-020)
SoulBnbApi.restore(entry_id, enactor:)
SoulBnbApi.delete(entry_id, enactor:, confirmations:, reason:)  # Destructive; requires confirmations: 2 (REQ-021)
```

### Culmination Proposals

```ruby
SoulCulminationApi.propose(character, title:, description:, source:, enactor: nil)
  # Deterministic duplicate handling: a repeat call with the same source is a no-op (REQ-023)
SoulCulminationApi.approve(culmination_id, enactor)
SoulCulminationApi.deny(culmination_id, enactor, reason:)
SoulCulminationApi.revoke(culmination_id, enactor, reason:)   # Preserves original record, appends correction_log entry
SoulCulminationApi.correct(culmination_id, enactor, reason:, title: nil, description: nil)
SoulCulminationApi.get_culminations(character, status: nil)
```

Per REQ-023, an integrating plugin MAY propose a Culmination but SHALL NOT create the record directly — SOUL always owns creation after validation/approval.

### Dice Engine (Addendum §2, implemented — `plugin/public/soul_dice_engine.rb`)

Pure math/RNG, no model dependencies. `SoulRollApi` is the only expected caller.

```ruby
SoulDiceEngine.roll(net_modifier)
  # => { total:, mode: (:normal/:explosion/:implosion), segments: [{d1:, d2:}, ...] }
  # Real RNG - the actual dice portion of a live roll resolution.

SoulDiceEngine.success_probability(net_modifier, required_dice_total)
  # => Float 0.0..1.0. Pure/deterministic, no RNG (Addendum §9 requires the
  # pre-roll probability to be calculable and stored, not estimated).
```

### Roll Initiation / Completion (Phase 4: standard rolls; Phase 5: GM-assisted)

```ruby
SoulRollApi.get_candidate_bnbs(character, skill_key)
  # => [CharacterBnbEntry, ...] owned, unresolved, modifier_eligible, skill-associated

SoulRollApi.start_roll(character, skill_key, context: {}, gm_requested: false)
  # Creates a PendingRoll; system_suggested_entries may be empty (REQ-028's
  # "no candidates found" case - not a distinct status). gm_requested combines
  # with rolls.gm_scene_policy (required/optional/unavailable) to determine
  # the effective gm_assisted value (Phase 5, REQ-029) - a GM-assisted roll
  # starts in status "awaiting_gm" instead of "awaiting_selection" and
  # requires a resolvable scene.

SoulRollApi.get_gm_candidate_view(pending_roll_id, gm)
  # Phase 5. Privacy-filtered candidate list for GM review - only the fields
  # rolls.privacy.gm_reveal_categories permits (default: name + public
  # description only). Requires scene-GM authority (REQ-005): can_review_rolls?
  # AND the gm is a participant in the roll's scene.

SoulRollApi.gm_submit_selections(pending_roll_id, gm, mandatory_ids: [], optional_ids: [])
  # Phase 5. Partitions the pending roll's own system_suggested_entries into
  # mandatory (survives +roll none, REQ-029) and optional. Transitions
  # "awaiting_gm" -> "awaiting_selection".

SoulRollApi.select_entries(pending_roll_id, character, tags: [], suggested: false, none: false)
  # REQ-026's three selection forms (+roll <tag>, +roll suggested, +roll none).
  # Governs only the OPTIONAL bucket - unchanged by Phase 5's GM-mandatory
  # entries, which are combined in at resolve_pending instead.

SoulRollApi.resolve_pending(pending_roll_id, character)   # character required for ownership check (REQ-002)
  # Combines accepted entries (player-selected + manually-identified +
  # GM-mandatory, Phase 5) -> net_modifier -> SoulDiceEngine -> degree of
  # success (Addendum §8.1) -> extraordinary flag (Addendum §9) -> Roll record

SoulRollApi.abort_pending(pending_roll_id, actor, reason:)
  # Player's own voluntary abort. Phase 5 narrows the window for GM-assisted
  # rolls: allowed while "awaiting_gm", no longer allowed once the GM has
  # submitted (status "awaiting_selection" with gm_assisted true) - only
  # force_abort_pending remains available past that point (REQ-029/CI-03).

SoulRollApi.force_abort_pending(pending_roll_id, actor, reason:)
  # Phase 5. Staff or scene-GM only, either open status, notifies the roller
  # via Login.notify (REQ-029's "notify affected participants").

SoulRollApi.expire_stale_pending_rolls(now = Time.now)   # cron-driven sweep, Addendum §6; sweeps both open statuses as of Phase 5
SoulRollApi.get_roll_history(character, limit: 50)
```

### Authorized History Queries

```ruby
SoulNarrativeHistoryApi.get_history(character, viewer)   # Privacy-filtered per REQ-005
SoulAuditApi.get_audit(character, viewer)                # Staff-only
```

## Hooks

> **Not yet verified against real source.** `get_hooks` was assumed in an earlier documentation pass but, unlike `get_cmd_handler`/`get_event_handler`/`get_web_request_handler` (all confirmed real dispatch points on `AresMUSH::Dispatcher`), grepping the current AresMUSH core turns up **zero** references to `get_hooks` anywhere in engine or bundled plugins. This is the same class of mistake Lesson 33 (Inklings dev guide) warns about: a hook-shaped method that reads plausibly but has no confirmed caller. Do not implement `:soul_roll_modifiers` this way. When Phase 4/5 builds the roll engine, design the real modifier-contribution mechanism using a confirmed dispatch point (most likely `get_event_handler` with a purpose-built `SoulRollResolvingEvent`, or a direct method call from `SoulRollApi` into each loaded plugin module) - re-verify against source at that time rather than carrying this forward.

## Events

SOUL fires events via `Global.dispatcher.queue_event SomeEvent.new(...)` - the real, confirmed event mechanism (`plugins/roles/public/roles_events.rb`, `plugins/idle/public/idle_event.rb`; NOT `Global.dispatcher.dispatch("name", *args)`, which Inklings' own `dispatch_inkling_*` methods call but which doesn't exist on the real `Dispatcher` class - those calls are silently inert). Event classes are plain Ruby classes with `attr_accessor` fields, defined flat under `AresMUSH::` (never nested under `AresMUSH::Soul::` - see `plugin/public/soul_events.rb`). Other plugins subscribe the normal way, returning a handler class from their own `get_event_handler` for the event's class name.

All events carry stable identifiers and only the context their documented consumers are authorized to see (REQ-047).

> **Implementation status:** `SoulBnbTransitionedEvent` and `SoulCulminationApprovedEvent` below are fired for real (Phase 3, `plugin/public/soul_events.rb`). `SoulXpAwardedEvent` and `SoulSkillAdvancedEvent` are documented here as the planned shape but are not yet fired by Phase 2's `SoulXpApi`/`SoulCharacterApi` - add them using the same `Global.dispatcher.queue_event` pattern when an integration actually needs to consume them, rather than assuming they already exist.

### `SoulXpAwardedEvent`

**Fired when:** XP is awarded.

```ruby
event.character_id
event.amount               # post-multiplier total
event.base_award
event.catchup_portion
event.source
event.awarded_at
```

### `SoulSkillAdvancedEvent`

```ruby
event.character_id
event.skill_key
event.old_rating
event.new_rating
event.xp_spent
event.advanced_at
```

### `SoulBnbTransitionedEvent`

**Fired when:** A character B&B entry is granted, progresses, is resolved, or is negated.

```ruby
event.character_id
event.entry_id
event.catalogue_id
event.old_level_state       # nil on initial grant
event.new_level_state
event.source
event.transitioned_at
```

### `SoulCulminationApprovedEvent`

```ruby
event.character_id
event.culmination_id
event.source
event.approved_at
```

### `SoulRollResolvedEvent`

```ruby
event.character_id
event.roll_id
event.skill_key
event.final_result
event.degree_of_success
event.extraordinary
event.gm_assisted
event.resolved_at
```

## Integration Contracts (FINAL REQ-039, REQ-040)

### Inklings: Validation Hook

```ruby
# Inklings calls this before staff approval, to get a normalized payload without mutating state
SoulInklingsHook.validate_outcome(
  outcome_type:,        # :xp, :boon_progression, :bane_progression, :culmination
  character:,
  proposed_transition:,  # exact shape per outcome_type - see Phase 7 handoff §5.4
  requester: nil,
  inkling_reference:
)
# Returns a JSON-safe normalized payload (string keys, no live model references - see
# docs/handoffs/Phase_7_Inklings_Hook_and_Grimoire_Mapping.md §5.5) or { error: }.
# Never mutates SOUL state.
```

### Inklings: Application Hook

```ruby
# Inklings calls this after approval, with the validated payload from above
SoulInklingsHook.apply_outcome(payload, source: "inkling:234")
# Re-derives the character from payload, revalidates current state (state may have
# changed since submission - e.g. the B&B ratio, or the target entry's level), applies
# atomically, returns { success:, soul_references: } or { error: }.
#
# Idempotency (REQ-038): :xp relies on SoulXpApi.award's own idempotency_key; :culmination
# relies on SoulCulminationApi.propose's own source-based dedup; :boon_progression/
# :bane_progression have no such protection in SoulBnbApi.grant/.progress themselves, so
# the hook checks each entry's own stored source/progression_history before calling them -
# see the Phase 7 handoff §5.2 for the exact mechanism. A repeat call with the same source
# never double-applies.
```

### Grimoire: Read-Only Capability Exchange

```ruby
# Grimoire reads Skills/Aspects/Resonance through documented read APIs only
SoulCharacterApi.get_skill_rating(caster, "ceremonial_magic")

# Grimoire branch -> Skill mapping (REQ-040: no dedicated Arcana Skill is created)
SoulFrameworkApi.get_skill_for_grimoire_branch(branch_key)
  # => the mapped Skill's hash, or nil if unmapped. Config-driven:
  # game/config/soul.yml's integrations.grimoire.branch_skill_map.

# SOUL never receives or stores Grimoire spell history (REQ-040).
```

## Compatibility Contract (FINAL REQ-049)

Public APIs, hooks, event payloads, configuration keys, and stored stable identifiers are documented and versioned. Breaking changes require migration guidance and an explicit version bump — see `docs/development/Release_Process.md`.

## Related Documents

- `docs/architecture/Plugin_Architecture.md` — Where these APIs live in the plugin structure
- `docs/architecture/Event_Flow.md` — Full workflow context for each API call
- `docs/architecture/Integration_Guide.md` — Step-by-step integration patterns for Inklings/Grimoire and other plugins

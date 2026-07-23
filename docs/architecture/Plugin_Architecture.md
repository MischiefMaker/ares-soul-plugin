# SOUL Plugin Architecture

Overview of SOUL's structure as an AresMUSH plugin. This document describes how SOUL is organized, how it integrates with Ares core, and how other plugins can extend it.

This document is derived from `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` (the authoritative specification — cited below as "FINAL") and `docs/spec/Implementation_Specification_Addendum.md` ("Addendum"). REQ-* references point to FINAL's Requirements Index (Appendix F).

## Scope (FINAL REQ-001)

SOUL SHALL replace the FS3 system entirely — it is the game's complete character advancement, resolution, and progression framework, not an add-on running alongside FS3.

SOUL SHALL provide: the Character Framework; optional Resonance; XP and advancement; Boons and Banes; Culminations; Narrative History; standard and GM-assisted rolls; equivalent MUSH and web workflows; permissions, privacy, validation, configuration, notifications, and audit; optional first-party integrations (Inklings, Grimoire).

SOUL SHALL complement, not replace, AresMUSH authentication, channels, mail, Jobs, scenes, and chargen/approval. SOUL SHALL load and support its core features without Inklings or Grimoire installed.

## Directory Structure

Follows standard AresMUSH plugin layout (CP-08 — AresMUSH First):

```
plugin/
  soul.rb                    # Module registration: plugin_dir, get_cmd_handler,
                              # get_event_handler, get_web_request_handler,
                              # check_config, permission helpers
  soul_config_validator.rb   # Config validation (Manage::ConfigValidator)
  commands/                  # One class per MUSH command (+soul, +roll, +bnb, +xp, ...)
  web/                       # Thin web request handlers
  public/                    # Business logic APIs (shared by MUSH and web)
  models/                    # Ohm::Model database classes (in the AresMUSH namespace)
  events/                    # Event handlers
  locales/                   # User-facing strings (locale_en.yml)
  help/en/                   # All help topics, player and staff alike - admin
                              # topics are distinguished by a "Permission
                              # Required" note in the body, not a separate
                              # directory (see docs/reference/Commands.md)
```

There is deliberately no `hooks/` directory. `get_cmd_handler`, `get_event_handler`, and `get_web_request_handler` are the only dispatch points the framework actually discovers automatically (`Global.plugin_manager.sorted_plugins.each { |p| ... if p.respond_to?(:get_x_handler) }` in `AresMUSH::Dispatcher`). Chargen integration works differently — see Character Integration below.

## Plugin Initialization

1. Plugin module registers command/event/web-handler dispatchers.
2. Configuration loaded live from `game/config/soul.yml` (CP-06 — read via `Global.read_config`, never memoized).
3. Event handlers subscribe to Ares lifecycle events (scene sharing, chargen approval via `Chargen.custom_approval`).

## Plugin Architecture Principles (FINAL REQ-002)

Per CP-04 (Plugin Ownership) and CP-08 (AresMUSH First):

- Commands and request handlers SHALL be thin adapters only.
- Shared services (in `public/*_api.rb`) SHALL own validation, permissions, calculations, state transitions, history effects, audit, and notifications.
- MUSH and web SHALL call the same services — no parallel logic paths.
- Serializers SHALL enforce the same privacy rules as commands and handlers.
- Handlers SHALL NOT trust client-supplied character IDs, scene roles, permissions, modifiers, or costs — these are re-validated server-side on every call.
- Events and hooks SHALL be idempotent where duplicate delivery is possible.
- Direct cross-plugin model access, monkey-patching, brittle polling, and duplicated business rules are prohibited.

## Command & Event Dispatch

Commands are dispatched by name through `get_cmd_handler`:
```ruby
def self.get_cmd_handler(cmd)
  case cmd.name
  when "soul"
    return SoulSheetCmd
  when "roll"
    return SoulRollCmd
  when "bnb"
    return SoulBnbCmd
  when "xp"
    return SoulXpCmd
  # ... other command families
  end
  nil
end
```

Events follow the same pattern via `get_event_handler`. See `docs/reference/Commands.md` for the full canonical command surface (FINAL REQ-026, REQ-037).

## Web Handler Pattern

Web handlers are thin adapters that:
1. Check login and permissions.
2. Unpack request arguments (never trusting client-supplied IDs/permissions/costs per REQ-002).
3. Delegate to business logic in `public/*_api.rb`.
4. Return a hash (success or `{ error: "..." }`).

## Data Domains SOUL Owns (FINAL REQ-003)

SOUL-owned persistent domains include:

- character SOUL state (Aspect/Skill references and ratings);
- approved Resonance and chargen lock state;
- XP balances, lifetime counters, catch-up counters, and award/spend ledger;
- character B&B entries and level/state history;
- Culminations;
- Narrative History;
- pending and completed roll records;
- SOUL audit records and idempotency keys.

Character-specific explanations and GM notes SHALL NOT be stored in public catalogue definitions (they belong on the character-owned B&B entry — see `docs/architecture/Data_Model.md`).

External plugin references (e.g. an Inkling ID) MAY be stored by stable external identifier, but external history SHALL NOT be copied into SOUL.

## Services (FINAL REQ-004)

Business logic is centralized into cohesive services for:

- framework/configuration validation;
- character/chargen validation;
- Resonance calculation and locking;
- XP awards, catch-up, spending, reversal, and correction;
- B&B catalogue and character state transitions;
- Culminations;
- Narrative History and audit;
- roll suggestion, pending-roll state, GM input, resolution, and abort;
- privacy/authorization;
- integrations and capability detection (`defined?(AresMUSH::Soul)` pattern for consumers).

Exact class names are an implementation decision, but service boundaries SHALL prevent rule duplication between MUSH commands, web handlers, and integration hooks.

## Character Integration

SOUL integrates with the Character profile via `custom_char_fields.rb` hooks (manual-paste snippet, per AresMUSH convention — this file is shared/game-owned and must not be auto-installed over):
- Returns SOUL-managed data as `char.custom.soul_*` on profile display.
- Supports the chargen integration described in FINAL §5.4 (Character Generation, REQ-011).
- Approval-time state locking uses the official `Chargen.custom_approval(char)` hook, which runs after `char.is_approved = true` persists — not a custom event.

## Permissions

All permission checks use configurable permission names (FINAL REQ-005):
```ruby
Global.read_config("soul", "permission_name")
```
See `docs/reference/Permissions.md` for the full permission matrix.

## Configuration

Configuration is read fresh on every use, never cached in a plugin-level constant or variable, per CP-06:
```ruby
Global.read_config("soul", "key_name")
```
This allows admins to edit `game/config/soul.yml` and have the change picked up on the next staff config reload — no plugin restart needed. See `docs/reference/Configuration.md`.

## Extensibility

### Hooks and Events for Other Plugins (FINAL REQ-046, REQ-047)

SOUL exposes documented service-level entry points and hook/event contracts for Inklings and Grimoire integration. See `docs/architecture/API_and_Hooks.md` for the full API and hook reference, and `docs/architecture/Integration_Guide.md` for integration patterns.

### Extension Ownership (FINAL REQ-048)

An extension MAY propose or request a SOUL-owned transition, but SOUL SHALL validate and apply it. SOUL MAY reference external records by stable identifier but SHALL NOT copy external domain history or reimplement another plugin's rules.

## Related Documents

- `docs/architecture/Data_Model.md` — database schema and relationships
- `docs/architecture/Event_Flow.md` — workflow and event sequences
- `docs/architecture/API_and_Hooks.md` — public API and hook reference
- `docs/architecture/Integration_Guide.md` — Inklings/Grimoire integration patterns
- `docs/reference/Configuration.md` — configuration structure
- `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` — authoritative specification

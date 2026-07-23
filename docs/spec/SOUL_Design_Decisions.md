# SOUL Design Decisions

A long-term record of why SOUL was designed the way it is. This document captures the reasoning behind architectural choices, trade-offs considered, and rejected alternatives.

## Overview

SOUL is designed as a story-first character progression and narrative framework for AresMUSH. This document explains the principles guiding that design and documents key decisions that shape the system.

## Major Design Decisions

### DD-01: Story-First Mechanics

**Decision:** Mechanics are designed to enhance roleplay, not become the focus of play.

**Rationale:** Players should gain more from good RP, Inklings, Boons & Banes, and long-term storytelling than from simply accumulating XP or grinding mechanics. The system rewards narrative investment.

### DD-02: On-Game Creation, Not Seeding

**Decision:** Boons & Banes are created via in-game commands post-install; examples are provided in README, not pre-seeded into the database.

**Rationale:** Follows established AresMUSH patterns where admins create data via commands. Keeps installation lightweight and transparent. Admins retain full control over what B&Bs exist in their world.

**Cross-Reference:** Implementation_Specification_Addendum §8 addresses B&B chargen limits and lifecycle.

### DD-03: Hooks and Services for Plugins

**Decision:** SOUL exposes hooks and services for optional plugins (Grimoire, Inklings) to integrate rather than duplicate functionality.

**Rationale:** Avoids coupling between plugins while allowing them to extend SOUL. Future plugins can add features without reimplementing SOUL's core concerns.

**Cross-Reference:** `docs/architecture/API_and_Hooks.md` details all public APIs and event hooks.

### DD-04: Flexible B&Bs with Lifecycle

**Decision:** Boons & Banes are managed instances with reusable definitions, character-specific instances, mechanical effects, tags, sources, history, and active/resolved lifecycle.

**Rationale:** Not static YAML lists. This gives admins the flexibility to model complex narrative effects and maintain history for storytelling purposes.

### DD-05: SOUL Owns Rolls

**Decision:** SOUL will eventually own character rolls, supporting normal player rolls, optional GM-assisted rolls, Boons & Banes, configurable scene policies, and asynchronous GM workflows.

**Rationale:** Centralizes mechanics so other plugins can hook into roll resolution rather than implementing parallel systems. Enables consistent treatment of modifiers across plugins.

**Cross-Reference:** Implementation_Specification_Addendum §2 (2d10 open-ended mechanics), §8.1 (six degrees of success), §9 (extraordinary luck messaging).

### DD-06: Aspect Weight (Configurable)

**Decision:** Aspects contribute a scaled modifier to rolls (default: Aspect Rating × 0.20), configurable for balance.

**Rationale:** Aspects provide character flavor and framework without overshadowing Skill investment. Configurable weight allows games to tune how much Aspect matters relative to Skill.

**Configuration:**
```yaml
aspect:
  weight: 0.20   # Default. Subject to playtesting and balance.
```

**Cross-Reference:** Implementation_Specification_Addendum §8 addresses Aspect contribution rounding.

## Rejected Alternatives

### YAML-Driven B&Bs

**Rejected:** Supporting both YAML-defined and command-created Boons & Banes.

**Why:** Dual-source approach adds significant complexity (merging, conflict resolution, precedence rules) without enough benefit at this stage. Database-only with README examples is simpler and more flexible.

### Pre-Seeded Database Records

**Rejected:** Creating initial B&B records during plugin installation via `init_plugin` hook.

**Why:** Breaks AresMUSH patterns where post-install setup happens via commands. Adds installation complexity and removes admin transparency about what data gets created.

## Deferred Ideas

### Multi-Aspect Skills

Deferred pending experience with single-aspect implementation. May revisit if games want skills that bridge multiple aspects.

### Resonance Decay

Deferred pending clarity on how resonance should interact with long-term character changes. Marked for future enhancement.

### Guild-Owned Resources

Deferred - potential future feature for group-based resource pools or shared progression. Would integrate via existing hook system if implemented.

## Future Considerations

### Configuration Extensibility

Plan to make gameplay values, limits, permissions, and progression rules configurable via YAML. This allows games to tune the system without forking code.

### Grimoire and Inklings Integration

Grimoire should eventually use SOUL skills and roll mechanics. Inklings should award XP, Boons, Banes, and other outcomes through SOUL hooks.

### Economy and Other Plugin Integration

The hook system should support integration from other plugins (Economy, etc.) without tight coupling to SOUL's internals.

## Historical Notes

This system was designed with lessons learned from the Inklings project and in preparation for its eventual replacement of FS3 in games that choose to use it. The architecture prioritizes compatibility with existing plugins and configurability for diverse game needs.

---

## Decision Index

Quick reference for all major design decisions (DD-##):

| Decision | Section | Status | Cross-Reference |
|----------|---------|--------|-----------------|
| DD-01 | Story-First Mechanics | ✅ Approved | Core philosophy |
| DD-02 | On-Game Creation, Not Seeding | ✅ Approved | Implementation_Specification_Addendum §8 |
| DD-03 | Hooks and Services for Plugins | ✅ Approved | docs/architecture/API_and_Hooks.md |
| DD-04 | Flexible B&Bs with Lifecycle | ✅ Approved | docs/architecture/Data_Model.md |
| DD-05 | SOUL Owns Rolls | ✅ Approved | Implementation_Specification_Addendum §2, §8.1, §9 |
| DD-06 | Aspect Weight (Configurable) | ✅ Approved | Implementation_Specification_Addendum §8 |

---

## Recommended Reading Order

1. **New to SOUL:** Start with Overview, then read Major Design Decisions (DD-01 through DD-06)
2. **Implementation planning:** Cross-reference each DD with the linked documents for detailed specifications
3. **Architecture questions:** See `docs/architecture/` for data models, API contracts, and integration patterns
4. **Configuration details:** See `docs/reference/Configuration.md` and `Implementation_Specification_Addendum.md` for tunable parameters

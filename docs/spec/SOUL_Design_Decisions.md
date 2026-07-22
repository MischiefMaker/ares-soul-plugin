# SOUL Design Decisions

A long-term record of why SOUL was designed the way it is. This document captures the reasoning behind architectural choices, trade-offs considered, and rejected alternatives.

## Overview

SOUL is designed as a story-first character progression and narrative framework for AresMUSH. This document explains the principles guiding that design and documents key decisions that shape the system.

## Major Design Decisions

### Story-First Mechanics

**Decision:** Mechanics are designed to enhance roleplay, not become the focus of play.

**Rationale:** Players should gain more from good RP, Inklings, Boons & Banes, and long-term storytelling than from simply accumulating XP or grinding mechanics. The system rewards narrative investment.

### On-Game Creation, Not Seeding

**Decision:** Boons & Banes are created via in-game commands post-install; examples are provided in README, not pre-seeded into the database.

**Rationale:** Follows established AresMUSH patterns where admins create data via commands. Keeps installation lightweight and transparent. Admins retain full control over what B&Bs exist in their world.

### Hooks and Services for Plugins

**Decision:** SOUL exposes hooks and services for optional plugins (Grimoire, Inklings) to integrate rather than duplicate functionality.

**Rationale:** Avoids coupling between plugins while allowing them to extend SOUL. Future plugins can add features without reimplementing SOUL's core concerns.

### Flexible B&Bs with Lifecycle

**Decision:** Boons & Banes are managed instances with reusable definitions, character-specific instances, mechanical effects, tags, sources, history, and active/resolved lifecycle.

**Rationale:** Not static YAML lists. This gives admins the flexibility to model complex narrative effects and maintain history for storytelling purposes.

### SOUL Owns Rolls

**Decision:** SOUL will eventually own character rolls, supporting normal player rolls, optional GM-assisted rolls, Boons & Banes, configurable scene policies, and asynchronous GM workflows.

**Rationale:** Centralizes mechanics so other plugins can hook into roll resolution rather than implementing parallel systems. Enables consistent treatment of modifiers across plugins.

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

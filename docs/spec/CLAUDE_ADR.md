# CLAUDE's Architecture Decision Record (ADR)

Claude's ongoing engineering notebook for SOUL implementation. This document tracks current status, recent changes, outstanding work, and design decisions made during development.

## Current Status

**Session Date:** 2026-07-22

**Current Branch:** `claude/soul-plugin-architecture-g8iew0`

**Phase:** Architectural planning and feasibility research.

**Context:**
- Established SOUL's role as a story-first character progression system
- Researched AresMUSH plugin development patterns via Inklings project guide
- Investigated database seeding patterns for initial Boon & Bane examples
- Decided on command-based creation with README examples (no pre-seeding)

## Recent Changes

### Documentation Setup (2026-07-22)
- Created CLAUDE.md with reference to ARES_PLUGIN_DEVELOPMENT_GUIDE.md
- Established repository documentation structure
- Created initial templates for architecture, reference, and development docs

### Feasibility Research (2026-07-22)
- Confirmed database seeding is not a standard AresMUSH pattern
- Core system seeds foundational data once via `init_db.rb`
- Plugins typically use YAML config, not pre-created records
- Decided against dual YAML+database approach for B&Bs (too complex for benefit)

## Outstanding Work

### Architecture & Design
- [ ] Define core Character model structure
- [ ] Design Aspect system and interaction with Skills
- [ ] Define Skill progression and advancement mechanics
- [ ] Design XP and catch-up XP systems
- [ ] Clarify Resonance mechanics and lifecycle
- [ ] Design Boon & Bane instance model and lifecycle
- [ ] Design roll resolution system and modifiers
- [ ] Design GM-assisted roll workflow

### Plugin Integration
- [ ] Document hook points for Grimoire integration
- [ ] Document hook points for Inklings integration
- [ ] Define public API surface for other plugins
- [ ] Plan configuration extensibility

### Implementation Planning
- [ ] Prioritize subsystems for initial implementation
- [ ] Identify dependencies between subsystems
- [ ] Plan web portal integration approach
- [ ] Design permission model

## Known Technical Debt

### Research Gaps
- Exact nature of "Resonance" and how it differs from other progression metrics
- How Boon & Banes mechanically interact with rolls (beyond "modifiers")
- Whether Aspects are tied to Skills or exist independently
- Character advancement velocity and balance targets

### Architecture Questions
- Should Resonance be character-wide or aspect-specific?
- Are B&B effects purely numerical or can they gate content/abilities?
- How does "catch-up XP" differ in mechanics from normal progression?
- What's the scope of GM-assisted rolls (approval workflow, cooldowns, costs)?

## Open Questions

1. **Aspects as Configuration:** Should the set of available Aspects be configurable per-game, or hardcoded?

2. **B&B Stacking:** Can a character have multiple instances of the same Boon/Bane type? How are they managed?

3. **Roll Modifiers:** Are Boon/Bane effects purely additive, or can they enable rerolls, automatic successes, etc.?

4. **Resonance Decay:** Should Resonance degrade over time, or persist indefinitely once earned?

5. **Catch-Up Mechanics:** Should catch-up XP have different spending rules or rewards, or just be accelerated earning?

## Session Notes

### Session: 2026-07-22
- User established SOUL's role as architectural context for other plugin development
- Explored feasibility of pre-seeded B&B examples
- Decided to follow AresMUSH patterns: command-based creation, README examples
- Set up initial repository documentation structure
- Next: Deep design work on core systems (Aspects, Skills, XP, B&Bs)

---

**Note:** This document is a living record. Each implementation session should update this section with current status, recent decisions, and outstanding questions. It serves as context-bridge between sessions.

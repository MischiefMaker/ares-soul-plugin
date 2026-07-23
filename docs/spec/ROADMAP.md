# SOUL Development Roadmap

High-level milestones for SOUL implementation. This roadmap reflects current planning; timelines and scope may adjust based on development progress and research findings.

## Completed Milestone: Architecture & Foundation

**Status:** ✅ Complete (2026-07-23)

**Achievements:**
- ✅ Finalized all 10 core mechanical decisions (see Implementation_Specification_Addendum.md)
- ✅ Resolved open design questions (Aspects, Resonance, B&B mechanics, XP costs, etc.)
- ✅ Established comprehensive specification with formulas, examples, and configuration
- ✅ Set up complete documentation structure (architecture, reference, development, spec)
- ✅ Researched AresMUSH patterns via Inklings project guide
- ✅ Created implementation checklist and prioritization (LlamaCoder handoff workflow)

**Key Decisions Locked:**
- Difficulty scale (8 levels: Trivial–Mythic)
- 2d20 open-ended rolling with Boon/Bane die rerolls
- Algebraic XP advancement costs with Resonance modifiers
- Catch-up XP median-based system (2x multiplier, weekly cron)
- Six degrees of success with configurable narrative output
- Character chargen limits (2:1 Boon-to-Bane ratio)

## Current Milestone: Core Implementation

**Status:** Ready to Begin (Handoff Preparation Phase)

**Phasing Strategy:**
The implementation will be broken into subsystems and handed to LlamaCoder for repetitive work, with Claude maintaining architecture review and acceptance. See SOUL_LLM_Implementation_Specification.md for handoff workflow.

**Phase 1: Foundation (Data Models & Configuration)**
- Character model schema and initialization
- Aspect system implementation
- Boon & Bane model and lifecycle
- Resonance mechanics
- Configuration system and YAML parsing

**Phase 2: Progression (XP & Advancement)**
- XP earning system (scene rewards, admin grants)
- Catch-up XP calculation and application
- Skill advancement mechanics
- XP spending and cost calculations
- Configuration-driven advancement curves

**Phase 3: Rolling (Dice Engine & Resolution)**
- Core 2d20 rolling engine with explosion/implosion
- Boon/Bane die reroll mechanics
- Modifier application (Skill + Aspect + other)
- Degree of success determination
- Extraordinary luck probability calculation

**Phase 4: Workflows (Commands & Web Portal)**
- Character management commands
- Roll command with contextual modifiers
- Pending roll approval workflow (GM-assisted)
- Roll history and statistics
- Web portal API endpoints

**Estimated Scope:** 4-6 implementation cycles (with LlamaCoder parallelization)

## Future Enhancements

### Phase 2: Rolls & Combat
- Full roll resolution system with B&B modifiers
- GM-assisted roll workflow
- Scene-based roll policies
- Comprehensive roll history and statistics

### Phase 3: Grimoire Integration
- Hookable spell system using SOUL skills
- Spell casting via SOUL rolls
- Magical resource management via Resonance

### Phase 3: Inklings Integration
- Inkling creation/management with SOUL hook access
- Inkling-based XP rewards
- Inkling narrative effects on Boons & Banes

### Phase 4: Polish & Refinement
- Performance optimization
- Admin tools for managing system state
- Extended configuration options
- Comprehensive documentation and guides

## Stretch Goals

### Multi-Game Research
- Gather feedback from pilot games
- Iterate based on live-play experience
- Publish detailed case studies of system usage

### Advanced Mechanics
- Guild or group-based progression
- Cross-character narrative bonds
- Resonance specialization trees
- Dynamic B&B effects based on context

### Ecosystem
- Reference implementation for plugin integration
- Plugin developer guides
- Community examples and templates

---

**Last Updated:** 2026-07-23

**Next Review:** After completing Phase 1 (Foundation) handoffs to LlamaCoder

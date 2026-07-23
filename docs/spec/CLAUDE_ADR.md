# CLAUDE's Architecture Decision Record (ADR)

Claude's ongoing engineering notebook for SOUL implementation. This document tracks current status, recent changes, outstanding work, and design decisions made during development.

## Current Status

**Session Date:** 2026-07-23

**Current Branch:** `main`

**Phase:** ✅ ARCHITECTURAL PHASE COMPLETE | Implementation Ready

**Context:**
- All 10 core mechanical decisions are locked in (see Implementation_Specification_Addendum.md)
- Complete specification with formulas, examples, configuration, and rationale for each system
- Three specification inconsistencies resolved:
  - §3 XP Advancement Cost: Confirmed algebraic model (removed pending options)
  - Extraordinary luck threshold: Standardized to 0.0001 (0.01% / 1 in 10,000) across all sections
  - Degrees of Success: Locked concrete margin thresholds; removed pending language
- Architecture is specification-complete and ready for implementation handoffs

## Recent Changes

### Architecture Complete (2026-07-23)
- Locked all 10 core mechanical decisions in Implementation_Specification_Addendum.md:
  1. ✅ Difficulty Scale (8-level fixed: Trivial through Mythic)
  2. ✅ Random Distribution (2d20 open-ended with explosion/implosion and Boon/Bane die rerolls)
  3. ✅ XP Advancement Cost (Algebraic model: ceil(new_rating² / 2) × development_modifier × resonance_modifier)
  4. ✅ Modifier Bounds (Removed; no caps, Boons/Banes modify luck via rerolls only)
  5. ✅ Chargen B&Bs (2:1 Boon-to-Bane ratio, per-Resonance-level configuration)
  6. ✅ Pending Roll Expiry (~30 days / 720 hours wall-clock)
  7. ✅ Aspect Rounding (Round nearest; Aspect × 0.20)
  8. ✅ Catch-Up XP (Weekly median-based, 2x multiplier until available_xp ≥ median)
  9. ✅ Degrees of Success (Six degrees with configurable narrative output)
  10. ✅ Extraordinary Luck Messaging (Probability-based <0.01%, 1 in 10,000)
- Resolved all specification inconsistencies (§3 status, extraordinary thresholds, degrees of success language)
- Documentation structure complete across architecture, reference, development, and specification docs

### Documentation Setup (2026-07-22)
- Created CLAUDE.md with reference to ARES_PLUGIN_DEVELOPMENT_GUIDE.md
- Established repository documentation structure
- Created initial templates for architecture, reference, and development docs

### Feasibility Research (2026-07-22)
- Confirmed database seeding is not a standard AresMUSH pattern
- Core system seeds foundational data once via `init_db.rb`
- Plugins typically use YAML config, not pre-created records
- Decided against dual YAML+database approach for B&Bs (too complex for benefit)

## Architectural Work (COMPLETE ✅)

All 10 core mechanical decisions are locked in. See Implementation_Specification_Addendum.md for complete specifications.

## Implementation Work (NEXT PHASE)

### LlamaCoder Handoff Preparation
- [ ] Prepare Character model and initialization system handoff
- [ ] Prepare Aspect system implementation handoff
- [ ] Prepare Skill progression and advancement handoff
- [ ] Prepare XP and catch-up XP systems handoff
- [ ] Prepare Resonance mechanics and lifecycle handoff
- [ ] Prepare Boon & Bane instance model handoff
- [ ] Prepare roll resolution engine handoff
- [ ] Prepare GM-assisted roll workflow handoff

### Plugin Integration & Extension
- [ ] Document hook points for Grimoire integration
- [ ] Document hook points for Inklings integration
- [ ] Define public API surface for other plugins
- [ ] Design and document configuration extensibility

### Web Portal & Commands
- [ ] Plan web portal integration approach
- [ ] Design permission model and enforcement
- [ ] Prepare command system handoffs
- [ ] Prepare web handler and API endpoint handoffs

## Resolved Architecture Questions

✅ **Resonance:** Character-wide metric affecting XP advancement costs (§3, §5). Ranges R-3 to R+3 with positive Resonance increasing advancement costs significantly (1.22x + 1x surcharge per level).

✅ **Boon & Bane Mechanics:** Purely mechanically (luck via die rerolls, not gating). +N rerolls 1-N, -N rerolls (21-N)-20. Chargen 2:1 ratio (unlimited Banes, capped Boons per R-level). Persist post-chargen unchanged.

✅ **Aspects:** Configurable set per-game; contribute to rolls via "Aspect × weight" (typically 0.20, rounded nearest) applied after all Boon/Bane rerolls.

✅ **Roll Modifiers:** Boon/Bane effects are die rerolls (not flat bonuses). Mechanical modifiers (Skill + Aspect + other) stack unbounded, applied after rerolls.

✅ **Resonance Persistence:** Persists indefinitely once earned; no decay.

✅ **Catch-Up Mechanics:** Accelerated *earning* only (2x multiplier from sources like scene XP, Inklings). Spending uses normal XP cost formula. Weekly median-based trigger, no grace period for new characters.

✅ **GM-Assisted Rolls:** Approval workflow for pending rolls; 720-hour (30-day) expiry; configurable per-player open roll cap.

## Outstanding Implementation Design

### Before Implementation Begins
- [ ] Finalize Character model schema (attributes, relationships, constraints)
- [ ] Decide on Boon & Bane seeding strategy (command-based, README examples, or YAML seed data)
- [ ] Define Permission model (who can create B&Bs, approve rolls, set Resonance, etc.)
- [ ] Plan database indexing strategy for roll queries and character lookups
- [ ] Design cron/scheduler approach for weekly catch-up calculation
- [ ] Finalize API contracts between Ruby backend and Ember web portal

## Session Notes

### Session: 2026-07-23 (Current)
- **Architecture Finalization:** All 10 core mechanical decisions locked in and specification-complete
- **Issue Resolution:**
  - Fixed §3 XP Advancement Cost: Confirmed algebraic model as single approved approach
  - Standardized extraordinary luck threshold to 0.0001 (0.01%) across §2 and §9
  - Removed "pending finalization" language from Degrees of Success (§8.1); margin thresholds locked
- **Status:** Architecture ✅ COMPLETE; Ready for implementation handoff preparation
- **Next Phase:** Transition to implementation with LlamaCoder handoffs for subsystems
- **Key Files:**
  - `docs/spec/Implementation_Specification_Addendum.md` - All 10 decisions with formulas and rationale
  - `docs/spec/SOUL_LLM_Implementation_Specification.md` - High-level overview and LlamaCoder workflow
  - `docs/spec/CLAUDE_ADR.md` - This document; architecture continuity record

### Session: 2026-07-22
- User established SOUL's role as architectural context for other plugin development
- Explored feasibility of pre-seeded B&B examples
- Decided to follow AresMUSH patterns: command-based creation, README examples
- Set up initial repository documentation structure
- Conducted deep design work on core systems (Aspects, Skills, XP, B&Bs)

---

**Note:** This document is a living record. Each implementation session should update this section with current status, recent decisions, and outstanding questions. It serves as context-bridge between sessions.

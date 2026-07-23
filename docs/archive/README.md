# Archived Documentation — Superseded Scaffolding

**Archived:** 2026-07-23

## Why these files are here

The files under this directory were written in a single commit (`4c9df1b`, "Set up
comprehensive documentation structure for SOUL", 2026-07-22) by a prior Claude
session. That session's own notes describe the work as "created initial
templates for architecture, reference, and development docs" — generic
placeholder content, invented without deriving it from the project's actual
governing specification.

The result directly contradicts `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md`,
which the project owner uploaded directly that same day and which declares
itself authoritative. Examples of the contradiction:

| Concept | Archived (fabricated) | Actual (FINAL.md) |
|---|---|---|
| Aspects | Combat, Social, Arcane, Mental (example names) | Body, Mind, Spirit (GL-04, REQ-008) |
| Skill range | 0–5 | 0–10 (REQ-010) |
| XP advancement cost | Flat table `[10,20,30,40,50]` | Algebraic model (resolved in Addendum §3) |
| Boon/Bane model | category + active/resolved, no IDs | Numeric ID + tag, catalogue/instance split, Minor/Major/Legendary/Negated/Epic levels (REQ-017/018) |
| Core commands | `soul`, `soul/advance`, `boon/create`, `roll` | `+soul`, `+xp/award`, `+bnb`, `+roll` (CI-05, REQ-026, REQ-037) |

None of this fabricated content reflected a real project-owner decision. It was
discovered and confirmed via git history during the 2026-07-23 session and is
preserved here for reference only — **it is not authoritative and should not be
used to inform implementation.**

## What governs instead

1. `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` — creator-built,
   authoritative requirements (REQ-001 through REQ-049).
2. `docs/spec/SOUL_Design_Decisions.md` — creator-built design rationale (DD-01
   through DD-06).
3. `docs/spec/Implementation_Specification_Addendum.md` — co-developed with the
   project owner, resolving FINAL.md's REQ-045 open decisions (dice mechanics,
   XP cost formula, chargen B&B ratio, degrees of success, extraordinary luck
   threshold, aspect rounding, pending roll expiry).

The active `docs/architecture/`, `docs/reference/`, and `docs/development/`
directories have been rebuilt from these three sources.

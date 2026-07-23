# SOUL Event Flow

Description of major workflows and event sequences in SOUL, derived from `docs/spec/SOUL_LLM_Implementation_Specification_FINAL.md` ("FINAL") Appendix A (Canonical Workflows) and §5–§6 (Character Model, Mechanics), plus `docs/spec/Implementation_Specification_Addendum.md` ("Addendum") for resolved roll mechanics.

## Character Approval (FINAL Appendix A.1, REQ-011)

**Initiated by:** Player completes chargen; staff reviews via the normal AresMUSH approval workflow.

**Flow:**
1. Load configured Character Framework and terminology.
2. Player selects Resonance (if enabled).
3. Player allocates Skills within the Resonance-derived allowance and starting cap.
4. Player selects chargen-available Boons/Banes and provides required private explanations.
5. Validate limits, prerequisites, ratios, Resonance gates, unique tags, and required fields.
6. Player may correct without losing editable work.
7. Submission enters the normal AresMUSH approval workflow.
8. On staff approval: chargen-only state locks (Resonance, starting B&Bs); SOUL creates only the feature-specific starting Narrative History entries required (e.g. approved starting Resonance).

**Failure path:** Incomplete or rejected chargen returns editable state; it SHALL NOT create Narrative History or partially lock chargen-only state.

Unused Skill points are forfeited at approval — no banking.

## XP Award (FINAL Appendix A.2, REQ-013, REQ-014)

**Initiated by:** Weekly approved-character award, scene sharing, forum contribution, approved Inkling outcome, or manual staff award (`+xp/award`).

**Flow:**
1. Determine source and idempotency key (duplicate delivery of the same scene-share or weekly tick SHALL NOT double-award).
2. Apply catch-up multiplier only if the character is eligible (`xp_earned + catchup_xp_earned < median`) and the source isn't a manual grant (manual grants apply catch-up only via the explicit `+xp/award/catchup` variant).
3. Cap the catch-up bonus at the current median gap.
4. Atomically update `xp_available`, `xp_earned` (base award only), and `catchup_xp_earned` (bonus portion only).
5. Ledger/audit entry created; batch awards share a batch ID.
6. Player notified.

**Failure path:** A catch-up calculation failure falls back to the valid base award and creates an audit error — it never blocks the underlying award.

## XP Spend / Skill Advancement (FINAL Appendix A.3, REQ-015)

**Initiated by:** Player via advancement command or web interface.

**Flow:**
1. Validate target Skill and prerequisites.
2. Calculate cost using the Addendum §3 algebraic formula (`base_cost × development_modifier × resonance_modifier`).
3. Show cost to the player before commitment.
4. Atomically deduct `xp_available` and apply the rating increase.
5. Increment `xp_spent` (Lifetime Spent XP) regardless of source.
6. Create history/audit entry; notify player.

**Failure path:** Failed purchases change neither `xp_available` nor the target rating.

## Boon/Bane Transition (FINAL Appendix A.4, REQ-016 through REQ-022)

### Acquisition (Chargen)

Players MAY add/remove chargen B&Bs only while chargen is unfinished (REQ-019). Validated against per-Resonance-level chargen limits and the Boon-to-Bane ratio (Addendum §5).

### Acquisition (Post-Chargen)

**Flow:**
1. Validate definition, owner, level/state, source, permissions, limits, and required explanation.
2. Apply the transition (grant new entry, or progress/resolve/negate an existing one).
3. Create Narrative History and audit entries.
4. Notify the character (and staff, if applicable).

Post-chargen Boons are earned through RP and an approved workflow — XP SHALL NOT buy them. Banes are progressed or resolved through RP — XP SHALL NOT remove them. The same validation and transition services back chargen, Inklings, Jobs, staff commands, MUSH, and web — no duplicated rule paths.

### Deletion (Exceptional Only)

Actual deletion (as opposed to resolution/negation) follows FINAL Appendix A.10:
1. Warn and recommend a non-destructive alternative (resolve/negate instead).
2. Require two explicit confirmations.
3. Capture an audit snapshot.
4. Preserve a linked Narrative History correction when character-facing.
5. Require authorized staff and a documented reason.

## Culmination (FINAL Appendix A.5, REQ-023)

**Flow:**
1. Receive request or proposal (staff review, approved Inkling, standalone workflow, or another plugin's proposal — the plugin SHALL NOT create the Culmination directly).
2. Validate eligibility and check for duplicates.
3. Staff approve/modify/deny (unless automation is explicitly enabled for a given source).
4. Create or reject the record.
5. Create Narrative History and audit entries; notify the player.

Revocation and correction append a linked record rather than delete or overwrite the original.

## Narrative Correction (FINAL Appendix A.6, REQ-006)

**Flow:**
1. Authorize the actor and require a documented reason.
2. Capture the before-state.
3. Append a linked correction/reversal record.
4. Preserve the original entry (never overwritten or deleted).
5. Create audit entry; notify the affected player where appropriate.

## Standard Roll (FINAL Appendix A.7, REQ-028; dice mechanics per Addendum §2)

**Initiated by:** Player via `+roll <skill>`.

**Flow:**
1. Validate character, Skill, context, permissions, and the player's pending-roll limit (default `1` open, Addendum §6).
2. Identify candidate active B&Bs matching the Skill/context.
3. Store pending-roll state.
4. Present concise suggestions to the player, or state that none matched.
   - If no candidates exist, SOUL pauses the roll, tells the player no matching B&Bs were found, and offers the chance to manually identify applicable B&Bs before the roll resolves. The player MAY continue without modifiers.
5. Accept the player's response: specific tags, `+roll suggested` (accept all system-suggested optional entries), or `+roll none` (decline optional entries).
6. Revalidate ownership, state, context, duplicates, and modifier bounds.
7. Resolve via the shared roll service:
   ```
   effective_base = skill_rating + round_nearest(aspect_rating × aspect.weight)
   modifier = sum(accepted B&B modifiers)   # bounded globally so Skill remains meaningful
   effective_rating = effective_base + modifier
   ```
   Dice resolution follows the Addendum §2 2d20 open-ended model: roll 2d20, explode on double-20 (add another 2d20, repeat while doubled), implode on double-1 (subtract another 2d20, repeat while doubled), then apply Boon/Bane die rerolls to the entire explosion chain, then add `effective_rating` as the mechanical modifier (Addendum §2 Steps 1–3).
8. Compare final total to the difficulty target (Addendum §1) and determine the degree of success (Addendum §8.1, six degrees).
9. Calculate pre-roll success/failure probability; if the achieved outcome had probability ≤ 0.01%, mark the roll `extraordinary` (Addendum §9).
10. Display result and modifier sources to the player and observers.
11. Create roll audit/history; clear pending state.

## GM-Assisted Roll (FINAL Appendix A.8, REQ-029)

**Initiated by:** `+roll/gm <skill>` (when scene policy is Required or Optional), or automatic conversion when scene policy is Required.

Scene policy is configurable per scene: **Required** (converts every roll), **Optional** (`+roll/gm` available), or **Unavailable** (falls back to standard roll).

**Flow:**
1. Start roll or scene-policy conversion.
2. Validate the scene GM's authority and the configured reveal policy — the GM sees only fields their reveal configuration permits.
3. Store pending state.
4. GM marks candidate B&Bs as optional suggestions or mandatory selections. Mandatory selections survive `+roll none` — the player cannot decline them, though the player remains the one who completes the roll.
5. Player selects among optional entries (`+roll <tag>`, `+roll suggested`, or `+roll none`).
6. Resolve with all mandatory entries plus the player's chosen optional entries, using the same resolution math as a standard roll.
7. Output result and audit; clear pending state.

**Abort:** The player MAY abort until the GM submits selections (affected GM is notified). Authorized staff MAY force-abort a genuine error before or after GM input, with recorded actor/reason. Abort clears pending state and creates audit — it SHALL NOT produce a completed roll result.

## Optional Plugin Missing (FINAL Appendix A.9, REQ-007, REQ-038)

**Flow:**
1. Capability check fails (`defined?(AresMUSH::Soul)` on the consumer side, or SOUL's own check for Inklings/Grimoire).
2. Disable only the dependent path.
3. Expose the equivalent standalone staff workflow.
4. Log an actionable warning.
5. Core SOUL operation continues unaffected.

## Integration Points

### Inklings (FINAL REQ-039)

Inklings owns the request, narrative content, approval workflow, status, and complete Inkling audit/history. SOUL owns validation and application of SOUL state, via two hooks:

1. **Submission/Validation:** Inklings calls a SOUL validation hook with outcome type, target character, proposed transition/value, requester/source, and stable Inkling reference. SOUL returns a normalized, validated payload or actionable errors — without mutating state. The payload stays stored with the Inkling; SOUL does not create duplicate pending progression.
2. **Approval/Application:** After Inklings approves the request, it calls a SOUL application hook with the approved payload and source identifiers. SOUL revalidates current state and idempotency, atomically applies the transition, creates Narrative History/audit as required, and returns success/failure plus created SOUL references.

Every Inklings-triggered outcome has an equivalent manual staff path (REQ-039).

### Grimoire (FINAL REQ-040)

Grimoire owns its spell catalogue, branch definitions, learning/casting lifecycle, and all spell history. SOUL exposes Skills/Aspects/Resonance through documented read APIs and MAY map configured Grimoire branches to Spirit Skills. SOUL SHALL NOT copy spell data/history or reimplement Grimoire's rules. Missing Grimoire does not affect non-magical SOUL functionality.

## Related Documents

- `docs/architecture/API_and_Hooks.md` — Full API and hook reference
- `docs/architecture/Data_Model.md` — Data structures referenced by these flows
- `docs/architecture/Integration_Guide.md` — Detailed integration patterns
- `docs/spec/Implementation_Specification_Addendum.md` — Dice mechanics, XP formula, degrees of success, extraordinary luck

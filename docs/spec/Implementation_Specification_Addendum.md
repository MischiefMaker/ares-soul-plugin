# SOUL Implementation Specification Addendum

Resolutions for open decisions deferred in the main implementation specification (REQ-045 and associated open items). This document complements `SOUL_LLM_Implementation_Specification.md` with concrete decisions required before implementation.

---

## 1. Difficulty Scale

**Status:** Approved

**Decision:**
Rolls use a fixed difficulty scale anchored on cumulative die roll outcomes. Success is achieved when the final roll result (after all modifiers) meets or exceeds the target number.

| Difficulty | Target |
|------------|--------|
| Trivial    | 11     |
| Easy       | 12     |
| Standard   | 13     |
| Difficult  | 17     |
| Hard       | 21     |
| Extreme    | 25     |
| Legendary  | 34     |
| Mythic     | 40     |

**Rationale:**
- Difficulty values range from 11-40, providing meaningful differentiation across eight levels
- "Standard" at 13 represents a moderately challenging task for an average character
- Extreme and beyond require sustained bonuses or exceptional rolls, preventing power-creep inflation
- Scale is independent of die mechanism (chosen separately) but derives from natural roll outcomes

**Configuration:**
```yaml
rolls:
  difficulties:
    trivial: 11
    easy: 12
    standard: 13
    difficult: 17
    hard: 21
    extreme: 25
    legendary: 34
    mythic: 40
```

**Player Guidance:**
- A base pool of 4-5 (typical starting character) has ~50% success at Standard difficulty
- A pool of 8+ (advanced character) has ~80% success at Standard
- Legendary and Mythic are reserved for climactic, once-per-campaign moments

---

## 2. Random Distribution Model

**Status:** Pending Decision

**Question:**
What die mechanism generates the base roll result?

**Options Under Consideration:**

### Option A: d10 (Ares Native)
- **Mechanism:** Roll 1d10 per point in the pool (e.g., pool 5 = 5d10), sum results
- **Range:** 5-50 for pool 5; scales linearly
- **Advantage:** Matches FS3's native mechanic; intuitive for Ares-familiar players
- **Disadvantage:** Large pools produce predictable outcomes; bell curve peaks at mid-range

### Option B: d20 Pool with Threshold
- **Mechanism:** Roll 1d20 per point in pool; count successes (results ≥ 11 = success)
- **Range:** 0-pool successes; more granular control
- **Advantage:** Bounded outcomes prevent unbounded high rolls; threshold model feels like genuine "difficulty"
- **Disadvantage:** Different conceptual model than FS3; requires relearning

### Option C: Single d20 + Pool Modifier
- **Mechanism:** Roll 1d20 once, add pool as flat bonus (d20 + pool)
- **Range:** 1-20 base, up to 1+pool+modifiers effective
- **Advantage:** Fast, simple; minimizes variance
- **Disadvantage:** Pool has less impact; diminishing returns at high ratings

**Recommendation:**
*Awaiting project-owner decision.* Implementation will proceed with **d10 pool model (Option A)** as default, with configuration abstraction to permit substitution.

**Provisional Configuration:**
```yaml
rolls:
  random_model: "d10_pool"  # alternatives: d20_pool, d20_single
```

---

## 3. XP Advancement Cost Table

**Status:** Pending Decision

**Question:**
What is the XP cost to advance each skill rating?

**Specification Requirement (REQ-014):**
"Advancement cost per rating SHALL be configurable and documented. Default advancement costs SHALL be balanced such that a typical character gains 1-2 skill advancements per month of active play."

**Options Under Consideration:**

### Option A: Linear Scaling
```yaml
advancement_cost: [10, 10, 10, 10, 10]
# Cost to advance 0→1, 1→2, 2→3, 3→4, 4→5: all 10 XP
```
- **Rationale:** Simplicity; each rating equally valued
- **Impact:** Flat progression; experienced characters advance at same rate as beginners
- **Monthly Rate:** With ~20 XP/month baseline, ~2 advancements/month (meets spec)

### Option B: Ascending Escalation
```yaml
advancement_cost: [10, 15, 20, 25, 30]
# Cost to advance 0→1=10, 1→2=15, 2→3=20, 3→4=25, 4→5=30
```
- **Rationale:** Higher ratings require greater investment; reinforces specialization
- **Impact:** Early progression fast, late progression slow; spreads advancement over longer timeframe
- **Monthly Rate:** ~1-2 advancements/month depending on player choice (meets spec)

### Option C: Exponential Acceleration
```yaml
advancement_cost: [5, 10, 20, 40, 80]
# Cost to advance: 5 → 10 → 20 → 40 → 80
```
- **Rationale:** High ratings become rare and prestigious; encourages broad vs. deep specialization
- **Impact:** Steep endgame cost; only dedicated players reach high ratings
- **Monthly Rate:** 2-3 early advancements, <1 late-game (may exceed spec unless XP scales with seniority)

**Recommendation:**
*Awaiting project-owner decision.* Implementation will use **Option B (Ascending Escalation)** as default, balancing accessibility early-game with meaningful late-game investment.

**Provisional Configuration:**
```yaml
xp:
  advancement_cost: [10, 15, 20, 25, 30]
```

**Catch-Up XP Interaction:**
Characters earning catch-up XP spend with the same cost table; catch-up only accelerates earning, not spending.

---

## 4. Global Modifier Bounds

**Status:** Pending Decision

**Question:**
What are the minimum and maximum modifiers that can be applied to a roll?

**Specification Requirement (REQ-030):**
"Modifiers SHALL have global bounds to prevent unbounded scaling and maintain meaningful skill differentiation."

**Modifier Sources (Cumulative):**
- Skill rating: +0 to +5 (rating-to-bonus)
- Aspect contribution: +0 to +1 (from Aspect × 0.20, rounded)
- Boon/Bane effects: TBD per B&B instance
- Scene policy: TBD (optional GM override)
- Resonance spend (future): TBD

**Options Under Consideration:**

### Option A: Tight Bounds (±5)
```yaml
rolls:
  modifier_min: -5
  modifier_max: +5
```
- **Effect:** Typical pool of 4 + skill 3 + aspect 1 = 8 base; bounds cap effective pool
- **Design:** Modifiers matter but don't overshadow pool; caps runaway B&B stacking
- **Concern:** B&B design becomes constrained; difficult to award "powerful" bonuses

### Option B: Moderate Bounds (±10)
```yaml
rolls:
  modifier_min: -10
  modifier_max: +10
```
- **Effect:** Allows meaningful B&B effects (+3 is substantial but not overwhelming)
- **Design:** A character with pool 5, skill 3, aspect 1, and two +2 Boons = 8 + 4 = 12 effective
- **Balance:** At Difficult (17), this shifts 50% → 25% success; meaningful but not dominant

### Option C: Permissive Bounds (±15)
```yaml
rolls:
  modifier_min: -15
  modifier_max: +15
```
- **Effect:** Allows powerful B&B effects (+5 is achievable)
- **Design:** Supports magical/enhancement-heavy systems; rewards long-term B&B accumulation
- **Concern:** High-end characters may become too powerful; Difficulty scaling must adjust

**Recommendation:**
*Awaiting project-owner decision.* Implementation will use **Option B (±10)** as default, balancing B&B impact against skill differentiation and difficulty scaling.

**Provisional Configuration:**
```yaml
rolls:
  modifier_min: -10
  modifier_max: +10
```

**B&B Effect Constraints:**
Individual B&B effects SHALL NOT exceed ±5. If a B&B grants +3, and a character has two instances, the second instance is NOT stacked (as per REQ-022's "no duplicates" default). Staff may override this rule per-character via admin approval.

---

## 5. Boon & Bane Chargen Limits

**Status:** Pending Decision

**Question:**
How many unspent Skill advancement points remain after chargen approval, and what happens to Boons/Banes awarded during chargen?

**Specification Requirement (REQ-011):**
"Unspent Skill points SHALL be forfeited when chargen is approved."

**Clarifications Needed:**

### 5.1 Skill Advancement Point Forfeiture
**Current Spec Language:** "Unspent Skill points SHALL be forfeited when chargen is approved" (REQ-011, Invariant).

**Interpretation:**
- During chargen, characters may distribute a fixed pool of "chargen points" across Skills (e.g., 10 points total)
- Any points not spent before approval are lost permanently
- Characters must spend all points or lose them; no banking for later advancement

**Configuration:**
```yaml
chargen:
  skill_points_total: 10
  skill_points_max_per_skill: 5
  forfeiture_on_approval: true  # Invariant: non-negotiable per spec
```

**Rationale:**
- Prevents characters from starting with unbalanced advantages
- Encourages deliberate chargen choices
- XP-earned advancement remains the post-chargen progression path

### 5.2 Boons & Banes Awarded During Chargen

**Question:** Can characters be granted Boons/Banes during chargen? If so, how many, and do they persist post-approval?

**Options Under Consideration:**

### Option A: Boons/Banes Pre-Allocated by Setting
- **Rule:** Characters receive 0-2 Boons/Banes as part of chargen based on archetype or player narrative
- **Persistence:** All chargen B&Bs persist post-approval; no forfeiture
- **Configuration:**
  ```yaml
  chargen:
    boons_per_character: 1
    banes_per_character: 1
  ```
- **Rationale:** B&Bs are narrative-driven; tying them to chargen anchors characters in their origin story
- **Concern:** Unequal if some characters choose zero B&Bs while others maximize

### Option B: No Chargen B&Bs
- **Rule:** Characters start with no Boons/Banes; all B&Bs are earned post-chargen via Inklings, GM awards, or scene events
- **Persistence:** N/A
- **Rationale:** Clean slate; B&Bs reflect earned achievements
- **Concern:** Characters feel less defined at start of play

### Option C: Optional Chargen B&Bs (Traded for XP)
- **Rule:** Characters may allocate chargen points toward Boons/Banes, forfeiting Skill points for B&B purchasing power
- **Configuration:**
  ```yaml
  chargen:
    skill_points_total: 10
    boon_point_cost: 3    # 1 Boon costs 3 points
    bane_point_cost: 2    # 1 Bane costs 2 points (counts toward max)
    max_boons_chargen: 2
    max_banes_chargen: 2
  ```
- **Rationale:** Trade-off system rewards deliberate choice; players weigh narrative flavor against mechanical power
- **Concern:** Complex UI in chargen; may confuse new players

**Recommendation:**
*Awaiting project-owner decision.* Implementation will use **Option A (Pre-Allocated)** as default, granting each character 1 Boon and 1 Bane based on archetype, with persistence post-approval.

**Provisional Configuration:**
```yaml
chargen:
  skill_points_total: 10
  skill_points_max_per_skill: 5
  forfeiture_on_approval: true
  
  boons_per_character: 1
  banes_per_character: 1
  persist_post_chargen: true
```

---

## 6. Pending Roll Expiry Mechanics

**Status:** Pending Decision

**Question (from Review):**
What is the canonical duration, trigger (wall-clock vs. scene-end), and notification behavior for expired pending rolls?

**Specification Reference:** REQ-027, REQ-044

**Options Under Consideration:**

### Option A: Wall-Clock Duration (Silent Expiry)
```yaml
rolls:
  pending_roll_timeout_hours: 24
  expiry_notification: false
  auto_failure_on_expiry: false  # Roll remains pending indefinitely; marked as "stale"
```
- **Mechanism:** Pending rolls older than 24 hours are marked expired; GM can no longer approve/reject
- **Player Experience:** Player receives no notification; must check `+pending` to see status
- **Admin Burden:** Staff must periodically clean expired rolls

### Option B: Scene-End Trigger (Player Notification)
```yaml
rolls:
  pending_roll_trigger: "scene_end"
  expiry_notification: true
  auto_failure_on_expiry: false
```
- **Mechanism:** When the scene ends, all pending rolls from that scene auto-expire
- **Player Experience:** Player receives notification: "Your pending roll in [Scene] has expired and is no longer valid"
- **Admin Burden:** Low; automatic cleanup tied to scene lifecycle
- **Concern:** Doesn't handle rolls from non-scene contexts (admin, OOC tests)

### Option C: Grace-Period with Auto-Resolve (Configurable)
```yaml
rolls:
  pending_roll_timeout_hours: 24
  grace_period_hours: 2     # 2-hour grace before expiry
  expiry_notification: true
  auto_failure_on_expiry: true  # Automatic failure if not resolved within grace period
```
- **Mechanism:** Pending roll waits for GM for 24 hours; at 22 hours, player receives warning; at 24 hours, auto-fails
- **Player Experience:** Player is notified at 22 hours; can reach out to staff or accept auto-failure
- **Admin Burden:** Staff can still manually intervene; auto-resolve prevents stalls
- **Concern:** Auto-failure is harsh; may require alternative (e.g., auto-approval)

**Recommendation:**
*Awaiting project-owner decision.* Implementation will use **Option C (Grace-Period with Auto-Resolve)** as default, balancing player agency with stall prevention.

**Provisional Configuration:**
```yaml
rolls:
  pending_roll_timeout_hours: 24
  grace_period_hours: 2
  expiry_notification: true
  auto_failure_on_expiry: true
  expiry_message: "Your pending roll has expired. It has been marked as failed. Contact staff if you believe this is in error."
```

---

## 7. Aspect Contribution Rounding

**Status:** Pending Decision

**Question (from Review):**
How are fractional Aspect contributions rounded?

**Specification Reference:** REQ-009

**Current Formula:** Aspect Contribution = Aspect Rating × 0.20

**Examples:**
- Aspect 1 → 1 × 0.20 = 0.20 → rounds to ?
- Aspect 3 → 3 × 0.20 = 0.60 → rounds to ?
- Aspect 5 → 5 × 0.20 = 1.00 → rounds to 1 (exact)

**Options Under Consideration:**

### Option A: Floor (Round Down)
```
Aspect 1 = 0.20 → 0
Aspect 3 = 0.60 → 0
Aspect 5 = 1.00 → 1
```
- **Effect:** Only Aspect 5 provides a bonus; lower aspects provide no contribution
- **Rationale:** Simplicity; clear thresholds
- **Concern:** Aspect 1-4 feel useless; discourages diverse aspect investment

### Option B: Ceiling (Round Up)
```
Aspect 1 = 0.20 → 1
Aspect 3 = 0.60 → 1
Aspect 5 = 1.00 → 1
```
- **Effect:** All aspects provide +1 contribution; no differentiation
- **Rationale:** Encourages broad aspect investment
- **Concern:** Removes scaling incentive; aspect rating becomes binary (you have it / you don't)

### Option C: Round Half-Up
```
Aspect 1 = 0.20 → 0
Aspect 3 = 0.60 → 1
Aspect 5 = 1.00 → 1
```
- **Effect:** Aspect 3+ provides +1; Aspect 1-2 provides 0
- **Rationale:** Balanced scaling; encourages Aspect 3+ investment
- **Concern:** Still binary at key threshold (Aspect 2 vs. 3)

### Option D: Banked Accumulation (No Rounding)
```
Track fractional contribution; only apply as integer when added to roll
Aspect 1 (0.20) + Aspect 2 (0.40) = 0.60 → 1 on roll
```
- **Effect:** Fractional bonuses accumulate across multiple aspects
- **Rationale:** Rewards diverse aspect investment; most nuanced
- **Concern:** Complex to communicate to players; harder to track

**Recommendation:**
*Awaiting project-owner decision.* Implementation will use **Option C (Round Half-Up)** as default, with configuration to switch mechanisms.

**Provisional Configuration:**
```yaml
aspects:
  contribution_formula: "aspect_rating * 0.20"
  contribution_rounding: "half_up"  # alternatives: floor, ceiling, banker's
```

---

## 8. Catch-Up XP Edge Cases

**Status:** Pending Decision

**Question (from Review):**
How are edge cases in catch-up XP calculation handled?

**Specification Reference:** REQ-014, REQ-015

**Scenario 1: New Character Grace Period**
- A new character joins mid-game when the group median `xp_earned` is 100
- Should the new character be included in the median calculation immediately?
- If included, they fall far behind and auto-trigger catch-up
- If excluded, they progress at normal rate until they're "caught up"

**Options:**
- **Included Immediately:** Catch-up XP applies to new characters from day 1 (generous)
- **Grace Period (7 days):** New characters are excluded from median calculation for 7 days (moderate)
- **Manual Approval:** Admins mark when a character "enters the group" and begins earning catch-up (control)

### Scenario 2: Small Community (< 3 Characters)
- Median is undefined with fewer than 3 characters
- Should catch-up apply, or does it require a minimum cohort?

**Options:**
- **Always Apply:** Assume a baseline median (e.g., 50 XP) if < 3 characters (generous)
- **Minimum Cohort:** Catch-up only applies if ≥3 approved characters exist (strict)
- **Average Instead:** Use average `xp_earned` instead of median (pragmatic)

### Scenario 3: Tied Median
- With even number of characters, median is (middle1 + middle2) / 2
- Does tie-breaking favor the character (round down threshold) or not?

**Options:**
- **Round Down:** Threshold benefit goes to lower value (character-favorable)
- **Round Up:** Threshold benefit goes to higher value (staff-favorable)

**Recommendation:**
*Awaiting project-owner decision.* Implementation will use:
- **Grace Period (7 days)** for new characters
- **Minimum Cohort of 3**; if < 3, catch-up disabled
- **Round Down** for tied median (character-favorable)

**Provisional Configuration:**
```yaml
xp:
  catchup:
    grace_period_days: 7
    minimum_cohort_size: 3
    median_tiebreak: "round_down"
    baseline_median_if_insufficient: null  # null = disable catch-up if < cohort
```

---

## Summary Table

| Decision | Status | Default Value |
|----------|--------|----------------|
| Difficulty Scale | ✅ Approved | See Table in §1 |
| Random Model | ⏳ Pending | d10 pool (provisional) |
| XP Advancement Cost | ⏳ Pending | [10, 15, 20, 25, 30] (provisional) |
| Modifier Bounds | ⏳ Pending | ±10 (provisional) |
| Chargen B&Bs | ⏳ Pending | 1 Boon + 1 Bane (provisional) |
| Pending Roll Expiry | ⏳ Pending | 24h auto-fail (provisional) |
| Aspect Rounding | ⏳ Pending | Round Half-Up (provisional) |
| Catch-Up Edge Cases | ⏳ Pending | 7d grace, 3-char minimum (provisional) |

---

## Next Steps

1. **Project Owner Review:** Present provisional defaults to project owner for approval
2. **Implementation Blocking:** Until decisions are locked, implementation defers on:
   - Service-layer unit tests (need XP costs, modifier bounds, rounding rules)
   - Web portal UI (need random model to design success feedback)
   - Admin commands (need chargen B&B limits to design allocation interface)
3. **Update CLAUDE_ADR.md:** Record each decision with rationale when approved
4. **Lock Decisions:** Once approved, archive this addendum and reference it in main spec

---

**Last Updated:** 2026-07-22

**Awaiting Approval From:** Project Owner (MischiefMaker)

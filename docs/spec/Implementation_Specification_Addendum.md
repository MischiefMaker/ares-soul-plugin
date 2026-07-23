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

**Status:** ✅ Approved

**Decision:**
Rolls use a base 2d10 mechanic with open-ended explosions on doubles. The outcome is the sum of all rolled dice (including rerolls from explosions).

**Base Mechanic:**

1. **Initial Roll:** Roll 2d10, sum the result (range: 2-20)

2. **Explosion on Double 10:** 
   - If both dice show 10 (double 10):
     - Roll another 2d10
     - Add `(reroll_sum - 2)` to the total (where reroll_sum is 2-20)
     - Continue rerolling if the new reroll is also a double 10
   - Example: Roll 2d10 → [10, 10] (sum 20) → reroll [9, 8] (sum 17) → add (17 - 2) = 15 → total 35

3. **Implosion on Double 1:**
   - If both dice show 1 (double 1):
     - Roll another 2d10
     - Subtract `(reroll_sum - 2)` from the total
     - Continue rerolling if the new reroll is also a double 1
   - Example: Roll 2d10 → [1, 1] (sum 2) → reroll [4, 5] (sum 9) → subtract (9 - 2) = 7 → total 2 - 7 = -5

4. **Final Result:** Sum of all rolls (initial + all explosions/implosions, clamped to minimum of -20 if needed)

**Rationale:**
- 2d10 base provides intuitive central tendency (expected value ~11, matching "Standard" difficulty)
- Open-ended explosions reward exceptional luck without hard caps
- Symmetry between double-10 (good luck) and double-1 (bad luck)
- Explosion bonus/penalty of `(reroll_sum - 2)` creates meaningful differentiation (explosions can add 0-18 per reroll)
- Repeating explosions allow for truly extraordinary outcomes (rare but memorable)

**Configuration:**
```yaml
rolls:
  random_model: "d10_open_ended"
  explosion:
    enabled: true
    trigger: "double_10"
    bonus_formula: "reroll_sum - 2"  # reroll_sum = sum of the 2d10 reroll
    
  implosion:
    enabled: true
    trigger: "double_1"
    penalty_formula: "reroll_sum - 2"
    
  # Customization options
  explosion_bonus_min: 0    # Minimum bonus per explosion
  explosion_bonus_max: 18   # Maximum bonus per explosion (2d10 = 2-20, minus 2 = 0-18)
  implosion_penalty_min: 0
  implosion_penalty_max: 18
```

**Examples:**

| Roll | Result | Notes |
|------|--------|-------|
| [5, 7] | 12 | Normal roll, no explosion/implosion |
| [10, 10] then [8, 6] | 20 + (14-2) = 32 | Explosion on double 10; reroll added |
| [10, 10] then [10, 10] then [6, 4] | 20 + (20-2) + (10-2) = 46 | Chained explosions |
| [1, 1] then [7, 3] | 2 - (10-2) = -6 | Implosion on double 1; reroll subtracted |
| [1, 1] then [1, 1] then [5, 5] | 2 - (2-2) - (10-2) = -8 | Chained implosions |

**Design Rationale for 2d10:**
- **Smooth, understandable bell curve:** 2d10 produces a natural distribution centered on 11, familiar to players and intuitive to explain
- **Skill matters:** Every skill point shifts the entire probability curve; no threshold effects or dead values
- **Distinct difficulties:** Eight discrete difficulty targets (11-40) provide clear separation; no confusion about target ranges
- **Rare tails without caps:** Open-ended explosions create statistically rare but unbounded high rolls; open-ended implosions create rare negative rolls; both feel exceptional without artificial ceilings
- **Narrative degrees:** Tails produce meaningful story outcomes even when pass/fail doesn't change (e.g., exceptional success vs. success both win, but with different narrative weight)

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

**Status:** ✅ Approved

**Decision:**
Characters can acquire Boons and Banes during chargen based on their Resonance level (R-level). A universal 2:1 ratio constrains Boons (never more than 2 Boons per Bane), while Banes have no count limit. Both are constrained by available level ratings at chargen.

### 5.1 Universal Boon-to-Bane Ratio

**Rule:** For every 2 Boons a character has, they must have at least 1 Bane.

```
min_banes_required = floor(boon_count / 2)
```

**Examples:**
- 0–1 Boon → 0 Banes required
- 2 Boons → 1 Bane required
- 3 Boons → 1 Bane required (3/2 = 1.5 → 1)
- 4 Boons → 2 Banes required
- 5 Boons → 2 Banes required

**Intent:** This ratio applies continuously (in chargen and post-chargen). It prevents runaway Boon accumulation and encourages narrative balance. Players can always take *fewer* Banes than required, but cannot exceed the Boon count imposed by this ratio.

### 5.2 Boon Chargen Limits (by Resonance Level)

**General Pattern:**
- Each Resonance level adds capacity (at negative R-levels, capacity decreases)
- Level distributions show *maximum* allowed at each level; players may choose lower levels
- Level 3 is the chargen maximum for Boons

| R-Level | Max Count | Max at Level 2 | Max at Level 3 |
|---------|-----------|----------------|----------------|
| R-3 | 0 | 0 | — |
| R-2 | 0 | 0 | — |
| R-1 | 1 | 0 | — |
| R0 | 2 | 1 | — |
| R1 | 3 | 2 | — |
| R2 | 3 | 3 | 1 |
| R3 | 4 | 3 | 2 |

**Interpretation Examples:**
- **R0, 2 Boons:** Could be [2, 1], [1, 1] (up to 1 can be level 2; rest are level 1)
- **R1, 3 Boons:** Could be [2, 2, 1] or [2, 1, 1] or [1, 1, 1] (up to 2 can be level 2; rest are level 1)
- **R2, 3 Boons:** Could be [3, 2, 1] or [2, 2, 2] or [1, 1, 1] (up to 3 at level 2 or 1 at level 3; rest lower)
- **R3, 4 Boons:** Could be [3, 3, 2, 1] or [3, 2, 2, 1] (up to 2 at level 3; rest level 2 or below)

### 5.3 Bane Chargen Limits (by Resonance Level)

**General Pattern:**
- Banes have *no count limit* (unlimited)
- Only the maximum level rating is constrained by R-level
- Players may take any number of Banes, subject only to the Boon-to-Bane ratio

| R-Level | Max Count | Max at Level 2 | Max at Level 3 |
|---------|-----------|----------------|----------------|
| R-3 | Unlimited | 3 | 3 |
| R-2 | Unlimited | 2 | 2 |
| R-1 | Unlimited | 2 | 1 |
| R0 | Unlimited | 1 | 0 |
| R1 | Unlimited | 2 | 1 |
| R2 | Unlimited | 3 | 2 |
| R3 | Unlimited | 3 | 3 |

**Interpretation Examples:**
- **R0, 1 Bane:** Can be level 1 or 2 (level 3 not available)
- **R0, 3 Banes:** Could be [2, 1, 1] (only 1 can be level 2 since level 3 unavailable)
- **R1, 5 Banes:** Could be [3, 2, 2, 1, 1] or [3, 3, 2, 1, 1] (up to 1 can be level 3, up to 2 level 2)
- **R3, unlimited Banes:** Can include [3, 3, 3, 3, 2, 2, 1] (up to 3 at level 3)

**Persistence:** All chargen B&Bs persist post-approval and cannot be forfeited or removed.

**Configuration:**

```yaml
chargen:
  boon_bane_ratio: 2
  ratio_rounding: "floor"
  
  resonance_levels:
    r_minus_3:
      boons:
        max_count: 0
        max_at_level_2: 0
        max_at_level_3: 0
      banes:
        max_count: null          # Unlimited
        max_at_level_2: 3
        max_at_level_3: 3
    
    r_minus_2:
      boons:
        max_count: 0
        max_at_level_2: 0
        max_at_level_3: 0
      banes:
        max_count: null          # Unlimited
        max_at_level_2: 2
        max_at_level_3: 2
    
    r_minus_1:
      boons:
        max_count: 1
        max_at_level_2: 0
        max_at_level_3: 0
      banes:
        max_count: null          # Unlimited
        max_at_level_2: 2
        max_at_level_3: 1
    
    r_0:
      boons:
        max_count: 2
        max_at_level_2: 1
        max_at_level_3: 0
      banes:
        max_count: null          # Unlimited
        max_at_level_2: 1
        max_at_level_3: 0
    
    r_1:
      boons:
        max_count: 3
        max_at_level_2: 2
        max_at_level_3: 0
      banes:
        max_count: null          # Unlimited
        max_at_level_2: 2
        max_at_level_3: 1
    
    r_2:
      boons:
        max_count: 3
        max_at_level_2: 3
        max_at_level_3: 1
      banes:
        max_count: null          # Unlimited
        max_at_level_2: 3
        max_at_level_3: 2
    
    r_3:
      boons:
        max_count: 4
        max_at_level_2: 3
        max_at_level_3: 2
      banes:
        max_count: null          # Unlimited
        max_at_level_2: 3
        max_at_level_3: 3
```

**Design Rationale:**

1. **Flexible Boon cap:** R-level determines maximum Boons, but 2:1 ratio creates meaningful Bane investment decisions
2. **Progressive level unlock:** R-1 to R1 keep Boons at level 2; R2+ unlock level 3, allowing powerful boons
3. **Bane freedom:** No count limit encourages narrative depth and character complexity
4. **Player agency:** Level distributions are maximums; players choose their distribution within constraints
5. **Continuous enforcement:** The 2:1 ratio applies throughout the character's life, not just chargen

**Examples:**

**Example 1: R0 Character**
- Max 2 Boons (up to 1 at level 2), subject to 2:1 ratio (needs 1 Bane)
- Unlimited Banes (no level 3 available at R0)
- Could allocate: [Lucky (L2), Connected (L1)] + [Cursed (L2)]

**Example 2: R3 Character (Post-Chargen)**
- Max 4 Boons (up to 3 at level 2 OR 2 at level 3), subject to 2:1 ratio (needs 2 Banes)
- Unlimited Banes (up to 3 at level 3)
- Could allocate: [Inspired (L3), Resilient (L3), Sharp-Witted (L2), Skilled (L1)] + [Fragile (L3), Distracted (L3), Isolated (L2)]

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

**Status:** ✅ Approved

**Decision:**
Fractional Aspect contributions are rounded to the nearest integer using standard rounding rules (0.5 and above rounds up, below 0.5 rounds down).

**Formula:**
```
Aspect Contribution = round_nearest(Aspect Rating × 0.20)
```

**Examples:**
```
Aspect 1 = 1 × 0.20 = 0.20 → 0
Aspect 2 = 2 × 0.20 = 0.40 → 0
Aspect 3 = 3 × 0.20 = 0.60 → 1
Aspect 4 = 4 × 0.20 = 0.80 → 1
Aspect 5 = 5 × 0.20 = 1.00 → 1
```

**Rationale:**
- **Standard behavior:** Round nearest follows familiar mathematical convention; intuitive for players
- **Balanced scaling:** Aspects 1-2 provide no contribution, Aspect 3+ provide +1, creating a natural threshold without being punitive
- **Simplicity:** Easy to compute and explain without special-case handling

**Configuration:**
```yaml
aspects:
  contribution_formula: "aspect_rating * 0.20"
  contribution_rounding: "nearest"  # Standard mathematical rounding
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

## 8.1 Degrees of Success

**Status:** Approved

**Decision:**
Roll outcomes are categorized into six degrees reflecting both pass/fail status and margin of success/failure. These degrees determine narrative scope and player/GM authority.

**The Six Degrees:**

| Result | Description |
|--------|-------------|
| **Exceptional Success** | Succeed with a large margin; introduce additional benefit |
| **Success** | Succeed with a normal margin; achieve goal |
| **Complicated Success** | Succeed with a small margin; achieve goal but with cost/complication |
| **Lucky Failure** | Fail with a small margin; miss goal but introduce benefit/opportunity |
| **Failure** | Fail with a normal margin; miss goal |
| **Catastrophic Failure** | Fail with a large margin; miss goal and introduce complication |

**Trigger Calculation:**

Degrees are determined by comparing final roll result to difficulty target:

```
margin = final_roll - difficulty_target

Exceptional Success:   margin >= +10
Success:              margin >= +0 and margin < +10
Complicated Success:  margin >= -5 and margin < +0
Lucky Failure:        margin >= -10 and margin < -5
Failure:              margin < -10
Catastrophic Failure: (same as Failure, but distinguished by narrative weight)
```

*Note: Exact margin thresholds are pending configuration finalization.*

**Output Format - GM-Less (Player Authority):**

Player receives a prompt calibrated to the narrative weight of the outcome:

| Result | Player Output |
|--------|---------------|
| **Exceptional Success** | **You succeed, and may introduce an additional benefit resulting from your success.** |
| **Success** | **You succeed.** |
| **Complicated Success** | **You succeed, but should introduce an additional complication resulting from your success.** |
| **Lucky Failure** | **You fail, but may introduce an additional benefit despite your failure.** |
| **Failure** | **You fail.** |
| **Catastrophic Failure** | **You fail, and should introduce an additional complication resulting from your failure.** |

**Rationale:**
- **"May"** (Exceptional Success, Lucky Failure): Optional flourish—pure player choice. Extra benefit is narrative dessert, not obligation.
- **"Should"** (Complicated Success, Catastrophic Failure): Encouraged narrative element. Complications are earned consequences of the roll; players are expected to articulate them.
- **"And"** (Exceptional/Catastrophic): Forward momentum—success/failure propels the story forward with added weight.
- **"But"** (Complicated/Lucky): Tension—primary outcome contradicted or complicated by secondary element.
- **Plain statement** (Success/Failure): Straightforward outcomes require no embellishment; player may continue describing action or RP.

**Output Format - GM-Led (GM Discretion):**

GM receives passive reporting of mechanical outcome; GM decides how to narrate/resolve:

```
Exceptional Success
Success with an additional benefit.

Success
Success.

Complicated Success
Success with an additional complication.

Lucky Failure
Failure with an additional benefit.

Failure
Failure.

Catastrophic Failure
Failure with an additional complication.
```

**GM Options:** The GM may then:
- Narrate the consequence directly
- Ask the player for their narration
- Collaborate on the outcome
- Adjust or ignore the suggested degree if dramatically appropriate

**Rationale:** Passive voice reports what happened mechanically without prescribing authority or narrative direction, preserving GM discretion in story-focused systems.

**Configuration:**

```yaml
rolls:
  degrees_of_success: true
  margin_thresholds:
    exceptional_success_min: 10
    complicated_success_max: -0.01  # Just below zero
    lucky_failure_max: -5
    catastrophic_failure_min: -10
  
  output_mode: "gm_led"  # alternatives: "gm_less", "hybrid"
```

---

## 9. Extraordinary Luck Messaging

**Status:** Approved

**Decision:**
Roll result messages indicating "extraordinary luck" (both good and bad) shall be triggered based on the pre-calculated success probability, not on dice mechanics (e.g., not on doubles or critical rolls).

**Trigger Rule:**

Before rolling, calculate the final success probability using:
- Skill rating
- Difficulty target
- All Boons and Banes (with mechanical effects)
- Situational modifiers
- Full open-ended dice distribution

After rolling, compare the outcome to the pre-calculated probability:

```
If success_probability < 0.5% AND roll succeeds:
    Display: "In an extraordinary string of good luck, [Character] succeeds."

If failure_probability < 0.5% AND roll fails:
    Display: "In an extraordinary string of bad luck, [Character] fails."
```

**Examples:**

| Scenario | Success Prob | Outcome | Message |
|----------|--------------|---------|---------|
| Character with 1% success chance | 1% | Succeeds | "In an extraordinary string of good luck, Sarah succeeds." |
| Character with 98% success chance | 98% | Fails | "In an extraordinary string of bad luck, Gandalf fails." |
| Character with 50% success chance | 50% | Succeeds | (Standard success message, no extraordinary tag) |

**Rationale:**
- Extraordinary messaging rewards/acknowledges statistically unlikely outcomes
- Probability-based triggering reflects the actual rarity of the outcome, not arbitrary dice patterns
- Threshold (< 0.5%) ensures messages are reserved for genuinely improbable events
- Applies equally to good and bad luck, maintaining narrative symmetry

**Implementation Notes:**
- Calculate probability *before* rolling (not retroactively after observing the outcome)
- Use the same random distribution and modifier application as the actual roll
- Store calculated probability alongside roll record for audit/transparency
- Message format and personalization are configurable; above are templates

**Configuration:**
```yaml
rolls:
  extraordinary_result_threshold: 0.005    # Probability threshold (0.5%)
  extraordinary_result_good: "In a shocking display of good luck"
  extraordinary_result_bad: "In a fit of bad luck"
```

**Message Format:**
The configured prefix is used with the outcome appended:
- Good luck: `"{prefix}, {character} succeeds."`
- Bad luck: `"{prefix}, {character} fails."`

**Examples with above config:**
- Good outcome: "In a shocking display of good luck, Sarah succeeds."
- Bad outcome: "In a fit of bad luck, Gandalf fails."

---

## Summary Table

| Decision | Status | Default Value |
|----------|--------|----------------|
| Difficulty Scale | ✅ Approved | See Table in §1 |
| Random Model | ✅ Approved | 2d10 open-ended (§2) |
| XP Advancement Cost | ✅ Approved | Algebraic model (§3) |
| Chargen B&Bs | ✅ Approved | 2:1 Boon-to-Bane ratio, per-R-level config (§5) |
| Aspect Rounding | ✅ Approved | Round Nearest (§7) |
| Degrees of Success | ✅ Approved | Six degrees with GM-less/GM-led output (§8.1) |
| Extraordinary Luck Messaging | ✅ Approved | Probability-based (<0.5%) (§9) |
| Modifier Bounds | ⏳ Pending | ±10 (provisional) |
| Pending Roll Expiry | ⏳ Pending | 24h auto-fail (provisional) |
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

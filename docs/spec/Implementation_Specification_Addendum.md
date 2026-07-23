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
Rolls use an open-ended 2d20 mechanic with explosion/implosion chains and Boon/Bane-driven die rerolls. Boons and Banes influence luck (die outcomes) rather than applying flat bonuses, ensuring no automatic success and no character power ceiling.

**Rolling Sequence:**

### Step 1: Explosion Chain (Determine all dice before any rerolls)

1. **Initial Roll:** Roll 2d20, sum the result (range: 2-40)

2. **Upward Explosion on Double 20:**
   - If both dice show 20 (double 20):
     - Roll another 2d20
     - Add this new result to the total
     - Check if the new roll is also a double 20; if so, repeat
   - Explosions chain indefinitely (rare but unbounded)
   - Example: [20, 20] (40) + [18, 17] (35) + [20, 20] (40) + [14, 9] (23) = 138

3. **Downward Implosion on Double 1:**
   - If both dice show 1 (double 1):
     - Roll another 2d20
     - Subtract this new result from the total
     - Check if the new roll is also a double 1; if so, repeat
   - Implosions chain indefinitely (rare but unbounded)
   - Example: [1, 1] (2) - [8, 7] (15) - [1, 1] (2) - [16, 11] (27) = -42

4. **No Partial Explosions:** Explosions are only triggered by the original natural dice rolls, never by rerolled dice (Step 2). Once the complete explosion chain is determined, no more dice rolls occur until Step 2.

### Step 2: Boon/Bane Die Rerolls (Modify luck, not the explosion chain)

Calculate the net Boon/Bane modifier (sum of all Boon and Bane effects):

**Positive Modifier (Boons, +1 to +N):**
- **+1:** Reroll every die showing 1
- **+2:** Reroll every die showing 1–2
- **+3:** Reroll every die showing 1–3
- **+N:** Reroll every die showing 1–N

**Negative Modifier (Banes, −1 to −N):**
- **−1:** Reroll every die showing 20
- **−2:** Reroll every die showing 19–20
- **−3:** Reroll every die showing 18–20
- **−N:** Reroll every die showing (21−N)–20

**Reroll Mechanics:**
- Apply rerolls to **every die rolled during the entire explosion chain** (initial dice + all explosion dice)
- If a rerolled die lands within the reroll band again, it is rerolled repeatedly until it lands outside that band
- Rerolls **never create, remove, or extend explosions** — they only change final die values
- After all rerolls, recalculate the total using the modified dice, preserving original explosion directions

**Example:**
```
Net modifier: +2 (reroll 1–2)
Original roll: [20, 20] + [18, 2] + [4, 1] = 65
Reroll band 1–2: 
  - [20, 20] → no change
  - [18, 2] → 2 rerolls to 14 → [18, 14]
  - [4, 1] → 1 rerolls to 16 → [4, 16]
Final: 20 + 20 + 18 + 14 + 4 + 16 = 92
```

### Step 3: Apply Mechanical Ability Modifiers

Add non-Boon/Bane modifiers:
- Skill rating (typically +0 to +5)
- Aspect contribution (Aspect × configurable weight, typically 0.20, rounded nearest)
- Other mechanical effects (scene policies, temporary buffs, etc.)

```
final_total = dice_sum + skill + (aspect × weight) + other_modifiers
```

No cap on total modifiers; unbounded scaling is intentional.

### Step 4: Compare Against Difficulty & Determine Outcome

- Success: `final_total ≥ difficulty`
- Failure: `final_total < difficulty`
- Calculate margin: `margin = final_total - difficulty`

Determine narrative degree (see §8.1: Degrees of Success).

### Step 5: Probability-Based Extraordinary Luck Marking

After rolling and resolving outcome:
1. Calculate pre-roll success probability using the complete 2d20 distribution, all modifiers, and difficulty
2. If the achieved outcome had probability ≤ 0.01% (1 in 10,000), mark roll as **EXTRAORDINARY**
3. Display extraordinary luck message (see §9)

**Configuration:**
```yaml
rolls:
  random_model: "d20_open_ended"
  explosion:
    enabled: true
    trigger: "double_20"
    
  implosion:
    enabled: true
    trigger: "double_1"
  
  boon_bane:
    # Boons/Banes modify luck via die rerolls, not flat bonuses
    # Net modifier determines reroll band; configurable per-game
    max_positive_modifier: null    # No cap; intentional
    max_negative_modifier: null    # No cap; intentional
  
  extraordinary_result_threshold: 0.0001  # 0.01% probability (1 in 10,000)
```

**Design Rationale:**

1. **2d20 Range (2-40):** Wider base than 2d10; provides more granularity and higher base difficulty anchors (matching difficulties in §1)
2. **Explosions & Implosions:** Open-ended with no hard caps; allows unbounded extraordinary outcomes
3. **Boons/Banes as Luck Modifiers:** Rerolling dice is mechanically cleaner than flat bonuses; preserves skill differentiation while making Boons/Banes mechanically meaningful
4. **No Automatic Success/Failure:** Even with max positive modifiers, a terrible roll (like [1,1]) cannot guarantee success; even with max negative modifiers, exceptional rolls (like [20,20]) cannot guarantee failure
5. **Explosion Chains Determined Early:** Prevents Boon/Bane rerolls from accidentally triggering new explosions
6. **Probability-Based Extraordinary:** Captures statistically unlikely outcomes regardless of dice mechanics; aligns narrative weight with actual rarity

---

## 3. XP Advancement Cost Table

**Status:** ✅ Approved

**Decision:**
XP advancement costs are calculated using an algebraic model combining skill rating curves, character development curves, and Resonance modifiers. This approach eliminates static lookup tables while maintaining configurability and natural scaling.

**Cost Calculation Formula:**

```
base_cost = ceil(new_rating² / 2)
development_modifier = 1 + (xp_spent / 250)^1.25
resonance_modifier = (char_resonance > 0) ?
                      (1 + 0.22 * char_resonance + 1 * char_resonance) :
                      (1 + 0.12 * char_resonance)
                      
final_cost = ceil(base_cost × development_modifier × resonance_modifier)
```

**Component Breakdown:**

### Skill Curve: `ceil(new_rating² / 2)`
- **Purpose:** Makes each higher rating progressively more expensive
- **Examples:**
  - Rating 1: ceil(1² / 2) = ceil(0.5) = 1 XP
  - Rating 3: ceil(9 / 2) = ceil(4.5) = 5 XP
  - Rating 5: ceil(25 / 2) = ceil(12.5) = 13 XP
  - Rating 9: ceil(81 / 2) = ceil(40.5) = 41 XP
  - Rating 10: ceil(100 / 2) = 50 XP
- **Design Rationale:** Ratings 9–10 become intentionally expensive without requiring a hand-maintained table; smooth curve enables natural tuning

### Development Curve: `1 + (xp_spent / 250)^1.25`
- **Purpose:** Advancement gradually slows as a character develops
- **Examples (with 0 Resonance):**
  - At 0 XP spent: 1 + (0/250)^1.25 = 1.0 multiplier → cost unchanged
  - At 250 XP spent: 1 + (250/250)^1.25 = 2.0 multiplier → costs double
  - At 500 XP spent: 1 + (500/250)^1.25 ≈ 2.78 multiplier → costs nearly triple
  - At 1000 XP spent: 1 + (1000/250)^1.25 ≈ 5.66 multiplier → costs >5× original
- **Design Rationale:** Uses XP spent (not rating), so broad and focused builds advance at similar overall rates; starts nearly flat, then ramps up naturally

### Resonance Modifiers

**Negative Resonance (Below 0):**
```
1 + 0.12 * char_resonance
Example: -5 Resonance → 1 + 0.12×(-5) = 0.4 multiplier → costs 40% of base
```

**Positive Resonance (Above 0):**
```
1 + 0.22 * char_resonance + 1 * char_resonance
Example: +5 Resonance → 1 + 0.22×5 + 1×5 = 6.1 multiplier → costs 610% of base
```

- **Design Rationale:**
  - Negative Resonance: Characters with lower innate potential pay slightly less for advancement
  - Positive Resonance: Characters with greater innate potential pay substantially more (steeper curve reflects greater starting potential)
  - Multiplicative curve: Effect grows naturally as characters progress through development curve
  - Flat surcharge (+1 per positive level): Ensures effect is noticeable even at low costs before development curve dominates

**Configuration:**
```yaml
xp:
  # Skill rating curve (configurable constants)
  skill_curve_numerator: 1      # numerator for rating²
  skill_curve_denominator: 2    # denominator (rating² / 2)
  
  # Development curve (configurable constants)
  development_base: 1           # baseline multiplier
  development_scale: 250        # XP spent threshold
  development_exponent: 1.25    # curve shape
  
  # Resonance modifiers
  negative_resonance_rate: 0.12  # multiplier per negative level
  positive_resonance_rate: 0.22  # multiplier per positive level
  positive_resonance_surcharge: 1  # flat +1 XP per positive level
```

**Design Goals Satisfied:**
- ✔ No giant lookup tables
- ✔ Entirely algebraic and configurable
- ✔ Very high ratings (9–10) are genuinely difficult to reach
- ✔ Positive Resonance makes advancement harder (intentional)
- ✔ Effect of Resonance grows naturally as characters progress
- ✔ Tunable by changing a few constants instead of rewriting a table

**Catch-Up XP Interaction:**
Characters earning catch-up XP spend with the same cost formula; catch-up only accelerates earning, not spending.

---

## 4. Modifier Bounds (Removed)

**Status:** ✅ Archived

**Decision:** Global modifier bounds are eliminated. The 2d20 open-ended rolling system (§2) with Boon/Bane-driven die rerolls achieves balance through mechanics, not caps:

- **No Automatic Success:** Even +N rerolls cannot guarantee success against high difficulties; the [1,1] implosion chain can reduce even high rolls to failure
- **No Automatic Failure:** Even −N rerolls cannot guarantee failure against low difficulties; the [20,20] explosion chain can boost even low rolls to success
- **Skill Still Matters:** Mechanical modifiers (Skill + Aspect) stack unbounded but are secondary to dice luck; a character with +10 modifiers still needs good rolls
- **Boons/Banes Influence Luck:** Rerolling dice is mathematically different from flat bonuses; a character with +5 Boons rerolls more dice but doesn't guarantee outcomes

**Rationale:** The removal of hard caps allows both extraordinary success stories and crushing failures, preserving narrative weight across the full range of outcomes.

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

**Status:** ✅ Approved

**Decision:**
Pending rolls expire after approximately 30 days (720 hours) of wall-clock time. Expired rolls are marked as inactive and can no longer be approved/rejected by GMs. No automatic resolution occurs; players and staff can still manually resolve expired rolls if needed.

**Mechanism:**
- Wall-clock expiry: Rolls older than 720 hours are marked expired
- No auto-resolve: Expired rolls remain in history but inactive
- GM capacity management: Open roll cap (configurable) prevents queue buildup

**Rationale:**
Since open rolls are already limited by configuration (per-player cap), individual rolls can afford longer expiry windows without creating system strain. A 30-day window accommodates asynchronous play patterns, scene delays, and multi-week narratives while still eventually clearing old rolls from active queues.

**Player Experience:**
- Players can still view expired rolls in their history
- GMs can still manually approve/reject expired rolls if narrative resolution is needed
- Automatic marking prevents confusion (expired rolls clearly distinguished)

**Configuration:**
```yaml
rolls:
  pending_roll_timeout_hours: 720        # ~30 days
  auto_failure_on_expiry: false          # Rolls expire silently, no auto-resolve
  
  # Hard cap on open rolls per player (separate config)
  max_pending_rolls_per_player: 5        # Prevents unbounded queue growth
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

## 8. Catch-Up XP Mechanism

**Status:** ✅ Approved

**Decision:**
Characters behind the group median earned XP automatically earn XP at a configurable multiplier from all sources except manual admin grants. Catch-up is calculated on a regular schedule (typically weekly) and continues until a character's total available XP meets or exceeds the group median.

**Calculation:**

1. **Schedule:** Run catch-up calculation periodically (configurable; default weekly via cron)

2. **Median Calculation:**
   - Calculate median of `earned_xp` from all approved characters
   - Newly approved characters are included immediately (no grace period)

3. **Catch-Up Eligibility:**
   - For each character: `available_xp = earned_xp + catchup_xp`
   - If `available_xp < median_earned_xp`, character qualifies for catch-up

4. **Catch-Up Earning:**
   - Qualifying characters earn XP at **2x multiplier** (configurable) from:
     - Scene participation
     - Inklings completion
     - Boon/Bane awards
     - Other automatic sources
   - **Excludes:** Manual XP grants by admins (admins can boost without triggering catch-up)

5. **Duration:**
   - Catch-up continues automatically until `available_xp >= median_earned_xp`
   - At that point, character reverts to normal 1x XP earning

**Rationale:**

- **No grace period:** New characters are included immediately; this encourages alt creation without penalizing new joiners
- **Median-driven:** Simple, adaptive to group progression; no hardcoded thresholds
- **Automatic:** No admin intervention needed; catches up happens transparently
- **Exempt from manual grants:** Admins can award XP for events, makeup, etc. without triggering catch-up
- **Multiplier is configurable:** Different games may want 1.5x, 2x, 3x, etc.

**Configuration:**

```yaml
xp:
  catchup:
    enabled: true
    schedule: "weekly"          # Cron-like: "weekly", "daily", etc. (configurable)
    multiplier: 2               # Earned XP is multiplied by this when catching up
    sources_excluded:
      - manual_grant            # Admin-granted XP doesn't count toward catch-up
    
  # Scheduling (if using cron)
  catchup_cron: "0 0 * * 1"     # Every Monday at midnight UTC (example)
```

**Examples:**

**Example 1: New Character**
- Group median: 200 earned XP
- New character: 0 earned XP, 0 catchup_xp
- Available: 0 (< 200) → qualifies for catch-up
- Player completes a scene earning 10 XP → gets 10 × 2 = 20 XP
- After earning 100 total (50 scenes × 2x): available_xp = 100 (still < 200)
- Catch-up continues until available_xp >= 200

**Example 2: Established Character with Catch-Up**
- Group median: 300 earned XP
- Character: 200 earned XP, 0 catchup_xp
- Available: 200 (< 300) → qualifies for catch-up
- Earns 25 XP from Inkling → gets 25 × 2 = 50 XP catchup
- After 2 Inklings (50 XP total): available_xp = 250 (still < 300)
- Admin grants 50 XP for special event → does NOT trigger catch-up (manual grant exempt)
- Available still at 250; catch-up continues until available_xp >= 300

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

**Configuration:**
```yaml
rolls:
  degrees_of_success:
    exceptional_success_min: 10
    success_min: 0
    complicated_success_min: -5
    lucky_failure_min: -10
    catastrophic_failure_min: null  # Below lucky_failure_min threshold
```

These thresholds are configurable per-game but locked to these defaults for SOUL.

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
If success_probability ≤ 0.01% AND roll succeeds:
    Display: "In an extraordinary string of good luck, [Character] succeeds."

If failure_probability ≤ 0.01% AND roll fails:
    Display: "In an extraordinary string of bad luck, [Character] fails."
```

**Examples:**

| Scenario | Success Prob | Outcome | Message |
|----------|--------------|---------|---------|
| Character with 0.005% success chance | 0.005% | Succeeds | "In an extraordinary string of good luck, Sarah succeeds." |
| Character with 99.995% success chance | 99.995% | Fails | "In an extraordinary string of bad luck, Gandalf fails." |
| Character with 50% success chance | 50% | Succeeds | (Standard success message, no extraordinary tag) |

**Rationale:**
- Extraordinary messaging rewards/acknowledges statistically unlikely outcomes
- Probability-based triggering reflects the actual rarity of the outcome, not arbitrary dice patterns
- Threshold (≤ 0.01%, or 1 in 10,000) ensures messages are reserved for genuinely improbable events
- Applies equally to good and bad luck, maintaining narrative symmetry

**Implementation Notes:**
- Calculate probability *before* rolling (not retroactively after observing the outcome)
- Use the same random distribution and modifier application as the actual roll
- Store calculated probability alongside roll record for audit/transparency
- Message format and personalization are configurable; above are templates

**Configuration:**
```yaml
rolls:
  extraordinary_result_threshold: 0.0001    # Probability threshold (0.01%, 1 in 10,000)
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
| Random Model | ✅ Approved | 2d20 open-ended with Boon/Bane die rerolls (§2) |
| XP Advancement Cost | ✅ Approved | Algebraic model (§3) |
| Modifier Bounds | ✅ Archived | No cap; Boons/Banes modify luck via rerolls (§4) |
| Chargen B&Bs | ✅ Approved | 2:1 Boon-to-Bane ratio, per-R-level config (§5) |
| Pending Roll Expiry | ✅ Approved | ~30 days wall-clock (§6) |
| Aspect Rounding | ✅ Approved | Round Nearest (§7) |
| Catch-Up XP | ✅ Approved | Median-based 2x multiplier, weekly calculation (§8) |
| Degrees of Success | ✅ Approved | Six degrees with GM-less/GM-led output (§8.1) |
| Extraordinary Luck Messaging | ✅ Approved | Probability-based (<0.01%) (§9) |

---

## SOUL LlamaCoder Handoff Instructions

This project uses a two-stage AI workflow.

### Your Role

You (Claude) are the project architect.

You are responsible for:

* Architecture
* Implementation planning
* API design
* System integration
* AresMUSH convention compliance
* Code review
* Documentation
* Final acceptance of all code

You remain responsible for the final implementation even when portions are delegated.

### LlamaCoder's Role

LlamaCoder is not responsible for architecture.

LlamaCoder is used only for repetitive implementation work once all architectural decisions have already been made.

Typical delegated work includes:

* Ruby boilerplate
* CRUD services
* Commands
* Request handlers
* Ember component scaffolding
* Configuration templates
* Localization
* Help files
* Repetitive UI implementation
* Test scaffolding

LlamaCoder must not reinterpret requirements, redesign systems, change APIs, rename concepts, or make architectural decisions.

### When Preparing Work for LlamaCoder

Whenever a task no longer requires architectural judgment, stop implementation and produce a complete LlamaCoder handoff instead of continuing.

Every handoff should include:

1. Scope of the task.
2. Relevant specification sections.
3. Files expected to be created or modified.
4. Existing services or APIs that must be used.
5. Constraints and invariants that may not change.
6. Acceptance criteria.
7. Testing requirements.
8. Explicit statement that LlamaCoder must not make architectural changes.

The handoff should be detailed enough that LlamaCoder can implement it without guessing.

### After LlamaCoder Finishes

Assume nothing.

Review every change for:

* Specification compliance
* AresMUSH convention compliance
* Architectural correctness
* Authorization and privacy
* Configuration
* Localization
* Duplication
* Edge cases
* Web/MUSH parity
* Tests
* Documentation

Correct any deficiencies yourself before accepting the implementation.

### Architectural Rule

If, while preparing a handoff, you discover an unresolved design question, do not delegate it. Stop and bring the issue back for architectural review. Only fully specified work may be handed to LlamaCoder.

---

## Next Steps

1. **Architecture Complete:** All 10 core specifications are now locked in
2. **Update CLAUDE_ADR.md:** Record decisions and mark architectural phase complete
3. **Implementation Phase:** Begin preparation of LlamaCoder handoffs for each subsystem
4. **Review Cycle:** Verify each implementation against specification and AresMUSH conventions

---

**Last Updated:** 2026-07-23

**Status:** Architecture ✅ Complete | Specifications ✅ Locked | Implementation 🔄 Ready to Begin

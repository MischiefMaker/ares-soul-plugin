module AresMUSH
  # XP ledger: earning, spending, catch-up, and the algebraic advancement
  # cost formula (FINAL REQ-013 through REQ-015; Implementation_Specification_Addendum.md
  # §3 and §8).
  class SoulXpApi
    def self.get_available_xp(character)
      return 0 unless character
      character.soul_xp_available || 0
    end

    def self.get_lifetime_earned_xp(character)
      return 0 unless character
      character.soul_xp_earned || 0
    end

    def self.get_lifetime_spent_xp(character)
      return 0 unless character
      character.soul_xp_spent || 0
    end

    def self.get_catchup_xp_earned(character)
      return 0 unless character
      character.soul_catchup_xp_earned || 0
    end

    # Median Lifetime Earned XP across approved, active characters (FINAL
    # REQ-014). Chargen.approved_chars (not Character.all) excludes NPCs,
    # rosters, and inactive characters - the same population the real
    # AresMUSH core uses for its own periodic-award sweeps (see
    # plugins/fs3skills/events/xp_cron_handler.rb).
    def self.median_earned_xp
      values = Chargen.approved_chars.map { |c| get_lifetime_earned_xp(c) }.sort
      return 0 if values.empty?

      mid = values.length / 2
      values.length.odd? ? values[mid] : (values[mid - 1] + values[mid]) / 2.0
    end

    # FINAL REQ-014: progress is xp_earned + catchup_xp_earned, compared
    # against the current median. Recomputed live on every award rather
    # than cached, so it's always current without a separate recalculation
    # step - "weekly recalculation" (Addendum §8) falls out naturally from
    # the weekly award cron being the main point awards happen.
    def self.catchup_eligible?(character)
      return false unless character
      return false unless Global.read_config("soul", "xp", "catchup", "enabled")

      progress = get_lifetime_earned_xp(character) + get_catchup_xp_earned(character)
      progress < median_earned_xp
    end

    # Awards XP, applying the catch-up multiplier only when apply_catchup
    # is true and the character is currently eligible (FINAL REQ-014).
    # Manual staff grants default apply_catchup to false at the command
    # layer (+xp/award vs. the explicit +xp/award/catchup) - see
    # docs/reference/Commands.md.
    #
    # idempotency_key, when given, makes repeated delivery of the same
    # logical award (a re-fired cron tick, a re-processed scene share) a
    # no-op rather than a double-award (FINAL REQ-013).
    def self.award(character, amount, source:, idempotency_key: nil, apply_catchup: true)
      return { error: "Character not found" } unless character
      return { error: "Amount must be positive" } if amount.to_i <= 0

      if idempotency_key && SoulXpLedgerEntry.find_one(idempotency_key: idempotency_key)
        return { success: true, awarded: 0, catchup_portion: 0, duplicate: true }
      end

      base_award = amount.to_i
      catchup_portion = 0

      if apply_catchup && catchup_eligible?(character)
        multiplier = Global.read_config("soul", "xp", "catchup", "multiplier") || 2.0
        gap = median_earned_xp - (get_lifetime_earned_xp(character) + get_catchup_xp_earned(character))
        uncapped_bonus = (base_award * multiplier) - base_award
        catchup_portion = [[uncapped_bonus, gap].min, 0].max.floor
      end

      total_awarded = base_award + catchup_portion

      character.update(
        soul_xp_available: get_available_xp(character) + total_awarded,
        soul_xp_earned: get_lifetime_earned_xp(character) + base_award,
        soul_catchup_xp_earned: get_catchup_xp_earned(character) + catchup_portion
      )

      SoulXpLedgerEntry.create(
        character: character,
        direction: "award",
        source: source,
        idempotency_key: idempotency_key,
        base_amount: base_award,
        catchup_amount: catchup_portion,
        created_at: Time.now
      )

      { success: true, awarded: total_awarded, base_award: base_award, catchup_portion: catchup_portion }
    end

    # The algebraic advancement cost formula (Addendum §3):
    #   base_cost = ceil(new_rating^2 * skill_curve_numerator / skill_curve_denominator)
    #   development_modifier = development_base + (xp_spent / development_scale) ^ development_exponent
    #   resonance_modifier = resonance > 0
    #     ? 1 + positive_resonance_rate*resonance + positive_resonance_surcharge*resonance
    #     : 1 + negative_resonance_rate*resonance
    #   final_cost = ceil(base_cost * development_modifier * resonance_modifier)
    def self.calculate_cost(character, skill_key, new_rating)
      numerator = Global.read_config("soul", "xp", "cost", "skill_curve_numerator") || 1
      denominator = Global.read_config("soul", "xp", "cost", "skill_curve_denominator") || 2
      base_cost = (new_rating.to_i**2 * numerator).fdiv(denominator).ceil

      dev_base = Global.read_config("soul", "xp", "cost", "development_base") || 1
      dev_scale = Global.read_config("soul", "xp", "cost", "development_scale") || 250
      dev_exponent = Global.read_config("soul", "xp", "cost", "development_exponent") || 1.25
      xp_spent = get_lifetime_spent_xp(character)
      development_modifier = dev_base + (xp_spent.to_f / dev_scale)**dev_exponent

      resonance = SoulResonanceApi.get_resonance(character) || 0
      if resonance > 0
        positive_rate = Global.read_config("soul", "xp", "cost", "positive_resonance_rate") || 0
        surcharge = Global.read_config("soul", "xp", "cost", "positive_resonance_surcharge") || 0
        resonance_modifier = 1 + (positive_rate * resonance) + (surcharge * resonance)
      else
        negative_rate = Global.read_config("soul", "xp", "cost", "negative_resonance_rate") || 0
        resonance_modifier = 1 + (negative_rate * resonance)
      end

      (base_cost * development_modifier * resonance_modifier).ceil
    end

    # Skill advancement flow (FINAL REQ-015): validate -> calculate cost ->
    # atomic deduct + advance -> Lifetime Spent XP -> ledger.
    def self.spend(character, skill_key, amount, enactor)
      return { error: "Character not found" } unless character
      return { error: "Unknown skill: #{skill_key}" } unless SoulFrameworkApi.valid_skill_key?(skill_key)
      return { error: "Amount must be positive" } if amount.to_i <= 0

      current_rating = SoulCharacterApi.get_skill_rating(character, skill_key)
      new_rating = current_rating + amount.to_i
      max_rating = SoulFrameworkApi.skill_max_rating
      return { error: "Rating would exceed the maximum of #{max_rating}" } if new_rating > max_rating

      cost = calculate_cost(character, skill_key, new_rating)
      available = get_available_xp(character)
      return { error: "Insufficient XP: need #{cost}, have #{available}" } if available < cost

      result = SoulCharacterApi.set_skill_rating(character, skill_key, new_rating, enactor)
      return result if result[:error]

      character.update(
        soul_xp_available: available - cost,
        soul_xp_spent: get_lifetime_spent_xp(character) + cost
      )

      SoulXpLedgerEntry.create(
        character: character,
        direction: "spend",
        source: skill_key.to_s,
        base_amount: cost,
        created_at: Time.now
      )

      { success: true, new_rating: new_rating, cost: cost, xp_remaining: available - cost }
    end

    def self.get_history(character, limit: 50)
      return [] unless character
      character.soul_xp_ledger_entries.to_a.sort_by { |e| e.created_at || Time.at(0) }.reverse.first(limit)
    end
  end
end

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
      catchup_config = Global.read_config("soul", "xp", "catchup") || {}
      return false unless catchup_config["enabled"]

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
    # notify: character-facing notification (2026-07-26 live testing: "We
    # need to add a notification when a player is awarded XP either
    # individually or to a scene. Look to how Inklings did it.") - opt-in,
    # not the default, since .award is also the engine behind the weekly
    # cron, forum reconciliation, automatic scene-share XP, and the
    # Inklings integration hook, none of which were part of that request
    # and would turn into notification spam if this defaulted on. Only the
    # staff-initiated individual (+xp/award, soulXpAward) and scene
    # (+xp/scene, soulXpScene) award paths pass notify: true.
    def self.award(character, amount, source:, idempotency_key: nil, apply_catchup: true, notify: false)
      return { error: "Character not found" } unless character
      return { error: "Amount must be positive" } if amount.to_i <= 0

      if idempotency_key && SoulXpLedgerEntry.find_one(idempotency_key: idempotency_key)
        return { success: true, awarded: 0, catchup_portion: 0, duplicate: true }
      end

      base_award = amount.to_i
      catchup_portion = 0

      if apply_catchup && catchup_eligible?(character)
        catchup_config = Global.read_config("soul", "xp", "catchup") || {}
        multiplier = catchup_config["multiplier"] || 2.0
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

      entry = SoulXpLedgerEntry.create(
        character: character,
        direction: "award",
        source: source,
        idempotency_key: idempotency_key,
        base_amount: base_award,
        catchup_amount: catchup_portion,
        created_at: Time.now
      )

      if notify
        catchup_note = catchup_portion > 0 ? " (including #{catchup_portion} catch-up)" : ""
        Soul.notify_player(
          character, "<SOUL> You were awarded #{total_awarded} XP#{catchup_note}. Use +soul to view your total.",
          type: "soul_xp", reference_id: entry.id
        )
      end

      { success: true, awarded: total_awarded, base_award: base_award, catchup_portion: catchup_portion }
    end

    # The algebraic advancement cost formula (Addendum §3):
    #   base_cost = ceil(new_rating^2 * skill_curve_numerator / skill_curve_denominator)
    #   development_modifier = development_base + (xp_spent / development_scale) ^ development_exponent
    #   resonance_modifier = resonance > 0
    #     ? 1 + positive_resonance_rate*resonance + positive_resonance_surcharge*resonance
    #     : 1 + negative_resonance_rate*resonance
    #   equivalent_skill_cost = ceil(base_cost * development_modifier * resonance_modifier)
    #   final_cost = ceil(equivalent_skill_cost * advancement_type_multiplier)
    def self.calculate_cost(character, trait_key, new_rating, trait_type: "skill")
      cost_config = Global.read_config("soul", "xp", "cost") || {}

      numerator = cost_config["skill_curve_numerator"] || 1
      denominator = cost_config["skill_curve_denominator"] || 2
      base_cost = (new_rating.to_i**2 * numerator).fdiv(denominator).ceil

      dev_base = cost_config["development_base"] || 1
      dev_scale = cost_config["development_scale"] || 250
      dev_exponent = cost_config["development_exponent"] || 1.25
      xp_spent = get_lifetime_spent_xp(character)
      development_modifier = dev_base + (xp_spent.to_f / dev_scale)**dev_exponent

      resonance = SoulResonanceApi.get_resonance(character) || 0
      if resonance > 0
        positive_rate = cost_config["positive_resonance_rate"] || 0
        surcharge = cost_config["positive_resonance_surcharge"] || 0
        resonance_modifier = 1 + (positive_rate * resonance) + (surcharge * resonance)
      else
        negative_rate = cost_config["negative_resonance_rate"] || 0
        resonance_modifier = 1 + (negative_rate * resonance)
      end

      equivalent_skill_cost = (base_cost * development_modifier * resonance_modifier).ceil
      multiplier_key = trait_type.to_s == "aspect" ? "aspect_cost_multiplier" : "skill_cost_multiplier"
      default_multiplier = trait_type.to_s == "aspect" ? 4 : 1
      multiplier = cost_config[multiplier_key] || default_multiplier
      (equivalent_skill_cost * multiplier).ceil
    end

    # Skill advancement flow (FINAL REQ-015): validate -> calculate cost ->
    # atomic deduct + advance -> Lifetime Spent XP -> ledger.
    def self.spend(character, skill_key, amount, enactor)
      spend_trait(character, "skill", skill_key, amount, enactor)
    end

    # Aspect advancement uses the same authoritative spend flow as Skills,
    # with Addendum §3's configurable Aspect cost multiplier.
    def self.spend_aspect(character, aspect_key, amount, enactor)
      spend_trait(character, "aspect", aspect_key, amount, enactor)
    end

    def self.spend_trait(character, trait_type, trait_key, amount, enactor)
      return { error: "Character not found" } unless character
      return { error: "Amount must be positive" } if amount.to_i <= 0

      is_aspect = trait_type.to_s == "aspect"
      valid = is_aspect ? SoulFrameworkApi.valid_aspect_key?(trait_key) : SoulFrameworkApi.valid_skill_key?(trait_key)
      label = is_aspect ? "aspect" : "skill"
      return { error: "Unknown #{label}: #{trait_key}" } unless valid

      current_rating = if is_aspect
                         SoulCharacterApi.get_aspect_rating(character, trait_key)
                       else
                         SoulCharacterApi.get_skill_rating(character, trait_key)
                       end
      new_rating = current_rating + amount.to_i
      max_rating = is_aspect ? SoulFrameworkApi.aspect_max_rating : SoulFrameworkApi.skill_max_rating
      return { error: "Rating would exceed the maximum of #{max_rating}" } if new_rating > max_rating

      cost = calculate_cost(character, trait_key, new_rating, trait_type: label)
      available = get_available_xp(character)
      return { error: "Insufficient XP: need #{cost}, have #{available}" } if available < cost

      result = if is_aspect
                 SoulCharacterApi.set_aspect_rating(character, trait_key, new_rating, enactor)
               else
                 SoulCharacterApi.set_skill_rating(character, trait_key, new_rating, enactor)
               end
      return result if result[:error]

      character.update(
        soul_xp_available: available - cost,
        soul_xp_spent: get_lifetime_spent_xp(character) + cost
      )

      SoulXpLedgerEntry.create(
        character: character,
        direction: "spend",
        source: is_aspect ? "aspect:#{trait_key}" : trait_key.to_s,
        base_amount: cost,
        created_at: Time.now
      )

      {
        success: true, trait_type: label, trait_key: trait_key.to_s,
        new_rating: new_rating, cost: cost, xp_remaining: available - cost
      }
    end

    def self.get_history(character, limit: 50)
      return [] unless character
      character.soul_xp_ledger_entries.to_a.sort_by { |e| e.created_at || Time.at(0) }.reverse.first(limit)
    end

    # Staff correction of available XP (FINAL REQ-015: corrections preserve the
    # original transaction, actor, reason, and audit trail). Does not destroy the
    # original ledger entry — creates a correction entry and records both in the
    # audit + Narrative History (REQ-006, CP-07). Supports both additions and
    # reversals via the direction parameter.
    #
    # direction: "correction" (default) adds to available (e.g. missed award bonus)
    # direction: "reversal" subtracts from available (e.g. accidental double-award)
    #
    # NOTE: Does not undo prior skill advances — only adjusts the available XP pool.
    # Full rollback of a spend (reverting skill rating + available XP) is out of scope.
    def self.correct(character, amount, reason:, actor:, direction: "correction")
      return { error: "Character not found" } unless character
      return { error: "Reason is required for an XP correction" } if reason.to_s.blank?
      return { error: "Amount must be positive" } if amount.to_i <= 0

      old_available = get_available_xp(character)
      corrected_amount = amount.to_i
      multiplier = direction == "reversal" ? -1 : 1
      new_available = old_available + (corrected_amount * multiplier)

      character.update(soul_xp_available: new_available)

      SoulXpLedgerEntry.create(
        character: character,
        direction: direction,
        source: "correction",
        base_amount: corrected_amount,
        created_at: Time.now
      )

      audit = SoulAuditApi.create(
        action: "xp_correction", character: character, actor: actor, reason: reason,
        before_state: { "xp_available" => old_available }, after_state: { "xp_available" => new_available }
      )
      action_text = direction == "reversal" ? "reversed" : "added"
      SoulNarrativeHistoryApi.create(
        character, event_type: "correction",
        narrative: "XP corrected: #{corrected_amount} XP #{action_text} to available pool. Reason: #{reason}",
        audit_entry: audit
      )

      { success: true, old_available: old_available, new_available: new_available, corrected_amount: corrected_amount }
    end

    # Scene-participant helper (used by +xp/scene command to preview recipients).
    # Returns approved, active characters currently in the scene. Filters to
    # Chargen.approved_chars (the same population used for catch-up eligibility
    # and median XP calculation).
    def self.get_scene_participants(scene = nil)
      return [] unless scene
      return [] unless scene.respond_to?(:participants)

      # Filter to approved characters only (matching the population for XP median calculation)
      approved_ids = Chargen.approved_chars.map(&:id).to_set
      scene.participants.select { |char| approved_ids.include?(char.id) }
    end
  end
end

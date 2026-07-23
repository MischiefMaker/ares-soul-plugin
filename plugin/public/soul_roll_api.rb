module AresMUSH
  # Standard-roll orchestration (FINAL REQ-025 through REQ-031). The dice
  # engine owns all probability and RNG mechanics; this service owns workflow,
  # authorization, B&B selection, persistence, expiry, and events.
  class SoulRollApi
    def self.get_candidate_bnbs(character, skill_key)
      return [] unless character

      SoulBnbApi.get_character_entries(character).select do |entry|
        catalogue = entry.catalogue_entry
        entry.resolved != "true" &&
          catalogue &&
          catalogue.modifier_eligible == "true" &&
          (catalogue.skill_associations || []).include?(skill_key.to_s)
      end
    end

    def self.get_open_pending_count(character)
      return 0 unless character

      expire_stale_pending_rolls
      character.pending_rolls.to_a.count { |pending| pending.status == "awaiting_selection" }
    end

    def self.start_roll(character, skill_key, context: {})
      return { error: "Character not found." } unless character
      skill = SoulFrameworkApi.get_skill(skill_key)
      return { error: "Unknown skill: #{skill_key}" } unless skill
      return { error: "You don't have permission to roll." } unless Soul.can_play?(character)

      limit = Global.read_config("soul", "rolls", "max_pending_rolls_per_player") || 1
      if get_open_pending_count(character) >= limit.to_i
        return { error: "You already have the maximum number of open pending rolls (#{limit})." }
      end

      normalized_context = normalize_context(context)
      difficulty_result = resolve_difficulty(normalized_context)
      return { error: difficulty_result[:error] } if difficulty_result[:error]

      timeout_hours = Global.read_config("soul", "rolls", "pending_roll_timeout_hours") || 720
      pending = PendingRoll.create(
        player: character,
        character: character,
        skill_key: skill_key.to_s,
        aspect_key: skill[:aspect_key].to_s,
        scene_id: normalized_context["scene_id"],
        context: normalized_context,
        difficulty: difficulty_result[:difficulty],
        system_suggested_entries: get_candidate_bnbs(character, skill_key).map { |entry| entry.id.to_s },
        gm_suggested_entries: [],
        gm_mandatory_entries: [],
        player_selected_entries: [],
        manually_identified_entries: [],
        status: "awaiting_selection",
        gm_assisted: "false",
        expires_at: Time.now + (timeout_hours.to_i * 60 * 60)
      )

      { success: true, pending_roll: pending }
    end

    def self.select_entries(pending_roll_id, character, tags: [], suggested: false, none: false)
      return { error: "Character not found." } unless character
      pending = PendingRoll[pending_roll_id]
      pending_error = validate_owned_open_pending(pending, character)
      return { error: pending_error } if pending_error

      requested_tags = Array(tags).map(&:to_s).reject(&:blank?)
      choices = (suggested ? 1 : 0) + (none ? 1 : 0) + (requested_tags.any? ? 1 : 0)
      return { error: "Choose exactly one of tags, suggested, or none." } unless choices == 1
      return { error: "Duplicate B&B tags are not allowed." } unless requested_tags.uniq.length == requested_tags.length

      if suggested
        error = validate_entry_ids(pending.system_suggested_entries, character)
        return { error: error } if error
        pending.update(
          player_selected_entries: pending.system_suggested_entries.map(&:to_s),
          manually_identified_entries: []
        )
      elsif none
        pending.update(player_selected_entries: [], manually_identified_entries: [])
      else
        result = resolve_owned_tags(character, requested_tags)
        return { error: result[:error] } if result[:error]

        suggested_ids = pending.system_suggested_entries.map(&:to_s)
        selected = result[:entries].select { |entry| suggested_ids.include?(entry.id.to_s) }
        manual = result[:entries].reject { |entry| suggested_ids.include?(entry.id.to_s) }
        pending.update(
          player_selected_entries: selected.map { |entry| entry.id.to_s },
          manually_identified_entries: manual.map { |entry| entry.id.to_s }
        )
      end

      { success: true, pending_roll: pending }
    end

    def self.resolve_pending(pending_roll_id)
      pending = PendingRoll[pending_roll_id]
      return { error: "Pending roll not found." } unless pending
      return { error: "Pending roll is not awaiting selection." } unless pending.status == "awaiting_selection"
      if pending.expires_at && pending.expires_at < Time.now
        expire_pending(pending, Time.now)
        return { error: "Pending roll has expired." }
      end

      character = pending.character
      return { error: "Pending roll has no character." } unless character
      return { error: "Pending roll ownership is invalid." } unless pending.player == character
      return { error: "You don't have permission to resolve this roll." } unless Soul.can_play?(character)

      selected_ids = pending.player_selected_entries.map(&:to_s)
      manual_ids = pending.manually_identified_entries.map(&:to_s)
      all_ids = selected_ids + manual_ids
      return { error: "Duplicate B&B selections are not allowed." } unless all_ids.uniq.length == all_ids.length

      entry_result = load_accepted_entries(character, selected_ids, manual_ids)
      return { error: entry_result[:error] } if entry_result[:error]

      modifier_result = build_applied_modifiers(entry_result[:entries], selected_ids)
      return { error: modifier_result[:error] } if modifier_result[:error]
      net_modifier = modifier_result[:modifiers].sum { |modifier| modifier["modifier"] }

      difficulty_result = resolve_difficulty(pending.context || {})
      return { error: difficulty_result[:error] } if difficulty_result[:error]
      difficulty = difficulty_result[:difficulty]
      effective_base = SoulCharacterApi.get_effective_base(character, pending.skill_key)
      required_dice_total = difficulty - effective_base
      chance_of_success = Soul::SoulDiceEngine.success_probability(net_modifier, required_dice_total)
      dice = Soul::SoulDiceEngine.roll(net_modifier)
      final_result = dice[:total] + effective_base
      margin = final_result - difficulty
      degree = degree_of_success(margin)
      succeeded = final_result >= difficulty
      outcome_probability = succeeded ? chance_of_success : 1.0 - chance_of_success
      threshold = Global.read_config("soul", "rolls", "extraordinary_result_threshold") || 0.0001
      extraordinary = outcome_probability <= threshold.to_f

      roll = Roll.create(
        character: character,
        skill_key: pending.skill_key,
        aspect_key: pending.aspect_key,
        scene_id: pending.scene_id,
        context: pending.context || {},
        difficulty: difficulty,
        dice_result: serialize_dice(dice),
        net_modifier: net_modifier,
        applied_modifiers: modifier_result[:modifiers],
        final_result: final_result,
        success_probability: outcome_probability,
        degree_of_success: degree,
        extraordinary: extraordinary ? "true" : "false",
        gm_assisted: "false",
        rolled_at: Time.now
      )
      pending.update(status: "resolved")

      Global.dispatcher.queue_event SoulRollResolvedEvent.new(
        character.id, roll.id, roll.skill_key, roll.final_result,
        roll.degree_of_success, roll.extraordinary, roll.gm_assisted
      )

      { success: true, roll: roll }
    end

    def self.abort_pending(pending_roll_id, actor, reason:)
      return { error: "A reason is required to abort a pending roll." } if reason.to_s.blank?
      pending = PendingRoll[pending_roll_id]
      pending_error = validate_owned_open_pending(pending, actor)
      return { error: pending_error } if pending_error
      return { error: "You don't have permission to abort this roll." } unless Soul.can_play?(actor)

      pending.update(status: "aborted")
      SoulAuditApi.create(
        action: "roll_abort",
        character: pending.character,
        actor: actor,
        reason: reason,
        before_state: { "status" => "awaiting_selection" },
        after_state: { "status" => "aborted" }
      )
      { success: true }
    end

    def self.expire_stale_pending_rolls(now = Time.now)
      expired = PendingRoll.find(status: "awaiting_selection").to_a.select do |pending|
        pending.expires_at && pending.expires_at < now
      end
      expired.each { |pending| expire_pending(pending, now) }
      expired.length
    end

    def self.get_roll_history(character, limit: 50)
      return [] unless character
      character.rolls.to_a
        .sort_by { |roll| roll.rolled_at || Time.at(0) }
        .reverse
        .first(limit)
    end

    def self.normalize_context(context)
      (context || {}).each_with_object({}) do |(key, value), normalized|
        normalized[key.to_s] = value
      end
    end
    private_class_method :normalize_context

    def self.resolve_difficulty(context)
      difficulty_key = context["difficulty"].to_s
      difficulties = Global.read_config("soul", "rolls", "difficulties") || {}
      difficulty = difficulties[difficulty_key]
      return { error: "Unknown difficulty: #{difficulty_key}" } unless difficulty

      { difficulty: difficulty.to_i }
    end
    private_class_method :resolve_difficulty

    def self.validate_owned_open_pending(pending, character)
      return "Pending roll not found." unless pending
      return "That pending roll does not belong to you." unless character && pending.character == character && pending.player == character
      if pending.status == "awaiting_selection" && pending.expires_at && pending.expires_at < Time.now
        expire_pending(pending, Time.now)
      end
      return "Pending roll is not awaiting selection." unless pending.status == "awaiting_selection"
      nil
    end
    private_class_method :validate_owned_open_pending

    def self.validate_entry_ids(ids, character)
      ids.each do |id|
        entry = CharacterBnbEntry[id]
        return "Selected B&B entry ##{id} no longer exists." unless entry
        return "Selected B&B entry ##{id} is not owned by #{character.name}." unless entry.character == character
        return "Selected B&B entry ##{id} is resolved." if entry.resolved == "true"
      end
      nil
    end
    private_class_method :validate_entry_ids

    def self.resolve_owned_tags(character, tags)
      owned = SoulBnbApi.get_character_entries(character).select { |entry| entry.resolved != "true" }
      entries = []
      tags.each do |tag|
        matches = owned.select do |entry|
          entry.catalogue_entry && entry.catalogue_entry.tag.to_s.casecmp(tag).zero?
        end
        return { error: "You do not own an unresolved B&B tagged '#{tag}'." } if matches.empty?
        return { error: "Tag '#{tag}' matches multiple owned B&B entries; use a unique tag." } if matches.length > 1
        entries << matches.first
      end
      { entries: entries }
    end
    private_class_method :resolve_owned_tags

    def self.load_accepted_entries(character, selected_ids, manual_ids)
      error = validate_entry_ids(selected_ids + manual_ids, character)
      return { error: error } if error

      entries = (selected_ids + manual_ids).map { |id| CharacterBnbEntry[id] }
      { entries: entries }
    end
    private_class_method :load_accepted_entries

    def self.build_applied_modifiers(entries, selected_ids)
      modifiers = []
      entries.each do |entry|
        magnitude = SoulBnbApi.level_modifier(entry.catalogue_entry, entry.level_state)
        if magnitude.nil?
          return { error: "B&B entry ##{entry.id} (#{entry.catalogue_entry.name}) has no configured modifier for #{entry.level_state}." }
        end
        signed = magnitude.to_i * (entry.boon? ? 1 : -1)
        modifiers << {
          "source" => selected_ids.include?(entry.id.to_s) ? "system_suggested" : "manually_identified",
          "entry_id" => entry.id.to_s,
          "tag" => entry.catalogue_entry.tag,
          "name" => entry.catalogue_entry.name,
          "level_state" => entry.level_state,
          "modifier" => signed
        }
      end
      { modifiers: modifiers }
    end
    private_class_method :build_applied_modifiers

    def self.degree_of_success(margin)
      config = Global.read_config("soul", "rolls", "degrees_of_success") || {}
      exceptional_min = config["exceptional_success_min"].to_i
      success_min = config["success_min"].to_i
      complicated_min = config["complicated_success_min"].to_i
      lucky_min = config["lucky_failure_min"].to_i
      failure_min = config["failure_min"].to_i
      catastrophic_min = config["catastrophic_failure_min"].to_i

      return "exceptional_success" if margin >= exceptional_min
      return "success" if margin >= success_min
      return "complicated_success" if margin >= complicated_min
      return "lucky_failure" if margin >= lucky_min
      return "failure" if margin >= failure_min
      return "catastrophic_failure" if margin < catastrophic_min
      "catastrophic_failure"
    end
    private_class_method :degree_of_success

    def self.serialize_dice(dice)
      {
        "total" => dice[:total],
        "mode" => dice[:mode].to_s,
        "segments" => dice[:segments].map do |segment|
          { "d1" => segment[:d1], "d2" => segment[:d2] }
        end
      }
    end
    private_class_method :serialize_dice

    def self.expire_pending(pending, now)
      pending.update(status: "expired")
      SoulAuditApi.create(
        action: "roll_expire",
        character: pending.character,
        actor: nil,
        reason: "Pending roll expired at #{now}.",
        source: "system",
        before_state: { "status" => "awaiting_selection" },
        after_state: { "status" => "expired" }
      )
    end
    private_class_method :expire_pending
  end
end

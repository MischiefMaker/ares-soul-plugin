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

    def self.get_open_pending_count(character, gm_assisted: false)
      return 0 unless character

      expire_stale_pending_rolls
      expected_flag = gm_assisted ? "true" : "false"
      character.pending_rolls.to_a.count do |pending|
        open_status?(pending.status) && pending.gm_assisted == expected_flag
      end
    end

    def self.start_roll(character, skill_key, context: {}, gm_requested: false)
      return { error: "Character not found." } unless character
      skill = SoulFrameworkApi.get_skill(skill_key)
      return { error: "Unknown skill: #{skill_key}" } unless skill
      return { error: "You don't have permission to roll." } unless Soul.can_play?(character)

      normalized_context = normalize_context(context)
      gm_assisted = gm_assisted?(gm_requested)
      if gm_assisted && !load_scene(normalized_context["scene_id"])
        return { error: "A valid scene is required for a GM-assisted roll." }
      end

      limit_key = gm_assisted ? "max_pending_rolls_per_player_gm" : "max_pending_rolls_per_player"
      default_limit = gm_assisted ? 2 : 1
      limit = Global.read_config("soul", "rolls", limit_key) || default_limit
      if get_open_pending_count(character, gm_assisted: gm_assisted) >= limit.to_i
        return { error: "You already have the maximum number of open pending rolls (#{limit})." }
      end

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
        status: gm_assisted ? "awaiting_gm" : "awaiting_selection",
        gm_assisted: gm_assisted ? "true" : "false",
        expires_at: Time.now + (timeout_hours.to_i * 60 * 60)
      )

      { success: true, pending_roll: pending }
    end

    def self.get_gm_candidate_view(pending_roll_id, gm)
      pending = PendingRoll[pending_roll_id]
      return { error: "Pending roll not found." } unless pending
      return { error: "Pending roll is not awaiting GM review." } unless pending.status == "awaiting_gm"
      if pending.expires_at && pending.expires_at < Time.now
        expire_pending(pending, Time.now)
        return { error: "Pending roll has expired." }
      end
      return { error: "You don't have permission to review this roll." } unless can_review_pending?(pending, gm)

      entry_error = validate_entry_ids(pending.system_suggested_entries, pending.character)
      return { error: entry_error } if entry_error

      categories = Global.read_config("soul", "privacy", "gm_reveal_categories") || []
      candidates = pending.system_suggested_entries.map do |id|
        gm_candidate_hash(CharacterBnbEntry[id], categories)
      end
      { success: true, candidates: candidates }
    end

    def self.gm_submit_selections(pending_roll_id, gm, mandatory_ids: [], optional_ids: [])
      pending = PendingRoll[pending_roll_id]
      return { error: "Pending roll not found." } unless pending
      return { error: "Pending roll is not awaiting GM review." } unless pending.status == "awaiting_gm"
      if pending.expires_at && pending.expires_at < Time.now
        expire_pending(pending, Time.now)
        return { error: "Pending roll has expired." }
      end
      return { error: "You don't have permission to review this roll." } unless can_review_pending?(pending, gm)

      mandatory = Array(mandatory_ids).map(&:to_s)
      optional = Array(optional_ids).map(&:to_s)
      return { error: "Duplicate GM selections are not allowed." } unless mandatory.uniq.length == mandatory.length && optional.uniq.length == optional.length
      return { error: "An entry cannot be both mandatory and optional." } if (mandatory & optional).any?

      candidates = pending.system_suggested_entries.map(&:to_s)
      invalid = (mandatory + optional).reject { |id| candidates.include?(id) }
      return { error: "GM selections must come from this roll's candidate list." } if invalid.any?

      entry_error = validate_entry_ids(mandatory + optional, pending.character)
      return { error: entry_error } if entry_error

      pending.update(
        gm_mandatory_entries: mandatory,
        gm_suggested_entries: optional,
        status: "awaiting_selection"
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
        suggestions = pending.gm_assisted == "true" ? pending.gm_suggested_entries : pending.system_suggested_entries
        error = validate_entry_ids(suggestions, character)
        return { error: error } if error
        pending.update(
          player_selected_entries: suggestions.map(&:to_s),
          manually_identified_entries: []
        )
      elsif none
        pending.update(player_selected_entries: [], manually_identified_entries: [])
      else
        result = resolve_owned_tags(character, requested_tags)
        return { error: result[:error] } if result[:error]

        suggested_ids = if pending.gm_assisted == "true"
                          pending.gm_suggested_entries.map(&:to_s)
                        else
                          pending.system_suggested_entries.map(&:to_s)
                        end
        selected = result[:entries].select { |entry| suggested_ids.include?(entry.id.to_s) }
        manual = result[:entries].reject { |entry| suggested_ids.include?(entry.id.to_s) }
        pending.update(
          player_selected_entries: selected.map { |entry| entry.id.to_s },
          manually_identified_entries: manual.map { |entry| entry.id.to_s }
        )
      end

      { success: true, pending_roll: pending }
    end

    def self.resolve_pending(pending_roll_id, character)
      pending = PendingRoll[pending_roll_id]
      pending_error = validate_owned_open_pending(pending, character)
      return { error: pending_error } if pending_error
      return { error: "You don't have permission to resolve this roll." } unless Soul.can_play?(character)

      selected_ids = pending.player_selected_entries.map(&:to_s)
      manual_ids = pending.manually_identified_entries.map(&:to_s)
      mandatory_ids = pending.gm_mandatory_entries.map(&:to_s)
      player_ids = selected_ids + manual_ids
      return { error: "Duplicate B&B selections are not allowed." } unless player_ids.uniq.length == player_ids.length
      all_ids = (player_ids + mandatory_ids).uniq

      entry_result = load_accepted_entries(character, all_ids, [])
      return { error: entry_result[:error] } if entry_result[:error]

      modifier_result = build_applied_modifiers(entry_result[:entries], selected_ids, mandatory_ids: mandatory_ids)
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
        gm_assisted: pending.gm_assisted,
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
      allowed_statuses = if pending && pending.gm_assisted == "true"
                           ["awaiting_gm"]
                         else
                           ["awaiting_gm", "awaiting_selection"]
                         end
      pending_error = validate_owned_open_pending(pending, actor, allowed_statuses: allowed_statuses)
      return { error: pending_error } if pending_error
      return { error: "You don't have permission to abort this roll." } unless Soul.can_play?(actor)

      old_status = pending.status
      pending.update(status: "aborted")
      SoulAuditApi.create(
        action: "roll_abort",
        character: pending.character,
        actor: actor,
        reason: reason,
        before_state: { "status" => old_status },
        after_state: { "status" => "aborted" }
      )
      { success: true }
    end

    def self.force_abort_pending(pending_roll_id, actor, reason:)
      return { error: "A reason is required to force-abort a pending roll." } if reason.to_s.blank?
      pending = PendingRoll[pending_roll_id]
      return { error: "Pending roll not found." } unless pending
      return { error: "Pending roll is not open." } unless open_status?(pending.status)
      if pending.expires_at && pending.expires_at < Time.now
        expire_pending(pending, Time.now)
        return { error: "Pending roll has expired." }
      end
      return { error: "You don't have permission to force-abort this roll." } unless can_review_pending?(pending, actor)

      old_status = pending.status
      pending.update(status: "aborted")
      SoulAuditApi.create(
        action: "roll_force_abort",
        character: pending.character,
        actor: actor,
        reason: reason,
        before_state: { "status" => old_status },
        after_state: { "status" => "aborted" }
      )
      Login.notify(
        pending.character,
        :soul,
        "Your pending SOUL roll was force-aborted: #{reason}",
        pending.id
      )
      { success: true }
    end

    def self.expire_stale_pending_rolls(now = Time.now)
      open_rolls = PendingRoll.find(status: "awaiting_gm").to_a +
                   PendingRoll.find(status: "awaiting_selection").to_a
      expired = open_rolls.select do |pending|
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

    def self.validate_owned_open_pending(pending, character, allowed_statuses: ["awaiting_selection"])
      return "Pending roll not found." unless pending
      return "That pending roll does not belong to you." unless character && pending.character == character && pending.player == character
      if open_status?(pending.status) && pending.expires_at && pending.expires_at < Time.now
        expire_pending(pending, Time.now)
      end
      unless allowed_statuses.include?(pending.status)
        return "Pending roll is not awaiting selection." if allowed_statuses == ["awaiting_selection"]
        return "Pending roll is not in an allowed status."
      end
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

    def self.build_applied_modifiers(entries, selected_ids, mandatory_ids: [])
      modifiers = []
      entries.each do |entry|
        magnitude = SoulBnbApi.level_modifier(entry.catalogue_entry, entry.level_state)
        if magnitude.nil?
          return { error: "B&B entry ##{entry.id} (#{entry.catalogue_entry.name}) has no configured modifier for #{entry.level_state}." }
        end
        signed = magnitude.to_i * (entry.boon? ? 1 : -1)
        source = if mandatory_ids.include?(entry.id.to_s)
                   "gm_mandatory"
                 elsif selected_ids.include?(entry.id.to_s)
                   "system_suggested"
                 else
                   "manually_identified"
                 end
        modifiers << {
          "source" => source,
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

    def self.gm_assisted?(gm_requested)
      policy = Global.read_config("soul", "rolls", "gm_scene_policy") || "optional"
      policy == "required" || (policy == "optional" && gm_requested)
    end
    private_class_method :gm_assisted?

    def self.load_scene(scene_id)
      return nil if scene_id.to_s.blank?
      Scene[scene_id]
    end
    private_class_method :load_scene

    def self.can_review_pending?(pending, actor)
      return false unless actor
      return true if Soul.can_manage_soul?(actor)

      scene = load_scene(pending.scene_id)
      Soul.can_review_rolls?(actor) && scene && scene.is_participant?(actor)
    end
    private_class_method :can_review_pending?

    def self.gm_candidate_hash(entry, categories)
      catalogue = entry.catalogue_entry
      candidate = { id: entry.id.to_s, tag: catalogue.tag }
      candidate[:name] = catalogue.name if categories.include?("name")
      candidate[:public_description] = catalogue.description if categories.include?("public_description")
      if categories.include?("mechanical_effect")
        magnitude = SoulBnbApi.level_modifier(catalogue, entry.level_state)
        candidate[:mechanical_effect] = magnitude.nil? ? nil : magnitude.to_i * (entry.boon? ? 1 : -1)
      end
      candidate[:character_explanation] = entry.character_explanation if categories.include?("character_explanation")
      candidate[:gm_notes] = entry.gm_notes if categories.include?("gm_notes")
      candidate
    end
    private_class_method :gm_candidate_hash

    def self.open_status?(status)
      ["awaiting_gm", "awaiting_selection"].include?(status)
    end
    private_class_method :open_status?

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
      old_status = pending.status
      pending.update(status: "expired")
      SoulAuditApi.create(
        action: "roll_expire",
        character: pending.character,
        actor: nil,
        reason: "Pending roll expired at #{now}.",
        source: "system",
        before_state: { "status" => old_status },
        after_state: { "status" => "expired" }
      )
    end
    private_class_method :expire_pending
  end
end

module AresMUSH
  # Standard-roll orchestration (FINAL REQ-025 through REQ-031). The dice
  # engine owns all probability and RNG mechanics; this service owns workflow,
  # authorization, B&B selection, persistence, expiry, and events.
  class SoulRollApi
    # Candidate active B&Bs for a roll (FINAL REQ-028 step 2): unresolved,
    # Skill-associated with this roll's Skill. Does NOT check
    # catalogue.modifier_eligible - that field means something unrelated
    # (whether a Bane satisfies the positive-Resonance chargen requirement,
    # bnb_catalogue_entry.rb) and checking it here was a real bug (found
    # 2026-07-25 via live testing: a B&B correctly associated with the
    # rolled Skill was never suggested) - modifier_eligible defaults false
    # and neither +bnb/create nor the admin page ever exposed a way to set
    # it true, so this check silently excluded every B&B in the game.
    def self.get_candidate_bnbs(character, skill_key)
      return [] unless character

      SoulBnbApi.get_character_entries(character).select do |entry|
        catalogue = entry.catalogue_entry
        entry.resolved != "true" &&
          catalogue &&
          (entry.associated_skills || []).include?(skill_key.to_s)
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

    # Lets a player abandon a stuck "awaiting_gm" roll (no scene-GM
    # available/paying attention - a real live-testing complaint,
    # 2026-07-25) without losing it entirely to /abort. Falls back to the
    # roll's own system_suggested_entries (already computed by start_roll
    # for every roll, GM-assisted or not) via get_player_candidate_view's
    # existing gm_assisted branching - flips gm_assisted to "false" so
    # that branch is actually reached, and so the roll that eventually
    # resolves is honestly recorded as a standard roll no GM ever
    # touched, not as a GM-assisted one.
    def self.cancel_gm_request(pending_roll_id, character)
      pending = PendingRoll[pending_roll_id]
      # status "awaiting_gm" is only ever set by a gm_requested start_roll,
      # so allowed_statuses alone is sufficient - no separate gm_assisted
      # check needed.
      pending_error = validate_owned_open_pending(pending, character, allowed_statuses: ["awaiting_gm"])
      return { error: pending_error } if pending_error

      pending.update(status: "awaiting_selection", gm_assisted: "false")
      { success: true, pending_roll: pending }
    end

    # Player-facing candidate view (REQ-028 step 4: "Present concise
    # suggestions or state that none matched"). Unlike get_gm_candidate_view,
    # there is no privacy-category filtering - these are the roller's own
    # B&B entries, already fully visible to them via +bnb. Mirrors
    # select_entries's own suggested-set branching exactly: a standard
    # roll's candidates are system_suggested_entries; a GM-assisted roll's
    # (once the GM has reviewed - status awaiting_selection) are the GM's
    # own gm_suggested_entries/gm_mandatory_entries, not the original
    # system suggestions the GM may have narrowed.
    def self.get_player_candidate_view(pending_roll_id, character)
      pending = PendingRoll[pending_roll_id]
      pending_error = validate_owned_open_pending(pending, character, allowed_statuses: ["awaiting_selection"])
      return { error: pending_error } if pending_error

      if pending.gm_assisted == "true"
        mandatory_ids = pending.gm_mandatory_entries.map(&:to_s)
        suggested_ids = pending.gm_suggested_entries.map(&:to_s)
      else
        mandatory_ids = []
        suggested_ids = pending.system_suggested_entries.map(&:to_s)
      end

      shown_ids = (mandatory_ids + suggested_ids).uniq
      candidates = shown_ids.map do |id|
        data = SoulBnbApi.get_character_entry_public(character, id)
        next if data.nil?
        data.merge(mandatory: mandatory_ids.include?(id))
      end.compact

      # Owned, unresolved entries not already offered above - for the
      # "identify a relevant owned B&B not suggested by the system"
      # picker (FINAL REQ-028's manual-identification allowance), a
      # dropdown of the player's own entries rather than free-text tags.
      manual_options = SoulBnbApi.get_character_entries(character)
        .reject { |entry| entry.resolved == "true" || shown_ids.include?(entry.id.to_s) }
        .map { |entry| SoulBnbApi.get_character_entry_public(character, entry.id) }

      { success: true, candidates: candidates, manual_options: manual_options }
    end

    # Configured difficulty names (REQ-026's `+roll <skill>=<difficulty>`
    # extension). Read-only config passthrough - no privacy concern, no
    # authorization beyond ordinary play access, since these are the same
    # names anyone can already pass to start_roll.
    def self.get_difficulty_options
      Global.read_config("soul", "rolls", "difficulties") || {}
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

        if pending.gm_assisted == "true"
          suggested_ids = pending.gm_suggested_entries.map(&:to_s)
          mandatory_ids = pending.gm_mandatory_entries.map(&:to_s)
          reviewed_ids = pending.system_suggested_entries.map(&:to_s)

          # A candidate the GM reviewed and did not mark mandatory or optional
          # was deliberately excluded (handoff §5.6) - it must not become
          # selectable again by naming it directly. Only entries the system
          # never proposed at all (genuinely outside GM review) may still be
          # manually identified.
          rejected = result[:entries].select do |entry|
            id = entry.id.to_s
            reviewed_ids.include?(id) && !suggested_ids.include?(id) && !mandatory_ids.include?(id)
          end
          if rejected.any?
            names = rejected.map { |entry| entry.catalogue_entry.tag }.join(", ")
            return { error: "The GM did not make #{names} available for this roll." }
          end
        else
          suggested_ids = pending.system_suggested_entries.map(&:to_s)
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

      posted = post_to_scene(character, roll)

      { success: true, roll: roll, posted_to_scene: posted }
    end

    # Roll results always post to the scene transcript (2026-07-25: "Roll
    # results should always be posted to the scene" - reverses the
    # original private-by-default design). Posted as the system
    # character, matching the one real precedent for this in AresMUSH
    # core: FS3Skills.emit_results' own Scenes.add_to_scene call
    # (plugins/fs3skills/helpers/rolls.rb) also defaults to
    # Game.master.system_character rather than the roller. A no-op if the
    # roll has no scene_id (e.g. a MUSH +roll made outside any scene) or
    # Scenes.add_to_scene's own guards decline (logging disabled, scene
    # gone) - never raises, since a roll should always succeed even if
    # posting isn't possible.
    def self.post_to_scene(character, roll)
      scene = load_scene(roll.scene_id)
      return false unless scene

      Scenes.add_to_scene(scene, build_scene_pose(character, roll))
      true
    end
    private_class_method :post_to_scene

    def self.build_scene_pose(character, roll)
      skill = SoulFrameworkApi.get_skill(roll.skill_key)
      skill_name = skill ? skill[:name] : roll.skill_key
      narrative = degree_narrative(roll.degree_of_success)
      extraordinary = roll.extraordinary == "true" ? " (Extraordinary!)" : ""
      "#{character.name} rolls #{skill_name}: #{narrative}#{extraordinary} " \
        "(#{roll.final_result} versus difficulty #{roll.difficulty})"
    end
    private_class_method :build_scene_pose

    # Addendum §8.1's "Output Format - GM-Less (Player Authority)" table,
    # verbatim - defined once so the scene pose, the MUSH private roll
    # result, and the web roll modal all show identical wording instead
    # of drifting (staff request, 2026-07-25: raw degree strings like
    # "Exceptional success" weren't what the Addendum specifies).
    DEGREE_NARRATIVE = {
      "exceptional_success" => "You succeed, and may introduce an additional benefit resulting from your success.",
      "success" => "You succeed.",
      "complicated_success" => "You succeed, but should introduce an additional complication resulting from your success.",
      "lucky_failure" => "You fail, but may introduce an additional benefit despite your failure.",
      "failure" => "You fail.",
      "catastrophic_failure" => "You fail, and should introduce an additional complication resulting from your failure."
    }.freeze

    # The three degrees that represent an actual success (Addendum §8.1's
    # Six Degrees table) - Lucky Failure keeps a beneficial narrative
    # flavor but is still a failure mechanically, matching
    # resolve_pending's own `succeeded = final_result >= difficulty`.
    SUCCESS_DEGREES = %w[exceptional_success success complicated_success].freeze

    def self.degree_narrative(degree)
      DEGREE_NARRATIVE[degree.to_s] || degree.to_s.tr("_", " ").capitalize
    end

    def self.degree_succeeded?(degree)
      SUCCESS_DEGREES.include?(degree.to_s)
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

    def self.get_open_pending_for_selection(character)
      get_open_pending_rolls(character)
        .find { |pending| pending.status == "awaiting_selection" }
    end

    def self.get_open_pending_rolls(character)
      return [] unless character

      expire_stale_pending_rolls
      character.pending_rolls.to_a
        .select { |pending| open_status?(pending.status) }
        .sort_by { |pending| pending.id.to_i }
        .reverse
    end

    def self.get_pending_gm_review(scene)
      return [] unless scene

      expire_stale_pending_rolls
      PendingRoll.find(status: "awaiting_gm").to_a
        .select { |pending| pending.scene_id.to_s == scene.id.to_s }
        .sort_by { |pending| pending.id.to_i }
        .reverse
    end

    # Every currently-open pending roll this actor is allowed to
    # force-abort - for the "Force-Abort Any Open Roll" picker (mischief
    # bug list, 2026-07-25: a typed Roll ID was the only way to reach a
    # roll outside the reviewer's current scene, with no way to discover
    # what IDs even exist). manage_soul staff see every open roll,
    # system-wide; a scene-scoped reviewer only sees rolls in scenes they
    # participate in - matches can_review_pending?'s own authorization
    # exactly, so nothing appears in this list that force_abort_pending
    # would reject anyway.
    def self.get_open_pending_rolls_for_reviewer(actor)
      return [] unless actor
      expire_stale_pending_rolls
      open_rolls = (PendingRoll.find(status: "awaiting_gm").to_a +
        PendingRoll.find(status: "awaiting_selection").to_a).sort_by { |pending| pending.id.to_i }.reverse

      return open_rolls if Soul.can_manage_soul?(actor)
      return [] unless Soul.can_review_rolls?(actor)

      open_rolls.select do |pending|
        scene = load_scene(pending.scene_id)
        scene && scene.is_participant?(actor)
      end
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

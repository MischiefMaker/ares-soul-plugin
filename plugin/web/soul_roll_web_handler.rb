module AresMUSH
  class SoulRollWebHandler
    def handle(request)
      error = Website.check_login(request)
      return error if error

      enactor = request.enactor
      player_commands = %w[
        soulRoll soulRollStart soulRollGm soulRollSelect soulRollAbort
        soulRollPending soulRollHistory soulRollCandidates soulRollDifficulties
      ]
      if player_commands.include?(request.cmd) && !Soul.can_play?(enactor)
        return { error: t('soul.permission_denied') }
      end

      case request.cmd
      when "soulRoll"
        pending_status(enactor)
      when "soulRollStart"
        start(request, false)
      when "soulRollGm"
        start(request, true)
      when "soulRollSelect"
        select_and_resolve(request)
      when "soulRollAbort"
        SoulRollApi.abort_pending(request.args['pending_roll_id'], enactor,
          reason: request.args['reason'])
      when "soulRollForceAbort"
        SoulRollApi.force_abort_pending(request.args['pending_roll_id'], enactor,
          reason: request.args['reason'])
      when "soulRollPending"
        { pending_rolls: SoulRollApi.get_open_pending_rolls(enactor).map { |pending| pending_hash(pending) } }
      when "soulRollHistory"
        { rolls: SoulRollApi.get_roll_history(enactor).map { |roll| roll_hash(roll) } }
      when "soulRollReview"
        review(request)
      when "soulRollMark"
        mark(request)
      when "soulRollCandidates"
        SoulRollApi.get_player_candidate_view(request.args['pending_roll_id'], enactor)
      when "soulRollDifficulties"
        { difficulties: SoulRollApi.get_difficulty_options }
      end
    end

    def pending_status(character)
      pending = SoulRollApi.get_open_pending_for_selection(character) ||
        SoulRollApi.get_open_pending_rolls(character).first
      { pending_roll: pending ? pending_hash(pending) : nil }
    end

    def start(request, gm_requested)
      result = SoulRollApi.start_roll(
        request.enactor,
        request.args['skill_key'],
        context: {
          difficulty: request.args['difficulty'] || "standard",
          scene_id: request.args['scene_id']
        },
        gm_requested: gm_requested
      )
      result[:error] ? result : { success: true, pending_roll: pending_hash(result[:pending_roll]) }
    end

    def select_and_resolve(request)
      pending = if request.args['pending_roll_id']
                  PendingRoll[request.args['pending_roll_id']]
                else
                  SoulRollApi.get_open_pending_for_selection(request.enactor)
                end
      return { error: t('soul.no_pending_selection') } unless pending

      mode = request.args['selection'].to_s
      result = if mode.casecmp("suggested").zero?
                 SoulRollApi.select_entries(pending.id, request.enactor, suggested: true)
               elsif mode.casecmp("none").zero?
                 SoulRollApi.select_entries(pending.id, request.enactor, none: true)
               else
                 raw_tags = request.args['tags'] || mode
                 tags = raw_tags.kind_of?(Array) ? raw_tags : raw_tags.to_s.split(/\s+/).reject(&:blank?)
                 SoulRollApi.select_entries(pending.id, request.enactor, tags: tags)
               end
      return result if result[:error]

      resolved = SoulRollApi.resolve_pending(pending.id, request.enactor)
      resolved[:error] ? resolved : { success: true, roll: roll_hash(resolved[:roll]) }
    end

    def review(request)
      if request.args['pending_roll_id']
        return SoulRollApi.get_gm_candidate_view(request.args['pending_roll_id'], request.enactor)
      end

      scene = Scene[request.args['scene_id']]
      return { error: t('soul.no_active_scene_short') } unless scene
      authorized = Soul.can_manage_soul?(request.enactor) ||
        (Soul.can_review_rolls?(request.enactor) && scene.is_participant?(request.enactor))
      return { error: t('soul.permission_denied') } unless authorized

      { pending_rolls: SoulRollApi.get_pending_gm_review(scene).map { |pending| pending_hash(pending) } }
    end

    def mark(request)
      roll_id = request.args['pending_roll_id']
      view = SoulRollApi.get_gm_candidate_view(roll_id, request.enactor)
      return view if view[:error]

      mandatory = resolve_tags(view[:candidates], request.args['mandatory_tags'])
      return mandatory if mandatory[:error]
      optional = resolve_tags(view[:candidates], request.args['optional_tags'])
      return optional if optional[:error]

      result = SoulRollApi.gm_submit_selections(
        roll_id, request.enactor, mandatory_ids: mandatory[:ids], optional_ids: optional[:ids]
      )
      result[:error] ? result : { success: true, pending_roll: pending_hash(result[:pending_roll]) }
    end

    def resolve_tags(candidates, raw_tags)
      tags = raw_tags.kind_of?(Array) ? raw_tags : raw_tags.to_s.split(/\s+/).reject(&:blank?)
      ids = tags.map do |tag|
        candidate = candidates.find { |item| item[:tag].to_s.casecmp(tag.to_s).zero? }
        return { error: t('soul.roll_candidate_not_found', tag: tag) } unless candidate
        candidate[:id]
      end
      { ids: ids }
    end

    def pending_hash(pending)
      {
        id: pending.id, character_id: pending.character.id, character: pending.character.name,
        skill_key: pending.skill_key, aspect_key: pending.aspect_key,
        scene_id: pending.scene_id, difficulty: pending.difficulty, status: pending.status,
        gm_assisted: pending.gm_assisted, expires_at: pending.expires_at
      }
    end

    def roll_hash(roll)
      {
        id: roll.id, skill_key: roll.skill_key, aspect_key: roll.aspect_key,
        scene_id: roll.scene_id, difficulty: roll.difficulty, dice_result: roll.dice_result,
        net_modifier: roll.net_modifier, applied_modifiers: roll.applied_modifiers,
        final_result: roll.final_result, success_probability: roll.success_probability,
        degree_of_success: roll.degree_of_success, extraordinary: roll.extraordinary,
        gm_assisted: roll.gm_assisted, rolled_at: roll.rolled_at
      }
    end
  end
end

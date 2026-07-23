module AresMUSH
  class SoulXpWebHandler
    def handle(request)
      error = Website.check_login(request)
      return error if error
      enactor = request.enactor

      staff_commands = %w[soulXpAward soulXpScene soulXpCorrect]
      if staff_commands.include?(request.cmd)
        return { error: t('soul.permission_denied') } unless Soul.can_manage_soul?(enactor)
      elsif !Soul.can_play?(enactor)
        return { error: t('soul.permission_denied') }
      end

      case request.cmd
      when "soulXp"
        summary(enactor)
      when "soulXpSpend"
        spend(request)
      when "soulXpAward"
        character = Character.find_one_by_name(request.args['character'])
        SoulXpApi.award(character, request.args['amount'], source: request.args['reason'],
          apply_catchup: request.args['apply_catchup'].to_s == "true")
      when "soulXpScene"
        scene = Scene[request.args['scene_id']]
        return { error: t('soul.no_active_scene') } unless scene
        participants = SoulXpApi.get_scene_participants(scene)
        return { preview: true, recipients: participants.map(&:name) } unless request.args['confirmed'].to_s == "true"
        results = participants.map do |character|
          SoulXpApi.award(character, request.args['amount'],
            source: "scene:#{scene.id}:#{request.args['reason']}",
            idempotency_key: "scene:#{scene.id}:#{character.id}:#{request.args['reason']}",
            apply_catchup: request.args['apply_catchup'].to_s == "true")
        end
        { success: results.none? { |result| result[:error] }, results: results }
      when "soulXpCorrect"
        character = Character.find_one_by_name(request.args['character'])
        SoulXpApi.correct(character, request.args['amount'], reason: request.args['reason'], actor: enactor)
      end
    end

    def summary(character)
      {
        available: SoulXpApi.get_available_xp(character),
        earned: SoulXpApi.get_lifetime_earned_xp(character),
        spent: SoulXpApi.get_lifetime_spent_xp(character),
        catchup: SoulXpApi.get_catchup_xp_earned(character),
        history: SoulXpApi.get_history(character).map do |entry|
          {
            id: entry.id, direction: entry.direction, source: entry.source,
            base_amount: entry.base_amount, catchup_amount: entry.catchup_amount,
            created_at: entry.created_at
          }
        end
      }
    end

    def spend(request)
      character = request.enactor
      skill = request.args['skill_key']
      amount = request.args['amount'].to_i
      target = SoulCharacterApi.get_skill_rating(character, skill) + amount
      cost = SoulXpApi.calculate_cost(character, skill, target)
      unless request.args['confirmed'].to_s == "true"
        return { preview: true, skill_key: skill, target_rating: target, cost: cost }
      end
      SoulXpApi.spend(character, skill, amount, character)
    end
  end
end

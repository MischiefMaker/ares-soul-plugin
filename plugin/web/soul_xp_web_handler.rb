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
        error = results.find { |result| result[:error] }
        error || { success: true, results: results }
      when "soulXpCorrect"
        character = Character.find_one_by_name(request.args['character'])
        direction = request.args['direction'].to_s == "reversal" ? "reversal" : "correction"
        SoulXpApi.correct(character, request.args['amount'], reason: request.args['reason'],
          actor: enactor, direction: direction)
      end
    end

    def summary(character)
      {
        available: SoulXpApi.get_available_xp(character),
        earned: SoulXpApi.get_lifetime_earned_xp(character),
        spent: SoulXpApi.get_lifetime_spent_xp(character),
        catchup: SoulXpApi.get_catchup_xp_earned(character),
        history: SoulXpApi.get_history(character, limit: 5).map do |entry|
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
      trait_type = request.args['trait_type'].to_s == "aspect" ? "aspect" : "skill"
      trait_key = request.args['trait_key'] || request.args['skill_key']
      amount = request.args['amount'].to_i
      return { error: "Amount must be positive" } if amount <= 0

      trait = trait_type == "aspect" ? SoulFrameworkApi.get_aspect(trait_key) : SoulFrameworkApi.get_skill(trait_key)
      return { error: "Unknown #{trait_type}: #{trait_key}" } unless trait

      current = if trait_type == "aspect"
                  SoulCharacterApi.get_aspect_rating(character, trait_key)
                else
                  SoulCharacterApi.get_skill_rating(character, trait_key)
                end
      target = current + amount
      max_rating = trait_type == "aspect" ? SoulFrameworkApi.aspect_max_rating : SoulFrameworkApi.skill_max_rating
      return { error: "Rating would exceed the maximum of #{max_rating}" } if target > max_rating

      cost = SoulXpApi.calculate_cost(character, trait_key, target, trait_type: trait_type)
      unless request.args['confirmed'].to_s == "true"
        return {
          preview: true, trait_type: trait_type, trait_key: trait_key,
          trait_name: trait[:name], target_rating: target, cost: cost
        }
      end
      if trait_type == "aspect"
        SoulXpApi.spend_aspect(character, trait_key, amount, character)
      else
        SoulXpApi.spend(character, trait_key, amount, character)
      end
    end
  end
end

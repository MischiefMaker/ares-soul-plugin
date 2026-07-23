module AresMUSH
  class SoulCulminationWebHandler
    def handle(request)
      error = Website.check_login(request)
      return error if error

      enactor = request.enactor
      case request.cmd
      when "soulCulminations"
        character = Character.find_one_by_name(request.args['character'] || enactor.name)
        return { error: t('soul.character_not_found') } unless character
        unless (character == enactor && Soul.can_play?(enactor)) || Soul.can_manage_soul?(enactor)
          return { error: t('soul.permission_denied') }
        end
        { entries: SoulCulminationApi.get_culminations(character).map { |c| serialize(c) } }
      when "soulCulminationPropose"
        return { error: t('soul.permission_denied') } unless Soul.can_manage_soul?(enactor)
        character = Character.find_one_by_name(request.args['character'])
        result = SoulCulminationApi.propose(character,
          title: request.args['title'], description: request.args['description'],
          source: "staff", enactor: enactor)
        result[:error] ? result : { success: true, culmination: serialize(result[:culmination]) }
      when "soulCulminationApprove"
        return { error: t('soul.permission_denied') } unless Soul.can_manage_soul?(enactor)
        result = SoulCulminationApi.approve(request.args['id'], enactor)
        result[:error] ? result : { success: true, culmination: serialize(result[:culmination]) }
      end
    end

    def serialize(culmination)
      {
        id: culmination.id, character: culmination.character.name,
        title: culmination.title, description: culmination.description,
        source: culmination.source, status: culmination.status,
        created_at: culmination.created_at
      }
    end
  end
end

module AresMUSH
  class SoulHistoryWebHandler
    def handle(request)
      error = Website.check_login(request)
      return error if error

      enactor = request.enactor
      character = Character.find_one_by_name(request.args['character'] || enactor.name)
      return { error: t('soul.character_not_found') } unless character
      unless (character == enactor && Soul.can_play?(enactor)) || Soul.can_manage_soul?(enactor)
        return { error: t('soul.permission_denied') }
      end

      {
        character: character.name,
        entries: SoulNarrativeHistoryApi.get_history(character, enactor).map do |entry|
          {
            id: entry.id, event_type: entry.event_type, narrative: entry.narrative,
            created_at: entry.created_at, external_reference: entry.external_reference
          }
        end
      }
    end
  end
end

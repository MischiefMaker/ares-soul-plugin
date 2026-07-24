module AresMUSH
  class SoulStaffWebHandler
    def handle(request)
      error = Website.check_login(request)
      return error if error
      return { error: t('soul.permission_denied') } unless Soul.can_manage_soul?(request.enactor)

      case request.cmd
      when "soulFramework"
        {
          aspects: SoulFrameworkApi.get_aspects,
          skills: SoulFrameworkApi.get_skills,
          min_rating: SoulFrameworkApi.skill_min_rating,
          max_rating: SoulFrameworkApi.skill_max_rating
        }
      when "soulFrameworkCorrect"
        character = Character.find_one_by_name(request.args['character'])
        SoulCharacterApi.correct_rating(
          character, request.args['kind'], request.args['key'], request.args['rating'],
          actor: request.enactor, reason: request.args['reason']
        )
      when "soulResonance"
        character = Character.find_one_by_name(request.args['character'])
        SoulResonanceApi.correct(character, request.args['value'], actor: request.enactor,
          reason: request.args['reason'])
      when "soulReload"
        errors = Soul.check_config
        { success: errors.empty?, live_read: true, errors: errors }
      when "soulAudit"
        character = Character.find_one_by_name(request.args['character'])
        return { error: t('soul.character_not_found') } unless character
        {
          character: character.name,
          entries: SoulAuditApi.get_audit(character, request.enactor).map do |entry|
            {
              id: entry.id, action: entry.action, actor: entry.actor && entry.actor.name,
              reason: entry.reason, source: entry.source, before_state: entry.before_state,
              after_state: entry.after_state, error: entry.error, created_at: entry.created_at
            }
          end
        }
      end
    end
  end
end

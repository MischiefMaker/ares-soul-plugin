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
      when "soulResonance"
        character = Character.find_one_by_name(request.args['character'])
        SoulResonanceApi.correct(character, request.args['value'], actor: request.enactor,
          reason: request.args['reason'])
      when "soulReload"
        { success: true, live_read: true }
      end
    end
  end
end

module AresMUSH
  class SoulSheetWebHandler
    def handle(request)
      error = Website.check_login(request)
      return error if error

      enactor = request.enactor
      character = Character.find_one_by_name(request.args['character'] || enactor.name)
      return { error: t('soul.character_not_found') } unless character
      return { error: t('soul.permission_denied') } unless can_view?(enactor, character, request.args['scene_id'])
      resonance = SoulResonanceApi.get_resonance(character)
      # Explanations are private (FINAL REQ-018) - only the owner or
      # manage_soul staff get them here, never a scene-GM viewer (tier 3 of
      # can_view? below). That's a narrower privacy bar than can_view? itself
      # uses, matching the "broader reveal" caution already established for
      # GM-assisted roll review (docs/reference/Permissions.md).
      private_view = character == enactor || Soul.can_manage_soul?(enactor)

      {
        character: character.name,
        aspects: SoulFrameworkApi.get_aspects.map do |aspect|
          {
            key: aspect[:key], name: aspect[:name],
            rating: SoulCharacterApi.get_aspect_rating(character, aspect[:key]),
            skills: SoulFrameworkApi.get_skills(aspect_key: aspect[:key]).map do |skill|
              {
                key: skill[:key], name: skill[:name],
                rating: SoulCharacterApi.get_skill_rating(character, skill[:key]),
                effective_base: SoulCharacterApi.get_effective_base(character, skill[:key])
              }
            end
          }
        end,
        bnb: SoulBnbApi.get_character_entries(character).map { |entry| serialize_bnb(entry, private_view) }.compact,
        resonance: resonance,
        resonance_label: resonance.nil? ? t('soul.unset') : "R#{resonance}",
        xp: {
          available: SoulXpApi.get_available_xp(character),
          earned: SoulXpApi.get_lifetime_earned_xp(character),
          spent: SoulXpApi.get_lifetime_spent_xp(character),
          catchup: SoulXpApi.get_catchup_xp_earned(character)
        }
      }
    end

    def can_view?(enactor, character, scene_id)
      return Soul.can_play?(enactor) if enactor == character
      return true if Soul.can_manage_soul?(enactor)
      return false unless Soul.can_review_rolls?(enactor)
      scene = Scene[scene_id]
      scene && scene.participants.include?(enactor) && scene.participants.include?(character)
    end

    def serialize_bnb(entry, private_view)
      return nil unless entry.catalogue_entry
      data = {
        id: entry.id, name: entry.catalogue_entry.name, tag: entry.catalogue_entry.tag,
        kind: entry.catalogue_entry.kind, description: entry.catalogue_entry.description,
        level_state: entry.level_state, resolved: entry.resolved == "true",
        explanation_visible: private_view
      }
      data[:explanation] = entry.character_explanation if private_view
      data
    end
  end
end

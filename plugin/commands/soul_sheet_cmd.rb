module AresMUSH
  module Soul
    class SoulSheetCmd
      include CommandHandler
      include TemplateFormatters

      attr_accessor :name

      def parse_args
        self.name = cmd.args ? titlecase_arg(cmd.args) : enactor_name
      end

      def check_can_view
        return nil if self.name == enactor_name && Soul.can_play?(enactor)
        return nil if Soul.can_manage_soul?(enactor)
        return nil if Soul.can_review_rolls?(enactor)
        t('soul.permission_denied')
      end

      def required_args
        [ self.name ]
      end

      def handle
        ClassTargetFinder.with_a_character(self.name, client, enactor) do |character|
          if character != enactor && !Soul.can_manage_soul?(enactor) && !scene_participant?(character)
            client.emit_failure t('soul.permission_denied')
            return
          end

          aspects = SoulFrameworkApi.get_aspects.map do |aspect|
            skills = SoulFrameworkApi.get_skills(aspect_key: aspect[:key]).map do |skill|
              t('soul.skill_summary', name: skill[:name],
                rating: SoulCharacterApi.get_skill_rating(character, skill[:key]))
            end
            title = "#{aspect[:name]} — #{SoulCharacterApi.get_aspect_rating(character, aspect[:key])}"
            section = client.screen_reader ? "%xh#{title}%xn" : line_with_text(title)
            "#{section}%r#{skills.join('%r')}"
          end
          bnb = SoulBnbApi.get_character_entries(character).map do |entry|
            next unless entry.catalogue_entry
            t('soul.bnb_summary', name: entry.catalogue_entry.name, level: entry.level_state)
          end.compact
          resonance = SoulResonanceApi.get_resonance(character)
          body = t('soul.sheet',
            name: character.name,
            framework: aspects.join("%r"),
            bnb: bnb.empty? ? t('soul.none') : bnb.join(', '),
            resonance: resonance.nil? ? t('soul.unset') : "R#{resonance}",
            available: SoulXpApi.get_available_xp(character),
            earned: SoulXpApi.get_lifetime_earned_xp(character),
            spent: SoulXpApi.get_lifetime_spent_xp(character))
          client.emit BorderedDisplayTemplate.new(
            body, t('soul.sheet_title', name: character.name)
          ).render
        end
      end

      def scene_participant?(character)
        scene = enactor_room && enactor_room.scene
        scene && scene.participants.include?(enactor) && scene.participants.include?(character)
      end
    end
  end
end

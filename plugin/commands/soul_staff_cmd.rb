module AresMUSH
  module Soul
    class SoulStaffCmd
      include CommandHandler

      attr_accessor :name, :value, :reason, :rating_key

      def parse_args
        if %w[framework/skill framework/aspect].include?(cmd.switch)
          self.name, details = cmd.args.to_s.split("=", 2)
          key, rating, reason = details.to_s.split("/", 3)
          self.rating_key, self.value, self.reason = key, integer_arg(rating), reason
        elsif cmd.switch == "resonance"
          args = cmd.parse_args(ArgParser.arg1_equals_arg2_slash_arg3)
          self.name, self.value, self.reason = args.arg1, integer_arg(args.arg2), args.arg3
        elsif cmd.switch == "audit"
          self.name = cmd.args.to_s.strip
        end
      end

      def check_permission
        Soul.can_manage_soul?(enactor) ? nil : t('soul.permission_denied')
      end

      def required_args
        case cmd.switch
        when "framework/skill", "framework/aspect"
          [ self.name, self.rating_key, self.value, self.reason ]
        when "resonance"
          [ self.name, self.value, self.reason ]
        when "audit"
          [ self.name ]
        else
          []
        end
      end

      def handle
        case cmd.switch
        when "framework"
          aspects = SoulFrameworkApi.get_aspects.map do |aspect|
            skills = SoulFrameworkApi.get_skills(aspect_key: aspect[:key]).map do |skill|
              t('soul.framework_skill', name: skill[:name], key: skill[:key])
            end
            t('soul.framework_aspect', name: aspect[:name], key: aspect[:key],
              skills: skills.join(', '))
          end
          client.emit BorderedListTemplate.new(aspects, t('soul.framework_title')).render
        when "framework/skill", "framework/aspect"
          ClassTargetFinder.with_a_character(self.name, client, enactor) do |character|
            kind = cmd.switch.split('/').last
            result = SoulCharacterApi.correct_rating(
              character, kind, self.rating_key, self.value, actor: enactor, reason: self.reason
            )
            if result[:error]
              client.emit_failure result[:error]
            else
              client.emit_success t('soul.framework_corrected', kind: kind.capitalize,
                key: self.rating_key, old: result[:old_rating], new: result[:new_rating])
            end
          end
        when "resonance"
          ClassTargetFinder.with_a_character(self.name, client, enactor) do |character|
            emit_result SoulResonanceApi.correct(character, self.value, actor: enactor, reason: self.reason)
          end
        when "reload"
          errors = Soul.check_config
          if errors.empty?
            client.emit_success t('soul.config_live')
          else
            client.emit_failure t('soul.config_invalid', errors: errors.join("%r"))
          end
        when "audit"
          ClassTargetFinder.with_a_character(self.name, client, enactor) do |character|
            lines = SoulAuditApi.get_audit(character, enactor).map do |entry|
              t('soul.audit_line', at: entry.created_at, action: entry.action,
                actor: entry.actor ? entry.actor.name : t('soul.system_actor'),
                reason: entry.reason.blank? ? t('soul.none') : entry.reason)
            end
            client.emit BorderedListTemplate.new(
              lines.empty? ? [t('soul.none')] : lines,
              t('soul.audit_title', name: character.name)
            ).render
          end
        end
      end

      def emit_result(result)
        result[:error] ? client.emit_failure(result[:error]) : client.emit_success(t('soul.resonance_corrected'))
      end
    end
  end
end

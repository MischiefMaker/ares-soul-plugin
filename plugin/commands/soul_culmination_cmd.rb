module AresMUSH
  module Soul
    class SoulCulminationCmd
      include CommandHandler

      attr_accessor :name, :title, :description, :culmination_id, :reason

      def parse_args
        case cmd.switch
        when "propose"
          args = cmd.parse_args(ArgParser.arg1_equals_arg2_slash_arg3)
          self.name, self.title, self.description = args.arg1, args.arg2, args.arg3
        when "approve"
          self.culmination_id = integer_arg(cmd.args)
        when "deny", "revoke"
          args = cmd.parse_args(ArgParser.arg1_equals_arg2)
          self.culmination_id, self.reason = integer_arg(args.arg1), args.arg2
        when "correct"
          args = cmd.parse_args(/(?<id>[^=]+)=(?<title>[^\/]*)\/(?<description>[^\/]*)\/(?<reason>.+)/)
          self.culmination_id = integer_arg(args.id)
          self.title = args.title.to_s.blank? ? nil : args.title
          self.description = args.description.to_s.blank? ? nil : args.description
          self.reason = args.reason
        else
          self.name = cmd.args ? titlecase_arg(cmd.args) : enactor_name
        end
      end

      def check_permission
        if %w[propose approve deny revoke correct].include?(cmd.switch)
          return t('soul.permission_denied') unless Soul.can_manage_soul?(enactor)
        elsif self.name != enactor_name && !Soul.can_manage_soul?(enactor)
          return t('soul.permission_denied')
        elsif !Soul.can_play?(enactor) && !Soul.can_manage_soul?(enactor)
          return t('soul.permission_denied')
        end
        nil
      end

      def required_args
        case cmd.switch
        when "propose"
          [ self.name, self.title, self.description ]
        when "approve"
          [ self.culmination_id ]
        when "deny", "revoke"
          [ self.culmination_id, self.reason ]
        when "correct"
          [ self.culmination_id, self.reason ]
        else
          [ self.name ]
        end
      end

      def handle
        case cmd.switch
        when "approve"
          emit_result SoulCulminationApi.approve(self.culmination_id, enactor), 'soul.culmination_approved'
          return
        when "deny"
          emit_result SoulCulminationApi.deny(self.culmination_id, enactor, reason: self.reason), 'soul.culmination_denied'
          return
        when "revoke"
          emit_result SoulCulminationApi.revoke(self.culmination_id, enactor, reason: self.reason), 'soul.culmination_revoked'
          return
        when "correct"
          result = SoulCulminationApi.correct(self.culmination_id, enactor,
            title: self.title, description: self.description, reason: self.reason)
          emit_result result, 'soul.culmination_corrected'
          return
        end

        ClassTargetFinder.with_a_character(self.name, client, enactor) do |character|
          if cmd.switch == "propose"
            result = SoulCulminationApi.propose(character, title: self.title,
              description: self.description, source: "staff", enactor: enactor)
            emit_result result, 'soul.culmination_proposed'
          else
            entries = SoulCulminationApi.get_culminations(character)
            lines = entries.map do |c|
              t('soul.culmination_line', id: c.id, status: c.status,
                title: c.title, description: c.description)
            end
            client.emit BorderedListTemplate.new(
              lines.empty? ? [t('soul.none')] : lines,
              t('soul.culminations_title', name: character.name)
            ).render
          end
        end
      end

      def emit_result(result, key)
        if result[:error]
          client.emit_failure result[:error]
        else
          client.emit_success t(key)
        end
      end
    end
  end
end

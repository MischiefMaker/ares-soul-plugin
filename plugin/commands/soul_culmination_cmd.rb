module AresMUSH
  module Soul
    class SoulCulminationCmd
      include CommandHandler

      attr_accessor :name, :title, :description, :culmination_id

      def parse_args
        case cmd.switch
        when "propose"
          args = cmd.parse_args(ArgParser.arg1_equals_arg2_slash_arg3)
          self.name, self.title, self.description = args.arg1, args.arg2, args.arg3
        when "approve"
          self.culmination_id = integer_arg(cmd.args)
        else
          self.name = cmd.args ? titlecase_arg(cmd.args) : enactor_name
        end
      end

      def check_permission
        if %w[propose approve].include?(cmd.switch)
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
        else
          [ self.name ]
        end
      end

      def handle
        if cmd.switch == "approve"
          emit_result SoulCulminationApi.approve(self.culmination_id, enactor), 'soul.culmination_approved'
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
            client.emit t('soul.culminations', name: character.name,
              entries: lines.empty? ? t('soul.none') : lines.join("%r"))
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

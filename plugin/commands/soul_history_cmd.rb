module AresMUSH
  module Soul
    class SoulHistoryCmd
      include CommandHandler

      attr_accessor :name

      def parse_args
        self.name = cmd.args ? titlecase_arg(cmd.args) : enactor_name
      end

      def check_can_view
        return nil if self.name == enactor_name && Soul.can_play?(enactor)
        return nil if Soul.can_manage_soul?(enactor)
        t('soul.permission_denied')
      end

      def handle
        ClassTargetFinder.with_a_character(self.name, client, enactor) do |character|
          history = SoulNarrativeHistoryApi.get_history(character, enactor)
          lines = history.map do |entry|
            t('soul.history_line', at: entry.created_at, narrative: entry.narrative)
          end
          client.emit BorderedListTemplate.new(
            lines.empty? ? [t('soul.none')] : lines,
            t('soul.history_title', name: character.name)
          ).render
        end
      end
    end
  end
end

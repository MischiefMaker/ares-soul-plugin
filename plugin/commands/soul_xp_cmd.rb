module AresMUSH
  module Soul
    class SoulXpCmd
      include CommandHandler

      attr_accessor :name, :skill, :amount, :reason, :scene_id, :confirmed

      def parse_args
        self.confirmed = cmd.args.to_s.end_with?("/confirm")
        raw = cmd.args.to_s.sub(/\/confirm\z/, '')
        case cmd.switch
        when "spend"
          args = ArgParser.parse(ArgParser.arg1_equals_arg2, raw)
          self.skill, self.amount = args.arg1, integer_arg(args.arg2)
        when "award", "award/catchup", "correct", "reverse"
          args = ArgParser.parse(ArgParser.arg1_equals_arg2_slash_arg3, raw)
          self.name, self.amount, self.reason = args.arg1, integer_arg(args.arg2), args.arg3
        when "scene", "scene/catchup"
          if raw.include?("=")
            args = ArgParser.parse(ArgParser.arg1_equals_arg2_slash_arg3, raw)
            self.scene_id, self.amount, self.reason = integer_arg(args.arg1), integer_arg(args.arg2), args.arg3
          else
            args = ArgParser.parse(ArgParser.arg1_slash_arg2, raw)
            self.amount, self.reason = integer_arg(args.arg1), args.arg2
          end
        end
      end

      def check_permission
        staff_switches = %w[award award/catchup scene scene/catchup correct reverse]
        return t('soul.permission_denied') if staff_switches.include?(cmd.switch) && !Soul.can_manage_soul?(enactor)
        return t('soul.permission_denied') if !staff_switches.include?(cmd.switch) && !Soul.can_play?(enactor)
        nil
      end

      def required_args
        case cmd.switch
        when "spend"
          [ self.skill, self.amount ]
        when "award", "award/catchup", "correct", "reverse"
          [ self.name, self.amount, self.reason ]
        when "scene", "scene/catchup"
          [ self.amount, self.reason ]
        else
          []
        end
      end

      def handle
        case cmd.switch
        when nil
          show_xp
        when "history"
          show_history
        when "spend"
          spend_xp
        when "award", "award/catchup", "correct", "reverse"
          with_character { |character| award_or_correct(character) }
        when "scene", "scene/catchup"
          scene_award
        end
      end

      def show_xp
        client.emit t('soul.xp_summary',
          available: SoulXpApi.get_available_xp(enactor),
          earned: SoulXpApi.get_lifetime_earned_xp(enactor),
          spent: SoulXpApi.get_lifetime_spent_xp(enactor),
          catchup: SoulXpApi.get_catchup_xp_earned(enactor))
      end

      def show_history
        lines = SoulXpApi.get_history(enactor).map do |entry|
          t('soul.xp_history_line', at: entry.created_at, direction: entry.direction,
            amount: entry.base_amount, source: entry.source)
        end
        client.emit t('soul.xp_history', entries: lines.empty? ? t('soul.none') : lines.join("%r"))
      end

      def spend_xp
        skill_data = SoulFrameworkApi.get_skill(self.skill)
        unless skill_data
          client.emit_failure t('soul.invalid_skill')
          return
        end
        target = SoulCharacterApi.get_skill_rating(enactor, self.skill) + self.amount.to_i
        cost = SoulXpApi.calculate_cost(enactor, self.skill, target)
        unless self.confirmed
          client.emit t('soul.xp_spend_preview', skill: skill_data[:name], target: target, cost: cost)
          return
        end
        emit_result SoulXpApi.spend(enactor, self.skill, self.amount, enactor), 'soul.xp_spent'
      end

      def award_or_correct(character)
        if %w[correct reverse].include?(cmd.switch)
          direction = cmd.switch == "reverse" ? "reversal" : "correction"
          result = SoulXpApi.correct(character, self.amount, reason: self.reason,
            actor: enactor, direction: direction)
        else
          result = SoulXpApi.award(character, self.amount, source: self.reason,
            apply_catchup: cmd.switch == "award/catchup")
        end
        emit_result result, 'soul.xp_awarded'
      end

      def scene_award
        scene = self.scene_id ? Scene[self.scene_id] : (enactor_room && enactor_room.scene)
        participants = SoulXpApi.get_scene_participants(scene)
        if participants.empty?
          client.emit_failure t('soul.no_scene_participants')
          return
        end
        unless self.confirmed
          client.emit t('soul.scene_xp_preview', names: participants.map(&:name).join(', '))
          return
        end
        results = participants.map do |character|
          SoulXpApi.award(character, self.amount, source: "scene:#{scene.id}:#{self.reason}",
            idempotency_key: "scene:#{scene.id}:#{character.id}:#{self.reason}",
            apply_catchup: cmd.switch == "scene/catchup")
        end
        error = results.find { |result| result[:error] }
        emit_result(error || { success: true }, 'soul.xp_awarded')
      end

      def with_character(&block)
        ClassTargetFinder.with_a_character(self.name, client, enactor, &block)
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

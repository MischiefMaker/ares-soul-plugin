module AresMUSH
  module Soul
    class SoulRollCmd
      include CommandHandler

      attr_accessor :raw, :roll_id, :reason, :skill, :difficulty,
                    :mandatory_tags, :optional_tags, :mark_payload

      def parse_args
        self.raw = cmd.args.to_s.strip
        case cmd.switch
        when "gm"
          self.skill, self.difficulty = self.raw.split("=", 2)
          self.difficulty ||= "standard"
        when "abort", "forceabort"
          id, self.reason = self.raw.split("=", 2)
          self.roll_id = integer_arg(id)
        when "review"
          self.roll_id = integer_arg(self.raw) unless self.raw.blank?
        when "mark"
          id, self.mark_payload = self.raw.split("=", 2)
          self.roll_id = integer_arg(id)
          mandatory, optional = self.mark_payload.to_s.split("/", 2)
          self.mandatory_tags = split_tags(mandatory)
          self.optional_tags = split_tags(optional)
        end
      end

      def check_permission
        player_switches = [nil, "gm", "abort", "pending", "history"]
        return t('soul.permission_denied') if player_switches.include?(cmd.switch) && !Soul.can_play?(enactor)
        nil
      end

      def required_args
        case cmd.switch
        when "gm"
          [ self.skill ]
        when "abort", "forceabort"
          [ self.roll_id, self.reason ]
        when "mark"
          [ self.roll_id, self.mark_payload ]
        else
          []
        end
      end

      def handle
        case cmd.switch
        when nil then handle_bare_roll
        when "gm" then start_roll(true)
        when "abort" then emit_simple_result(SoulRollApi.abort_pending(self.roll_id, enactor, reason: self.reason))
        when "forceabort" then emit_simple_result(SoulRollApi.force_abort_pending(self.roll_id, enactor, reason: self.reason))
        when "pending" then show_pending
        when "history" then show_history
        when "review" then review_rolls
        when "mark" then mark_roll
        end
      end

      def handle_bare_roll
        pending = SoulRollApi.get_open_pending_for_selection(enactor)
        if self.raw.blank?
          show_status(pending || SoulRollApi.get_open_pending_rolls(enactor).first)
        elsif self.raw.casecmp("suggested").zero?
          select_and_resolve(pending, suggested: true)
        elsif self.raw.casecmp("none").zero?
          select_and_resolve(pending, none: true)
        elsif pending
          select_and_resolve(pending, tags: split_tags(self.raw))
        else
          self.skill, self.difficulty = self.raw.split("=", 2)
          self.difficulty ||= "standard"
          start_roll(false)
        end
      end

      def start_roll(gm_requested)
        scene = enactor_room && enactor_room.scene
        result = SoulRollApi.start_roll(
          enactor,
          self.skill,
          context: { difficulty: self.difficulty, scene_id: scene && scene.id },
          gm_requested: gm_requested
        )
        if result[:error]
          client.emit_failure result[:error]
        else
          pending = result[:pending_roll]
          client.emit_success t('soul.roll_started', id: pending.id, status: pending.status)
        end
      end

      def select_and_resolve(pending, tags: [], suggested: false, none: false)
        unless pending
          client.emit_failure t('soul.no_pending_selection')
          return
        end

        selected = SoulRollApi.select_entries(
          pending.id, enactor, tags: tags, suggested: suggested, none: none
        )
        if selected[:error]
          client.emit_failure selected[:error]
          return
        end
        emit_roll_result SoulRollApi.resolve_pending(pending.id, enactor)
      end

      def show_status(pending)
        unless pending
          client.emit t('soul.no_open_pending')
          return
        end
        client.emit t('soul.roll_pending_line', id: pending.id, skill: pending.skill_key,
          status: pending.status, gm_assisted: pending.gm_assisted)
      end

      def show_pending
        lines = SoulRollApi.get_open_pending_rolls(enactor).map do |pending|
          t('soul.roll_pending_line', id: pending.id, skill: pending.skill_key,
            status: pending.status, gm_assisted: pending.gm_assisted)
        end
        client.emit t('soul.roll_pending', entries: lines.empty? ? t('soul.none') : lines.join("%r"))
      end

      def show_history
        lines = SoulRollApi.get_roll_history(enactor).map { |roll| roll_line(roll) }
        client.emit t('soul.roll_history', entries: lines.empty? ? t('soul.none') : lines.join("%r"))
      end

      def review_rolls
        if self.roll_id
          result = SoulRollApi.get_gm_candidate_view(self.roll_id, enactor)
          if result[:error]
            client.emit_failure result[:error]
          else
            lines = result[:candidates].map { |candidate| candidate_line(candidate) }
            client.emit t('soul.roll_candidates',
              entries: lines.empty? ? t('soul.none') : lines.join("%r"))
          end
          return
        end

        scene = enactor_room && enactor_room.scene
        unless scene
          client.emit_failure t('soul.no_active_scene_short')
          return
        end
        authorized = Soul.can_manage_soul?(enactor) ||
          (Soul.can_review_rolls?(enactor) && scene.is_participant?(enactor))
        unless authorized
          client.emit_failure t('soul.permission_denied')
          return
        end
        lines = SoulRollApi.get_pending_gm_review(scene).map do |pending|
          t('soul.roll_review_line', id: pending.id, character: pending.character.name,
            skill: pending.skill_key)
        end
        client.emit t('soul.roll_reviews', entries: lines.empty? ? t('soul.none') : lines.join("%r"))
      end

      def mark_roll
        view = SoulRollApi.get_gm_candidate_view(self.roll_id, enactor)
        if view[:error]
          client.emit_failure view[:error]
          return
        end
        mandatory = resolve_candidate_tags(view[:candidates], self.mandatory_tags)
        return if mandatory.nil?
        optional = resolve_candidate_tags(view[:candidates], self.optional_tags)
        return if optional.nil?

        result = SoulRollApi.gm_submit_selections(
          self.roll_id, enactor, mandatory_ids: mandatory, optional_ids: optional
        )
        emit_simple_result(result)
      end

      def resolve_candidate_tags(candidates, tags)
        tags.map do |tag|
          candidate = candidates.find { |item| item[:tag].to_s.casecmp(tag).zero? }
          unless candidate
            client.emit_failure t('soul.roll_candidate_not_found', tag: tag)
            return nil
          end
          candidate[:id]
        end
      end

      def split_tags(value)
        value.to_s.split(/\s+/).reject(&:blank?)
      end

      def emit_simple_result(result)
        result[:error] ? client.emit_failure(result[:error]) : client.emit_success(t('soul.roll_updated'))
      end

      def emit_roll_result(result)
        if result[:error]
          client.emit_failure result[:error]
        else
          client.emit_success roll_line(result[:roll])
        end
      end

      def roll_line(roll)
        t('soul.roll_result', id: roll.id, skill: roll.skill_key, result: roll.final_result,
          degree: roll.degree_of_success, extraordinary: roll.extraordinary)
      end

      def candidate_line(candidate)
        details = candidate.reject { |key, _| [:id, :tag].include?(key) }
          .map { |key, value| "#{key}=#{value}" }.join(", ")
        t('soul.roll_candidate_line', id: candidate[:id], tag: candidate[:tag], details: details)
      end
    end
  end
end

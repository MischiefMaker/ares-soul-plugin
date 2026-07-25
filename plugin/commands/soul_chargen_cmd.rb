module AresMUSH
  module Soul
    class SoulChargenCmd
      include CommandHandler
      include TemplateFormatters

      attr_accessor :value, :skill, :aspect, :rating, :reference, :level,
                    :explanation, :entry_ref, :skill_associations

      # Dispatched under the "soul" root as a compound switch ("cg",
      # "cg/resonance", "cg/skill", "cg/bnb", "cg/drop") - not its own
      # "chargen" root. Core AresMUSH's own chargen.yml defines a
      # built-in shortcut, `chargen: cg`, that rewrites the literal word
      # "chargen" to "cg" before command dispatch ever sees it - so a
      # SOUL-owned "+chargen" root is permanently unreachable on any
      # stock game, shadowed by core's own chargen review flow (found
      # during internal testing, 2026-07-24 - see docs/development/
      # Bug_List.md BUG-004). "cg" is namespaced under "soul" (not a
      # bare root of its own) specifically so it can't collide with that
      # same core shortcut a second time.
      def sub_switch
        cmd.switch.to_s.sub(/\Acg\/?/, '')
      end

      def parse_args
        case sub_switch
        when "resonance"
          self.value = integer_arg(cmd.args)
        when "skill"
          args = cmd.parse_args(ArgParser.arg1_equals_arg2)
          self.skill, self.rating = args.arg1, integer_arg(args.arg2)
        when "aspect"
          args = cmd.parse_args(ArgParser.arg1_equals_arg2)
          self.aspect, self.rating = args.arg1, integer_arg(args.arg2)
        when "bnb"
          # +soul/cg/bnb <id or tag>/<level>/<skill1,skill2,...>=<explanation>
          left, self.explanation = cmd.args.to_s.split("=", 2)
          self.reference, self.level, skills_raw = left.to_s.split("/", 3)
          self.level ||= "minor"
          self.skill_associations = skills_raw.to_s.split(",").map(&:strip).reject(&:blank?)
        when "drop"
          # Accepts either the entry ID shown in +soul/cg's status listing
          # or the catalogue entry's tag (SoulBnbApi.drop_chargen_selection
          # handles both) - matches "id or tag" everywhere else in this
          # project, unlike the numeric-only syntax this used to require.
          self.entry_ref = cmd.args.to_s
        end
      end

      # Deliberately does NOT gate on Soul.can_play? - chargen is only ever
      # usable by a character that has NOT been approved yet, and can_play?
      # (BUG-002, 2026-07-24) now defaults to Character#is_approved?, which
      # is the exact opposite of who this command is for. The is_approved?
      # check below is chargen's own, correct gate: block already-approved
      # characters, allow everyone still going through chargen.
      def check_permission
        return t('soul.chargen_approved') if enactor.is_approved?
        nil
      end

      def required_args
        case sub_switch
        when "resonance" then [ self.value ]
        when "skill" then [ self.skill, self.rating ]
        when "aspect" then [ self.aspect, self.rating ]
        when "bnb" then [ self.reference, self.explanation ]
        when "drop" then [ self.entry_ref ]
        else []
        end
      end

      def handle
        case sub_switch
        when "" then show_status
        when "resonance" then emit_result SoulResonanceApi.set_resonance(enactor, self.value, enactor)
        when "skill" then set_skill
        when "aspect" then set_aspect
        when "bnb"
          emit_result SoulBnbApi.grant(enactor, self.reference, level_state: self.level,
            source: "chargen", explanation: self.explanation,
            associated_skills: self.skill_associations.presence)
        when "catalogue" then show_catalogue
        when "drop" then emit_result SoulBnbApi.drop_chargen_selection(self.entry_ref, enactor)
        end
      end

      def set_skill
        result = SoulChargenWebHandler.set_skill(enactor, self.skill, self.rating)
        emit_result result
      end

      def set_aspect
        result = SoulChargenWebHandler.set_aspect(enactor, self.aspect, self.rating)
        emit_result result
      end

      def show_catalogue
        entries = SoulBnbApi.get_catalogue(chargen_available: true)
        lines = entries.map do |entry|
          skill_names = (entry.skill_associations || []).map do |key|
            SoulFrameworkApi.get_skill(key)&.dig(:name) || key
          end
          t('soul.chargen_catalogue_line',
            id: entry.id, tag: entry.tag, name: entry.name, kind: entry.kind,
            description: entry.description,
            skills: skill_names.empty? ? t('soul.none') : skill_names.join(", "))
        end
        client.emit BorderedListTemplate.new(
          lines.empty? ? [t('soul.none')] : lines,
          t('soul.chargen_catalogue_title')
        ).render
      end

      def show_status
        status = SoulChargenWebHandler.status(enactor)
        skills = status[:aspects].map do |aspect|
          title = "#{aspect[:name]} [#{aspect[:key]}]: #{aspect[:rating]}"
          section = client.screen_reader ? "%xh#{title}%xn" : line_with_text(title)
          aspect_skills = status[:skills].select { |skill| skill[:aspect_key] == aspect[:key] }
            .map { |skill| "#{skill[:name]} [#{skill[:key]}]: #{skill[:rating]}" }
          "#{section}%r#{aspect_skills.join('%r')}"
        end
        entries = status[:selected_bnb].map do |entry|
          "##{entry[:id]} [#{entry[:tag]}] #{entry[:name]} (#{entry[:level_state]})"
        end
        readiness = [
          checklist_line("Skill points fully spent", status[:skill_points_fully_spent]),
          checklist_line("Aspect points fully spent", status[:aspect_points_fully_spent]),
          checklist_line("Boon/Bane ratio satisfied", status[:bnb_ratio_satisfied])
        ].join("%r")
        body = t('soul.chargen_status',
          resonance: status[:resonance].nil? ? t('soul.unset') : "R#{status[:resonance]}",
          spent: status[:points_spent], remaining: status[:points_remaining],
          aspect_spent: status[:aspect_points_spent], aspect_remaining: status[:aspect_points_remaining],
          skills: skills.join("%r"), bnb: entries.empty? ? t('soul.none') : entries.join("%r"),
          readiness: readiness)
        client.emit BorderedDisplayTemplate.new(body, t('soul.chargen_title')).render
      end

      def emit_result(result)
        result[:error] ? client.emit_failure(result[:error]) : client.emit_success(t('soul.chargen_updated'))
      end

      # Informational readiness indicators only - approval is never blocked
      # on these (see the comment on SoulChargenWebHandler.status).
      def checklist_line(label, satisfied)
        satisfied ? "%xg#{label}: Yes%xn" : "%xr#{label}: No%xn"
      end
    end
  end
end

module AresMUSH
  module Soul
    class SoulChargenCmd
      include CommandHandler
      include TemplateFormatters

      attr_accessor :value, :skill, :rating, :reference, :level,
                    :explanation, :entry_id

      def parse_args
        case cmd.switch
        when "resonance"
          self.value = integer_arg(cmd.args)
        when "skill"
          args = cmd.parse_args(ArgParser.arg1_equals_arg2)
          self.skill, self.rating = args.arg1, integer_arg(args.arg2)
        when "bnb"
          left, self.explanation = cmd.args.to_s.split("=", 2)
          self.reference, self.level = left.to_s.split("/", 2)
          self.level ||= "minor"
        when "drop"
          self.entry_id = integer_arg(cmd.args)
        end
      end

      def check_permission
        return t('soul.permission_denied') unless Soul.can_play?(enactor)
        return t('soul.chargen_approved') if enactor.is_approved?
        nil
      end

      def required_args
        case cmd.switch
        when "resonance" then [ self.value ]
        when "skill" then [ self.skill, self.rating ]
        when "bnb" then [ self.reference, self.explanation ]
        when "drop" then [ self.entry_id ]
        else []
        end
      end

      def handle
        case cmd.switch
        when nil then show_status
        when "resonance" then emit_result SoulResonanceApi.set_resonance(enactor, self.value, enactor)
        when "skill" then set_skill
        when "bnb"
          emit_result SoulBnbApi.grant(enactor, self.reference, level_state: self.level,
            source: "chargen", explanation: self.explanation)
        when "drop" then emit_result SoulBnbApi.drop_chargen_selection(self.entry_id, enactor)
        end
      end

      def set_skill
        result = SoulChargenWebHandler.set_skill(enactor, self.skill, self.rating)
        emit_result result
      end

      def show_status
        status = SoulChargenWebHandler.status(enactor)
        skills = status[:aspects].map do |aspect|
          title = aspect[:name]
          section = client.screen_reader ? "%xh#{title}%xn" : line_with_text(title)
          aspect_skills = status[:skills].select { |skill| skill[:aspect_key] == aspect[:key] }
            .map { |skill| "#{skill[:name]} [#{skill[:key]}]: #{skill[:rating]}" }
          "#{section}%r#{aspect_skills.join('%r')}"
        end
        entries = status[:selected_bnb].map do |entry|
          "##{entry[:id]} [#{entry[:tag]}] #{entry[:name]} (#{entry[:level_state]})"
        end
        body = t('soul.chargen_status',
          resonance: status[:resonance].nil? ? t('soul.unset') : "R#{status[:resonance]}",
          spent: status[:points_spent], remaining: status[:points_remaining],
          skills: skills.join("%r"), bnb: entries.empty? ? t('soul.none') : entries.join("%r"))
        client.emit BorderedDisplayTemplate.new(body, t('soul.chargen_title')).render
      end

      def emit_result(result)
        result[:error] ? client.emit_failure(result[:error]) : client.emit_success(t('soul.chargen_updated'))
      end
    end
  end
end

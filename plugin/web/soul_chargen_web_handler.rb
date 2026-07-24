module AresMUSH
  class SoulChargenWebHandler
    def handle(request)
      error = Website.check_login(request)
      return error if error
      character = request.enactor
      # Deliberately does NOT gate on Soul.can_play? - see the matching
      # comment on SoulChargenCmd#check_permission (BUG-002/BUG-005,
      # 2026-07-24). Chargen is only for characters that are NOT approved
      # yet, the opposite of what can_play? now checks by default.
      return { error: t('soul.chargen_approved') } if character.is_approved?

      case request.cmd
      when "soulChargenStatus"
        self.class.status(character)
      when "soulChargenResonance"
        result = SoulResonanceApi.set_resonance(character, request.args['value'], character)
        result[:error] ? result : self.class.status(character)
      when "soulChargenSkill"
        result = self.class.set_skill(character, request.args['skill_key'], request.args['rating'].to_i)
        result[:error] ? result : self.class.status(character)
      when "soulChargenBnb"
        result = SoulBnbApi.grant(character, request.args['reference'],
          level_state: request.args['level_state'] || "minor", source: "chargen",
          explanation: request.args['explanation'])
        result[:error] ? result : self.class.status(character)
      when "soulChargenDrop"
        result = SoulBnbApi.drop_chargen_selection(request.args['entry_id'], character)
        result[:error] ? result : self.class.status(character)
      end
    end

    def self.status(character)
      resonance = SoulResonanceApi.get_resonance(character)
      allowance = SoulResonanceApi.chargen_allowance(resonance || 0)
      skills = SoulFrameworkApi.get_skills.map do |skill|
        skill.merge(rating: SoulCharacterApi.get_skill_rating(character, skill[:key]))
      end
      selected = SoulBnbApi.get_character_entries(character).select { |entry| entry.source == "chargen" }
      spent = skills.sum { |skill| skill[:rating].to_i }
      {
        resonance_enabled: SoulResonanceApi.enabled?, resonance: resonance,
        resonance_label: resonance.nil? ? t('soul.unset') : "R#{resonance}",
        resonance_min: SoulResonanceApi.min, resonance_max: SoulResonanceApi.max,
        resonance_options: (SoulResonanceApi.min..SoulResonanceApi.max).to_a,
        skill_points: allowance[:skill_points], starting_cap: allowance[:starting_cap],
        points_spent: spent, points_remaining: allowance[:skill_points] - spent,
        aspects: SoulFrameworkApi.get_aspects, skills: skills,
        catalogue: SoulBnbApi.get_catalogue(chargen_available: true).map { |entry| catalogue_hash(entry) },
        selected_bnb: selected.map { |entry| selected_hash(entry) },
        has_selected_bnb: selected.any?
      }
    end

    def self.set_skill(character, skill_key, rating)
      resonance = SoulResonanceApi.get_resonance(character) || 0
      allowance = SoulResonanceApi.chargen_allowance(resonance)
      return { error: "Rating exceeds the chargen starting cap of #{allowance[:starting_cap]}." } if
        rating.to_i > allowance[:starting_cap]

      current = SoulFrameworkApi.get_skills.sum do |skill|
        SoulCharacterApi.get_skill_rating(character, skill[:key])
      end
      old_rating = SoulCharacterApi.get_skill_rating(character, skill_key)
      proposed = current - old_rating + rating.to_i
      return { error: "That allocation would spend #{proposed} of #{allowance[:skill_points]} Skill points." } if
        proposed > allowance[:skill_points]

      SoulCharacterApi.set_skill_rating(character, skill_key, rating.to_i, character)
    end

    def self.catalogue_hash(entry)
      {
        id: entry.id, tag: entry.tag, name: entry.name, description: entry.description,
        kind: entry.kind
      }
    end

    def self.selected_hash(entry)
      {
        id: entry.id, tag: entry.catalogue_entry.tag, name: entry.catalogue_entry.name,
        kind: entry.catalogue_entry.kind, level_state: entry.level_state,
        explanation: entry.character_explanation
      }
    end
  end
end

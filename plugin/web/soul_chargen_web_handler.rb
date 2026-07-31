module AresMUSH
  class SoulChargenWebHandler
    def handle(request)
      error = Website.check_login(request)
      return error if error
      character = self.class.resolve_character(request)
      return { error: t('soul.permission_denied') } unless character

      case request.cmd
      when "soulChargenStatus"
        self.class.status(character)
      when "soulChargenResonance"
        result = SoulResonanceApi.set_resonance(character, request.args['value'], request.enactor)
        result[:error] ? result : self.class.status(character)
      when "soulChargenSkill"
        result = self.class.set_skill(character, request.args['skill_key'], request.args['rating'].to_i)
        result[:error] ? result : self.class.status(character).merge(warning: result[:warning])
      when "soulChargenAspect"
        result = self.class.set_aspect(character, request.args['aspect_key'], request.args['rating'].to_i)
        result[:error] ? result : self.class.status(character).merge(warning: result[:warning])
      when "soulChargenBnb"
        result = SoulBnbApi.grant(character, request.args['reference'],
          level_state: request.args['level_state'] || "minor", source: "chargen",
          explanation: request.args['explanation'],
          associated_skills: request.args['associated_skills'].presence)
        result[:error] ? result : self.class.status(character)
      when "soulChargenDrop"
        result = SoulBnbApi.drop_chargen_selection(request.args['entry_id'], character)
        result[:error] ? result : self.class.status(character)
      end
    end

    # Which character this request operates on. Mirrors the real targeting/
    # permission pattern AresMUSH core itself uses for admin-run chargen
    # (plugins/chargen/web/chargen_char_request_handler.rb: staff who
    # can_approve? may load any character by id; everyone else only
    # themselves) - staff run chargen for an applicant through the game's
    # own /chargen/:id page (the SOUL tab installed via chargen-custom.
    # snippet.hbs), not a SOUL-specific URL. Without this, the SOUL tab had
    # no way to know which character that page was showing and always fell
    # back to request.enactor - the logged-in staff member's own character
    # (2026-07-31 live testing: an admin walking an applicant through
    # chargen via /chargen/8 was silently editing their own Resonance/
    # Skills/B&Bs instead of the applicant's).
    #
    # request.args['character_id'] is only present when the web component
    # was handed a target character (see soul-chargen.js) - a normal
    # player's own chargen page never sends it, so this is a no-op for the
    # overwhelmingly common case. `Character.find_one_by_name` tries a
    # direct Ohm id lookup before falling back to a name search (engine/
    # aresmush/models/character.rb), so the numeric :char_id straight from
    # the URL resolves correctly.
    def self.resolve_character(request)
      enactor = request.enactor
      return nil unless enactor
      target_id = request.args['character_id']
      return enactor if target_id.blank?

      target = Character.find_one_by_name(target_id.to_s)
      return nil unless target
      return target if target.id == enactor.id
      return target if Soul.can_manage_soul?(enactor)
      nil
    end

    def self.status(character)
      SoulResonanceApi.default_at_chargen(character)
      resonance = SoulResonanceApi.get_resonance(character)
      allowance = SoulResonanceApi.chargen_allowance(resonance || 0)
      skills = SoulFrameworkApi.get_skills.map do |skill|
        skill.merge(rating: SoulCharacterApi.get_skill_rating(character, skill[:key]))
      end
      aspects = SoulFrameworkApi.get_aspects.map do |aspect|
        aspect.merge(rating: SoulCharacterApi.get_aspect_rating(character, aspect[:key]))
      end
      selected = SoulBnbApi.get_character_entries(character).select { |entry| entry.source == "chargen" }
      spent = skills.sum { |skill| skill[:rating].to_i }
      aspect_spent = aspects.sum { |aspect| aspect[:rating].to_i }
      {
        character_name: character.name,
        resonance_enabled: SoulResonanceApi.enabled?, resonance: resonance,
        resonance_description: SoulResonanceApi.description,
        resonance_label: resonance.nil? ? t('soul.unset') : "R#{resonance}",
        resonance_min: SoulResonanceApi.min, resonance_max: SoulResonanceApi.max,
        resonance_options: (SoulResonanceApi.min..SoulResonanceApi.max).to_a,
        skill_points: allowance[:skill_points], starting_cap: allowance[:starting_cap],
        points_spent: spent, points_remaining: allowance[:skill_points] - spent,
        aspect_points: allowance[:aspect_points],
        aspect_min_rating: SoulFrameworkApi.aspect_min_rating, aspect_max_rating: SoulFrameworkApi.aspect_max_rating,
        aspect_points_spent: aspect_spent, aspect_points_remaining: allowance[:aspect_points] - aspect_spent,
        # Readiness indicators (mischief bug list item 12, 2026-07-25) -
        # informational only, not enforced at approval: SoulBnbApi.grant
        # prevents ever exceeding the 2:1 ratio, but nothing stops a player
        # leaving points unspent, going over budget (set_skill/set_aspect
        # only warn on this - see the comment above those methods), or
        # approving with an unsatisfied ratio. Surfaced here so players and
        # staff can see it before approval; whether to also block approval
        # on it is an open product decision - see Bug_List.md. Exact
        # equality, not >=, so an over-budget character reads as "not
        # fully spent" rather than falsely reading "OK".
        skill_points_fully_spent: spent == allowance[:skill_points],
        aspect_points_fully_spent: aspect_spent == allowance[:aspect_points],
        bnb_ratio_satisfied: SoulBnbApi.ratio_currently_satisfied?(character),
        aspects: aspects, skills: skills,
        catalogue: SoulBnbApi.get_catalogue(chargen_available: true).map { |entry| catalogue_hash(entry) },
        selected_bnb: selected.map { |entry| selected_hash(entry) },
        has_selected_bnb: selected.any?,
        bnb_description: SoulBnbApi.chargen_description
      }
    end

    # Starting-cap/budget overruns are only ever soft warnings here, not
    # blocking errors - most commonly hit when a player lowers Resonance
    # after already spending points against a higher allowance, which
    # would otherwise trap them unable to even lower a Skill back down
    # (mischief bug list, 2026-07-25). Staff catch and resolve any
    # still-over-budget character at approval via Soul.app_review /
    # SoulChargenWebHandler.status's readiness indicators - this method
    # only guards the true hard bounds (unknown Skill, rating outside
    # SoulFrameworkApi's configured min/max).
    def self.set_skill(character, skill_key, rating)
      resonance = SoulResonanceApi.get_resonance(character) || 0
      allowance = SoulResonanceApi.chargen_allowance(resonance)

      current = SoulFrameworkApi.get_skills.sum do |skill|
        SoulCharacterApi.get_skill_rating(character, skill[:key])
      end
      old_rating = SoulCharacterApi.get_skill_rating(character, skill_key)
      proposed = current - old_rating + rating.to_i

      warnings = []
      warnings << "exceeds the chargen starting cap of #{allowance[:starting_cap]}" if
        rating.to_i > allowance[:starting_cap]
      warnings << "spends #{proposed} of #{allowance[:skill_points]} Skill points" if
        proposed > allowance[:skill_points]

      result = SoulCharacterApi.set_skill_rating(character, skill_key, rating.to_i, character)
      return result if result[:error]
      warnings.any? ? result.merge(warning: "This rating #{warnings.join(' and ')}.") : result
    end

    def self.set_aspect(character, aspect_key, rating)
      resonance = SoulResonanceApi.get_resonance(character) || 0
      allowance = SoulResonanceApi.chargen_allowance(resonance)
      min = SoulFrameworkApi.aspect_min_rating
      max = SoulFrameworkApi.aspect_max_rating
      return { error: "Rating must be between #{min} and #{max}." } if rating.to_i < min || rating.to_i > max

      current = SoulFrameworkApi.get_aspects.sum do |aspect|
        SoulCharacterApi.get_aspect_rating(character, aspect[:key])
      end
      old_rating = SoulCharacterApi.get_aspect_rating(character, aspect_key)
      proposed = current - old_rating + rating.to_i

      result = SoulCharacterApi.set_aspect_rating(character, aspect_key, rating.to_i, character)
      return result if result[:error]
      proposed > allowance[:aspect_points] ?
        result.merge(warning: "This rating spends #{proposed} of #{allowance[:aspect_points]} Aspect points.") :
        result
    end

    def self.catalogue_hash(entry)
      skill_names = (entry.skill_associations || []).map do |key|
        SoulFrameworkApi.get_skill(key)&.dig(:name) || key
      end
      {
        id: entry.id, tag: entry.tag, name: entry.name, description: entry.description,
        kind: entry.kind, skill_associations: skill_names.join(", "),
        has_fixed_skills: entry.skill_associations.present?
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

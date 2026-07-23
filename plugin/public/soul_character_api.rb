module AresMUSH
  # Character Aspect/Skill ratings and their contribution to rolls (FINAL
  # REQ-008 through REQ-010; aspect contribution formula per REQ-009 and
  # Implementation_Specification_Addendum.md §7).
  class SoulCharacterApi
    def self.get_skill_rating(character, skill_key)
      return 0 unless character
      char_skill = CharacterSkill.find_one(character_id: character.id, skill_key: skill_key.to_s)
      char_skill ? char_skill.rating : 0
    end

    def self.get_aspect_rating(character, aspect_key)
      return 0 unless character
      char_aspect = CharacterAspect.find_one(character_id: character.id, aspect_key: aspect_key.to_s)
      char_aspect ? char_aspect.rating : 0
    end

    # Direct rating set, bypassing XP - used by chargen allocation and staff
    # correction. Ordinary post-chargen advancement goes through
    # SoulXpApi.spend instead, which enforces the XP cost.
    def self.set_skill_rating(character, skill_key, rating, enactor)
      return { error: "Character not found" } unless character
      return { error: "Unknown skill: #{skill_key}" } unless SoulFrameworkApi.valid_skill_key?(skill_key)

      min = SoulFrameworkApi.skill_min_rating
      max = SoulFrameworkApi.skill_max_rating
      return { error: "Rating must be between #{min} and #{max}" } if rating < min || rating > max

      char_skill = CharacterSkill.find_one(character_id: character.id, skill_key: skill_key.to_s)
      if char_skill
        char_skill.update(rating: rating, last_advanced_at: Time.now)
      else
        CharacterSkill.create(character: character, skill_key: skill_key.to_s, rating: rating, last_advanced_at: Time.now)
      end

      { success: true, new_rating: rating }
    end

    def self.set_aspect_rating(character, aspect_key, rating, enactor)
      return { error: "Character not found" } unless character
      return { error: "Unknown aspect: #{aspect_key}" } unless SoulFrameworkApi.valid_aspect_key?(aspect_key)

      char_aspect = CharacterAspect.find_one(character_id: character.id, aspect_key: aspect_key.to_s)
      if char_aspect
        char_aspect.update(rating: rating)
      else
        CharacterAspect.create(character: character, aspect_key: aspect_key.to_s, rating: rating)
      end

      { success: true, new_rating: rating }
    end

    def self.aspect_weight
      Global.read_config("soul", "aspect", "weight") || 0.20
    end

    # Standard rounding (Addendum §7): 0.5 and above rounds up. Ruby's
    # Float#round already rounds half away from zero (matches "up" for the
    # non-negative values Aspect contributions produce in practice).
    def self.round_nearest(value)
      value.round
    end

    def self.aspect_contribution(aspect_rating)
      round_nearest(aspect_rating * aspect_weight)
    end

    # Skill rating + rounded Aspect contribution - the base a roll's
    # mechanical modifier builds on, before Boon/Bane die rerolls or other
    # modifiers are applied (Addendum §2 Step 3, FINAL REQ-030).
    def self.get_effective_base(character, skill_key)
      skill = SoulFrameworkApi.get_skill(skill_key)
      return 0 unless skill

      skill_rating = get_skill_rating(character, skill_key)
      aspect_rating = get_aspect_rating(character, skill[:aspect_key])
      skill_rating + aspect_contribution(aspect_rating)
    end
  end
end

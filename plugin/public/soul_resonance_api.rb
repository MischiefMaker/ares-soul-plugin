module AresMUSH
  # Resonance: optional, chargen-only setting-relative starting position
  # (FINAL GL-06, REQ-012). Locks at chargen approval and does not advance
  # or decay afterward.
  class SoulResonanceApi
    def self.enabled?
      !!Global.read_config("soul", "resonance", "enabled")
    end

    # Returns nil if the player hasn't chosen a Resonance yet (distinct
    # from an explicit R0 choice - see the attribute comment in
    # plugin/models/character_soul_fields.rb for why this isn't a
    # DataType::Integer attribute).
    def self.get_resonance(character)
      return nil unless character
      value = character.resonance
      value.nil? || value.to_s.blank? ? nil : value.to_i
    end

    def self.locked?(character)
      return false unless character
      !character.resonance_locked_at.nil?
    end

    def self.min
      Global.read_config("soul", "resonance", "min") || -3
    end

    def self.max
      Global.read_config("soul", "resonance", "max") || 3
    end

    # Chargen Skill point allowance and starting cap for a given Resonance
    # value (FINAL REQ-012 formula). Positive and negative rates are
    # independently configurable so asymmetric scaling is supported.
    def self.chargen_allowance(resonance)
      r = resonance.to_i
      base_points = Global.read_config("soul", "resonance", "r0_skill_points") || 15
      base_cap = Global.read_config("soul", "resonance", "r0_starting_cap") || 7

      if r > 0
        points_rate = Global.read_config("soul", "resonance", "positive_skill_points_per_level") || 0
        cap_rate = Global.read_config("soul", "resonance", "positive_starting_cap_per_level") || 0
      elsif r < 0
        points_rate = Global.read_config("soul", "resonance", "negative_skill_points_per_level") || 0
        cap_rate = Global.read_config("soul", "resonance", "negative_starting_cap_per_level") || 0
      else
        points_rate = 0
        cap_rate = 0
      end

      {
        skill_points: base_points + (r * points_rate),
        starting_cap: base_cap + (r * cap_rate)
      }
    end

    # Player-facing chargen selection - only valid before approval locks it.
    def self.set_resonance(character, value, enactor)
      return { error: "Character not found" } unless character
      return { error: "This game does not use Resonance." } unless enabled?
      return { error: "Resonance is already locked and cannot be changed here - contact staff." } if locked?(character)

      r = value.to_i
      return { error: "Resonance must be between #{min} and #{max}" } if r < min || r > max

      character.update(resonance: r.to_s)
      { success: true, resonance: r, chargen_allowance: chargen_allowance(r) }
    end

    # Called from the game's own plugins/chargen/custom_approval.rb, after
    # char.is_approved = true persists (see
    # custom-install/custom_approval.snippet.rb). Defaults to R0 if the
    # player never explicitly chose one. A no-op if already locked (e.g. a
    # re-approval), so it's safe to call more than once.
    def self.lock_at_approval(character)
      return unless enabled?
      return if locked?(character)

      resonance = get_resonance(character) || 0
      character.update(resonance: resonance.to_s, resonance_locked_at: Time.now)
      # TODO(Phase 3): create a Narrative History entry for approved starting
      # Resonance here once the Narrative History model exists (FINAL REQ-012:
      # "Approval SHALL create a Narrative History entry for starting Resonance").
    end

    # Staff correction of an already-locked Resonance value (FINAL REQ-012:
    # "Administrative correction SHALL preserve the original value, new
    # value, actor, reason, and source"). Appends to the character's
    # lightweight correction log pending the real Audit model (Phase 3) -
    # see the attribute comment in character_soul_fields.rb.
    def self.correct(character, new_value, actor:, reason:)
      return { error: "Character not found" } unless character
      return { error: "Reason is required for a Resonance correction" } if reason.to_s.blank?

      r = new_value.to_i
      return { error: "Resonance must be between #{min} and #{max}" } if r < min || r > max

      old_value = get_resonance(character)
      log = character.resonance_correction_log || []
      log << {
        "old_value" => old_value,
        "new_value" => r,
        "actor" => actor ? actor.name : "unknown",
        "reason" => reason,
        "corrected_at" => Time.now.to_s
      }
      character.update(resonance: r.to_s, resonance_correction_log: log)

      { success: true, old_value: old_value, new_value: r }
    end
  end
end

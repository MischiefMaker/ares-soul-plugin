module AresMUSH
  module Soul
    # Validates game/config/soul.yml at plugin load and whenever staff
    # reload game config (see AresMUSH::Manage::ConfigValidator, the same
    # helper Jobs/Chargen/FS3Skills and other bundled plugins use via their
    # own <name>_config_validator.rb + <Name>.check_config). Returns an
    # array of human-readable error strings (FINAL REQ-042); an empty
    # array means the config is structurally valid.
    #
    # This covers structural/type/range validation only - the parts
    # checkable from soul.yml alone. Cross-referential checks that need
    # Phase 2+ model code to exist (every Skill's aspect key resolves to a
    # real Aspect, every B&B catalogue tag is unique, chargen resonance-
    # level tables are internally consistent) belong in the Character
    # Framework / B&B catalogue loading code itself, once those models
    # exist - see docs/spec/IMPLEMENTATION_CHECKLIST.md Phase 2/3.
    class SoulConfigValidator
      attr_accessor :validator

      def initialize
        @validator = Manage::ConfigValidator.new("soul")
      end

      def validate
        @validator.require_boolean("enabled")

        # Permission settings are plain strings, not Role names (a Role
        # grants the named permission to whichever characters hold it -
        # see AresMUSH::Role#has_permission? - so there's no fixed list to
        # check membership against at config-load time, unlike
        # check_role_exists which validates an actual Role name).
        @validator.require_nonblank_text("manage_permission")
        @validator.require_nonblank_text("gm_review_permission")
        validate_play_permission

        validate_framework
        validate_aspect_weight
        validate_resonance
        validate_xp
        validate_bnb
        validate_rolls
        validate_integrations

        @validator.errors
      end

      private

      def validate_framework
        @validator.require_hash("framework")
        framework = @validator.config["framework"]
        return unless framework.kind_of?(Hash)

        min = framework["skill_min_rating"]
        max = framework["skill_max_rating"]
        if !min.kind_of?(Integer)
          @validator.add_error("soul:framework.skill_min_rating must be a whole number.")
        end
        if !max.kind_of?(Integer)
          @validator.add_error("soul:framework.skill_max_rating must be a whole number.")
        end
        if min.kind_of?(Integer) && max.kind_of?(Integer) && min >= max
          @validator.add_error("soul:framework.skill_max_rating must be greater than skill_min_rating.")
        end

        aspects = framework["aspects"]
        if !aspects.kind_of?(Hash) || aspects.empty?
          @validator.add_error("soul:framework.aspects must be a non-empty hash of Aspect definitions.")
        end
      end

      # Unlike manage_permission/gm_review_permission, play_permission is
      # optional (nil by default) - ordinary play access defaults to
      # Character#is_approved? instead, since no bundled AresMUSH
      # permission means "is an approved player" (see Soul.can_play?).
      # This only validates the type when a game does configure it.
      def validate_play_permission
        value = @validator.config["play_permission"]
        return if value.nil?
        if !value.kind_of?(String) || value.blank?
          @validator.add_error("soul:play_permission, if set, must be a non-blank text string.")
        end
      end

      def validate_aspect_weight
        @validator.require_hash("aspect")
        aspect = @validator.config["aspect"]
        return unless aspect.kind_of?(Hash)

        weight = aspect["weight"]
        if !weight.kind_of?(Numeric) || weight < 0
          @validator.add_error("soul:aspect.weight must be a non-negative number (default 0.20 - FINAL REQ-009).")
        end

        rounding = aspect["contribution_rounding"]
        if !["nearest"].include?(rounding)
          @validator.add_error("soul:aspect.contribution_rounding must be 'nearest' (Addendum §7 - the only rounding rule currently specified).")
        end
      end

      def validate_resonance
        @validator.require_hash("resonance")
        resonance = @validator.config["resonance"]
        return unless resonance.kind_of?(Hash)

        return unless resonance["enabled"]

        min = resonance["min"]
        max = resonance["max"]
        if !min.kind_of?(Integer) || !max.kind_of?(Integer) || min >= max
          @validator.add_error("soul:resonance.min must be a whole number less than resonance.max (canonical default -3..3 - FINAL REQ-012).")
        end

        %w[r0_skill_points r0_starting_cap positive_skill_points_per_level negative_skill_points_per_level
           positive_starting_cap_per_level negative_starting_cap_per_level].each do |key|
          if !resonance[key].kind_of?(Integer)
            @validator.add_error("soul:resonance.#{key} must be a whole number.")
          end
        end
      end

      def validate_xp
        @validator.require_hash("xp")
        xp = @validator.config["xp"]
        return unless xp.kind_of?(Hash)

        %w[weekly_award scene_sharer_award scene_participant_award forum_award].each do |key|
          if !xp[key].kind_of?(Integer) || xp[key] < 0
            @validator.add_error("soul:xp.#{key} must be a non-negative whole number.")
          end
        end

        # check_cron accepts either a config-section field name or (as here)
        # a nested cron hash passed directly - see Manage::ConfigValidator
        # and jobs_config_validator.rb's identical use for nested schedules.
        @validator.check_cron(xp["weekly_award_cron"])

        cost = xp["cost"]
        if !cost.kind_of?(Hash)
          @validator.add_error("soul:xp.cost must be a hash of the algebraic cost formula's constants (Addendum §3).")
        else
          %w[skill_curve_numerator skill_curve_denominator development_base development_scale].each do |key|
            if !cost[key].kind_of?(Numeric) || cost[key] <= 0
              @validator.add_error("soul:xp.cost.#{key} must be a positive number.")
            end
          end
          if !cost["development_exponent"].kind_of?(Numeric) || cost["development_exponent"] <= 0
            @validator.add_error("soul:xp.cost.development_exponent must be a positive number.")
          end
          if !cost["negative_resonance_rate"].kind_of?(Numeric) || !cost["positive_resonance_rate"].kind_of?(Numeric)
            @validator.add_error("soul:xp.cost.negative_resonance_rate and positive_resonance_rate must be numbers.")
          end
        end

        catchup = xp["catchup"]
        if !catchup.kind_of?(Hash)
          @validator.add_error("soul:xp.catchup must be a hash (Addendum §8).")
        else
          if !catchup["multiplier"].kind_of?(Numeric) || catchup["multiplier"] < 1
            @validator.add_error("soul:xp.catchup.multiplier must be a number >= 1.")
          end
          if !catchup["grace_period_weeks"].kind_of?(Integer) || catchup["grace_period_weeks"] < 0
            @validator.add_error("soul:xp.catchup.grace_period_weeks must be a non-negative whole number.")
          end
        end
      end

      def validate_bnb
        @validator.require_hash("bnb")
        bnb = @validator.config["bnb"]
        return unless bnb.kind_of?(Hash)

        if !bnb["categories"].kind_of?(Array) || bnb["categories"].empty?
          @validator.add_error("soul:bnb.categories must be a non-empty list (default Arcane, Mundane - CI-01).")
        end

        if !bnb["chargen_ratio"].kind_of?(Integer) || bnb["chargen_ratio"] < 1
          @validator.add_error("soul:bnb.chargen_ratio must be a whole number >= 1 (Addendum §5).")
        end
        if !["floor", "ceil", "round"].include?(bnb["ratio_rounding"])
          @validator.add_error("soul:bnb.ratio_rounding must be one of: floor, ceil, round.")
        end

        if !bnb["resonance_levels"].kind_of?(Hash) || bnb["resonance_levels"].empty?
          @validator.add_error("soul:bnb.resonance_levels must be a non-empty hash, one entry per configured Resonance level (Addendum §5.2-§5.3).")
        end
      end

      def validate_rolls
        @validator.require_hash("rolls")
        rolls = @validator.config["rolls"]
        return unless rolls.kind_of?(Hash)

        if !["d20_open_ended"].include?(rolls["random_model"])
          @validator.add_error("soul:rolls.random_model must be 'd20_open_ended' (Addendum §2 - the only random model currently specified).")
        end

        difficulties = rolls["difficulties"]
        expected_difficulties = %w[trivial easy standard difficult hard extreme legendary mythic]
        if !difficulties.kind_of?(Hash) || (expected_difficulties - difficulties.keys).any?
          @validator.add_error("soul:rolls.difficulties must define all eight levels: #{expected_difficulties.join(', ')} (Addendum §1).")
        elsif difficulties.values.any? { |v| !v.kind_of?(Integer) }
          @validator.add_error("soul:rolls.difficulties values must all be whole numbers.")
        end

        threshold = rolls["extraordinary_result_threshold"]
        if !threshold.kind_of?(Numeric) || threshold <= 0 || threshold >= 1
          @validator.add_error("soul:rolls.extraordinary_result_threshold must be a number between 0 and 1 (default 0.0001 - Addendum §9).")
        end

        degrees = rolls["degrees_of_success"]
        if !degrees.kind_of?(Hash) || !degrees["exceptional_success_min"].kind_of?(Integer)
          @validator.add_error("soul:rolls.degrees_of_success must be a hash with at least exceptional_success_min set (Addendum §8.1).")
        end

        if !rolls["pending_roll_timeout_hours"].kind_of?(Integer) || rolls["pending_roll_timeout_hours"] <= 0
          @validator.add_error("soul:rolls.pending_roll_timeout_hours must be a positive whole number (default 720 - Addendum §6).")
        end

        if !rolls["max_pending_rolls_per_player"].kind_of?(Integer) || rolls["max_pending_rolls_per_player"] < 1
          @validator.add_error("soul:rolls.max_pending_rolls_per_player must be a whole number >= 1 (CI-04 default 1).")
        end
        if !rolls["max_pending_rolls_per_player_gm"].kind_of?(Integer) || rolls["max_pending_rolls_per_player_gm"] < 1
          @validator.add_error("soul:rolls.max_pending_rolls_per_player_gm must be a whole number >= 1 (CI-04 default 2).")
        end

        if !["required", "optional", "unavailable"].include?(rolls["gm_scene_policy"])
          @validator.add_error("soul:rolls.gm_scene_policy must be one of: required, optional, unavailable (FINAL REQ-029).")
        end
      end

      def validate_integrations
        integrations = @validator.config["integrations"]
        return unless integrations.kind_of?(Hash)

        grimoire = integrations["grimoire"]
        return unless grimoire.kind_of?(Hash)

        branch_map = grimoire["branch_skill_map"]
        return if branch_map.nil?

        unless branch_map.kind_of?(Hash)
          @validator.add_error("soul:integrations.grimoire.branch_skill_map must be a hash of branch key => Skill key (FINAL REQ-040).")
          return
        end

        skills = (@validator.config["framework"] || {})["skills"] || {}
        branch_map.each do |branch_key, skill_key|
          unless skills.key?(skill_key.to_s)
            @validator.add_error("soul:integrations.grimoire.branch_skill_map.#{branch_key} references unknown Skill '#{skill_key}'.")
          end
        end
      end
    end
  end
end

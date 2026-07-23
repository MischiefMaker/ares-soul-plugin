module AresMUSH
  module Soul
    # Open-ended 2d20 dice engine (Addendum §2). Pure math/RNG - no Character,
    # Ohm, or config-catalogue dependencies, so it's independently testable and
    # safe to call from any context (SoulRollApi, specs, a future GM-assist
    # simulator, etc.).
    #
    # Two entry points serve two different needs:
    #
    # - .roll(net_modifier) actually rolls dice (real RNG) for a live roll
    #   resolution. Non-deterministic by design - it's the outcome players see.
    #
    # - .success_probability(net_modifier, required_dice_total) computes the
    #   EXACT probability of the dice portion alone meeting or exceeding a
    #   target, with no RNG involved. This has to be a pure deterministic
    #   function - FINAL REQ-030 requires "rounding SHALL be deterministic and
    #   identical in MUSH, web, tests, manual paths, and integrations," and
    #   Addendum §9 requires probability to be calculated *before* rolling and
    #   stored for audit. A Monte Carlo estimate would violate both by varying
    #   between calls for the same inputs.
    #
    # Both must implement the identical rule set (explosion/implosion trigger
    # on ORIGINAL dice only, reroll applied afterward to every die in the
    # chain) or the stored probability would not describe the actual roll
    # mechanism.
    class SoulDiceEngine
      DIE_MIN = 1
      DIE_MAX = 20

      # Rerolls are only meaningful while at least one die value survives
      # outside the band - a boon/bane modifier large enough to cover the
      # entire 1..20 range has no basis in the spec (Addendum §2 says "no
      # cap" on modifier magnitude, but never describes a band covering all
      # 20 faces) and would make the reroll loop in .roll never terminate.
      # Capping the effective band at 19 faces (leaving exactly one legal
      # value) is a deliberate implementation safety margin, not a spec rule -
      # documented here since it's the one place this engine deviates from
      # "no cap" literalism.
      MAX_BAND_SIZE = DIE_MAX - 1

      # --- Live roll resolution (RNG-based) ---

      # net_modifier: sum of all active Boon (+) and Bane (-) mechanical
      # modifiers (Addendum §2 Step 2), NOT including Skill/Aspect/other flat
      # modifiers (those are added separately in Step 3 by the caller).
      #
      # Returns:
      #   total: dice-only total after explosion/implosion and reroll
      #   mode: :explosion, :implosion, or :normal
      #   segments: [{d1:, d2:}, ...] post-reroll dice, in chain order,
      #             for display/audit (Addendum §2's worked examples format)
      def self.roll(net_modifier)
        band = reroll_band(net_modifier)

        first_d1, first_d2 = roll_die, roll_die
        segments = [{ d1: first_d1, d2: first_d2 }]
        mode = :normal

        if first_d1 == DIE_MAX && first_d2 == DIE_MAX
          mode = :explosion
          loop do
            d1, d2 = roll_die, roll_die
            segments << { d1: d1, d2: d2 }
            break unless d1 == DIE_MAX && d2 == DIE_MAX
          end
        elsif first_d1 == DIE_MIN && first_d2 == DIE_MIN
          mode = :implosion
          loop do
            d1, d2 = roll_die, roll_die
            segments << { d1: d1, d2: d2 }
            break unless d1 == DIE_MIN && d2 == DIE_MIN
          end
        end

        segments.each do |seg|
          seg[:d1] = apply_reroll(seg[:d1], band)
          seg[:d2] = apply_reroll(seg[:d2], band)
        end

        total = segments[0][:d1] + segments[0][:d2]
        segments[1..-1].to_a.each do |seg|
          contribution = seg[:d1] + seg[:d2]
          total += (mode == :implosion ? -contribution : contribution)
        end

        { total: total, mode: mode, segments: segments }
      end

      def self.roll_die
        rand(DIE_MIN..DIE_MAX)
      end
      private_class_method :roll_die

      # --- Exact probability calculation (no RNG) ---

      # Probability that the DICE-ONLY portion of a roll with this
      # net_modifier meets or exceeds required_dice_total (i.e. the caller
      # has already subtracted Skill/Aspect/other flat modifiers from the
      # roll's difficulty to get required_dice_total). depth bounds the
      # explosion/implosion recursion; each additional level only matters
      # for the 1-in-400 branch that continues the chain, so the truncated
      # probability mass at depth 12 is on the order of (1/400)^12 -
      # unrepresentable in a Float, let alone visible at the 0.01% precision
      # Addendum §9 cares about. Truncating deeper chains to "contribute
      # nothing further" is a safe, negligible-error approximation, not a
      # simplification of the mechanic itself.
      def self.success_probability(net_modifier, required_dice_total, depth: 12)
        pmf = total_pmf(net_modifier, depth)
        pmf.sum { |total, probability| total >= required_dice_total ? probability : 0.0 }
      end

      # Full dice-only outcome distribution for a given net_modifier, as a
      # Hash of { total => probability }. Exposed separately from
      # .success_probability so callers needing the whole distribution
      # (e.g. a future "show me my odds" display) don't have to re-derive it.
      def self.total_pmf(net_modifier, depth = 12)
        band = reroll_band(net_modifier)
        contribution = die_contribution_pmf(band)

        pmf = {}
        each_die_pair do |d1, d2, weight|
          segment_pmf = convolve(contribution[d1], contribution[d2])

          if d1 == DIE_MAX && d2 == DIE_MAX
            deeper = chain_pmf(:explosion, contribution, depth - 1)
            merge_weighted!(pmf, convolve(segment_pmf, deeper), weight)
          elsif d1 == DIE_MIN && d2 == DIE_MIN
            deeper = chain_pmf(:implosion, contribution, depth - 1)
            merge_weighted!(pmf, convolve(segment_pmf, negate(deeper)), weight)
          else
            merge_weighted!(pmf, segment_pmf, weight)
          end
        end
        pmf
      end

      # --- Internal probability machinery ---

      # Distribution of contribution from one CONTINUATION segment (and
      # everything that follows it in the same chain), always returned as a
      # positive-domain sum - the caller negates the whole thing once for
      # implosion chains (matching the worked example in Addendum §2:
      # total = first_segment - sum(all continuation segments), not a
      # segment-by-segment alternating sign).
      def self.chain_pmf(mode, contribution, depth)
        return { 0 => 1.0 } if depth <= 0

        trigger_value = mode == :explosion ? DIE_MAX : DIE_MIN
        pmf = {}
        each_die_pair do |d1, d2, weight|
          segment_pmf = convolve(contribution[d1], contribution[d2])

          if d1 == trigger_value && d2 == trigger_value
            deeper = chain_pmf(mode, contribution, depth - 1)
            merge_weighted!(pmf, convolve(segment_pmf, deeper), weight)
          else
            merge_weighted!(pmf, segment_pmf, weight)
          end
        end
        pmf
      end
      private_class_method :chain_pmf

      # All 400 equally-likely (d1, d2) pre-reroll pairs, each weight 1/400.
      def self.each_die_pair
        weight = 1.0 / ((DIE_MAX - DIE_MIN + 1)**2)
        (DIE_MIN..DIE_MAX).each do |d1|
          (DIE_MIN..DIE_MAX).each do |d2|
            yield d1, d2, weight
          end
        end
      end
      private_class_method :each_die_pair

      # For each possible original die value, the distribution of what that
      # die contributes to the total AFTER reroll. A die outside the reroll
      # band always contributes its own value (point mass). A die inside the
      # band is repeatedly rerolled until it lands outside the band, which
      # converges to a uniform distribution over the non-band values
      # regardless of the original in-band value or how many rerolls it
      # took - so every in-band original value maps to the SAME distribution
      # object (computed once, not once per value).
      def self.die_contribution_pmf(band)
        outside_values = (DIE_MIN..DIE_MAX).reject { |v| band && v.between?(band[0], band[1]) }
        reroll_pmf = outside_values.each_with_object({}) { |v, h| h[v] = 1.0 / outside_values.size }

        (DIE_MIN..DIE_MAX).each_with_object({}) do |v, h|
          h[v] = (band && v.between?(band[0], band[1])) ? reroll_pmf : { v => 1.0 }
        end
      end
      private_class_method :die_contribution_pmf

      def self.convolve(pmf_a, pmf_b)
        result = {}
        pmf_a.each do |value_a, prob_a|
          pmf_b.each do |value_b, prob_b|
            key = value_a + value_b
            result[key] = (result[key] || 0.0) + (prob_a * prob_b)
          end
        end
        result
      end
      private_class_method :convolve

      def self.merge_weighted!(target, pmf, weight)
        pmf.each { |value, probability| target[value] = (target[value] || 0.0) + (probability * weight) }
        target
      end
      private_class_method :merge_weighted!

      def self.negate(pmf)
        pmf.each_with_object({}) { |(value, probability), h| h[-value] = probability }
      end
      private_class_method :negate

      # Positive modifier (Boon): reroll every die showing 1..N.
      # Negative modifier (Bane): reroll every die showing (21-N)..20.
      # Zero: no reroll. See MAX_BAND_SIZE for why N is capped at 19.
      def self.reroll_band(net_modifier)
        n = net_modifier.to_i
        return nil if n == 0

        magnitude = [n.abs, MAX_BAND_SIZE].min
        n > 0 ? [DIE_MIN, DIE_MIN + magnitude - 1] : [DIE_MAX - magnitude + 1, DIE_MAX]
      end
      private_class_method :reroll_band

      def self.apply_reroll(value, band)
        return value unless band
        return value unless value.between?(band[0], band[1])

        loop do
          value = roll_die
          break unless value.between?(band[0], band[1])
        end
        value
      end
      private_class_method :apply_reroll
    end
  end
end

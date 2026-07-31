require_relative 'spec_helper'

module AresMUSH
  describe SoulXpApi do
    let(:character) { Fabricate(:character) }

    before do
      allow(Global).to receive(:read_config).and_call_original
      # Real Global.read_config (engine/aresmush/global.rb) is capped at
      # section/key/subkey - three args, two levels deep. Reading a third
      # level (e.g. soul.xp.cost.skill_curve_numerator) directly raises
      # ArgumentError in production; the only supported approach is to read
      # the two-level parent hash once and index into it in Ruby, so these
      # mocks stub the same two-level calls the real code makes.
      allow(Global).to receive(:read_config).with("soul", "xp", "cost").and_return(
        "skill_curve_numerator" => 1, "skill_curve_denominator" => 2,
        "skill_cost_multiplier" => 1, "aspect_cost_multiplier" => 4,
        "development_base" => 1, "development_scale" => 250, "development_exponent" => 1.25,
        "negative_resonance_rate" => 0.12, "positive_resonance_rate" => 0.22,
        "positive_resonance_surcharge" => 1
      )
      allow(Global).to receive(:read_config).with("soul", "xp", "catchup").and_return(
        "enabled" => true, "multiplier" => 2.0
      )
      allow(Global).to receive(:read_config).with("soul", "framework", "skill_max_rating").and_return(10)
      allow(Global).to receive(:read_config).with("soul", "framework", "aspect_min_rating").and_return(0)
      allow(Global).to receive(:read_config).with("soul", "framework", "aspect_max_rating").and_return(10)
    end

    describe ".calculate_cost" do
      it "matches the Addendum §3 worked example at rating 5, 0 XP spent, R0" do
        expect(SoulXpApi.calculate_cost(character, "blade", 5)).to eq(13)
      end

      it "matches the worked example at rating 3" do
        expect(SoulXpApi.calculate_cost(character, "blade", 3)).to eq(5)
      end

      it "matches the worked example at rating 10" do
        expect(SoulXpApi.calculate_cost(character, "blade", 10)).to eq(50)
      end

      it "doubles cost at 250 XP spent (development curve)" do
        character.update(soul_xp_spent: 250)
        expect(SoulXpApi.calculate_cost(character, "blade", 5)).to eq(26)
      end

      it "reduces cost to 40% at -5 Resonance" do
        character.update(resonance: "-5")
        cost = SoulXpApi.calculate_cost(character, "blade", 5)
        expect(cost).to eq((13 * 0.4).ceil)
      end

      it "increases cost to 710% at +5 Resonance (corrected worked example)" do
        character.update(resonance: "5")
        cost = SoulXpApi.calculate_cost(character, "blade", 5)
        expect(cost).to eq((13 * 7.1).ceil)
      end

      it "never decreases as rating rises (REQ-015 invariant)" do
        costs = (1..10).map { |r| SoulXpApi.calculate_cost(character, "blade", r) }
        expect(costs).to eq(costs.sort)
      end

      it "prices an Aspect at exactly four times the equivalent Skill cost" do
        skill_cost = SoulXpApi.calculate_cost(character, "blade", 3)
        aspect_cost = SoulXpApi.calculate_cost(character, "body", 3, trait_type: "aspect")
        expect(aspect_cost).to eq(skill_cost * 4)
      end
    end

    describe ".award" do
      it "does not double-award on a repeated idempotency key" do
        SoulXpApi.award(character, 10, source: "scene:1", idempotency_key: "scene:1:#{character.id}", apply_catchup: false)
        SoulXpApi.award(character, 10, source: "scene:1", idempotency_key: "scene:1:#{character.id}", apply_catchup: false)
        expect(SoulXpApi.get_lifetime_earned_xp(character)).to eq(10)
      end

      it "applies no catch-up when apply_catchup is false" do
        allow(SoulXpApi).to receive(:catchup_eligible?).and_return(true)
        result = SoulXpApi.award(character, 2, source: "admin", apply_catchup: false)
        expect(result[:catchup_portion]).to eq(0)
      end

      it "caps the catch-up bonus at the median gap (Addendum §8 Example B.4)" do
        allow(SoulXpApi).to receive(:catchup_eligible?).and_return(true)
        allow(SoulXpApi).to receive(:median_earned_xp).and_return(1)
        result = SoulXpApi.award(character, 2, source: "weekly", apply_catchup: true)
        expect(result[:awarded]).to eq(3)   # 2 base + 1 capped catch-up, not 4
      end

      # notify: character-facing notification (2026-07-26 live testing:
      # "We need to add a notification when a player is awarded XP either
      # individually or to a scene. Look to how Inklings did it.") - opt-in,
      # see the comment on .award itself for why it defaults to false.
      it "does not notify by default" do
        expect(Soul).not_to receive(:notify_player)
        SoulXpApi.award(character, 10, source: "admin", apply_catchup: false)
      end

      it "notifies the character with the total awarded when notify: true" do
        expect(Soul).to receive(:notify_player).with(
          character, match(/10 XP/), type: "soul_xp", reference_id: anything
        )
        SoulXpApi.award(character, 10, source: "admin", apply_catchup: false, notify: true)
      end

      it "mentions the catch-up portion in the notification when present" do
        allow(SoulXpApi).to receive(:catchup_eligible?).and_return(true)
        allow(SoulXpApi).to receive(:median_earned_xp).and_return(100)
        expect(Soul).to receive(:notify_player).with(
          character, match(/catch-up/), type: "soul_xp", reference_id: anything
        )
        SoulXpApi.award(character, 2, source: "weekly", apply_catchup: true, notify: true)
      end
    end

    describe ".spend" do
      it "deducts XP and advances the rating on success" do
        character.update(soul_xp_available: 20)
        result = SoulXpApi.spend(character, "blade", 1, character)
        expect(result[:success]).to be true
        expect(result[:new_rating]).to eq(1)
        expect(SoulXpApi.get_available_xp(character)).to eq(20 - result[:cost])
      end

      it "returns an error when XP is insufficient" do
        character.update(soul_xp_available: 0)
        result = SoulXpApi.spend(character, "blade", 1, character)
        expect(result[:error]).to match(/insufficient/i)
      end

      it "returns an error for an unknown skill" do
        result = SoulXpApi.spend(character, "nonexistent_skill", 1, character)
        expect(result[:error]).to match(/unknown skill/i)
      end

      it "deducts XP, advances an Aspect, and identifies it in the ledger" do
        character.update(soul_xp_available: 100)
        result = SoulXpApi.spend_aspect(character, "body", 1, character)

        expect(result[:success]).to be true
        expect(result[:trait_type]).to eq("aspect")
        expect(SoulCharacterApi.get_aspect_rating(character, "body")).to eq(1)
        expect(SoulXpApi.get_available_xp(character)).to eq(100 - result[:cost])
        expect(character.soul_xp_ledger_entries.to_a.last.source).to eq("aspect:body")
      end

      it "returns an error for an unknown Aspect" do
        result = SoulXpApi.spend_aspect(character, "nonexistent_aspect", 1, character)
        expect(result[:error]).to match(/unknown aspect/i)
      end
    end

    describe ".correct" do
      it "adds XP to available when correcting" do
        character.update(soul_xp_available: 50)
        staff = Fabricate(:character)
        result = SoulXpApi.correct(character, 10, reason: "Duplicate award reversal", actor: staff)
        expect(result[:success]).to be true
        expect(result[:old_available]).to eq(50)
        expect(result[:new_available]).to eq(60)
        expect(SoulXpApi.get_available_xp(character)).to eq(60)
      end

      it "creates a correction ledger entry" do
        character.update(soul_xp_available: 50)
        staff = Fabricate(:character)
        SoulXpApi.correct(character, 10, reason: "Test correction", actor: staff)
        ledger = SoulXpLedgerEntry.find(:direction, "correction")
        expect(ledger).to exist
      end

      it "records audit trail with actor and reason" do
        character.update(soul_xp_available: 50)
        staff = Fabricate(:character)
        SoulXpApi.correct(character, 10, reason: "Duplicate award reversal", actor: staff)
        audit = AresMUSH::SoulAuditEntry.find_one(action: "xp_correction")
        expect(audit).to exist
        expect(audit.actor_id).to eq(staff.id)
        expect(audit.reason).to eq("Duplicate award reversal")
      end

      it "returns an error if reason is blank" do
        staff = Fabricate(:character)
        result = SoulXpApi.correct(character, 10, reason: "", actor: staff)
        expect(result[:error]).to match(/reason.*required/i)
      end

      it "subtracts XP from available when direction is reversal" do
        character.update(soul_xp_available: 50)
        staff = Fabricate(:character)
        result = SoulXpApi.correct(character, 10, reason: "Accidental double-award", actor: staff, direction: "reversal")
        expect(result[:success]).to be true
        expect(result[:old_available]).to eq(50)
        expect(result[:new_available]).to eq(40)
        expect(SoulXpApi.get_available_xp(character)).to eq(40)
      end

      it "returns an error if amount is not positive" do
        staff = Fabricate(:character)
        result = SoulXpApi.correct(character, 0, reason: "Test", actor: staff)
        expect(result[:error]).to match(/positive/i)
      end
    end

    describe ".get_scene_participants" do
      it "returns an empty list when scene is nil" do
        result = SoulXpApi.get_scene_participants(nil)
        expect(result).to eq([])
      end

      it "filters to approved characters only" do
        scene = Fabricate(:scene)
        approved = Fabricate(:character)
        unapproved = Fabricate(:character, is_approved: false)
        allow(scene).to receive(:participants).and_return([approved, unapproved])
        allow(Chargen).to receive(:approved_chars).and_return([approved])
        result = SoulXpApi.get_scene_participants(scene)
        expect(result).to eq([approved])
      end

      it "handles scenes with no participants" do
        scene = Fabricate(:scene)
        allow(scene).to receive(:participants).and_return([])
        result = SoulXpApi.get_scene_participants(scene)
        expect(result).to be_empty
      end

      it "returns an empty list when scene does not respond to participants" do
        scene = Object.new
        result = SoulXpApi.get_scene_participants(scene)
        expect(result).to eq([])
      end
    end
  end
end

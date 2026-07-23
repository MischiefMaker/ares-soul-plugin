require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulXpApi do
    let(:character) { Fabricate(:character) }

    before do
      allow(Global).to receive(:read_config).and_call_original
      allow(Global).to receive(:read_config).with("soul", "xp", "cost", "skill_curve_numerator").and_return(1)
      allow(Global).to receive(:read_config).with("soul", "xp", "cost", "skill_curve_denominator").and_return(2)
      allow(Global).to receive(:read_config).with("soul", "xp", "cost", "development_base").and_return(1)
      allow(Global).to receive(:read_config).with("soul", "xp", "cost", "development_scale").and_return(250)
      allow(Global).to receive(:read_config).with("soul", "xp", "cost", "development_exponent").and_return(1.25)
      allow(Global).to receive(:read_config).with("soul", "xp", "cost", "negative_resonance_rate").and_return(0.12)
      allow(Global).to receive(:read_config).with("soul", "xp", "cost", "positive_resonance_rate").and_return(0.22)
      allow(Global).to receive(:read_config).with("soul", "xp", "cost", "positive_resonance_surcharge").and_return(1)
      allow(Global).to receive(:read_config).with("soul", "xp", "catchup", "enabled").and_return(true)
      allow(Global).to receive(:read_config).with("soul", "xp", "catchup", "multiplier").and_return(2.0)
      allow(Global).to receive(:read_config).with("soul", "framework", "skill_max_rating").and_return(10)
    end

    describe ".calculate_cost" do
      it "matches the Addendum §3 worked example at rating 5, 0 XP spent, R0" do
        expect(Soul::SoulXpApi.calculate_cost(character, "blade", 5)).to eq(13)
      end

      it "matches the worked example at rating 3" do
        expect(Soul::SoulXpApi.calculate_cost(character, "blade", 3)).to eq(5)
      end

      it "matches the worked example at rating 10" do
        expect(Soul::SoulXpApi.calculate_cost(character, "blade", 10)).to eq(50)
      end

      it "doubles cost at 250 XP spent (development curve)" do
        character.update(soul_xp_spent: 250)
        expect(Soul::SoulXpApi.calculate_cost(character, "blade", 5)).to eq(26)
      end

      it "reduces cost to 40% at -5 Resonance" do
        character.update(resonance: "-5")
        cost = Soul::SoulXpApi.calculate_cost(character, "blade", 5)
        expect(cost).to eq((13 * 0.4).ceil)
      end

      it "increases cost to 710% at +5 Resonance (corrected worked example)" do
        character.update(resonance: "5")
        cost = Soul::SoulXpApi.calculate_cost(character, "blade", 5)
        expect(cost).to eq((13 * 7.1).ceil)
      end

      it "never decreases as rating rises (REQ-015 invariant)" do
        costs = (1..10).map { |r| Soul::SoulXpApi.calculate_cost(character, "blade", r) }
        expect(costs).to eq(costs.sort)
      end
    end

    describe ".award" do
      it "does not double-award on a repeated idempotency key" do
        Soul::SoulXpApi.award(character, 10, source: "scene:1", idempotency_key: "scene:1:#{character.id}", apply_catchup: false)
        Soul::SoulXpApi.award(character, 10, source: "scene:1", idempotency_key: "scene:1:#{character.id}", apply_catchup: false)
        expect(Soul::SoulXpApi.get_lifetime_earned_xp(character)).to eq(10)
      end

      it "applies no catch-up when apply_catchup is false" do
        allow(Soul::SoulXpApi).to receive(:catchup_eligible?).and_return(true)
        result = Soul::SoulXpApi.award(character, 2, source: "admin", apply_catchup: false)
        expect(result[:catchup_portion]).to eq(0)
      end

      it "caps the catch-up bonus at the median gap (Addendum §8 Example B.4)" do
        allow(Soul::SoulXpApi).to receive(:catchup_eligible?).and_return(true)
        allow(Soul::SoulXpApi).to receive(:median_earned_xp).and_return(1)
        result = Soul::SoulXpApi.award(character, 2, source: "weekly", apply_catchup: true)
        expect(result[:awarded]).to eq(3)   # 2 base + 1 capped catch-up, not 4
      end
    end

    describe ".spend" do
      it "deducts XP and advances the rating on success" do
        character.update(soul_xp_available: 20)
        result = Soul::SoulXpApi.spend(character, "blade", 1, character)
        expect(result[:success]).to be true
        expect(result[:new_rating]).to eq(1)
        expect(Soul::SoulXpApi.get_available_xp(character)).to eq(20 - result[:cost])
      end

      it "returns an error when XP is insufficient" do
        character.update(soul_xp_available: 0)
        result = Soul::SoulXpApi.spend(character, "blade", 1, character)
        expect(result[:error]).to match(/insufficient/i)
      end

      it "returns an error for an unknown skill" do
        result = Soul::SoulXpApi.spend(character, "nonexistent_skill", 1, character)
        expect(result[:error]).to match(/unknown skill/i)
      end
    end

    describe ".correct" do
      it "adds XP to available when correcting" do
        character.update(soul_xp_available: 50)
        staff = Fabricate(:character)
        result = Soul::SoulXpApi.correct(character, 10, reason: "Duplicate award reversal", actor: staff)
        expect(result[:success]).to be true
        expect(result[:old_available]).to eq(50)
        expect(result[:new_available]).to eq(60)
        expect(Soul::SoulXpApi.get_available_xp(character)).to eq(60)
      end

      it "creates a correction ledger entry" do
        character.update(soul_xp_available: 50)
        staff = Fabricate(:character)
        Soul::SoulXpApi.correct(character, 10, reason: "Test correction", actor: staff)
        ledger = Soul::SoulXpLedgerEntry.find(:direction, "correction")
        expect(ledger).to exist
      end

      it "records audit trail with actor and reason" do
        character.update(soul_xp_available: 50)
        staff = Fabricate(:character)
        Soul::SoulXpApi.correct(character, 10, reason: "Duplicate award reversal", actor: staff)
        audit = AresMUSH::SoulAuditEntry.find_one(action: "xp_correction")
        expect(audit).to exist
        expect(audit.actor_id).to eq(staff.id)
        expect(audit.reason).to eq("Duplicate award reversal")
      end

      it "returns an error if reason is blank" do
        staff = Fabricate(:character)
        result = Soul::SoulXpApi.correct(character, 10, reason: "", actor: staff)
        expect(result[:error]).to match(/reason.*required/i)
      end

      it "returns an error if amount is not positive" do
        staff = Fabricate(:character)
        result = Soul::SoulXpApi.correct(character, 0, reason: "Test", actor: staff)
        expect(result[:error]).to match(/positive/i)
      end
    end

    describe ".get_scene_participants" do
      it "returns an empty list when scene is nil" do
        result = Soul::SoulXpApi.get_scene_participants(nil)
        expect(result).to eq([])
      end

      it "filters to approved characters only" do
        scene = Fabricate(:scene)
        approved = Fabricate(:character)
        unapproved = Fabricate(:character, is_approved: false)
        scene.update(people: [approved, unapproved])
        allow(Chargen).to receive(:approved_chars).and_return([approved])
        result = Soul::SoulXpApi.get_scene_participants(scene)
        expect(result).to eq([approved])
      end

      it "handles scenes with no people" do
        scene = Fabricate(:scene)
        result = Soul::SoulXpApi.get_scene_participants(scene)
        expect(result).to be_empty
      end
    end
  end
end

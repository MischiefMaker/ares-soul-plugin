require_relative 'spec_helper'

module AresMUSH
  describe SoulResonanceApi do
    let(:character) { Fabricate(:character) }

    before do
      allow(Global).to receive(:read_config).and_call_original
      allow(Global).to receive(:read_config).with("soul", "resonance", "enabled").and_return(true)
      allow(Global).to receive(:read_config).with("soul", "resonance", "min").and_return(-3)
      allow(Global).to receive(:read_config).with("soul", "resonance", "max").and_return(3)
      allow(Global).to receive(:read_config).with("soul", "resonance", "r0_skill_points").and_return(15)
      allow(Global).to receive(:read_config).with("soul", "resonance", "r0_starting_cap").and_return(7)
      allow(Global).to receive(:read_config).with("soul", "resonance", "positive_skill_points_per_level").and_return(2)
      allow(Global).to receive(:read_config).with("soul", "resonance", "negative_skill_points_per_level").and_return(2)
      allow(Global).to receive(:read_config).with("soul", "resonance", "positive_starting_cap_per_level").and_return(1)
      allow(Global).to receive(:read_config).with("soul", "resonance", "negative_starting_cap_per_level").and_return(1)
      allow(Global).to receive(:read_config).with("soul", "resonance", "r0_aspect_points").and_return(5)
      allow(Global).to receive(:read_config).with("soul", "resonance", "positive_aspect_points_per_level").and_return(1)
      allow(Global).to receive(:read_config).with("soul", "resonance", "negative_aspect_points_per_level").and_return(1)
    end

    describe ".chargen_allowance" do
      it "matches the canonical symmetric table (FINAL REQ-012) and the Aspect point-buy pool (added 2026-07-24 at the project owner's direction)" do
        expect(SoulResonanceApi.chargen_allowance(-3)).to eq(skill_points: 9, starting_cap: 4, aspect_points: 2)
        expect(SoulResonanceApi.chargen_allowance(-1)).to eq(skill_points: 13, starting_cap: 6, aspect_points: 4)
        expect(SoulResonanceApi.chargen_allowance(0)).to eq(skill_points: 15, starting_cap: 7, aspect_points: 5)
        expect(SoulResonanceApi.chargen_allowance(1)).to eq(skill_points: 17, starting_cap: 8, aspect_points: 6)
        expect(SoulResonanceApi.chargen_allowance(3)).to eq(skill_points: 21, starting_cap: 10, aspect_points: 8)
      end
    end

    describe ".get_resonance" do
      it "returns nil when never chosen, not 0" do
        expect(SoulResonanceApi.get_resonance(character)).to be_nil
      end

      it "returns the chosen value, including an explicit R0" do
        character.update(resonance: "0")
        expect(SoulResonanceApi.get_resonance(character)).to eq(0)
      end
    end

    describe ".set_resonance" do
      it "sets the value before locking" do
        result = SoulResonanceApi.set_resonance(character, 2, character)
        expect(result[:success]).to be true
        expect(SoulResonanceApi.get_resonance(character)).to eq(2)
      end

      it "rejects a value outside the configured range" do
        result = SoulResonanceApi.set_resonance(character, 5, character)
        expect(result[:error]).to match(/between/i)
      end

      it "refuses to change an already-locked Resonance" do
        character.update(resonance: "1", resonance_locked_at: Time.now)
        result = SoulResonanceApi.set_resonance(character, 2, character)
        expect(result[:error]).to match(/locked/i)
      end
    end

    describe ".lock_at_approval" do
      it "defaults to R0 if the player never chose one" do
        SoulResonanceApi.lock_at_approval(character)
        expect(SoulResonanceApi.get_resonance(character)).to eq(0)
        expect(SoulResonanceApi.locked?(character)).to be true
      end

      it "is a no-op if already locked" do
        character.update(resonance: "2", resonance_locked_at: Time.now)
        expect { SoulResonanceApi.lock_at_approval(character) }.not_to change { character.reload.resonance }
      end
    end

    describe ".correct" do
      it "requires a reason" do
        character.update(resonance: "1", resonance_locked_at: Time.now)
        result = SoulResonanceApi.correct(character, 2, actor: character, reason: "")
        expect(result[:error]).to match(/reason/i)
      end

      it "updates the value and appends to the correction log" do
        character.update(resonance: "1", resonance_locked_at: Time.now)
        result = SoulResonanceApi.correct(character, 2, actor: character, reason: "Staff review")
        expect(result[:success]).to be true
        expect(SoulResonanceApi.get_resonance(character)).to eq(2)
        expect(character.reload.resonance_correction_log.length).to eq(1)
      end
    end
  end
end

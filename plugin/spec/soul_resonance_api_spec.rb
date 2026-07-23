require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulResonanceApi do
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
    end

    describe ".chargen_allowance" do
      it "matches the canonical symmetric table (FINAL REQ-012)" do
        expect(Soul::SoulResonanceApi.chargen_allowance(-3)).to eq(skill_points: 9, starting_cap: 4)
        expect(Soul::SoulResonanceApi.chargen_allowance(-1)).to eq(skill_points: 13, starting_cap: 6)
        expect(Soul::SoulResonanceApi.chargen_allowance(0)).to eq(skill_points: 15, starting_cap: 7)
        expect(Soul::SoulResonanceApi.chargen_allowance(1)).to eq(skill_points: 17, starting_cap: 8)
        expect(Soul::SoulResonanceApi.chargen_allowance(3)).to eq(skill_points: 21, starting_cap: 10)
      end
    end

    describe ".get_resonance" do
      it "returns nil when never chosen, not 0" do
        expect(Soul::SoulResonanceApi.get_resonance(character)).to be_nil
      end

      it "returns the chosen value, including an explicit R0" do
        character.update(resonance: "0")
        expect(Soul::SoulResonanceApi.get_resonance(character)).to eq(0)
      end
    end

    describe ".set_resonance" do
      it "sets the value before locking" do
        result = Soul::SoulResonanceApi.set_resonance(character, 2, character)
        expect(result[:success]).to be true
        expect(Soul::SoulResonanceApi.get_resonance(character)).to eq(2)
      end

      it "rejects a value outside the configured range" do
        result = Soul::SoulResonanceApi.set_resonance(character, 5, character)
        expect(result[:error]).to match(/between/i)
      end

      it "refuses to change an already-locked Resonance" do
        character.update(resonance: "1", resonance_locked_at: Time.now)
        result = Soul::SoulResonanceApi.set_resonance(character, 2, character)
        expect(result[:error]).to match(/locked/i)
      end
    end

    describe ".lock_at_approval" do
      it "defaults to R0 if the player never chose one" do
        Soul::SoulResonanceApi.lock_at_approval(character)
        expect(Soul::SoulResonanceApi.get_resonance(character)).to eq(0)
        expect(Soul::SoulResonanceApi.locked?(character)).to be true
      end

      it "is a no-op if already locked" do
        character.update(resonance: "2", resonance_locked_at: Time.now)
        expect { Soul::SoulResonanceApi.lock_at_approval(character) }.not_to change { character.reload.resonance }
      end
    end

    describe ".correct" do
      it "requires a reason" do
        character.update(resonance: "1", resonance_locked_at: Time.now)
        result = Soul::SoulResonanceApi.correct(character, 2, actor: character, reason: "")
        expect(result[:error]).to match(/reason/i)
      end

      it "updates the value and appends to the correction log" do
        character.update(resonance: "1", resonance_locked_at: Time.now)
        result = Soul::SoulResonanceApi.correct(character, 2, actor: character, reason: "Staff review")
        expect(result[:success]).to be true
        expect(Soul::SoulResonanceApi.get_resonance(character)).to eq(2)
        expect(character.reload.resonance_correction_log.length).to eq(1)
      end
    end
  end
end

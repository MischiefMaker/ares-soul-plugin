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

    describe ".description" do
      it "falls back to DEFAULT_DESCRIPTION when unconfigured" do
        allow(Global).to receive(:read_config).with("soul", "resonance", "description").and_return(nil)
        expect(SoulResonanceApi.description).to eq(SoulResonanceApi::DEFAULT_DESCRIPTION)
      end

      it "uses the configured description when present (2026-07-26: made configurable at the " \
        "project owner's request)" do
        allow(Global).to receive(:read_config).with("soul", "resonance", "description")
          .and_return("Custom flavor text.")
        expect(SoulResonanceApi.description).to eq("Custom flavor text.")
      end
    end

    describe ".warning_label (2026-07-26: non-blocking +app review heads-up)" do
      it "returns nil for a value inside the configured range" do
        expect(SoulResonanceApi.warning_label(1)).to be_nil
      end

      it "returns 'Very High!' at or above warn_high_at (defaults to .max)" do
        expect(SoulResonanceApi.warning_label(3)).to eq("Very High!")
      end

      it "returns 'Very Low!' at or below warn_low_at (defaults to .min)" do
        expect(SoulResonanceApi.warning_label(-3)).to eq("Very Low!")
      end

      it "returns nil for a nil value (never chosen yet)" do
        expect(SoulResonanceApi.warning_label(nil)).to be_nil
      end

      it "honors configured warn_high_at/warn_low_at overrides" do
        allow(Global).to receive(:read_config).with("soul", "resonance", "warn_high_at").and_return(2)
        allow(Global).to receive(:read_config).with("soul", "resonance", "warn_low_at").and_return(-2)
        expect(SoulResonanceApi.warning_label(2)).to eq("Very High!")
        expect(SoulResonanceApi.warning_label(-2)).to eq("Very Low!")
      end

      it "returns nil regardless of value when review_flag_at_extremes is false" do
        allow(Global).to receive(:read_config).with("soul", "resonance", "review_flag_at_extremes")
          .and_return(false)
        expect(SoulResonanceApi.warning_label(3)).to be_nil
        expect(SoulResonanceApi.warning_label(-3)).to be_nil
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

    describe ".default_at_chargen" do
      it "sets an unset character to R0, unlocked" do
        allow(character).to receive(:is_approved?).and_return(false)
        SoulResonanceApi.default_at_chargen(character)
        expect(SoulResonanceApi.get_resonance(character)).to eq(0)
        expect(SoulResonanceApi.locked?(character)).to be false
      end

      it "does not override a value the player already chose" do
        allow(character).to receive(:is_approved?).and_return(false)
        character.update(resonance: "2")
        SoulResonanceApi.default_at_chargen(character)
        expect(SoulResonanceApi.get_resonance(character)).to eq(2)
      end

      it "is a no-op once the character is approved" do
        allow(character).to receive(:is_approved?).and_return(true)
        SoulResonanceApi.default_at_chargen(character)
        expect(SoulResonanceApi.get_resonance(character)).to be_nil
      end

      it "is a no-op when Resonance is disabled" do
        allow(Global).to receive(:read_config).with("soul", "resonance", "enabled").and_return(false)
        SoulResonanceApi.default_at_chargen(character)
        expect(SoulResonanceApi.get_resonance(character)).to be_nil
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

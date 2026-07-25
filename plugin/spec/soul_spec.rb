require_relative 'spec_helper'

module AresMUSH
  describe Soul do
    describe ".app_review" do
      let(:character) { Fabricate(:character) }

      it "returns nil when SOUL is disabled" do
        allow(Global).to receive(:read_config).with("soul", "enabled").and_return(false)
        expect(Soul.app_review(character)).to be_nil
      end

      it "returns nil when the character hasn't touched any SOUL chargen step yet" do
        allow(Global).to receive(:read_config).with("soul", "enabled").and_return(true)
        allow(SoulChargenWebHandler).to receive(:status).with(character).and_return(
          resonance: nil, points_spent: 0, aspect_points_spent: 0, has_selected_bnb: false
        )
        expect(Soul.app_review(character)).to be_nil
      end

      it "reports readiness once the character has spent Skill points" do
        allow(Global).to receive(:read_config).with("soul", "enabled").and_return(true)
        allow(SoulChargenWebHandler).to receive(:status).with(character).and_return(
          resonance: nil, resonance_enabled: false,
          points_spent: 15, skill_points: 15, skill_points_fully_spent: true,
          aspect_points_spent: 3, aspect_points: 5, aspect_points_fully_spent: false,
          bnb_ratio_satisfied: true, has_selected_bnb: true
        )

        result = Soul.app_review(character)
        expect(result).to match(/SOUL Skill points/)
        expect(result).to match(/SOUL Aspect points/)
        expect(result).to match(/SOUL Boon\/Bane ratio/)
        expect(result).not_to match(/SOUL Resonance/)
      end

      it "includes Resonance when Resonance is enabled" do
        allow(Global).to receive(:read_config).with("soul", "enabled").and_return(true)
        allow(SoulChargenWebHandler).to receive(:status).with(character).and_return(
          resonance: 1, resonance_enabled: true,
          points_spent: 15, skill_points: 15, skill_points_fully_spent: true,
          aspect_points_spent: 5, aspect_points: 5, aspect_points_fully_spent: true,
          bnb_ratio_satisfied: true, has_selected_bnb: false
        )

        expect(Soul.app_review(character)).to match(/SOUL Resonance.*R1/)
      end

      it "returns nil for a nil character" do
        expect(Soul.app_review(nil)).to be_nil
      end
    end
  end
end

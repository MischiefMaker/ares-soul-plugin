require_relative 'spec_helper'

module AresMUSH
  describe SoulCharacterApi do
    let(:character) { Fabricate(:character) }

    before do
      allow(Global).to receive(:read_config).and_call_original
      allow(Global).to receive(:read_config).with("soul", "aspect", "weight").and_return(0.20)
      allow(Global).to receive(:read_config).with("soul", "framework", "skill_min_rating").and_return(0)
      allow(Global).to receive(:read_config).with("soul", "framework", "skill_max_rating").and_return(10)
      allow(Global).to receive(:read_config).with("soul", "framework", "aspects").and_return(
        "body" => { "name" => "Body", "order" => 1 }
      )
      allow(Global).to receive(:read_config).with("soul", "framework", "skills").and_return(
        "blade" => { "name" => "Blade", "aspect" => "body", "order" => 1 }
      )
    end

    describe ".aspect_contribution" do
      it "matches the Addendum §7 rounding examples" do
        expect(SoulCharacterApi.aspect_contribution(1)).to eq(0)   # 0.20 -> 0
        expect(SoulCharacterApi.aspect_contribution(2)).to eq(0)   # 0.40 -> 0
        expect(SoulCharacterApi.aspect_contribution(3)).to eq(1)   # 0.60 -> 1
        expect(SoulCharacterApi.aspect_contribution(4)).to eq(1)   # 0.80 -> 1
        expect(SoulCharacterApi.aspect_contribution(5)).to eq(1)   # 1.00 -> 1
      end
    end

    describe ".set_skill_rating / .get_skill_rating" do
      it "sets and reads back a rating" do
        result = SoulCharacterApi.set_skill_rating(character, "blade", 4, character)
        expect(result[:success]).to be true
        expect(SoulCharacterApi.get_skill_rating(character, "blade")).to eq(4)
      end

      it "rejects a rating above the configured maximum" do
        result = SoulCharacterApi.set_skill_rating(character, "blade", 11, character)
        expect(result[:error]).to match(/between/i)
      end

      it "rejects an unknown skill key" do
        result = SoulCharacterApi.set_skill_rating(character, "nonexistent", 1, character)
        expect(result[:error]).to match(/unknown skill/i)
      end

      it "returns 0 for a skill the character has no rating in yet" do
        expect(SoulCharacterApi.get_skill_rating(character, "blade")).to eq(0)
      end
    end

    describe ".get_effective_base" do
      it "combines Skill rating with rounded Aspect contribution" do
        SoulCharacterApi.set_skill_rating(character, "blade", 3, character)
        SoulCharacterApi.set_aspect_rating(character, "body", 4, character)
        # 3 (skill) + round_nearest(4 * 0.20) = 3 + 1 = 4
        expect(SoulCharacterApi.get_effective_base(character, "blade")).to eq(4)
      end
    end
  end
end

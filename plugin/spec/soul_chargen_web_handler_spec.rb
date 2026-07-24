require_relative 'spec_helper'

module AresMUSH
  describe SoulChargenWebHandler do
    let(:character) { Fabricate(:character) }

    before do
      allow(Website).to receive(:check_login).and_return(nil)
    end

    it "rejects an approved character" do
      allow(character).to receive(:is_approved?).and_return(true)
      request = double(cmd: "soulChargenStatus", enactor: character, args: {})
      expect(subject.handle(request)[:error]).to be_present
    end

    it "allows an unapproved character with no play_permission configured (BUG-005)" do
      allow(character).to receive(:is_approved?).and_return(false)
      allow(SoulResonanceApi).to receive(:enabled?).and_return(false)
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(nil)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(skill_points: 15, starting_cap: 7)
      allow(SoulFrameworkApi).to receive(:get_skills).and_return([])
      allow(SoulFrameworkApi).to receive(:get_aspects).and_return([])
      allow(SoulBnbApi).to receive(:get_character_entries).and_return([])
      allow(SoulBnbApi).to receive(:get_catalogue).and_return([])
      request = double(cmd: "soulChargenStatus", enactor: character, args: {})
      expect(subject.handle(request)[:error]).to be_nil
    end

    it "rejects a Skill allocation over the available budget" do
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(0)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(
        skill_points: 3, starting_cap: 5
      )
      allow(SoulFrameworkApi).to receive(:get_skills).and_return([
        { key: "blade" }, { key: "spirit" }
      ])
      allow(SoulCharacterApi).to receive(:get_skill_rating).with(character, "blade").and_return(2)
      allow(SoulCharacterApi).to receive(:get_skill_rating).with(character, "spirit").and_return(1)

      result = SoulChargenWebHandler.set_skill(character, "blade", 4)
      expect(result[:error]).to match(/spend 5 of 3/i)
    end

    it "sets a Skill when the cap and budget permit it" do
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(0)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(
        skill_points: 5, starting_cap: 4
      )
      allow(SoulFrameworkApi).to receive(:get_skills).and_return([{ key: "blade" }])
      allow(SoulCharacterApi).to receive(:get_skill_rating).and_return(0)
      allow(SoulCharacterApi).to receive(:set_skill_rating).and_return(success: true, new_rating: 3)

      expect(SoulChargenWebHandler.set_skill(character, "blade", 3)[:success]).to be true
      expect(SoulCharacterApi).to have_received(:set_skill_rating).with(character, "blade", 3, character)
    end

    it "provides display-ready summary fields for the chargen layout" do
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(1)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(
        skill_points: 17, starting_cap: 8
      )
      allow(SoulResonanceApi).to receive(:enabled?).and_return(true)
      allow(SoulResonanceApi).to receive(:min).and_return(-3)
      allow(SoulResonanceApi).to receive(:max).and_return(3)
      allow(SoulFrameworkApi).to receive(:get_skills).and_return([])
      allow(SoulFrameworkApi).to receive(:get_aspects).and_return([])
      allow(SoulBnbApi).to receive(:get_character_entries).and_return([])
      allow(SoulBnbApi).to receive(:get_catalogue).and_return([])

      status = SoulChargenWebHandler.status(character)
      expect(status[:resonance_label]).to eq("R1")
      expect(status[:has_selected_bnb]).to be false
    end
  end
end

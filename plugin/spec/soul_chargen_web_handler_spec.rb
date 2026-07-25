require_relative 'spec_helper'

module AresMUSH
  describe SoulChargenWebHandler do
    let(:character) { Fabricate(:character) }

    before do
      allow(Website).to receive(:check_login).and_return(nil)
    end

    it "allows an already-approved character (web chargen intentionally has no is_approved? gate)" do
      allow(character).to receive(:is_approved?).and_return(true)
      allow(SoulResonanceApi).to receive(:enabled?).and_return(false)
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(nil)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(
        skill_points: 15, starting_cap: 7, aspect_points: 5
      )
      allow(SoulFrameworkApi).to receive(:get_skills).and_return([])
      allow(SoulFrameworkApi).to receive(:get_aspects).and_return([])
      allow(SoulFrameworkApi).to receive(:aspect_min_rating).and_return(0)
      allow(SoulFrameworkApi).to receive(:aspect_max_rating).and_return(5)
      allow(SoulBnbApi).to receive(:get_character_entries).and_return([])
      allow(SoulBnbApi).to receive(:get_catalogue).and_return([])
      request = double(cmd: "soulChargenStatus", enactor: character, args: {})
      expect(subject.handle(request)[:error]).to be_nil
    end

    it "allows an unapproved character with no play_permission configured (BUG-005)" do
      allow(character).to receive(:is_approved?).and_return(false)
      allow(SoulResonanceApi).to receive(:enabled?).and_return(false)
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(nil)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(
        skill_points: 15, starting_cap: 7, aspect_points: 5
      )
      allow(SoulFrameworkApi).to receive(:get_skills).and_return([])
      allow(SoulFrameworkApi).to receive(:get_aspects).and_return([])
      allow(SoulFrameworkApi).to receive(:aspect_min_rating).and_return(0)
      allow(SoulFrameworkApi).to receive(:aspect_max_rating).and_return(5)
      allow(SoulBnbApi).to receive(:get_character_entries).and_return([])
      allow(SoulBnbApi).to receive(:get_catalogue).and_return([])
      request = double(cmd: "soulChargenStatus", enactor: character, args: {})
      expect(subject.handle(request)[:error]).to be_nil
    end

    it "rejects a Skill allocation over the available budget" do
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(0)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(
        skill_points: 3, starting_cap: 5, aspect_points: 5
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
        skill_points: 5, starting_cap: 4, aspect_points: 5
      )
      allow(SoulFrameworkApi).to receive(:get_skills).and_return([{ key: "blade" }])
      allow(SoulCharacterApi).to receive(:get_skill_rating).and_return(0)
      allow(SoulCharacterApi).to receive(:set_skill_rating).and_return(success: true, new_rating: 3)

      expect(SoulChargenWebHandler.set_skill(character, "blade", 3)[:success]).to be true
      expect(SoulCharacterApi).to have_received(:set_skill_rating).with(character, "blade", 3, character)
    end

    it "rejects an Aspect allocation over the available budget" do
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(0)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(
        skill_points: 15, starting_cap: 7, aspect_points: 3
      )
      allow(SoulFrameworkApi).to receive(:aspect_min_rating).and_return(0)
      allow(SoulFrameworkApi).to receive(:aspect_max_rating).and_return(5)
      allow(SoulFrameworkApi).to receive(:get_aspects).and_return([
        { key: "body" }, { key: "mind" }
      ])
      allow(SoulCharacterApi).to receive(:get_aspect_rating).with(character, "body").and_return(2)
      allow(SoulCharacterApi).to receive(:get_aspect_rating).with(character, "mind").and_return(1)

      result = SoulChargenWebHandler.set_aspect(character, "body", 4)
      expect(result[:error]).to match(/spend 5 of 3/i)
    end

    it "rejects an Aspect allocation outside the configured min/max range" do
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(0)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(
        skill_points: 15, starting_cap: 7, aspect_points: 5
      )
      allow(SoulFrameworkApi).to receive(:aspect_min_rating).and_return(0)
      allow(SoulFrameworkApi).to receive(:aspect_max_rating).and_return(5)

      result = SoulChargenWebHandler.set_aspect(character, "body", 6)
      expect(result[:error]).to match(/between/i)
    end

    it "sets an Aspect when the range and budget permit it" do
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(0)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(
        skill_points: 15, starting_cap: 7, aspect_points: 5
      )
      allow(SoulFrameworkApi).to receive(:aspect_min_rating).and_return(0)
      allow(SoulFrameworkApi).to receive(:aspect_max_rating).and_return(5)
      allow(SoulFrameworkApi).to receive(:get_aspects).and_return([{ key: "body" }])
      allow(SoulCharacterApi).to receive(:get_aspect_rating).and_return(0)
      allow(SoulCharacterApi).to receive(:set_aspect_rating).and_return(success: true, new_rating: 3)

      expect(SoulChargenWebHandler.set_aspect(character, "body", 3)[:success]).to be true
      expect(SoulCharacterApi).to have_received(:set_aspect_rating).with(character, "body", 3, character)
    end

    it "provides display-ready summary fields for the chargen layout" do
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(1)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(
        skill_points: 17, starting_cap: 8, aspect_points: 6
      )
      allow(SoulResonanceApi).to receive(:enabled?).and_return(true)
      allow(SoulResonanceApi).to receive(:min).and_return(-3)
      allow(SoulResonanceApi).to receive(:max).and_return(3)
      allow(SoulFrameworkApi).to receive(:get_skills).and_return([])
      allow(SoulFrameworkApi).to receive(:get_aspects).and_return([])
      allow(SoulFrameworkApi).to receive(:aspect_min_rating).and_return(0)
      allow(SoulFrameworkApi).to receive(:aspect_max_rating).and_return(5)
      allow(SoulBnbApi).to receive(:get_character_entries).and_return([])
      allow(SoulBnbApi).to receive(:get_catalogue).and_return([])

      status = SoulChargenWebHandler.status(character)
      expect(status[:resonance_label]).to eq("R1")
      expect(status[:has_selected_bnb]).to be false
      expect(status[:aspect_points]).to eq(6)
      expect(status[:aspect_min_rating]).to eq(0)
      expect(status[:aspect_max_rating]).to eq(5)
      expect(SoulBnbApi).to have_received(:get_catalogue).with(chargen_available: true)
    end

    it "flags catalogue entries with no fixed Skill so the UI can show a Skill picker (BUG-015)" do
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(0)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(
        skill_points: 5, starting_cap: 4, aspect_points: 5
      )
      allow(SoulResonanceApi).to receive(:enabled?).and_return(false)
      allow(SoulFrameworkApi).to receive(:get_skills).and_return([])
      allow(SoulFrameworkApi).to receive(:get_aspects).and_return([])
      allow(SoulFrameworkApi).to receive(:aspect_min_rating).and_return(0)
      allow(SoulFrameworkApi).to receive(:aspect_max_rating).and_return(5)
      allow(SoulBnbApi).to receive(:get_character_entries).and_return([])
      configurable = double(id: 1, tag: "cursed", name: "Cursed", description: "x", kind: "bane",
        skill_associations: [])
      fixed = double(id: 2, tag: "attuned", name: "Attuned", description: "x", kind: "boon",
        skill_associations: ["blade"])
      allow(SoulBnbApi).to receive(:get_catalogue).and_return([configurable, fixed])

      status = SoulChargenWebHandler.status(character)
      expect(status[:catalogue].find { |e| e[:id] == 1 }[:has_fixed_skills]).to be false
      expect(status[:catalogue].find { |e| e[:id] == 2 }[:has_fixed_skills]).to be true
    end

    it "reports readiness indicators without blocking anything (informational only)" do
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(0)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(
        skill_points: 5, starting_cap: 4, aspect_points: 5
      )
      allow(SoulResonanceApi).to receive(:enabled?).and_return(false)
      allow(SoulFrameworkApi).to receive(:get_skills).and_return([{ key: "blade" }])
      allow(SoulFrameworkApi).to receive(:get_aspects).and_return([{ key: "body" }])
      allow(SoulFrameworkApi).to receive(:aspect_min_rating).and_return(0)
      allow(SoulFrameworkApi).to receive(:aspect_max_rating).and_return(5)
      allow(SoulCharacterApi).to receive(:get_skill_rating).and_return(5)
      allow(SoulCharacterApi).to receive(:get_aspect_rating).and_return(2)
      allow(SoulBnbApi).to receive(:get_character_entries).and_return([])
      allow(SoulBnbApi).to receive(:get_catalogue).and_return([])

      status = SoulChargenWebHandler.status(character)
      expect(status[:skill_points_fully_spent]).to be true
      expect(status[:aspect_points_fully_spent]).to be false
      expect(status[:bnb_ratio_satisfied]).to be true
    end
  end
end

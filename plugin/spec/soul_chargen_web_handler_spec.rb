require_relative 'spec_helper'

module AresMUSH
  describe SoulChargenWebHandler do
    let(:character) { Fabricate(:character) }

    before do
      allow(Website).to receive(:check_login).and_return(nil)
    end

    describe ".resolve_character" do
      let(:staff) { Fabricate(:character) }
      let(:applicant) { Fabricate(:character) }

      it "targets the enactor when no character_id is given (the overwhelmingly common case)" do
        request = double(enactor: applicant, args: {})
        expect(SoulChargenWebHandler.resolve_character(request)).to eq(applicant)
      end

      # 2026-07-31 live testing: an admin walking an applicant through
      # chargen via the game's own /chargen/:id page (the SOUL tab) was
      # silently editing their own Resonance/Skills/B&Bs instead of the
      # applicant's, because this method didn't exist yet and the handler
      # always used request.enactor.
      it "lets manage_soul staff target another character by id" do
        allow(Soul).to receive(:can_manage_soul?).with(staff).and_return(true)
        allow(Character).to receive(:find_one_by_name).with(applicant.id.to_s).and_return(applicant)
        request = double(enactor: staff, args: { 'character_id' => applicant.id.to_s })
        expect(SoulChargenWebHandler.resolve_character(request)).to eq(applicant)
      end

      it "denies a non-staff character trying to target someone else" do
        allow(Soul).to receive(:can_manage_soul?).with(applicant).and_return(false)
        other = Fabricate(:character)
        allow(Character).to receive(:find_one_by_name).with(other.id.to_s).and_return(other)
        request = double(enactor: applicant, args: { 'character_id' => other.id.to_s })
        expect(SoulChargenWebHandler.resolve_character(request)).to be_nil
      end

      it "allows targeting yourself by id even without manage_soul (a no-op, not a privilege check)" do
        allow(Character).to receive(:find_one_by_name).with(applicant.id.to_s).and_return(applicant)
        request = double(enactor: applicant, args: { 'character_id' => applicant.id.to_s })
        expect(SoulChargenWebHandler.resolve_character(request)).to eq(applicant)
      end

      it "returns nil for an unknown character_id" do
        allow(Character).to receive(:find_one_by_name).with("99999").and_return(nil)
        request = double(enactor: staff, args: { 'character_id' => "99999" })
        expect(SoulChargenWebHandler.resolve_character(request)).to be_nil
      end

      it "returns nil when there is no enactor" do
        request = double(enactor: nil, args: {})
        expect(SoulChargenWebHandler.resolve_character(request)).to be_nil
      end
    end

    it "returns a permission error from handle when resolve_character denies the request" do
      request = double(cmd: "soulChargenStatus", enactor: character, args: { 'character_id' => "99999" })
      allow(Character).to receive(:find_one_by_name).with("99999").and_return(nil)
      expect(subject.handle(request)[:error]).to match(/permission/i)
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

    it "still applies a Skill allocation over the available budget, with a warning instead of blocking " \
      "(mischief bug list, 2026-07-25 - lowering Resonance after spending must not trap the player)" do
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(0)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(
        skill_points: 3, starting_cap: 5, aspect_points: 5
      )
      allow(SoulFrameworkApi).to receive(:get_skills).and_return([
        { key: "blade" }, { key: "spirit" }
      ])
      allow(SoulCharacterApi).to receive(:get_skill_rating).with(character, "blade").and_return(2)
      allow(SoulCharacterApi).to receive(:get_skill_rating).with(character, "spirit").and_return(1)
      allow(SoulCharacterApi).to receive(:set_skill_rating).and_return(success: true, new_rating: 4)

      result = SoulChargenWebHandler.set_skill(character, "blade", 4)
      expect(result[:error]).to be_nil
      expect(result[:warning]).to match(/spend 5 of 3/i)
      expect(SoulCharacterApi).to have_received(:set_skill_rating).with(character, "blade", 4, character)
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

    it "still applies an Aspect allocation over the available budget, with a warning instead of blocking" do
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
      allow(SoulCharacterApi).to receive(:set_aspect_rating).and_return(success: true, new_rating: 4)

      result = SoulChargenWebHandler.set_aspect(character, "body", 4)
      expect(result[:error]).to be_nil
      expect(result[:warning]).to match(/spend 5 of 3/i)
      expect(SoulCharacterApi).to have_received(:set_aspect_rating).with(character, "body", 4, character)
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
      expect(status[:character_name]).to eq(character.name)
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

    it "flags an over-budget character as not fully spent rather than falsely reading OK " \
      "(e.g. after lowering Resonance below an already-spent total)" do
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(0)
      allow(SoulResonanceApi).to receive(:chargen_allowance).and_return(
        skill_points: 3, starting_cap: 4, aspect_points: 5
      )
      allow(SoulResonanceApi).to receive(:enabled?).and_return(false)
      allow(SoulFrameworkApi).to receive(:get_skills).and_return([{ key: "blade" }])
      allow(SoulFrameworkApi).to receive(:get_aspects).and_return([])
      allow(SoulFrameworkApi).to receive(:aspect_min_rating).and_return(0)
      allow(SoulFrameworkApi).to receive(:aspect_max_rating).and_return(5)
      allow(SoulCharacterApi).to receive(:get_skill_rating).and_return(5)
      allow(SoulBnbApi).to receive(:get_character_entries).and_return([])
      allow(SoulBnbApi).to receive(:get_catalogue).and_return([])

      status = SoulChargenWebHandler.status(character)
      expect(status[:points_remaining]).to eq(-2)
      expect(status[:skill_points_fully_spent]).to be false
    end
  end
end

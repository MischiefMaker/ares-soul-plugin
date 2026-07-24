require_relative 'spec_helper'

module AresMUSH
  describe SoulSheetWebHandler do
    it "rejects a guessed character without permission" do
      viewer = Fabricate(:character)
      target = Fabricate(:character)
      request = double(enactor: viewer, args: { 'character' => target.name })
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_play?).and_return(true)
      allow(Soul).to receive(:can_manage_soul?).and_return(false)
      allow(Soul).to receive(:can_review_rolls?).and_return(false)
      expect(subject.handle(request)[:error]).to be_present
    end

    it "provides a display label when Resonance is unset" do
      character = Fabricate(:character)
      request = double(enactor: character, args: {})
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_play?).and_return(true)
      allow(SoulResonanceApi).to receive(:get_resonance).and_return(nil)
      allow(SoulFrameworkApi).to receive(:get_aspects).and_return([])
      allow(SoulBnbApi).to receive(:get_character_entries).and_return([])

      expect(subject.handle(request)[:resonance_label]).to eq("Unset")
    end

    describe "B&B explanation visibility" do
      let(:target) { Fabricate(:character) }
      let(:catalogue) { double(name: "Cursed", tag: "cursed", kind: "bane", description: "A curse.") }
      let(:entry) do
        double(id: 9, catalogue_entry: catalogue, level_state: "minor", resolved: "false",
          character_explanation: "A witch's grudge.")
      end

      before do
        allow(Website).to receive(:check_login).and_return(nil)
        allow(SoulResonanceApi).to receive(:get_resonance).and_return(nil)
        allow(SoulFrameworkApi).to receive(:get_aspects).and_return([])
        allow(SoulBnbApi).to receive(:get_character_entries).with(target).and_return([entry])
      end

      it "shows the owner their own explanation" do
        request = double(enactor: target, args: {})
        allow(Soul).to receive(:can_play?).and_return(true)

        bnb = subject.handle(request)[:bnb].first
        expect(bnb[:explanation_visible]).to be true
        expect(bnb[:explanation]).to eq("A witch's grudge.")
      end

      it "shows manage_soul staff another character's explanation" do
        staff = Fabricate(:character)
        request = double(enactor: staff, args: { 'character' => target.name })
        allow(Soul).to receive(:can_manage_soul?).with(staff).and_return(true)

        bnb = subject.handle(request)[:bnb].first
        expect(bnb[:explanation_visible]).to be true
        expect(bnb[:explanation]).to eq("A witch's grudge.")
      end

      it "does not show a scene-GM viewer the explanation, even though they can view the Sheet" do
        gm = Fabricate(:character)
        scene = double(participants: [gm, target])
        request = double(enactor: gm, args: { 'character' => target.name, 'scene_id' => 1 })
        allow(Soul).to receive(:can_manage_soul?).with(gm).and_return(false)
        allow(Soul).to receive(:can_review_rolls?).with(gm).and_return(true)
        allow(Scene).to receive(:[]).with(1).and_return(scene)

        bnb = subject.handle(request)[:bnb].first
        expect(bnb[:explanation_visible]).to be false
        expect(bnb).not_to have_key(:explanation)
      end
    end
  end
end

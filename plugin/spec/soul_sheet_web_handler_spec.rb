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
  end
end

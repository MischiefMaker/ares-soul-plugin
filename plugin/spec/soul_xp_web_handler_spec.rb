require_relative 'spec_helper'

module AresMUSH
  describe SoulXpWebHandler do
    it "previews a spend before committing" do
      character = Fabricate(:character)
      request = double(cmd: "soulXpSpend", enactor: character,
        args: { 'skill_key' => 'strength', 'amount' => 1 })
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_play?).and_return(true)
      allow(SoulXpApi).to receive(:calculate_cost).and_return(1)
      allow(SoulCharacterApi).to receive(:get_skill_rating).and_return(0)
      expect(subject.handle(request)[:preview]).to be true
    end
  end
end

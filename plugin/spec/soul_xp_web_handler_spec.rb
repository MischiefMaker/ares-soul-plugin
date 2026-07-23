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

    it "surfaces a failed scene award as an error like the MUSH command" do
      staff = Fabricate(:character)
      recipient = Fabricate(:character)
      scene = double(id: 12)
      request = double(cmd: "soulXpScene", enactor: staff,
        args: { 'scene_id' => '12', 'amount' => 2, 'reason' => 'scene',
                'confirmed' => 'true' })
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_manage_soul?).and_return(true)
      allow(Scene).to receive(:[]).with('12').and_return(scene)
      allow(SoulXpApi).to receive(:get_scene_participants).and_return([recipient])
      allow(SoulXpApi).to receive(:award).and_return(error: "award failed")

      expect(subject.handle(request)).to eq(error: "award failed")
    end
  end
end

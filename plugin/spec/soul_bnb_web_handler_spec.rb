require_relative 'spec_helper'

module AresMUSH
  describe SoulBnbWebHandler do
    it "rechecks staff permission for catalogue creation" do
      request = double(cmd: "soulBnbCreate", enactor: Fabricate(:character), args: {})
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_manage_soul?).and_return(false)
      expect(subject.handle(request)[:error]).to be_present
    end

    describe "soulBnbHere" do
      before do
        allow(Website).to receive(:check_login).and_return(nil)
        allow(Soul).to receive(:can_play?).and_return(true)
      end

      it "rejects a requester who is not a participant in the scene" do
        enactor = Fabricate(:character)
        scene = double(participants: [])
        allow(Scene).to receive(:[]).and_return(scene)
        request = double(cmd: "soulBnbHere", enactor: enactor, args: { 'scene_id' => '1', 'reference' => 'tag' })
        expect(subject.handle(request)[:error]).to be_present
      end

      it "returns public-safe matches among scene participants" do
        enactor = Fabricate(:character)
        other = Fabricate(:character)
        scene = double(participants: [enactor, other])
        allow(Scene).to receive(:[]).and_return(scene)
        catalogue = double(id: 5)
        allow(SoulBnbApi).to receive(:get_catalogue_entry).and_return(catalogue)
        entry = double(id: 9, catalogue_entry: catalogue)
        allow(SoulBnbApi).to receive(:get_character_entries).with(enactor).and_return([entry])
        allow(SoulBnbApi).to receive(:get_character_entries).with(other).and_return([])
        allow(SoulBnbApi).to receive(:get_character_entry_public).with(enactor, 9).and_return(
          name: "Lucky", level_state: "minor"
        )

        request = double(cmd: "soulBnbHere", enactor: enactor, args: { 'scene_id' => '1', 'reference' => 'lucky' })
        result = subject.handle(request)
        expect(result[:matches]).to eq([{ character: enactor.name, name: "Lucky", level_state: "minor" }])
      end
    end
  end
end

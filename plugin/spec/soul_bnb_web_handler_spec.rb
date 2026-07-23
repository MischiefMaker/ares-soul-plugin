require_relative 'spec_helper'

module AresMUSH
  describe SoulBnbWebHandler do
    it "rechecks staff permission for catalogue creation" do
      request = double(cmd: "soulBnbCreate", enactor: Fabricate(:character), args: {})
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_manage_soul?).and_return(false)
      expect(subject.handle(request)[:error]).to be_present
    end

    it "keeps the query/search path staff-only while ordinary catalogue browsing remains playable" do
      enactor = Fabricate(:character)
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_play?).and_return(true)
      allow(Soul).to receive(:can_manage_soul?).and_return(false)

      search = double(cmd: "soulBnbCatalogue", enactor: enactor, args: { 'query' => 'hidden' })
      expect(subject.handle(search)[:error]).to be_present

      allow(SoulBnbApi).to receive(:get_catalogue).and_return([])
      browse = double(cmd: "soulBnbCatalogue", enactor: enactor, args: {})
      expect(subject.handle(browse)).to eq(entries: [])
    end

    it "allows a manage-only staff member to search without requiring play permission" do
      staff = Fabricate(:character)
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_manage_soul?).and_return(true)
      allow(Soul).to receive(:can_play?).and_return(false)
      allow(SoulBnbApi).to receive(:search).and_return([])
      request = double(cmd: "soulBnbCatalogue", enactor: staff, args: { 'query' => 'anything' })

      expect(subject.handle(request)).to eq(entries: [])
    end

    it "uses the MUSH command's minor default for a web grant with no level" do
      staff = Fabricate(:character)
      character = Fabricate(:character)
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_manage_soul?).and_return(true)
      allow(Character).to receive(:find_one_by_name).and_return(character)
      allow(SoulBnbApi).to receive(:grant).and_return(error: "test")
      request = double(cmd: "soulBnbGrant", enactor: staff,
        args: { 'character' => character.name, 'catalogue_ref' => 'lucky',
                'explanation' => 'Because' })

      subject.handle(request)
      expect(SoulBnbApi).to have_received(:grant).with(
        character, "lucky", level_state: "minor", source: "admin",
        explanation: "Because", enactor: staff
      )
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

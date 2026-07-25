require_relative 'spec_helper'

module AresMUSH
  describe SoulBnbWebHandler do
    it "rechecks staff permission for catalogue creation" do
      request = double(cmd: "soulBnbCreate", enactor: Fabricate(:character), args: {})
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_manage_soul?).and_return(false)
      expect(subject.handle(request)[:error]).to be_present
    end

    it "requires only play permission for catalogue browsing (2026-07-25 profile rework, FR-015)" do
      enactor = Fabricate(:character)
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_play?).and_return(true)
      allow(Soul).to receive(:can_manage_soul?).and_return(false)
      allow(SoulFrameworkApi).to receive(:get_skills).and_return([])
      allow(SoulBnbApi).to receive(:get_catalogue_page).and_return(
        entries: [], page: 1, total_pages: 1, total_count: 0
      )

      request = double(cmd: "soulBnbCatalogue", enactor: enactor, args: {})
      result = subject.handle(request)
      expect(result[:entries]).to eq([])
      expect(result[:available_skills]).to eq([])
    end

    it "rejects catalogue browsing for a viewer with neither play nor manage permission" do
      enactor = Fabricate(:character)
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_play?).and_return(false)
      allow(Soul).to receive(:can_manage_soul?).and_return(false)
      request = double(cmd: "soulBnbCatalogue", enactor: enactor, args: {})
      expect(subject.handle(request)[:error]).to be_present
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

    describe "soulBnbList" do
      before do
        allow(Website).to receive(:check_login).and_return(nil)
        allow(Soul).to receive(:can_play?).and_return(true)
      end

      it "defaults to the enactor's own character when none is given" do
        enactor = Fabricate(:character)
        allow(SoulBnbApi).to receive(:get_character_entries).with(enactor).and_return([])
        allow(SoulBnbApi).to receive(:get_requests).with(character: enactor).and_return([])
        request = double(cmd: "soulBnbList", enactor: enactor, args: {})
        expect(subject.handle(request)).to eq(entries: [], requests: [])
      end

      it "rejects viewing another character's list without manage_soul permission" do
        enactor = Fabricate(:character)
        other = Fabricate(:character)
        allow(Character).to receive(:find_one_by_name).and_return(other)
        allow(Soul).to receive(:can_manage_soul?).and_return(false)
        request = double(cmd: "soulBnbList", enactor: enactor, args: { 'character' => other.name })
        expect(subject.handle(request)[:error]).to be_present
      end
    end

    describe "soulBnbRequest / soulBnbRequestsList / soulBnbRequestApprove / soulBnbRequestDeny" do
      it "creates a request scoped to the enactor, ignoring any character arg" do
        enactor = Fabricate(:character)
        allow(Website).to receive(:check_login).and_return(nil)
        allow(Soul).to receive(:can_play?).and_return(true)
        allow(SoulBnbApi).to receive(:request).and_return(error: "test")
        request = double(cmd: "soulBnbRequest", enactor: enactor,
          args: { 'catalogue_ref' => 'lucky', 'explanation' => 'Because' })

        subject.handle(request)
        expect(SoulBnbApi).to have_received(:request).with(
          enactor, "lucky", explanation: "Because", level_state: "minor", associated_skills: nil
        )
      end

      it "requires manage_soul permission to list, approve, or deny requests" do
        enactor = Fabricate(:character)
        allow(Website).to receive(:check_login).and_return(nil)
        allow(Soul).to receive(:can_manage_soul?).and_return(false)
        allow(Soul).to receive(:can_play?).and_return(true)

        %w[soulBnbRequestsList soulBnbRequestApprove soulBnbRequestDeny].each do |cmd|
          request = double(cmd: cmd, enactor: enactor, args: {})
          expect(subject.handle(request)[:error]).to be_present
        end
      end

      it "approves a request through the API and serializes the result" do
        staff = Fabricate(:character)
        allow(Website).to receive(:check_login).and_return(nil)
        allow(Soul).to receive(:can_manage_soul?).and_return(true)
        entry = double(character: staff, id: 1, catalogue_entry: double(tag: "x", name: "X", kind: "boon"),
          level_state: "minor", resolved: "false")
        allow(SoulBnbApi).to receive(:get_character_entry_public).and_return(id: 1, level_state: "minor")
        req_double = double(id: 5, character: staff,
          catalogue_entry: double(id: 2, tag: "lucky", name: "Lucky", kind: "boon"),
          level_state: "minor", player_explanation: "x", status: "approved", staff_reason: nil, created_at: nil)
        allow(SoulBnbApi).to receive(:approve_request).and_return(success: true, request: req_double, entry: entry)
        request = double(cmd: "soulBnbRequestApprove", enactor: staff, args: { 'request_id' => '5' })

        result = subject.handle(request)
        expect(result[:success]).to be true
        expect(result[:request][:tag]).to eq("lucky")
      end
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

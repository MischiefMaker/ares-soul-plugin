require_relative 'spec_helper'

module AresMUSH
  describe SoulRollWebHandler do
    let(:character) { Fabricate(:character) }

    before do
      allow(Website).to receive(:check_login).and_return(nil)
      allow(Soul).to receive(:can_play?).and_return(true)
    end

    def request(command, args = {})
      double(cmd: command, enactor: character, args: args)
    end

    it "rejects unauthenticated requests" do
      allow(Website).to receive(:check_login).and_return(error: "login")
      expect(subject.handle(request("soulRoll"))).to eq(error: "login")
    end

    it "rejects player operations without play permission" do
      allow(Soul).to receive(:can_play?).and_return(false)
      expect(subject.handle(request("soulRollStart"))[:error]).to be_present
    end

    it "delegates standard and GM starts" do
      allow(SoulRollApi).to receive(:start_roll).and_return(error: "test")
      subject.handle(request("soulRollStart", 'skill_key' => 'strength'))
      expect(SoulRollApi).to have_received(:start_roll).with(
        character, "strength",
        context: { difficulty: "standard", scene_id: nil },
        gm_requested: false
      )

      subject.handle(request("soulRollGm",
        'skill_key' => 'strength', 'difficulty' => 'hard', 'scene_id' => '4'))
      expect(SoulRollApi).to have_received(:start_roll).with(
        character, "strength",
        context: { difficulty: "hard", scene_id: "4" },
        gm_requested: true
      )
    end

    it "selects and resolves a pending roll" do
      pending = double(id: 12)
      allow(SoulRollApi).to receive(:get_open_pending_for_selection).and_return(pending)
      allow(SoulRollApi).to receive(:select_entries).and_return(success: true)
      allow(SoulRollApi).to receive(:resolve_pending).and_return(error: "test")

      subject.handle(request("soulRollSelect", 'selection' => 'none'))
      expect(SoulRollApi).to have_received(:select_entries).with(
        12, character, none: true
      )
      expect(SoulRollApi).to have_received(:resolve_pending).with(12, character)
    end

    it "delegates abort operations" do
      allow(SoulRollApi).to receive(:abort_pending).and_return(success: true)
      subject.handle(request("soulRollAbort",
        'pending_roll_id' => '12', 'reason' => 'changed'))
      expect(SoulRollApi).to have_received(:abort_pending).with(
        "12", character, reason: "changed"
      )

      allow(SoulRollApi).to receive(:force_abort_pending).and_return(success: true)
      subject.handle(request("soulRollForceAbort",
        'pending_roll_id' => '12', 'reason' => 'ruling'))
      expect(SoulRollApi).to have_received(:force_abort_pending).with(
        "12", character, reason: "ruling"
      )
    end

    it "returns pending rolls and history" do
      allow(SoulRollApi).to receive(:get_open_pending_rolls).and_return([])
      expect(subject.handle(request("soulRollPending"))[:pending_rolls]).to eq([])
      allow(SoulRollApi).to receive(:get_roll_history).and_return([])
      expect(subject.handle(request("soulRollHistory"))[:rolls]).to eq([])
    end

    it "delegates review by id without duplicating permission logic" do
      allow(SoulRollApi).to receive(:get_gm_candidate_view).and_return(success: true)
      subject.handle(request("soulRollReview", 'pending_roll_id' => '12'))
      expect(SoulRollApi).to have_received(:get_gm_candidate_view).with("12", character)
    end

    it "resolves mark tags and submits IDs" do
      allow(SoulRollApi).to receive(:get_gm_candidate_view).and_return(
        success: true, candidates: [{ id: "1", tag: "must" }, { id: "2", tag: "may" }]
      )
      allow(SoulRollApi).to receive(:gm_submit_selections).and_return(error: "test")

      subject.handle(request("soulRollMark",
        'pending_roll_id' => '12', 'mandatory_tags' => ['must'], 'optional_tags' => ['may']))
      expect(SoulRollApi).to have_received(:gm_submit_selections).with(
        "12", character, mandatory_ids: ["1"], optional_ids: ["2"]
      )
    end

    it "delegates the player candidate view" do
      allow(SoulRollApi).to receive(:get_player_candidate_view).and_return(success: true, candidates: [])
      result = subject.handle(request("soulRollCandidates", 'pending_roll_id' => '12'))
      expect(SoulRollApi).to have_received(:get_player_candidate_view).with("12", character)
      expect(result).to eq(success: true, candidates: [])
    end

    it "rejects candidate/difficulty requests without play permission" do
      allow(Soul).to receive(:can_play?).and_return(false)
      expect(subject.handle(request("soulRollCandidates"))[:error]).to be_present
      expect(subject.handle(request("soulRollDifficulties"))[:error]).to be_present
    end

    it "returns configured difficulty options" do
      allow(SoulRollApi).to receive(:get_difficulty_options).and_return("standard" => 13)
      expect(subject.handle(request("soulRollDifficulties"))).to eq(difficulties: { "standard" => 13 })
    end

    it "includes the rolling character in pending-roll payloads" do
      pending = double(id: 12, character: character, skill_key: "strength", aspect_key: "body",
        scene_id: nil, difficulty: 13, status: "awaiting_selection", gm_assisted: "false", expires_at: nil)
      allow(SoulRollApi).to receive(:get_open_pending_rolls).and_return([pending])
      result = subject.handle(request("soulRollPending"))
      expect(result[:pending_rolls].first).to include(character_id: character.id, character: character.name)
    end
  end
end

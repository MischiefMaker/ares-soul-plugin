require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulRollCmd do
    let(:character) { Fabricate(:character) }
    let(:client) { double(emit: nil, emit_success: nil, emit_failure: nil) }

    before do
      allow(subject).to receive(:enactor).and_return(character)
      allow(subject).to receive(:client).and_return(client)
      allow(subject).to receive(:enactor_room).and_return(nil)
      allow(Soul).to receive(:can_play?).and_return(true)
      allow(Soul).to receive(:can_review_rolls?).and_return(false)
      allow(Soul).to receive(:can_manage_soul?).and_return(false)
    end

    def run_command(switch, args)
      command = double(root: "roll", switch: switch, args: args)
      allow(subject).to receive(:cmd).and_return(command)
      subject.parse_args
      subject.handle
    end

    it "is registered for the roll command family" do
      cmd = double(root: "roll")
      expect(Soul.get_cmd_handler(nil, cmd, nil)).to eq(Soul::SoulRollCmd)
    end

    it "starts a standard roll at standard difficulty" do
      allow(SoulRollApi).to receive(:get_open_pending_for_selection).and_return(nil)
      allow(SoulRollApi).to receive(:start_roll).and_return(
        success: true, pending_roll: double(id: 1, status: "awaiting_selection")
      )

      run_command(nil, "strength")
      expect(SoulRollApi).to have_received(:start_roll).with(
        character, "strength", context: { difficulty: "standard", scene_id: nil },
        gm_requested: false
      )
    end

    it "passes an explicit difficulty through unchanged" do
      allow(SoulRollApi).to receive(:get_open_pending_for_selection).and_return(nil)
      allow(SoulRollApi).to receive(:start_roll).and_return(
        success: true, pending_roll: double(id: 1, status: "awaiting_selection")
      )

      run_command(nil, "strength=hard")
      expect(SoulRollApi).to have_received(:start_roll).with(
        character, "strength", context: { difficulty: "hard", scene_id: nil },
        gm_requested: false
      )
    end

    it "treats a word as a tag selection when a roll is awaiting selection" do
      pending = double(id: 12)
      allow(SoulRollApi).to receive(:get_open_pending_for_selection).and_return(pending)
      allow(SoulRollApi).to receive(:select_entries).and_return(success: true)
      allow(SoulRollApi).to receive(:resolve_pending).and_return(error: "stop")
      allow(SoulRollApi).to receive(:start_roll)

      run_command(nil, "strength")
      expect(SoulRollApi).to have_received(:select_entries).with(
        12, character, tags: ["strength"], suggested: false, none: false
      )
      expect(SoulRollApi).not_to have_received(:start_roll)
    end

    it "supports suggested and none selection and completes the roll" do
      pending = double(id: 12)
      allow(SoulRollApi).to receive(:get_open_pending_for_selection).and_return(pending)
      allow(SoulRollApi).to receive(:select_entries).and_return(success: true)
      allow(SoulRollApi).to receive(:resolve_pending).and_return(error: "displayed")

      run_command(nil, "suggested")
      expect(SoulRollApi).to have_received(:select_entries).with(
        12, character, tags: [], suggested: true, none: false
      )
      expect(SoulRollApi).to have_received(:resolve_pending).with(12, character)
    end

    it "starts a requested GM roll" do
      allow(SoulRollApi).to receive(:start_roll).and_return(
        success: true, pending_roll: double(id: 2, status: "awaiting_gm")
      )

      run_command("gm", "strength=hard")
      expect(SoulRollApi).to have_received(:start_roll).with(
        character, "strength", context: { difficulty: "hard", scene_id: nil },
        gm_requested: true
      )
    end

    it "delegates abort and force-abort with their reasons" do
      allow(SoulRollApi).to receive(:abort_pending).and_return(success: true)
      run_command("abort", "12=changed my mind")
      expect(SoulRollApi).to have_received(:abort_pending).with(
        12, character, reason: "changed my mind"
      )

      allow(SoulRollApi).to receive(:force_abort_pending).and_return(success: true)
      run_command("forceabort", "13=scene ruling")
      expect(SoulRollApi).to have_received(:force_abort_pending).with(
        13, character, reason: "scene ruling"
      )
    end

    it "lists pending rolls and history" do
      allow(SoulRollApi).to receive(:get_open_pending_rolls).and_return([])
      run_command("pending", "")
      expect(SoulRollApi).to have_received(:get_open_pending_rolls).with(character)

      allow(SoulRollApi).to receive(:get_roll_history).and_return([])
      run_command("history", "")
      expect(SoulRollApi).to have_received(:get_roll_history).with(character)
    end

    it "uses API authorization for review by id" do
      allow(SoulRollApi).to receive(:get_gm_candidate_view).and_return(
        success: true, candidates: []
      )
      run_command("review", "12")
      expect(SoulRollApi).to have_received(:get_gm_candidate_view).with(12, character)
      expect(Soul).not_to have_received(:can_review_rolls?)
    end

    it "gates review discovery on current-scene authority" do
      scene = double(is_participant?: true)
      room = double(scene: scene)
      allow(subject).to receive(:enactor_room).and_return(room)
      allow(Soul).to receive(:can_manage_soul?).and_return(false)
      allow(Soul).to receive(:can_review_rolls?).and_return(true)
      allow(SoulRollApi).to receive(:get_pending_gm_review).and_return([])

      run_command("review", "")
      expect(SoulRollApi).to have_received(:get_pending_gm_review).with(scene)
    end

    it "resolves mark tags through the privacy-filtered candidate view" do
      candidates = [{ id: "1", tag: "required" }, { id: "2", tag: "optional" }]
      allow(SoulRollApi).to receive(:get_gm_candidate_view).and_return(
        success: true, candidates: candidates
      )
      allow(SoulRollApi).to receive(:gm_submit_selections).and_return(success: true)

      run_command("mark", "12=required/optional")
      expect(SoulRollApi).to have_received(:gm_submit_selections).with(
        12, character, mandatory_ids: ["1"], optional_ids: ["2"]
      )
    end

    it "rejects an unknown mark tag before submission" do
      allow(SoulRollApi).to receive(:get_gm_candidate_view).and_return(
        success: true, candidates: [{ id: "1", tag: "known" }]
      )
      allow(SoulRollApi).to receive(:gm_submit_selections)

      run_command("mark", "12=missing/")
      expect(SoulRollApi).not_to have_received(:gm_submit_selections)
      expect(client).to have_received(:emit_failure)
    end
  end
end

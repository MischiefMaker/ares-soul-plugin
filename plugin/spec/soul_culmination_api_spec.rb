require_relative 'spec_helper'

module AresMUSH
  describe SoulCulminationApi do
    let(:staff) { Fabricate(:character) }
    let(:character) { Fabricate(:character) }

    before do
      allow(Global).to receive(:read_config).and_call_original
      allow(Global).to receive(:read_config).with("soul", "manage_permission").and_return("manage_apps")
      allow(Global).to receive(:read_config).with("soul", "culminations", "approval_required").and_return(true)
      allow(staff).to receive(:has_permission?).with("manage_apps").and_return(true)
      allow(character).to receive(:has_permission?).with("manage_apps").and_return(false)
    end

    describe ".propose" do
      it "creates a proposed (not approved) Culmination for a non-staff source when approval is required" do
        result = SoulCulminationApi.propose(character, title: "First Blood", description: "Won a duel",
          source: "inkling:1")
        expect(result[:success]).to be true
        expect(result[:culmination].status).to eq("proposed")
      end

      it "auto-approves immediately when a staffer proposes directly, even with approval_required true " \
        "(staff request, 2026-07-25: the gate exists to let a human review an automated/semi-trusted " \
        "source, not to make a staffer re-approve their own direct action)" do
        result = SoulCulminationApi.propose(character, title: "Survived Alpha Testing", description: "Braved bugs",
          source: "staff", enactor: staff)
        expect(result[:success]).to be true
        culmination = result[:culmination]
        expect(culmination.status).to eq("approved")
        expect(culmination.approved_by).to eq(staff)
        expect(culmination.approved_at).to be_present
        expect(character.narrative_history_entries.to_a.any? { |e| e.event_type == "culmination_approved" }).to be true
      end

      it "does not create a duplicate for the same source" do
        SoulCulminationApi.propose(character, title: "First Blood", description: "Won a duel", source: "inkling:42")
        result = SoulCulminationApi.propose(character, title: "First Blood", description: "Won a duel", source: "inkling:42")
        expect(result[:duplicate]).to be true
      end
    end

    describe ".approve" do
      it "requires manage_soul permission" do
        culmination = SoulCulminationApi.propose(character, title: "X", description: "Y", source: "inkling:1")[:culmination]
        result = SoulCulminationApi.approve(culmination.id, character)
        expect(result[:error]).to match(/permission/i)
      end

      it "approves a proposed Culmination and creates Narrative History" do
        culmination = SoulCulminationApi.propose(character, title: "X", description: "Y", source: "inkling:1")[:culmination]
        result = SoulCulminationApi.approve(culmination.id, staff)
        expect(result[:success]).to be true
        expect(Culmination[culmination.id].status).to eq("approved")
        expect(character.narrative_history_entries.to_a.any? { |e| e.event_type == "culmination_approved" }).to be true
      end
    end

    describe ".revoke" do
      it "preserves the original record and appends a correction entry rather than deleting" do
        culmination = SoulCulminationApi.propose(character, title: "X", description: "Y", source: "staff",
          enactor: staff)[:culmination]
        SoulCulminationApi.revoke(culmination.id, staff, reason: "Granted in error")

        culmination = Culmination[culmination.id]
        expect(culmination.status).to eq("revoked")
        expect(culmination.title).to eq("X")   # original preserved
        expect(culmination.correction_log.length).to eq(1)
      end

      it "requires a reason" do
        culmination = SoulCulminationApi.propose(character, title: "X", description: "Y", source: "staff",
          enactor: staff)[:culmination]
        result = SoulCulminationApi.revoke(culmination.id, staff, reason: "")
        expect(result[:error]).to match(/reason/i)
      end
    end

    describe ".correct" do
      it "updates the title and description when provided" do
        culmination = SoulCulminationApi.propose(character, title: "X", description: "Y", source: "staff")[:culmination]
        result = SoulCulminationApi.correct(culmination.id, staff, title: "New Title", description: "New Desc",
          reason: "Typo fix")
        expect(result[:success]).to be true
        expect(Culmination[culmination.id].title).to eq("New Title")
        expect(Culmination[culmination.id].description).to eq("New Desc")
      end

      it "leaves the title and description unchanged when blank - a blank field must not silently erase " \
        "an existing value (the web form's Correct-only fields are optional)" do
        culmination = SoulCulminationApi.propose(character, title: "X", description: "Y", source: "staff")[:culmination]
        result = SoulCulminationApi.correct(culmination.id, staff, title: "", description: "", reason: "No change")
        expect(result[:success]).to be true
        expect(Culmination[culmination.id].title).to eq("X")
        expect(Culmination[culmination.id].description).to eq("Y")
      end

      it "requires a reason" do
        culmination = SoulCulminationApi.propose(character, title: "X", description: "Y", source: "staff")[:culmination]
        result = SoulCulminationApi.correct(culmination.id, staff, title: "New", reason: "")
        expect(result[:error]).to match(/reason/i)
      end
    end
  end
end

require_relative 'spec_helper'

module AresMUSH
  describe SoulCulminationApi do
    let(:staff) { Fabricate(:character) }
    let(:character) { Fabricate(:character) }

    before do
      allow(Global).to receive(:read_config).and_call_original
      allow(Global).to receive(:read_config).with("soul", "manage_permission").and_return("manage_jobs")
      allow(Global).to receive(:read_config).with("soul", "culminations", "approval_required").and_return(true)
      allow(staff).to receive(:has_permission?).with("manage_jobs").and_return(true)
      allow(character).to receive(:has_permission?).with("manage_jobs").and_return(false)
    end

    describe ".propose" do
      it "creates a proposed (not approved) Culmination when approval is required" do
        result = SoulCulminationApi.propose(character, title: "First Blood", description: "Won a duel", source: "staff")
        expect(result[:success]).to be true
        expect(result[:culmination].status).to eq("proposed")
      end

      it "does not create a duplicate for the same source" do
        SoulCulminationApi.propose(character, title: "First Blood", description: "Won a duel", source: "inkling:42")
        result = SoulCulminationApi.propose(character, title: "First Blood", description: "Won a duel", source: "inkling:42")
        expect(result[:duplicate]).to be true
      end
    end

    describe ".approve" do
      it "requires manage_soul permission" do
        culmination = SoulCulminationApi.propose(character, title: "X", description: "Y", source: "staff")[:culmination]
        result = SoulCulminationApi.approve(culmination.id, character)
        expect(result[:error]).to match(/permission/i)
      end

      it "approves a proposed Culmination and creates Narrative History" do
        culmination = SoulCulminationApi.propose(character, title: "X", description: "Y", source: "staff")[:culmination]
        result = SoulCulminationApi.approve(culmination.id, staff)
        expect(result[:success]).to be true
        expect(Culmination[culmination.id].status).to eq("approved")
        expect(character.narrative_history_entries.to_a.any? { |e| e.event_type == "culmination_approved" }).to be true
      end
    end

    describe ".revoke" do
      it "preserves the original record and appends a correction entry rather than deleting" do
        culmination = SoulCulminationApi.propose(character, title: "X", description: "Y", source: "staff")[:culmination]
        SoulCulminationApi.approve(culmination.id, staff)
        SoulCulminationApi.revoke(culmination.id, staff, reason: "Granted in error")

        culmination = Culmination[culmination.id]
        expect(culmination.status).to eq("revoked")
        expect(culmination.title).to eq("X")   # original preserved
        expect(culmination.correction_log.length).to eq(1)
      end

      it "requires a reason" do
        culmination = SoulCulminationApi.propose(character, title: "X", description: "Y", source: "staff")[:culmination]
        SoulCulminationApi.approve(culmination.id, staff)
        result = SoulCulminationApi.revoke(culmination.id, staff, reason: "")
        expect(result[:error]).to match(/reason/i)
      end
    end
  end
end

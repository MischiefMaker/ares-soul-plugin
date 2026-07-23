require_relative 'spec_helper'

module AresMUSH
  describe SoulNarrativeHistoryApi do
    let(:staff) { Fabricate(:character) }
    let(:owner) { Fabricate(:character) }
    let(:other) { Fabricate(:character) }

    before do
      allow(Global).to receive(:read_config).and_call_original
      allow(Global).to receive(:read_config).with("soul", "manage_permission").and_return("manage_jobs")
      allow(staff).to receive(:has_permission?).with("manage_jobs").and_return(true)
      allow(owner).to receive(:has_permission?).with("manage_jobs").and_return(false)
      allow(other).to receive(:has_permission?).with("manage_jobs").and_return(false)
    end

    describe ".create" do
      it "stores a polymorphic-ish reference to the SOUL record" do
        culmination = Culmination.create(character: owner, title: "X", description: "Y", created_at: Time.now)
        entry = SoulNarrativeHistoryApi.create(owner, event_type: "culmination_approved", narrative: "Test", soul_record: culmination)
        expect(entry.soul_record_type).to eq("Culmination")
        expect(entry.soul_record_id).to eq(culmination.id)
      end
    end

    describe ".get_history" do
      before { SoulNarrativeHistoryApi.create(owner, event_type: "resonance_approved", narrative: "Starting Resonance approved.") }

      it "is visible to the owner" do
        expect(SoulNarrativeHistoryApi.get_history(owner, owner)).not_to be_empty
      end

      it "is visible to staff" do
        expect(SoulNarrativeHistoryApi.get_history(owner, staff)).not_to be_empty
      end

      it "is not visible to an unrelated character" do
        expect(SoulNarrativeHistoryApi.get_history(owner, other)).to eq([])
      end
    end
  end

  describe SoulAuditApi do
    let(:staff) { Fabricate(:character) }
    let(:owner) { Fabricate(:character) }

    before do
      allow(Global).to receive(:read_config).and_call_original
      allow(Global).to receive(:read_config).with("soul", "manage_permission").and_return("manage_jobs")
      allow(staff).to receive(:has_permission?).with("manage_jobs").and_return(true)
      allow(owner).to receive(:has_permission?).with("manage_jobs").and_return(false)
      SoulAuditApi.create(action: "test_action", character: owner, actor: staff, reason: "testing")
    end

    it "is visible to staff" do
      expect(SoulAuditApi.get_audit(owner, staff)).not_to be_empty
    end

    it "is not visible to the character it concerns (staff-only, unlike Narrative History)" do
      expect(SoulAuditApi.get_audit(owner, owner)).to eq([])
    end
  end
end

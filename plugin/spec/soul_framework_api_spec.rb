require_relative 'spec_helper'

module AresMUSH
  # Only covers .get_skill_for_grimoire_branch (Phase 7, FINAL REQ-040) - the
  # rest of SoulFrameworkApi predates this file and has no dedicated spec
  # coverage yet (a pre-existing gap from Phase 2, not addressed here).
  describe SoulFrameworkApi do
    describe ".get_skill_for_grimoire_branch" do
      it "returns the mapped Skill's hash for a configured branch" do
        allow(Global).to receive(:read_config).and_call_original
        allow(Global).to receive(:read_config)
          .with("soul", "integrations", "grimoire", "branch_skill_map")
          .and_return("evocation" => "ceremonial_magic")
        allow(SoulFrameworkApi).to receive(:get_skill).with("ceremonial_magic")
          .and_return(key: "ceremonial_magic", name: "Ceremonial Magic", aspect_key: "spirit", order: 0)

        result = SoulFrameworkApi.get_skill_for_grimoire_branch("evocation")
        expect(result[:key]).to eq("ceremonial_magic")
      end

      it "returns nil for an unmapped branch" do
        allow(Global).to receive(:read_config).and_call_original
        allow(Global).to receive(:read_config)
          .with("soul", "integrations", "grimoire", "branch_skill_map")
          .and_return({})

        expect(SoulFrameworkApi.get_skill_for_grimoire_branch("evocation")).to be_nil
      end

      it "returns nil when no branch_skill_map is configured at all" do
        allow(Global).to receive(:read_config).and_call_original
        allow(Global).to receive(:read_config)
          .with("soul", "integrations", "grimoire", "branch_skill_map")
          .and_return(nil)

        expect(SoulFrameworkApi.get_skill_for_grimoire_branch("evocation")).to be_nil
      end
    end
  end
end

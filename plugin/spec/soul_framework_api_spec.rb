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
          .with("soul", "integrations", "grimoire")
          .and_return("branch_skill_map" => { "evocation" => "ceremonial" })
        allow(SoulFrameworkApi).to receive(:get_skill).with("ceremonial")
          .and_return(key: "ceremonial", name: "Ceremonial Magic", aspect_key: "spirit", order: 0)

        result = SoulFrameworkApi.get_skill_for_grimoire_branch("evocation")
        expect(result[:key]).to eq("ceremonial")
      end

      it "returns nil for an unmapped branch" do
        allow(Global).to receive(:read_config).and_call_original
        allow(Global).to receive(:read_config)
          .with("soul", "integrations", "grimoire")
          .and_return("branch_skill_map" => {})

        expect(SoulFrameworkApi.get_skill_for_grimoire_branch("evocation")).to be_nil
      end

      it "returns nil when no branch_skill_map is configured at all" do
        allow(Global).to receive(:read_config).and_call_original
        allow(Global).to receive(:read_config)
          .with("soul", "integrations", "grimoire")
          .and_return(nil)

        expect(SoulFrameworkApi.get_skill_for_grimoire_branch("evocation")).to be_nil
      end
    end

    describe ".resolve_skill_key" do
      before do
        allow(Global).to receive(:read_config).and_call_original
        allow(Global).to receive(:read_config).with("soul", "framework", "skills").and_return(
          "ceremonial_magic" => { "name" => "Ceremonial Magic", "aspect" => "spirit" }
        )
      end

      it "passes through an already-valid key unchanged" do
        expect(SoulFrameworkApi.resolve_skill_key("ceremonial_magic")).to eq("ceremonial_magic")
      end

      it "resolves the display name, spaces and all (mischief bug list, 2026-07-25)" do
        expect(SoulFrameworkApi.resolve_skill_key("Ceremonial Magic")).to eq("ceremonial_magic")
        expect(SoulFrameworkApi.resolve_skill_key("ceremonial magic")).to eq("ceremonial_magic")
      end

      it "resolves a space-for-underscore typo against the key itself" do
        expect(SoulFrameworkApi.resolve_skill_key("ceremonial magic")).to eq("ceremonial_magic")
      end

      it "returns the original input unchanged when nothing matches" do
        expect(SoulFrameworkApi.resolve_skill_key("nonexistent")).to eq("nonexistent")
      end
    end
  end
end

require_relative 'spec_helper'

module AresMUSH
  describe SoulBnbApi do
    let(:staff) { Fabricate(:character) }
    let(:character) { Fabricate(:character) }

    let(:level_definitions) do
      {
        "minor" => { "modifier" => 1 }, "major" => { "modifier" => 2 },
        "legendary" => { "modifier" => 3 }, "negated" => { "modifier" => 0 },
        "epic" => { "modifier" => nil }
      }
    end

    before do
      allow(Global).to receive(:read_config).and_call_original
      allow(Global).to receive(:read_config).with("soul", "manage_permission").and_return("manage_jobs")
      allow(staff).to receive(:has_permission?).with("manage_jobs").and_return(true)
      allow(character).to receive(:has_permission?).with("manage_jobs").and_return(false)
      allow(Global).to receive(:read_config).with("soul", "bnb", "level_definitions").and_return(level_definitions)
      allow(Global).to receive(:read_config).with("soul", "bnb", "chargen_ratio").and_return(2)
      allow(Global).to receive(:read_config).with("soul", "bnb", "ratio_rounding").and_return("floor")
      allow(Global).to receive(:read_config).with("soul", "resonance", "enabled").and_return(true)
    end

    def create_boon(tag)
      SoulBnbApi.create_catalogue_entry(name: tag.capitalize, description: "test", kind: "boon", tag: tag, enactor: staff)[:entry]
    end

    def create_bane(tag)
      SoulBnbApi.create_catalogue_entry(name: tag.capitalize, description: "test", kind: "bane", tag: tag, enactor: staff)[:entry]
    end

    describe ".create_catalogue_entry" do
      it "requires manage_soul permission" do
        result = SoulBnbApi.create_catalogue_entry(name: "Lucky", description: "x", kind: "boon", tag: "lucky", enactor: character)
        expect(result[:error]).to match(/permission/i)
      end

      it "rejects a duplicate tag" do
        create_boon("lucky")
        result = SoulBnbApi.create_catalogue_entry(name: "Lucky Again", description: "x", kind: "boon", tag: "lucky", enactor: staff)
        expect(result[:error]).to match(/already in use/i)
      end

      it "rejects an invalid kind" do
        result = SoulBnbApi.create_catalogue_entry(name: "X", description: "x", kind: "neutral", tag: "x", enactor: staff)
        expect(result[:error]).to match(/boon.*bane/i)
      end
    end

    describe "chargen B&B ratio (Addendum §5.1)" do
      it "blocks a 2nd Boon grant with no Banes" do
        boon = create_boon("lucky")
        boon2 = create_boon("brave")
        SoulBnbApi.grant(character, boon, level_state: "minor", source: "chargen")
        result = SoulBnbApi.grant(character, boon2, level_state: "minor", source: "chargen")
        expect(result[:error]).to match(/ratio/i)
      end

      it "allows the 2nd Boon once a Bane exists" do
        boon = create_boon("lucky")
        boon2 = create_boon("brave")
        bane = create_bane("cursed")
        SoulBnbApi.grant(character, boon, level_state: "minor", source: "chargen")
        SoulBnbApi.grant(character, bane, level_state: "minor", source: "chargen")
        result = SoulBnbApi.grant(character, boon2, level_state: "minor", source: "chargen")
        expect(result[:success]).to be true
      end
    end

    describe "chargen Resonance-level limits (Addendum §5.2)" do
      before do
        allow(Global).to receive(:read_config).with("soul", "bnb", "resonance_levels").and_return(
          "r_0" => { "boons" => { "max_count" => 1, "max_at_level_2" => 0 }, "banes" => { "max_count" => nil } }
        )
      end

      it "blocks exceeding max_count at the character's Resonance level" do
        character.update(resonance: "0", resonance_locked_at: Time.now)
        boon = create_boon("lucky")
        boon2 = create_boon("brave")
        SoulBnbApi.grant(character, boon, level_state: "minor", source: "chargen")
        result = SoulBnbApi.grant(character, boon2, level_state: "minor", source: "chargen")
        expect(result[:error]).to match(/maximum boons/i)
      end
    end

    describe ".resolve / .restore" do
      it "preserves the prior level rather than deleting the entry" do
        boon = create_boon("lucky")
        grant_result = SoulBnbApi.grant(character, boon, level_state: "major", source: "admin")
        entry = grant_result[:entry]

        SoulBnbApi.resolve(entry.id, reason: "Story resolved", enactor: staff)
        entry = CharacterBnbEntry[entry.id]
        expect(entry.resolved).to eq("true")
        expect(entry.preserved_level_state).to eq("major")

        SoulBnbApi.restore(entry.id, enactor: staff)
        entry = CharacterBnbEntry[entry.id]
        expect(entry.resolved).to eq("false")
        expect(entry.level_state).to eq("major")
      end
    end

    describe ".delete" do
      it "requires a reason and two confirmations" do
        boon = create_boon("lucky")
        entry = SoulBnbApi.grant(character, boon, level_state: "minor", source: "admin")[:entry]

        result = SoulBnbApi.delete(entry.id, enactor: staff, confirmations: 1, reason: "test")
        expect(result[:error]).to match(/confirm/i)

        result = SoulBnbApi.delete(entry.id, enactor: staff, confirmations: 2, reason: "Duplicate entry")
        expect(result[:success]).to be true
        expect(CharacterBnbEntry[entry.id]).to be_nil
      end
    end
  end
end

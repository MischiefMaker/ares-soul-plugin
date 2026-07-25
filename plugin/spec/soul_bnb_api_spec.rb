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
      allow(Global).to receive(:read_config).with("soul", "manage_permission").and_return("manage_apps")
      allow(staff).to receive(:has_permission?).with("manage_apps").and_return(true)
      allow(character).to receive(:has_permission?).with("manage_apps").and_return(false)
      allow(Global).to receive(:read_config).with("soul", "bnb", "level_definitions").and_return(level_definitions)
      allow(Global).to receive(:read_config).with("soul", "bnb", "chargen_ratio").and_return(2)
      allow(Global).to receive(:read_config).with("soul", "bnb", "ratio_rounding").and_return("floor")
      allow(Global).to receive(:read_config).with("soul", "resonance", "enabled").and_return(true)
      allow(Global).to receive(:read_config).with("soul", "framework", "skills").and_return(
        "blade" => { "name" => "Blade", "aspect" => "body" }
      )
    end

    def create_boon(tag)
      SoulBnbApi.create_catalogue_entry(name: tag.capitalize, description: "test", kind: "boon", tag: tag,
        enactor: staff, skill_associations: ["blade"])[:entry]
    end

    def create_bane(tag)
      SoulBnbApi.create_catalogue_entry(name: tag.capitalize, description: "test", kind: "bane", tag: tag,
        enactor: staff, skill_associations: ["blade"])[:entry]
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

      it "allows an entry with no fixed associated Skills (configurable per instance instead)" do
        result = SoulBnbApi.create_catalogue_entry(name: "X", description: "x", kind: "boon", tag: "x",
          enactor: staff, skill_associations: [])
        expect(result[:success]).to be true
      end

      it "rejects an unknown Skill key when a fixed default is given" do
        result = SoulBnbApi.create_catalogue_entry(name: "X", description: "x", kind: "boon", tag: "x",
          enactor: staff, skill_associations: ["nonexistent_skill"])
        expect(result[:error]).to match(/unknown skill/i)
      end
    end

    describe ".set_skill_associations" do
      it "requires manage_soul permission" do
        boon = create_boon("lucky")
        result = SoulBnbApi.set_skill_associations(boon.tag, ["blade"], enactor: character)
        expect(result[:error]).to match(/permission/i)
      end

      it "updates an existing entry's associated Skills" do
        boon = create_boon("lucky")
        result = SoulBnbApi.set_skill_associations(boon.tag, ["blade", "spirit"], enactor: staff)
        expect(result[:success]).to be true
        expect(boon.reload.skill_associations).to eq(["blade", "spirit"])
      end

      it "rejects an empty list" do
        boon = create_boon("lucky")
        result = SoulBnbApi.set_skill_associations(boon.tag, [], enactor: staff)
        expect(result[:error]).to match(/associated Skill/i)
      end

      it "rejects an unknown catalogue entry" do
        result = SoulBnbApi.set_skill_associations("nonexistent", ["blade"], enactor: staff)
        expect(result[:error]).to match(/unknown/i)
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

    describe ".grant" do
      it "refuses to grant a legacy catalogue entry with no associated Skills" do
        boon = create_boon("lucky")
        boon.update(skill_associations: [])
        result = SoulBnbApi.grant(character, boon, level_state: "minor", source: "chargen")
        expect(result[:error]).to match(/associated Skill/i)
      end
    end

    describe ".progress_direction" do
      it "progresses a Boon up the ladder (minor -> major)" do
        boon = create_boon("lucky")
        entry = SoulBnbApi.grant(character, boon, level_state: "minor", source: "admin")[:entry]
        result = SoulBnbApi.progress_direction(entry.id, "progress", enactor: staff)
        expect(result[:success]).to be true
        expect(CharacterBnbEntry[entry.id].level_state).to eq("major")
      end

      it "regresses a Boon down the ladder (major -> minor)" do
        boon = create_boon("lucky")
        entry = SoulBnbApi.grant(character, boon, level_state: "major", source: "admin")[:entry]
        result = SoulBnbApi.progress_direction(entry.id, "regress", enactor: staff)
        expect(result[:success]).to be true
        expect(CharacterBnbEntry[entry.id].level_state).to eq("minor")
      end

      it "progresses a Bane down the ladder - Progress is always the direction good for the character" do
        bane = create_bane("cursed")
        entry = SoulBnbApi.grant(character, bane, level_state: "major", source: "admin")[:entry]
        result = SoulBnbApi.progress_direction(entry.id, "progress", enactor: staff)
        expect(result[:success]).to be true
        expect(CharacterBnbEntry[entry.id].level_state).to eq("minor")
      end

      it "regresses a Bane up the ladder (worse for the character)" do
        bane = create_bane("cursed")
        entry = SoulBnbApi.grant(character, bane, level_state: "minor", source: "admin")[:entry]
        result = SoulBnbApi.progress_direction(entry.id, "regress", enactor: staff)
        expect(result[:success]).to be true
        expect(CharacterBnbEntry[entry.id].level_state).to eq("major")
      end

      it "refuses to progress a Boon already at legendary" do
        boon = create_boon("lucky")
        entry = SoulBnbApi.grant(character, boon, level_state: "legendary", source: "admin")[:entry]
        result = SoulBnbApi.progress_direction(entry.id, "progress", enactor: staff)
        expect(result[:error]).to match(/limit/i)
      end

      it "refuses to adjust a resolved entry" do
        boon = create_boon("lucky")
        entry = SoulBnbApi.grant(character, boon, level_state: "minor", source: "admin")[:entry]
        SoulBnbApi.resolve(entry.id, reason: "done", enactor: staff)
        result = SoulBnbApi.progress_direction(entry.id, "progress", enactor: staff)
        expect(result[:error]).to match(/resolved/i)
      end
    end

    describe ".get_character_entry_public" do
      it "includes kind - the web/MUSH B&B list displays render blank without it" do
        boon = create_boon("lucky")
        entry = SoulBnbApi.grant(character, boon, level_state: "minor", source: "admin")[:entry]
        result = SoulBnbApi.get_character_entry_public(character, entry.id)
        expect(result[:kind]).to eq("Boon")
      end

      it "includes the associated Skill names and capitalizes kind/level for display" do
        boon = create_boon("lucky")
        entry = SoulBnbApi.grant(character, boon, level_state: "minor", source: "admin",
          associated_skills: ["blade"])[:entry]
        result = SoulBnbApi.get_character_entry_public(character, entry.id)
        expect(result[:level_state]).to eq("Minor")
        expect(result[:skills]).to eq("Blade")
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

    describe ".get_catalogue" do
      it "filters by chargen_available when requested" do
        available = create_boon("lucky")
        SoulBnbApi.create_catalogue_entry(
          name: "Unlucky", description: "test", kind: "boon", tag: "unlucky",
          enactor: staff, chargen_available: false, skill_associations: ["blade"]
        )

        expect(SoulBnbApi.get_catalogue(chargen_available: true)).to eq([available])
      end
    end

    describe ".get_catalogue_page" do
      it "paginates and reports total_count/total_pages" do
        5.times { |i| create_boon("boon#{i}") }
        result = SoulBnbApi.get_catalogue_page(page: 1, per_page: 2)
        expect(result[:entries].count).to eq(2)
        expect(result[:total_count]).to eq(5)
        expect(result[:total_pages]).to eq(3)
      end

      it "clamps an out-of-range page to the last page" do
        3.times { |i| create_boon("boon#{i}") }
        result = SoulBnbApi.get_catalogue_page(page: 99, per_page: 2)
        expect(result[:page]).to eq(2)
      end
    end

    describe ".request / .approve_request / .deny_request" do
      it "creates a pending request rather than a live entry" do
        boon = create_boon("lucky")
        result = SoulBnbApi.request(character, boon, explanation: "I want this.")
        expect(result[:success]).to be true
        expect(result[:request].status).to eq("pending")
        expect(SoulBnbApi.get_character_entries(character)).to be_empty
      end

      it "rejects a request with no explanation" do
        boon = create_boon("lucky")
        result = SoulBnbApi.request(character, boon, explanation: "")
        expect(result[:error]).to match(/explanation/i)
      end

      it "rejects a duplicate pending request for the same catalogue entry" do
        boon = create_boon("lucky")
        SoulBnbApi.request(character, boon, explanation: "First.")
        result = SoulBnbApi.request(character, boon, explanation: "Second.")
        expect(result[:error]).to match(/already have a pending request/i)
      end

      it "rejects a request for a B&B the character already owns" do
        boon = create_boon("lucky")
        SoulBnbApi.grant(character, boon, level_state: "minor", source: "admin")
        result = SoulBnbApi.request(character, boon, explanation: "I want this too.")
        expect(result[:error]).to match(/already have/i)
      end

      it "approve_request requires manage_soul permission" do
        boon = create_boon("lucky")
        request = SoulBnbApi.request(character, boon, explanation: "Please.")[:request]
        result = SoulBnbApi.approve_request(request.id, character)
        expect(result[:error]).to match(/permission/i)
      end

      it "approving creates a live CharacterBnbEntry and marks the request approved" do
        boon = create_boon("lucky")
        request = SoulBnbApi.request(character, boon, explanation: "Please.")[:request]
        result = SoulBnbApi.approve_request(request.id, staff)
        expect(result[:success]).to be true
        expect(result[:entry].character).to eq(character)
        expect(SoulBnbApi.get_character_entries(character).count).to eq(1)
        expect(BnbRequest[request.id].status).to eq("approved")
      end

      it "denying requires a reason and never creates a live entry" do
        boon = create_boon("lucky")
        request = SoulBnbApi.request(character, boon, explanation: "Please.")[:request]
        expect(SoulBnbApi.deny_request(request.id, staff, reason: "")[:error]).to match(/reason/i)

        result = SoulBnbApi.deny_request(request.id, staff, reason: "Not appropriate.")
        expect(result[:success]).to be true
        expect(BnbRequest[request.id].status).to eq("denied")
        expect(SoulBnbApi.get_character_entries(character)).to be_empty
      end

      it "refuses to resolve an already-resolved request" do
        boon = create_boon("lucky")
        request = SoulBnbApi.request(character, boon, explanation: "Please.")[:request]
        SoulBnbApi.approve_request(request.id, staff)
        result = SoulBnbApi.approve_request(request.id, staff)
        expect(result[:error]).to match(/not pending/i)
      end
    end

    describe "chargen grant/drop lifecycle (FINAL REQ-011)" do
      before do
        allow(character).to receive(:is_approved?).and_return(false)
      end

      it "defers Narrative History and the transition event for a pre-approval chargen grant" do
        boon = create_boon("lucky")
        expect(SoulNarrativeHistoryApi).not_to receive(:create)
        expect(Global.dispatcher).not_to receive(:queue_event)
        result = SoulBnbApi.grant(character, boon, level_state: "minor", source: "chargen")
        expect(result[:success]).to be true
      end

      it "still creates Narrative History for a non-chargen grant on an unapproved character" do
        boon = create_boon("lucky")
        expect(SoulNarrativeHistoryApi).to receive(:create)
        SoulBnbApi.grant(character, boon, level_state: "minor", source: "admin")
      end

      it "still creates Narrative History if a chargen-sourced grant somehow reaches an already-approved character" do
        allow(character).to receive(:is_approved?).and_return(true)
        boon = create_boon("lucky")
        expect(SoulNarrativeHistoryApi).to receive(:create)
        SoulBnbApi.grant(character, boon, level_state: "minor", source: "chargen")
      end

      describe ".drop_chargen_selection" do
        it "hard-deletes a pre-approval chargen selection" do
          boon = create_boon("lucky")
          entry = SoulBnbApi.grant(character, boon, level_state: "minor", source: "chargen")[:entry]
          result = SoulBnbApi.drop_chargen_selection(entry.id, character)
          expect(result[:success]).to be true
          expect(CharacterBnbEntry[entry.id]).to be_nil
        end

        it "refuses to drop a non-chargen entry" do
          boon = create_boon("lucky")
          entry = SoulBnbApi.grant(character, boon, level_state: "minor", source: "admin")[:entry]
          expect(SoulBnbApi.drop_chargen_selection(entry.id, character)[:error]).to be_present
        end

        it "refuses to drop once the character is approved" do
          boon = create_boon("lucky")
          entry = SoulBnbApi.grant(character, boon, level_state: "minor", source: "chargen")[:entry]
          allow(character).to receive(:is_approved?).and_return(true)
          expect(SoulBnbApi.drop_chargen_selection(entry.id, character)[:error]).to be_present
        end

        it "refuses to drop another character's entry" do
          boon = create_boon("lucky")
          entry = SoulBnbApi.grant(character, boon, level_state: "minor", source: "chargen")[:entry]
          other = Fabricate(:character)
          expect(SoulBnbApi.drop_chargen_selection(entry.id, other)[:error]).to be_present
        end

        it "also accepts the catalogue entry's tag, not just the numeric entry ID" do
          boon = create_boon("lucky")
          entry = SoulBnbApi.grant(character, boon, level_state: "minor", source: "chargen")[:entry]
          result = SoulBnbApi.drop_chargen_selection("lucky", character)
          expect(result[:success]).to be true
          expect(CharacterBnbEntry[entry.id]).to be_nil
        end

        it "does the tag lookup case-insensitively" do
          boon = create_boon("lucky")
          SoulBnbApi.grant(character, boon, level_state: "minor", source: "chargen")
          expect(SoulBnbApi.drop_chargen_selection("LUCKY", character)[:success]).to be true
        end
      end

      describe ".finalize_chargen_grants" do
        it "creates Narrative History for every surviving chargen selection" do
          boon = create_boon("lucky")
          bane = create_bane("cursed")
          SoulBnbApi.grant(character, boon, level_state: "minor", source: "chargen")
          SoulBnbApi.grant(character, bane, level_state: "minor", source: "chargen")

          expect { SoulBnbApi.finalize_chargen_grants(character) }
            .to change { character.narrative_history_entries.to_a.size }.by(2)
        end

        it "does not duplicate Narrative History on a second call (safe for re-approval)" do
          boon = create_boon("lucky")
          SoulBnbApi.grant(character, boon, level_state: "minor", source: "chargen")

          SoulBnbApi.finalize_chargen_grants(character)
          expect { SoulBnbApi.finalize_chargen_grants(character) }
            .not_to change { character.narrative_history_entries.to_a.size }
        end

        it "never creates history for an entry already dropped pre-approval" do
          boon = create_boon("lucky")
          entry = SoulBnbApi.grant(character, boon, level_state: "minor", source: "chargen")[:entry]
          SoulBnbApi.drop_chargen_selection(entry.id, character)

          expect { SoulBnbApi.finalize_chargen_grants(character) }
            .not_to change { character.narrative_history_entries.to_a.size }
        end
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

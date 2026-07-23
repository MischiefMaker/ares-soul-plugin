require_relative 'spec_helper'

module AresMUSH
  describe SoulRollApi do
    let(:character) { Fabricate(:character) }
    let(:other_character) { Fabricate(:character) }
    let(:gm) { Fabricate(:character) }
    let(:skill) { { key: "strength", name: "Strength", aspect_key: "body", order: 1 } }
    let(:degrees) do
      {
        "exceptional_success_min" => 10,
        "success_min" => 0,
        "complicated_success_min" => -5,
        "lucky_failure_min" => -10,
        "failure_min" => -20,
        "catastrophic_failure_min" => -20
      }
    end

    before do
      allow(Global).to receive(:read_config).and_call_original
      allow(Global).to receive(:read_config).with("soul", "play_permission").and_return("play")
      allow(character).to receive(:has_permission?).with("play").and_return(true)
      allow(other_character).to receive(:has_permission?).with("play").and_return(true)
      allow(Global).to receive(:read_config).with("soul", "rolls", "max_pending_rolls_per_player").and_return(1)
      allow(Global).to receive(:read_config).with("soul", "rolls", "max_pending_rolls_per_player_gm").and_return(2)
      allow(Global).to receive(:read_config).with("soul", "rolls", "pending_roll_timeout_hours").and_return(720)
      allow(Global).to receive(:read_config).with("soul", "rolls", "gm_scene_policy").and_return("optional")
      allow(Global).to receive(:read_config).with("soul", "rolls", "difficulties").and_return("standard" => 13)
      allow(Global).to receive(:read_config).with("soul", "rolls", "degrees_of_success").and_return(degrees)
      allow(Global).to receive(:read_config).with("soul", "rolls", "extraordinary_result_threshold").and_return(0.0001)
      allow(Global).to receive(:read_config).with("soul", "privacy", "gm_reveal_categories").and_return(
        ["name", "public_description"]
      )
      allow(SoulFrameworkApi).to receive(:get_skill).with("strength").and_return(skill)
      allow(SoulCharacterApi).to receive(:get_effective_base).and_return(3)
      allow(Soul).to receive(:can_review_rolls?).and_return(false)
      allow(Soul).to receive(:can_manage_soul?).and_return(false)
      allow(Login).to receive(:notify)
      allow(Global.dispatcher).to receive(:queue_event)
    end

    def catalogue(tag, kind: "boon", modifier: "true", skills: ["strength"], epic_modifier: nil)
      BnbCatalogueEntry.create(
        name: tag.capitalize,
        description: "Test #{tag}",
        tag: tag,
        kind: kind,
        modifier_eligible: modifier,
        skill_associations: skills,
        epic_modifier: epic_modifier
      )
    end

    def owned_entry(tag, kind: "boon", level: "minor", modifier: "true", skills: ["strength"], owner: character)
      CharacterBnbEntry.create(
        character: owner,
        catalogue_entry: catalogue(tag, kind: kind, modifier: modifier, skills: skills),
        level_state: level,
        resolved: "false"
      )
    end

    def pending_for(owner = character, attrs = {})
      PendingRoll.create({
        player: owner,
        character: owner,
        skill_key: "strength",
        aspect_key: "body",
        difficulty: 13,
        context: { "difficulty" => "standard" },
        status: "awaiting_selection",
        gm_assisted: "false",
        expires_at: Time.now + 3600
      }.merge(attrs))
    end

    describe ".get_candidate_bnbs" do
      it "includes only unresolved, modifier-eligible, skill-associated entries" do
        candidate = owned_entry("strong")
        owned_entry("flavor", modifier: "false")
        owned_entry("mind", skills: ["academics"])
        resolved = owned_entry("resolved")
        resolved.update(resolved: "true")

        expect(SoulRollApi.get_candidate_bnbs(character, "strength")).to eq([candidate])
      end
    end

    describe ".start_roll" do
      it "creates a normal awaiting-selection pending roll" do
        result = SoulRollApi.start_roll(character, "strength", context: { difficulty: "standard", scene_id: "12" })
        pending = result[:pending_roll]

        expect(result[:success]).to be true
        expect(pending.status).to eq("awaiting_selection")
        expect(pending.difficulty).to eq(13)
        expect(pending.scene_id).to eq("12")
        expect(pending.gm_assisted).to eq("false")
      end

      it "rejects an unknown skill" do
        allow(SoulFrameworkApi).to receive(:get_skill).with("missing").and_return(nil)
        result = SoulRollApi.start_roll(character, "missing", context: { difficulty: "standard" })
        expect(result[:error]).to match(/unknown skill/i)
      end

      it "rejects an unknown difficulty" do
        result = SoulRollApi.start_roll(character, "strength", context: { difficulty: "impossible" })
        expect(result[:error]).to match(/unknown difficulty/i)
      end

      it "enforces the pending-roll limit" do
        pending_for
        result = SoulRollApi.start_roll(character, "strength", context: { difficulty: "standard" })
        expect(result[:error]).to match(/maximum number/i)
      end

      it "keeps the no-candidates case in awaiting_selection for manual identification" do
        manual = owned_entry("manual", modifier: "false")
        result = SoulRollApi.start_roll(character, "strength", context: { difficulty: "standard" })
        pending = result[:pending_roll]

        selection = SoulRollApi.select_entries(pending.id, character, tags: ["manual"])
        expect(pending.system_suggested_entries).to eq([])
        expect(selection[:success]).to be true
        expect(pending.manually_identified_entries).to eq([manual.id.to_s])
      end

      it "always starts a GM-assisted roll under the required policy" do
        scene = Fabricate(:scene, owner: gm)
        allow(Global).to receive(:read_config).with("soul", "rolls", "gm_scene_policy").and_return("required")

        without_request = SoulRollApi.start_roll(
          character, "strength", context: { difficulty: "standard", scene_id: scene.id }
        )
        with_request = SoulRollApi.start_roll(
          character, "strength",
          context: { difficulty: "standard", scene_id: scene.id },
          gm_requested: true
        )

        expect(without_request[:success]).to be true
        expect(with_request[:success]).to be true
        expect(without_request[:pending_roll].gm_assisted).to eq("true")
        expect(with_request[:pending_roll].gm_assisted).to eq("true")
        expect(without_request[:pending_roll].status).to eq("awaiting_gm")
      end

      it "rejects a GM-assisted roll without a resolvable scene" do
        result = SoulRollApi.start_roll(
          character, "strength", context: { difficulty: "standard" }, gm_requested: true
        )
        expect(result[:error]).to match(/valid scene/i)
      end

      it "starts a standard roll under the optional policy when GM help was not requested" do
        result = SoulRollApi.start_roll(character, "strength", context: { difficulty: "standard" })
        expect(result[:pending_roll].gm_assisted).to eq("false")
        expect(result[:pending_roll].status).to eq("awaiting_selection")
      end

      it "starts a GM-assisted roll under the optional policy when requested" do
        scene = Fabricate(:scene, owner: gm)
        result = SoulRollApi.start_roll(
          character, "strength",
          context: { difficulty: "standard", scene_id: scene.id },
          gm_requested: true
        )
        expect(result[:pending_roll].gm_assisted).to eq("true")
        expect(result[:pending_roll].status).to eq("awaiting_gm")
      end

      it "falls back to a standard roll under the unavailable policy" do
        allow(Global).to receive(:read_config).with("soul", "rolls", "gm_scene_policy").and_return("unavailable")
        with_request = SoulRollApi.start_roll(
          character, "strength", context: { difficulty: "standard" }, gm_requested: true
        )
        without_request = SoulRollApi.start_roll(
          other_character, "strength", context: { difficulty: "standard" }
        )
        expect(with_request[:success]).to be true
        expect(without_request[:success]).to be true
        expect(with_request[:pending_roll].gm_assisted).to eq("false")
        expect(without_request[:pending_roll].gm_assisted).to eq("false")
      end

      it "enforces standard and GM-assisted limits independently" do
        pending_for
        scene = Fabricate(:scene, owner: gm)

        result = SoulRollApi.start_roll(
          character, "strength",
          context: { difficulty: "standard", scene_id: scene.id },
          gm_requested: true
        )
        expect(result[:success]).to be true
        expect(SoulRollApi.get_open_pending_count(character, gm_assisted: false)).to eq(1)
        expect(SoulRollApi.get_open_pending_count(character, gm_assisted: true)).to eq(1)

        pending_for(other_character, status: "awaiting_gm", gm_assisted: "true")
        reverse_result = SoulRollApi.start_roll(
          other_character, "strength", context: { difficulty: "standard" }
        )
        expect(reverse_result[:success]).to be true
      end
    end

    describe ".get_gm_candidate_view" do
      it "returns only the configured privacy fields" do
        entry = owned_entry("private")
        entry.update(character_explanation: "Private explanation", gm_notes: "Private notes")
        scene = Fabricate(:scene, owner: gm)
        pending = pending_for(
          character,
          status: "awaiting_gm",
          gm_assisted: "true",
          scene_id: scene.id,
          system_suggested_entries: [entry.id.to_s]
        )
        allow(Soul).to receive(:can_review_rolls?).with(gm).and_return(true)

        candidate = SoulRollApi.get_gm_candidate_view(pending.id, gm)[:candidates].first
        expect(candidate).to include(id: entry.id.to_s, tag: "private", name: "Private")
        expect(candidate).to include(public_description: "Test private")
        expect(candidate).not_to have_key(:mechanical_effect)
        expect(candidate).not_to have_key(:character_explanation)
        expect(candidate).not_to have_key(:gm_notes)
      end

      it "rejects a reviewer who is not a scene participant" do
        scene = Fabricate(:scene, owner: character)
        pending = pending_for(character, status: "awaiting_gm", gm_assisted: "true", scene_id: scene.id)
        allow(Soul).to receive(:can_review_rolls?).with(gm).and_return(true)

        expect(SoulRollApi.get_gm_candidate_view(pending.id, gm)[:error]).to match(/permission/i)
      end

      it "rejects a participant without the GM review permission" do
        scene = Fabricate(:scene, owner: gm)
        pending = pending_for(character, status: "awaiting_gm", gm_assisted: "true", scene_id: scene.id)

        expect(SoulRollApi.get_gm_candidate_view(pending.id, gm)[:error]).to match(/permission/i)
      end
    end

    describe ".gm_submit_selections" do
      def gm_pending(entries)
        scene = Fabricate(:scene, owner: gm)
        allow(Soul).to receive(:can_review_rolls?).with(gm).and_return(true)
        pending_for(
          character,
          status: "awaiting_gm",
          gm_assisted: "true",
          scene_id: scene.id,
          system_suggested_entries: entries.map { |entry| entry.id.to_s }
        )
      end

      it "partitions candidates and advances to player selection" do
        mandatory = owned_entry("mandatory")
        optional = owned_entry("optional")
        pending = gm_pending([mandatory, optional])

        result = SoulRollApi.gm_submit_selections(
          pending.id, gm, mandatory_ids: [mandatory.id], optional_ids: [optional.id]
        )
        expect(result[:success]).to be true
        expect(pending.gm_mandatory_entries).to eq([mandatory.id.to_s])
        expect(pending.gm_suggested_entries).to eq([optional.id.to_s])
        expect(pending.status).to eq("awaiting_selection")
      end

      it "rejects an entry outside the pending candidate list" do
        candidate = owned_entry("candidate")
        outside = owned_entry("outside")
        pending = gm_pending([candidate])

        result = SoulRollApi.gm_submit_selections(pending.id, gm, mandatory_ids: [outside.id])
        expect(result[:error]).to match(/candidate list/i)
      end

      it "rejects overlap between mandatory and optional entries" do
        candidate = owned_entry("candidate")
        pending = gm_pending([candidate])

        result = SoulRollApi.gm_submit_selections(
          pending.id, gm, mandatory_ids: [candidate.id], optional_ids: [candidate.id]
        )
        expect(result[:error]).to match(/both mandatory and optional/i)
      end

      it "rejects a caller without scene-GM authority" do
        candidate = owned_entry("candidate")
        scene = Fabricate(:scene, owner: character)
        pending = pending_for(
          character,
          status: "awaiting_gm",
          gm_assisted: "true",
          scene_id: scene.id,
          system_suggested_entries: [candidate.id.to_s]
        )

        result = SoulRollApi.gm_submit_selections(pending.id, gm, optional_ids: [candidate.id])
        expect(result[:error]).to match(/permission/i)
      end
    end

    describe ".select_entries" do
      it "selects every system suggestion" do
        first = owned_entry("first")
        second = owned_entry("second")
        pending = pending_for(character, system_suggested_entries: [first.id.to_s, second.id.to_s])

        result = SoulRollApi.select_entries(pending.id, character, suggested: true)
        expect(result[:success]).to be true
        expect(pending.player_selected_entries).to contain_exactly(first.id.to_s, second.id.to_s)
      end

      it "selects no optional entries" do
        pending = pending_for(character, player_selected_entries: ["123"])
        result = SoulRollApi.select_entries(pending.id, character, none: true)
        expect(result[:success]).to be true
        expect(pending.player_selected_entries).to eq([])
      end

      it "separates suggested tags from manually identified tags" do
        suggested = owned_entry("suggested")
        manual = owned_entry("manual", modifier: "false")
        pending = pending_for(character, system_suggested_entries: [suggested.id.to_s])

        SoulRollApi.select_entries(pending.id, character, tags: ["suggested", "manual"])
        expect(pending.player_selected_entries).to eq([suggested.id.to_s])
        expect(pending.manually_identified_entries).to eq([manual.id.to_s])
      end

      it "rejects another character's pending roll" do
        pending = pending_for(other_character)
        result = SoulRollApi.select_entries(pending.id, character, none: true)
        expect(result[:error]).to match(/does not belong/i)
      end

      it "rejects duplicate tags" do
        owned_entry("same")
        pending = pending_for
        result = SoulRollApi.select_entries(pending.id, character, tags: ["same", "same"])
        expect(result[:error]).to match(/duplicate/i)
      end

      it "rejects conflicting selection forms" do
        pending = pending_for
        result = SoulRollApi.select_entries(pending.id, character, tags: ["tag"], none: true)
        expect(result[:error]).to match(/exactly one/i)
      end

      it "rejects a tag naming a candidate the GM reviewed and excluded" do
        excluded = owned_entry("excluded")
        approved = owned_entry("approved")
        pending = pending_for(
          character,
          gm_assisted: "true",
          system_suggested_entries: [excluded.id.to_s, approved.id.to_s],
          gm_suggested_entries: [approved.id.to_s],
          gm_mandatory_entries: []
        )

        result = SoulRollApi.select_entries(pending.id, character, tags: ["excluded"])
        expect(result[:error]).to match(/did not make/i)
        expect(pending.player_selected_entries).to eq([])
        expect(pending.manually_identified_entries).to eq([])
      end

      it "still allows manually identifying a B&B the system never proposed on a GM-assisted roll" do
        never_suggested = owned_entry("fresh", modifier: "false")
        pending = pending_for(
          character,
          gm_assisted: "true",
          system_suggested_entries: [],
          gm_suggested_entries: [],
          gm_mandatory_entries: []
        )

        result = SoulRollApi.select_entries(pending.id, character, tags: ["fresh"])
        expect(result[:success]).to be true
        expect(pending.manually_identified_entries).to eq([never_suggested.id.to_s])
      end

      it "allows selecting a GM-approved optional tag on a GM-assisted roll" do
        approved = owned_entry("approved")
        pending = pending_for(
          character,
          gm_assisted: "true",
          system_suggested_entries: [approved.id.to_s],
          gm_suggested_entries: [approved.id.to_s],
          gm_mandatory_entries: []
        )

        result = SoulRollApi.select_entries(pending.id, character, tags: ["approved"])
        expect(result[:success]).to be true
        expect(pending.player_selected_entries).to eq([approved.id.to_s])
      end
    end

    describe ".resolve_pending" do
      let(:engine_calls) { [] }

      before do
        allow(Soul::SoulDiceEngine).to receive(:success_probability) do
          engine_calls << :probability
          0.75
        end
        allow(Soul::SoulDiceEngine).to receive(:roll) do
          engine_calls << :roll
          { total: 15, mode: :normal, segments: [{ d1: 7, d2: 8 }] }
        end
      end

      it "persists internally consistent roll data and resolves the pending roll" do
        boon = owned_entry("boon", kind: "boon")
        pending = pending_for(character, player_selected_entries: [boon.id.to_s])

        result = SoulRollApi.resolve_pending(pending.id, character)
        roll = result[:roll]

        expect(result[:success]).to be true
        expect(roll.dice_result["total"] + 3).to eq(roll.final_result)
        expect(roll.net_modifier).to eq(1)
        expect(roll.degree_of_success).to eq("success")
        expect(roll.success_probability).to eq(0.75)
        expect(pending.status).to eq("resolved")
        expect(engine_calls).to eq([:probability, :roll])
        expect(Soul::SoulDiceEngine).to have_received(:roll).once
      end

      it "resolves a Bane-only roll with a negative modifier" do
        bane = owned_entry("bane", kind: "bane")
        pending = pending_for(character, manually_identified_entries: [bane.id.to_s])

        roll = SoulRollApi.resolve_pending(pending.id, character)[:roll]
        expect(roll.net_modifier).to eq(-1)
        expect(roll.dice_result["segments"]).to eq([{ "d1" => 7, "d2" => 8 }])
      end

      it "applies a GM-mandatory entry after the player declines all optional entries" do
        mandatory = owned_entry("mandatory", kind: "boon")
        pending = pending_for(
          character,
          gm_assisted: "true",
          gm_mandatory_entries: [mandatory.id.to_s],
          gm_suggested_entries: []
        )

        SoulRollApi.select_entries(pending.id, character, none: true)
        roll = SoulRollApi.resolve_pending(pending.id, character)[:roll]

        expect(pending.player_selected_entries).to eq([])
        expect(roll.net_modifier).to eq(1)
        expect(roll.gm_assisted).to eq("true")
        expect(roll.applied_modifiers.first["source"]).to eq("gm_mandatory")
      end

      it "fails cleanly for an Epic entry without a configured modifier" do
        epic = owned_entry("epic", level: "epic")
        pending = pending_for(character, player_selected_entries: [epic.id.to_s])

        result = SoulRollApi.resolve_pending(pending.id, character)
        expect(result[:error]).to match(/no configured modifier/i)
        expect(Roll.all.to_a).to be_empty
      end

      it "revalidates the stored difficulty tier before rolling" do
        pending = pending_for(character, context: { "difficulty" => "removed" })

        result = SoulRollApi.resolve_pending(pending.id, character)
        expect(result[:error]).to match(/unknown difficulty/i)
        expect(Soul::SoulDiceEngine).not_to have_received(:roll)
      end

      it "rejects a character who does not own the pending roll" do
        pending = pending_for(other_character)

        result = SoulRollApi.resolve_pending(pending.id, character)
        expect(result[:error]).to match(/does not belong/i)
        expect(Roll.all.to_a).to be_empty
        expect(Soul::SoulDiceEngine).not_to have_received(:roll)
      end

      it "uses failure probability for a failed extraordinary result" do
        allow(Soul::SoulDiceEngine).to receive(:success_probability).and_return(0.99995)
        allow(Soul::SoulDiceEngine).to receive(:roll).and_return(
          total: 1, mode: :normal, segments: [{ d1: 1, d2: 1 }]
        )
        pending = pending_for

        roll = SoulRollApi.resolve_pending(pending.id, character)[:roll]
        expect(roll.success_probability).to be_within(1e-10).of(0.00005)
        expect(roll.extraordinary).to eq("true")
      end

      it "fires the resolved event" do
        pending = pending_for
        SoulRollApi.resolve_pending(pending.id, character)
        expect(Global.dispatcher).to have_received(:queue_event).with(an_instance_of(SoulRollResolvedEvent))
      end
    end

    describe Soul::XpCronHandler do
      it "runs pending-roll expiry on every cron tick" do
        event = double(time: Time.now)
        allow(SoulRollApi).to receive(:expire_stale_pending_rolls)
        allow(Cron).to receive(:is_cron_match?).and_return(false)

        Soul::XpCronHandler.new.on_event(event)
        expect(SoulRollApi).to have_received(:expire_stale_pending_rolls).with(event.time)
      end
    end

    describe ".abort_pending" do
      it "aborts an owned roll and creates an audit entry" do
        pending = pending_for
        result = SoulRollApi.abort_pending(pending.id, character, reason: "Changed approach")

        expect(result[:success]).to be true
        expect(pending.status).to eq("aborted")
        expect(SoulAuditEntry.find(action: "roll_abort").to_a.length).to eq(1)
      end

      it "allows a player to abort while awaiting GM review" do
        pending = pending_for(character, status: "awaiting_gm", gm_assisted: "true")
        result = SoulRollApi.abort_pending(pending.id, character, reason: "Changed approach")
        expect(result[:success]).to be true
        expect(pending.status).to eq("aborted")
      end

      it "rejects a player abort after the GM has submitted" do
        pending = pending_for(character, status: "awaiting_selection", gm_assisted: "true")
        result = SoulRollApi.abort_pending(pending.id, character, reason: "Changed approach")
        expect(result[:error]).to match(/allowed status/i)
        expect(pending.status).to eq("awaiting_selection")
      end

      it "continues to allow standard-roll aborts during player selection" do
        pending = pending_for(character, status: "awaiting_selection", gm_assisted: "false")
        result = SoulRollApi.abort_pending(pending.id, character, reason: "Changed approach")
        expect(result[:success]).to be true
      end
    end

    describe ".force_abort_pending" do
      it "allows a scene GM to force-abort either open status and notifies once" do
        scene = Fabricate(:scene, owner: gm)
        allow(Soul).to receive(:can_review_rolls?).with(gm).and_return(true)

        ["awaiting_gm", "awaiting_selection"].each do |status|
          pending = pending_for(character, status: status, gm_assisted: "true", scene_id: scene.id)
          result = SoulRollApi.force_abort_pending(pending.id, gm, reason: "Scene ruling")

          expect(result[:success]).to be true
          expect(pending.status).to eq("aborted")
          expect(Login).to have_received(:notify).with(
            character, :soul, a_string_including("Scene ruling"), pending.id
          ).once
        end
      end

      it "requires a reason" do
        pending = pending_for(character, status: "awaiting_gm", gm_assisted: "true")
        result = SoulRollApi.force_abort_pending(pending.id, gm, reason: " ")
        expect(result[:error]).to match(/reason/i)
      end

      it "rejects a caller without staff or scene-GM authority" do
        scene = Fabricate(:scene, owner: character)
        pending = pending_for(character, status: "awaiting_gm", gm_assisted: "true", scene_id: scene.id)

        result = SoulRollApi.force_abort_pending(pending.id, gm, reason: "No authority")
        expect(result[:error]).to match(/permission/i)
        expect(Login).not_to have_received(:notify)
      end
    end

    describe ".expire_stale_pending_rolls" do
      it "expires both stale open statuses without creating completed rolls" do
        stale = pending_for(character, expires_at: Time.now - 60)
        stale_gm = pending_for(
          other_character,
          status: "awaiting_gm",
          gm_assisted: "true",
          expires_at: Time.now - 60
        )
        fresh = pending_for(other_character, expires_at: Time.now + 60)
        resolved = pending_for(character, status: "resolved", expires_at: Time.now - 60)

        count = SoulRollApi.expire_stale_pending_rolls(Time.now)
        expect(count).to eq(2)
        expect(stale.status).to eq("expired")
        expect(stale_gm.status).to eq("expired")
        expect(fresh.status).to eq("awaiting_selection")
        expect(resolved.status).to eq("resolved")
        expect(Roll.all.to_a).to be_empty
      end
    end

    describe ".get_roll_history" do
      it "returns newest rolls first and honors the limit" do
        old = Roll.create(character: character, rolled_at: Time.now - 60)
        recent = Roll.create(character: character, rolled_at: Time.now)

        expect(SoulRollApi.get_roll_history(character, limit: 1)).to eq([recent])
        expect(SoulRollApi.get_roll_history(character, limit: 2)).to eq([recent, old])
      end
    end

    describe ".get_open_pending_for_selection" do
      it "returns the newest awaiting-selection roll for the character" do
        older = pending_for(character)
        newer = pending_for(character)
        pending_for(character, status: "awaiting_gm", gm_assisted: "true")
        pending_for(other_character)

        expect(SoulRollApi.get_open_pending_for_selection(character)).to eq(newer)
        expect(SoulRollApi.get_open_pending_for_selection(nil)).to be_nil
        expect(older.status).to eq("awaiting_selection")
      end
    end

    describe ".get_open_pending_rolls" do
      it "returns both open statuses for only the requested character" do
        selecting = pending_for(character)
        gm_review = pending_for(character, status: "awaiting_gm", gm_assisted: "true")
        pending_for(character, status: "resolved")
        pending_for(other_character)

        expect(SoulRollApi.get_open_pending_rolls(character)).to contain_exactly(selecting, gm_review)
        expect(SoulRollApi.get_open_pending_rolls(nil)).to eq([])
      end
    end

    describe ".get_pending_gm_review" do
      it "returns only awaiting-GM rolls in the requested scene" do
        scene = Fabricate(:scene)
        other_scene = Fabricate(:scene)
        match = pending_for(character, status: "awaiting_gm", gm_assisted: "true", scene_id: scene.id)
        pending_for(other_character, status: "awaiting_selection", scene_id: scene.id)
        pending_for(other_character, status: "awaiting_gm", gm_assisted: "true", scene_id: other_scene.id)

        expect(SoulRollApi.get_pending_gm_review(scene)).to eq([match])
        expect(SoulRollApi.get_pending_gm_review(nil)).to eq([])
      end
    end
  end
end

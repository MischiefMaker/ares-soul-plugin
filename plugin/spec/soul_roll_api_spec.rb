require_relative 'spec_helper'

module AresMUSH
  describe SoulRollApi do
    let(:character) { Fabricate(:character) }
    let(:other_character) { Fabricate(:character) }
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
      allow(Global).to receive(:read_config).with("soul", "rolls", "pending_roll_timeout_hours").and_return(720)
      allow(Global).to receive(:read_config).with("soul", "rolls", "difficulties").and_return("standard" => 13)
      allow(Global).to receive(:read_config).with("soul", "rolls", "degrees_of_success").and_return(degrees)
      allow(Global).to receive(:read_config).with("soul", "rolls", "extraordinary_result_threshold").and_return(0.0001)
      allow(SoulFrameworkApi).to receive(:get_skill).with("strength").and_return(skill)
      allow(SoulCharacterApi).to receive(:get_effective_base).and_return(3)
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

        result = SoulRollApi.resolve_pending(pending.id)
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

        roll = SoulRollApi.resolve_pending(pending.id)[:roll]
        expect(roll.net_modifier).to eq(-1)
        expect(roll.dice_result["segments"]).to eq([{ "d1" => 7, "d2" => 8 }])
      end

      it "fails cleanly for an Epic entry without a configured modifier" do
        epic = owned_entry("epic", level: "epic")
        pending = pending_for(character, player_selected_entries: [epic.id.to_s])

        result = SoulRollApi.resolve_pending(pending.id)
        expect(result[:error]).to match(/no configured modifier/i)
        expect(Roll.all.to_a).to be_empty
      end

      it "revalidates the stored difficulty tier before rolling" do
        pending = pending_for(character, context: { "difficulty" => "removed" })

        result = SoulRollApi.resolve_pending(pending.id)
        expect(result[:error]).to match(/unknown difficulty/i)
        expect(Soul::SoulDiceEngine).not_to have_received(:roll)
      end

      it "uses failure probability for a failed extraordinary result" do
        allow(Soul::SoulDiceEngine).to receive(:success_probability).and_return(0.99995)
        allow(Soul::SoulDiceEngine).to receive(:roll).and_return(
          total: 1, mode: :normal, segments: [{ d1: 1, d2: 1 }]
        )
        pending = pending_for

        roll = SoulRollApi.resolve_pending(pending.id)[:roll]
        expect(roll.success_probability).to be_within(1e-10).of(0.00005)
        expect(roll.extraordinary).to eq("true")
      end

      it "fires the resolved event" do
        pending = pending_for
        SoulRollApi.resolve_pending(pending.id)
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
    end

    describe ".expire_stale_pending_rolls" do
      it "expires only stale open rolls without creating completed rolls" do
        stale = pending_for(character, expires_at: Time.now - 60)
        fresh = pending_for(other_character, expires_at: Time.now + 60)
        resolved = pending_for(character, status: "resolved", expires_at: Time.now - 60)

        count = SoulRollApi.expire_stale_pending_rolls(Time.now)
        expect(count).to eq(1)
        expect(stale.status).to eq("expired")
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
  end
end

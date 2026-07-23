require_relative 'spec_helper'

module AresMUSH
  describe SoulInklingsHook do
    let(:character) { Fabricate(:character) }
    let(:requester) { Fabricate(:character) }
    let(:levels) do
      {
        "minor" => { "modifier" => 1 },
        "major" => { "modifier" => 2 },
        "legendary" => { "modifier" => 3 }
      }
    end

    before do
      allow(Global).to receive(:read_config).and_call_original
      allow(Global).to receive(:read_config)
        .with("soul", "bnb", "level_definitions").and_return(levels)
      allow(SoulBnbApi).to receive(:ratio_satisfied_after_boon?).and_return(true)
      allow(Global.dispatcher).to receive(:queue_event)
    end

    def catalogue(tag, kind)
      BnbCatalogueEntry.create(
        tag: tag,
        name: tag.capitalize,
        description: "Test #{tag}",
        kind: kind,
        active: "true"
      )
    end

    def validate(type, transition)
      SoulInklingsHook.validate_outcome(
        outcome_type: type,
        character: character,
        proposed_transition: transition,
        requester: requester,
        inkling_reference: "inkling:234"
      )
    end

    describe ".validate_outcome" do
      it "normalizes XP without mutating state" do
        before_count = SoulXpLedgerEntry.all.to_a.length
        payload = validate(:xp, amount: 3)

        expect(payload).to eq(
          "outcome_type" => "xp",
          "character_id" => character.id,
          "proposed_transition" => { "amount" => 3 },
          "requester_id" => requester.id,
          "inkling_reference" => "inkling:234"
        )
        expect(SoulXpLedgerEntry.all.to_a.length).to eq(before_count)
      end

      it "rejects a non-positive XP amount" do
        expect(validate(:xp, amount: 0)[:error]).to match(/positive integer/i)
      end

      it "normalizes a valid fresh Boon grant without creating an entry" do
        boon = catalogue("gift", "boon")
        payload = validate(
          :boon_progression,
          catalogue_id: boon.id,
          from: nil,
          to: "Minor"
        )

        expect(payload["proposed_transition"]).to eq(
          "catalogue_id" => boon.id.to_s,
          "from" => nil,
          "to" => "Minor"
        )
        expect(character.character_bnb_entries.to_a).to be_empty
      end

      it "normalizes a valid Bane progression" do
        bane = catalogue("curse", "bane")
        entry = CharacterBnbEntry.create(
          character: character,
          catalogue_entry: bane,
          level_state: "minor",
          resolved: "false"
        )
        payload = validate(
          :bane_progression,
          catalogue_id: bane.id,
          from: "Minor",
          to: "Major"
        )

        expect(payload[:error]).to be_nil
        expect(entry.level_state).to eq("minor")
      end

      it "rejects kind mismatches, unknown levels, duplicate grants, and stale progressions" do
        bane = catalogue("wrong_kind", "bane")
        expect(validate(
          :boon_progression, catalogue_id: bane.id, to: "Minor"
        )[:error]).to match(/requires a Boon/i)

        boon = catalogue("unknown_level", "boon")
        expect(validate(
          :boon_progression, catalogue_id: boon.id, to: "Mythic"
        )[:error]).to match(/unknown level/i)

        CharacterBnbEntry.create(
          character: character,
          catalogue_entry: boon,
          level_state: "minor",
          resolved: "false"
        )
        expect(validate(
          :boon_progression, catalogue_id: boon.id, to: "Major"
        )[:error]).to match(/already owns/i)
        expect(validate(
          :boon_progression, catalogue_id: boon.id, from: "Major", to: "Legendary"
        )[:error]).to match(/state changed/i)
      end

      it "rejects a missing progression target and an invalid Boon ratio" do
        boon = catalogue("ratio", "boon")
        expect(validate(
          :boon_progression, catalogue_id: boon.id, from: "Minor", to: "Major"
        )[:error]).to match(/does not own/i)

        allow(SoulBnbApi).to receive(:ratio_satisfied_after_boon?).and_return(false)
        expect(validate(
          :boon_progression, catalogue_id: boon.id, to: "Minor"
        )[:error]).to match(/ratio/i)
      end

      it "validates Culmination fields" do
        payload = validate(:culmination, title: "Turning Point", description: "Changed forever.")
        expect(payload["proposed_transition"]["title"]).to eq("Turning Point")
        expect(validate(:culmination, title: "", description: "Text")[:error]).to match(/title/i)
        expect(validate(:culmination, title: "Title", description: "")[:error]).to match(/description/i)
      end

      it "rejects unknown outcome types and catalogue references" do
        expect(validate(:mystery, {})[:error]).to match(/unknown outcome/i)
        expect(validate(
          :bane_progression, catalogue_id: "missing", to: "minor"
        )[:error]).to match(/unknown Boon\/Bane/i)
      end

      it "does not perform a SOUL permission check on the requester" do
        allow(Soul).to receive(:can_play?)
        allow(Soul).to receive(:can_manage_soul?)
        validate(:xp, amount: 1)
        expect(Soul).not_to have_received(:can_play?)
        expect(Soul).not_to have_received(:can_manage_soul?)
      end
    end

    describe ".apply_outcome" do
      it "applies XP with catch-up and the source as its idempotency key" do
        payload = validate(:xp, amount: 4)
        allow(SoulXpApi).to receive(:award).and_return(
          success: true, awarded: 6, base_award: 4, catchup_portion: 2
        )

        result = SoulInklingsHook.apply_outcome(payload, source: "inkling:234")
        expect(SoulXpApi).to have_received(:award).with(
          character, 4,
          source: "inkling:234",
          idempotency_key: "inkling:234",
          apply_catchup: true
        )
        expect(result[:soul_references]).to eq(
          awarded: 6, base_award: 4, catchup_portion: 2
        )
      end

      it "applies a fresh Boon grant only once on repeated delivery" do
        boon = catalogue("once", "boon")
        payload = validate(
          :boon_progression,
          catalogue_id: boon.id,
          to: "Minor"
        )

        first = SoulInklingsHook.apply_outcome(payload, source: "inkling:234")
        second = SoulInklingsHook.apply_outcome(payload, source: "inkling:234")
        entries = character.character_bnb_entries.to_a.select do |entry|
          entry.catalogue_entry == boon
        end

        expect(first[:success]).to be true
        expect(second[:duplicate]).to be true
        expect(entries.length).to eq(1)
        expect(second[:soul_references][:character_bnb_entry_id]).to eq(entries.first.id)
      end

      it "applies a progression only once even though the first call changes current state" do
        bane = catalogue("progress_once", "bane")
        entry = CharacterBnbEntry.create(
          character: character,
          catalogue_entry: bane,
          level_state: "minor",
          resolved: "false",
          source: "chargen",
          progression_history: [{ "level_state" => "minor", "source" => "chargen" }]
        )
        payload = validate(
          :bane_progression,
          catalogue_id: bane.id,
          from: "Minor",
          to: "Major"
        )

        first = SoulInklingsHook.apply_outcome(payload, source: "inkling:234")
        second = SoulInklingsHook.apply_outcome(payload, source: "inkling:234")

        expect(first[:success]).to be true
        expect(second[:duplicate]).to be true
        expect(entry.level_state).to eq("major")
        expect(entry.progression_history.count { |row| row["source"] == "inkling:234" }).to eq(1)
      end

      it "revalidates a progression against current state before applying" do
        boon = catalogue("stale", "boon")
        entry = CharacterBnbEntry.create(
          character: character,
          catalogue_entry: boon,
          level_state: "minor",
          resolved: "false"
        )
        payload = validate(
          :boon_progression,
          catalogue_id: boon.id,
          from: "Minor",
          to: "Major"
        )
        entry.update(level_state: "legendary")

        result = SoulInklingsHook.apply_outcome(payload, source: "inkling:235")
        expect(result[:error]).to match(/state changed/i)
      end

      it "revalidates catalogue kind during application" do
        bane = catalogue("kind", "bane")
        payload = {
          "outcome_type" => "boon_progression",
          "character_id" => character.id,
          "proposed_transition" => {
            "catalogue_id" => bane.id.to_s,
            "from" => nil,
            "to" => "Minor"
          },
          "requester_id" => requester.id,
          "inkling_reference" => "inkling:234"
        }
        expect(SoulInklingsHook.apply_outcome(payload, source: "inkling:234")[:error])
          .to match(/requires a Boon/i)
      end

      it "delegates Culmination idempotency to the existing API" do
        payload = validate(
          :culmination,
          title: "Turning Point",
          description: "Changed forever."
        )
        culmination = double(id: "9")
        allow(SoulCulminationApi).to receive(:propose).and_return(
          success: true, culmination: culmination, duplicate: true
        )

        result = SoulInklingsHook.apply_outcome(payload, source: "inkling:234")
        expect(SoulCulminationApi).to have_received(:propose).with(
          character,
          title: "Turning Point",
          description: "Changed forever.",
          source: "inkling:234",
          enactor: nil
        )
        expect(result[:duplicate]).to be true
        expect(result[:soul_references]).to eq(culmination_id: "9")
      end

      it "returns an error when the stored character no longer exists" do
        payload = validate(:xp, amount: 1)
        payload["character_id"] = "99999999"
        expect(SoulInklingsHook.apply_outcome(payload, source: "inkling:234")[:error])
          .to match(/character not found/i)
      end
    end
  end
end

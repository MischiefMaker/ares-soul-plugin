require_relative 'spec_helper'

module AresMUSH
  describe Roll do
    let(:character) { Fabricate(:character) }

    it "stores structured roll data and string booleans" do
      roll = Roll.create(
        character: character,
        skill_key: "strength",
        aspect_key: "body",
        difficulty: 13,
        dice_result: { "total" => 10, "mode" => "normal", "segments" => [] },
        applied_modifiers: [],
        final_result: 13,
        success_probability: 0.5,
        degree_of_success: "success",
        extraordinary: "false",
        gm_assisted: "false",
        rolled_at: Time.now
      )

      expect(roll.dice_result["total"]).to eq(10)
      expect(roll.extraordinary).to eq("false")
      expect(roll.gm_assisted).to eq("false")
    end
  end

  describe PendingRoll do
    let(:character) { Fabricate(:character) }

    it "defaults to the Phase 4 standard-roll state" do
      pending = PendingRoll.create(player: character, character: character)

      expect(pending.status).to eq("awaiting_selection")
      expect(pending.gm_assisted).to eq("false")
      expect(pending.system_suggested_entries).to eq([])
      expect(pending.gm_suggested_entries).to eq([])
      expect(pending.gm_mandatory_entries).to eq([])
    end
  end
end

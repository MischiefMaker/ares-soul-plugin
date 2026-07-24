require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulConfigValidator do
    let(:valid_config) do
      {
        "enabled" => true,
        "manage_permission" => "manage_jobs",
        "gm_review_permission" => "manage_scenes",
        "framework" => {
          "skill_min_rating" => 0,
          "skill_max_rating" => 10,
          "aspects" => { "body" => { "name" => "Body" } }
        },
        "aspect" => { "weight" => 0.20, "contribution_rounding" => "nearest" },
        "resonance" => {
          "enabled" => true, "min" => -3, "max" => 3,
          "r0_skill_points" => 15, "r0_starting_cap" => 7,
          "positive_skill_points_per_level" => 2, "negative_skill_points_per_level" => 2,
          "positive_starting_cap_per_level" => 1, "negative_starting_cap_per_level" => 1
        },
        "xp" => {
          "weekly_award" => 1, "scene_sharer_award" => 2,
          "scene_participant_award" => 1, "forum_award" => 1,
          "cost" => {
            "skill_curve_numerator" => 1, "skill_curve_denominator" => 2,
            "development_base" => 1, "development_scale" => 250,
            "development_exponent" => 1.25,
            "negative_resonance_rate" => 0.12, "positive_resonance_rate" => 0.22
          },
          "catchup" => { "multiplier" => 2.0, "grace_period_weeks" => 0 }
        },
        "bnb" => {
          "categories" => ["Arcane", "Mundane"],
          "chargen_ratio" => 2,
          "ratio_rounding" => "floor",
          "resonance_levels" => { "r_0" => {} }
        },
        "rolls" => {
          "random_model" => "d20_open_ended",
          "difficulties" => {
            "trivial" => 11, "easy" => 12, "standard" => 13, "difficult" => 17,
            "hard" => 21, "extreme" => 25, "legendary" => 34, "mythic" => 40
          },
          "extraordinary_result_threshold" => 0.0001,
          "degrees_of_success" => { "exceptional_success_min" => 10 },
          "pending_roll_timeout_hours" => 720,
          "max_pending_rolls_per_player" => 1,
          "max_pending_rolls_per_player_gm" => 2,
          "gm_scene_policy" => "optional"
        }
      }
    end

    before { allow(Global).to receive(:read_config).with("soul").and_return(valid_config) }

    describe "validate" do
      it "returns no errors for a valid config" do
        expect(Soul::SoulConfigValidator.new.validate).to eq([])
      end

      it "flags a missing enabled flag" do
        valid_config.delete("enabled")
        errors = Soul::SoulConfigValidator.new.validate
        expect(errors).to include(match(/enabled/))
      end

      it "flags an invalid random_model" do
        valid_config["rolls"]["random_model"] = "d10"
        errors = Soul::SoulConfigValidator.new.validate
        expect(errors).to include(match(/random_model/))
      end

      it "flags an out-of-range extraordinary_result_threshold" do
        valid_config["rolls"]["extraordinary_result_threshold"] = 1.5
        errors = Soul::SoulConfigValidator.new.validate
        expect(errors).to include(match(/extraordinary_result_threshold/))
      end

      it "flags a skill_max_rating that isn't greater than skill_min_rating" do
        valid_config["framework"]["skill_max_rating"] = 0
        errors = Soul::SoulConfigValidator.new.validate
        expect(errors).to include(match(/skill_max_rating/))
      end

      it "flags a chargen_ratio below 1" do
        valid_config["bnb"]["chargen_ratio"] = 0
        errors = Soul::SoulConfigValidator.new.validate
        expect(errors).to include(match(/chargen_ratio/))
      end

      it "flags an incomplete difficulties hash" do
        valid_config["rolls"]["difficulties"].delete("mythic")
        errors = Soul::SoulConfigValidator.new.validate
        expect(errors).to include(match(/difficulties/))
      end

      it "accepts an absent integrations section" do
        expect(Soul::SoulConfigValidator.new.validate).to eq([])
      end

      it "accepts a branch_skill_map referencing a real Skill" do
        valid_config["framework"]["skills"] = { "ceremonial_magic" => { "name" => "Ceremonial Magic", "aspect" => "spirit" } }
        valid_config["integrations"] = { "grimoire" => { "branch_skill_map" => { "evocation" => "ceremonial_magic" } } }
        expect(Soul::SoulConfigValidator.new.validate).to eq([])
      end

      it "flags a branch_skill_map referencing an unknown Skill" do
        valid_config["framework"]["skills"] = {}
        valid_config["integrations"] = { "grimoire" => { "branch_skill_map" => { "evocation" => "nonexistent_skill" } } }
        errors = Soul::SoulConfigValidator.new.validate
        expect(errors).to include(match(/branch_skill_map.*evocation/))
      end

      it "flags a branch_skill_map that isn't a hash" do
        valid_config["integrations"] = { "grimoire" => { "branch_skill_map" => "evocation" } }
        errors = Soul::SoulConfigValidator.new.validate
        expect(errors).to include(match(/branch_skill_map/))
      end
    end
  end
end

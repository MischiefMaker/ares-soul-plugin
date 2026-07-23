module AresMUSH
  # Permanent record of a completed SOUL roll (FINAL REQ-031). Rolls are
  # append-only; the structured dice and modifier fields preserve enough
  # detail to audit the result without re-running random mechanics.
  class Roll < Ohm::Model
    include ObjectModel

    reference :character, "AresMUSH::Character"

    attribute :skill_key
    attribute :aspect_key
    attribute :scene_id
    attribute :context, :type => DataType::Hash, :default => {}
    attribute :difficulty, :type => DataType::Integer
    attribute :dice_result, :type => DataType::Hash, :default => {}
    attribute :net_modifier, :type => DataType::Integer, :default => 0
    attribute :applied_modifiers, :type => DataType::Array, :default => []
    attribute :final_result, :type => DataType::Integer
    attribute :success_probability, :type => DataType::Float
    attribute :degree_of_success
    # Plain string booleans match the existing SOUL model convention.
    attribute :extraordinary, :default => "false"
    attribute :gm_assisted, :default => "false"
    attribute :rolled_at, :type => DataType::Time

    index :skill_key
    index :degree_of_success
  end
end

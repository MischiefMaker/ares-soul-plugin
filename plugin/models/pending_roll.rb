module AresMUSH
  # Stored standard-roll workflow state (FINAL REQ-027). Phase 4 uses only
  # awaiting_selection/resolved/aborted/expired; GM fields are present but
  # remain empty until Phase 5.
  class PendingRoll < Ohm::Model
    include ObjectModel

    reference :player, "AresMUSH::Character"
    reference :character, "AresMUSH::Character"

    attribute :skill_key
    attribute :aspect_key
    attribute :scene_id
    attribute :context, :type => DataType::Hash, :default => {}
    attribute :difficulty, :type => DataType::Integer
    attribute :system_suggested_entries, :type => DataType::Array, :default => []
    attribute :gm_suggested_entries, :type => DataType::Array, :default => []
    attribute :gm_mandatory_entries, :type => DataType::Array, :default => []
    attribute :player_selected_entries, :type => DataType::Array, :default => []
    attribute :manually_identified_entries, :type => DataType::Array, :default => []
    attribute :status, :default => "awaiting_selection"
    attribute :gm_assisted, :default => "false"
    attribute :expires_at, :type => DataType::Time

    index :status
    index :skill_key
  end
end

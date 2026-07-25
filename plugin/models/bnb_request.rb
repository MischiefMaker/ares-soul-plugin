module AresMUSH
  # A player-initiated request to add a Boon/Bane post-chargen (2026-07-25
  # profile rework - see docs/development/Bug_List.md FR-015), awaiting
  # staff approval. Deliberately NOT a CharacterBnbEntry - nothing here is
  # mechanically live until SoulBnbApi.approve_request converts it into one
  # via the existing .grant path, so a pending request can never leak into
  # roll suggestions, ratio checks, or the character sheet. Shape mirrors
  # Culmination's propose/approve/deny pattern (culmination.rb).
  class BnbRequest < Ohm::Model
    include ObjectModel

    reference :character, "AresMUSH::Character"
    reference :catalogue_entry, "AresMUSH::BnbCatalogueEntry"

    attribute :level_state, :default => "minor"
    attribute :associated_skills, :type => DataType::Array, :default => []
    # Player's own reasoning for the request - becomes the granted entry's
    # character_explanation on approval.
    attribute :player_explanation
    # "pending" / "approved" / "denied".
    attribute :status, :default => "pending"
    reference :resolved_by, "AresMUSH::Character"
    attribute :resolved_at, :type => DataType::Time
    attribute :staff_reason
    attribute :created_at, :type => DataType::Time

    index :status
  end
end

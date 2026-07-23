module AresMUSH
  # A permanent record of a significant story milestone (FINAL REQ-023,
  # GL-15) - not an XP purchase. Unlike Boons/Banes, Culminations have no
  # shared catalogue - each is a bespoke, staff-authored (or approved-Inkling
  # -sourced) title and narrative description, closer in shape to the real
  # AresMUSH Achievements plugin's per-grant record
  # (plugins/achievements/public/achievement.rb) than to the two-layer B&B
  # model.
  class Culmination < Ohm::Model
    include ObjectModel

    reference :character, "AresMUSH::Character"
    attribute :title
    attribute :description
    # e.g. "staff", "inkling:234", "workflow:<name>", or another plugin's
    # stable identifier (FINAL: "staff review, approved Inkling, standalone
    # workflow, or proposal from another plugin").
    attribute :source
    # "proposed" (awaiting staff decision) / "approved" / "denied" / "revoked".
    attribute :status, :default => "proposed"
    attribute :visibility
    # External reference, e.g. an Inkling ID, if this came from one.
    attribute :source_link
    reference :approved_by, "AresMUSH::Character"
    attribute :approved_at, :type => DataType::Time
    # Append-only {actor, reason, action, at} entries for corrections and
    # revocations - the original record is never deleted or overwritten
    # (FINAL REQ-023: "Revocation and correction SHALL preserve the
    # original record and append a linked revocation/correction").
    attribute :correction_log, :type => DataType::Array, :default => []
    attribute :created_at, :type => DataType::Time

    index :status
  end
end

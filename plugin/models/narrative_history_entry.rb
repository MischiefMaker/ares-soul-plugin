module AresMUSH
  # The character-facing record of meaningful SOUL-owned events (FINAL
  # REQ-024, GL-16) - distinct from the technical Audit log (see
  # soul_audit_entry.rb and REQ-006). Only qualifying events create one of
  # these: approved starting Resonance, B&B acquisition/progression/
  # resolution/negation, significant configured advancement, Culminations,
  # and authorized corrections/reversals. Ordinary reads, failed
  # validation, retries, and diagnostics SHALL NOT create an entry here -
  # those belong only in SoulAuditEntry.
  class NarrativeHistoryEntry < Ohm::Model
    include ObjectModel

    reference :character, "AresMUSH::Character"
    # e.g. "resonance_approved", "bnb_granted", "bnb_resolved",
    # "culmination_approved", "correction".
    attribute :event_type
    # Concise, character-facing text - not a technical dump.
    attribute :narrative
    attribute :visibility
    # Polymorphic-ish reference to the SOUL record this entry documents
    # (e.g. soul_record_type "CharacterBnbEntry", soul_record_id its .id) -
    # Ohm has no native polymorphic association, so this is two plain
    # attributes rather than a typed reference.
    attribute :soul_record_type
    attribute :soul_record_id
    # e.g. an Inkling ID. SOUL never copies the external record's own
    # history alongside this - just the reference (FINAL REQ-024: "SOUL MAY
    # reference an Inkling or Grimoire record, but SHALL NOT copy external
    # history").
    attribute :external_reference
    # Set when this entry is itself a correction/reversal of an earlier
    # one - points at that earlier entry's .id. The original entry is never
    # overwritten or deleted; this is how the two stay linked (CP-07).
    attribute :correction_of_id
    # Links back to the SoulAuditEntry created alongside this one, if any.
    attribute :audit_entry_id
    attribute :created_at, :type => DataType::Time

    index :event_type
    index :soul_record_type
  end
end

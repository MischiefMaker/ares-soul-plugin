module AresMUSH
  # The technical, staff-facing operational record (FINAL REQ-006, GL-17) -
  # actors, timestamps, sources, reasons, before/after values, and errors.
  # Distinct from NarrativeHistoryEntry: this MAY contain detail unsuitable
  # for a character-facing narrative, and covers routine failures/
  # diagnostics that never qualify for Narrative History.
  class SoulAuditEntry < Ohm::Model
    include ObjectModel

    # The character the action concerned, if any (nil for system-wide
    # actions like a cron sweep touching no single character).
    reference :character, "AresMUSH::Character"
    # Who performed the action; nil for system/cron-initiated entries.
    reference :actor, "AresMUSH::Character"
    # e.g. "resonance_correction", "bnb_delete", "culmination_revoke".
    attribute :action
    attribute :reason
    # e.g. "admin", "cron:weekly", "inkling:234".
    attribute :source
    attribute :before_state, :type => DataType::Hash, :default => {}
    attribute :after_state, :type => DataType::Hash, :default => {}
    # Set only when this entry records a failure (REQ-007: a failed
    # catch-up calculation, a rejected destructive-delete attempt, etc.).
    attribute :error
    attribute :created_at, :type => DataType::Time

    index :action
  end
end

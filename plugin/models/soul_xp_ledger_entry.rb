module AresMUSH
  # One award or spend event on a character's XP ledger (FINAL REQ-003's
  # "award/spend ledger", REQ-013). Backs idempotency (a repeated scene-share
  # or weekly cron tick with the same idempotency_key SHALL NOT double-award,
  # per FINAL REQ-013) and provides the history view for +xp/history.
  class SoulXpLedgerEntry < Ohm::Model
    include ObjectModel

    reference :character, "AresMUSH::Character"
    # "award" or "spend".
    attribute :direction
    # Free-text origin: "weekly", "scene:<id>", "forum", "inkling:<id>",
    # "admin", or a Skill key for spends (e.g. "blade").
    attribute :source
    # Stable key used to detect duplicate delivery of the same logical
    # event (e.g. "weekly:2026-W30:<char_id>", "scene:42:<char_id>").
    # Manual admin grants and spends may leave this blank - only sources
    # that could plausibly be redelivered need one.
    attribute :idempotency_key
    # For awards: the base amount before any catch-up multiplier. For
    # spends: the XP cost paid.
    attribute :base_amount, :type => DataType::Integer, :default => 0
    # For awards: the bonus portion added by the catch-up multiplier
    # (FINAL REQ-014). Always 0 for spends and for non-catch-up awards.
    attribute :catchup_amount, :type => DataType::Integer, :default => 0
    attribute :created_at, :type => DataType::Time

    index :idempotency_key
  end
end

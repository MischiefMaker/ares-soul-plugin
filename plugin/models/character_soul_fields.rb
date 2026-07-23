module AresMUSH
  class Character
    # Resonance (FINAL REQ-012, GL-06). Plain untyped attribute rather than
    # DataType::Integer - Ohm's Integer cast is `x.to_i`, which turns a truly
    # unset attribute (nil, before the player has chosen a Resonance during
    # chargen) into 0, indistinguishable from an explicit R0 choice. Read via
    # SoulResonanceApi.get_resonance, which parses this manually and
    # preserves the nil-vs-R0 distinction.
    attribute :resonance
    # Set once, by Soul.lock_resonance_at_approval (called from the game's
    # own plugins/chargen/custom_approval.rb - see
    # custom-install/custom_approval.snippet.rb). DataType::Time's cast is
    # nil-safe (`t && ...`), so this correctly reads as nil until locked.
    attribute :resonance_locked_at, :type => DataType::Time
    # Lightweight append-only correction trail (actor, reason, old/new value,
    # timestamp) for staff Resonance corrections after locking. Superseded by
    # the real Narrative History / Audit models once Phase 3 builds them -
    # see docs/spec/IMPLEMENTATION_CHECKLIST.md Phase 3.
    attribute :resonance_correction_log, :type => DataType::Array, :default => []

    # XP ledger counters (FINAL REQ-013). All default to 0 like FS3Skills'
    # own fs3_xp attribute (plugins/fs3skills/public/fs3skills_char.rb) -
    # every character has these from creation, so the nil-cast footgun
    # above doesn't apply here.
    attribute :soul_xp_available, :type => DataType::Integer, :default => 0
    attribute :soul_xp_earned, :type => DataType::Integer, :default => 0
    attribute :soul_xp_spent, :type => DataType::Integer, :default => 0
    attribute :soul_catchup_xp_earned, :type => DataType::Integer, :default => 0

    collection :character_aspects, "AresMUSH::CharacterAspect"
    collection :character_skills, "AresMUSH::CharacterSkill"
    collection :soul_xp_ledger_entries, "AresMUSH::SoulXpLedgerEntry"
  end
end

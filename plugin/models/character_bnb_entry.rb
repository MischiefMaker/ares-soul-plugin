module AresMUSH
  # A character-owned instance of a Boon/Bane catalogue entry (FINAL
  # REQ-018). Its own auto-incrementing .id is a separate sequence from the
  # catalogue's - e.g. catalogue "Cursed" might be #27, while Sarah's and
  # Morgan's instances are #123 and #146, both referencing catalogue #27
  # (FINAL's own worked example).
  class CharacterBnbEntry < Ohm::Model
    include ObjectModel

    reference :character, "AresMUSH::Character"
    reference :catalogue_entry, "AresMUSH::BnbCatalogueEntry"

    # "minor" / "major" / "legendary" / "negated" / "epic" (or configured
    # equivalents) - the entry's CURRENT level/state.
    attribute :level_state
    # Private; owner + authorized staff only (FINAL REQ-018). Never shown
    # in public presentation.
    attribute :character_explanation
    attribute :associated_skills, :type => DataType::Array, :default => []
    # e.g. "[Chargen]", "[Inkling 234]", "[Admin]".
    attribute :source
    # One entry per attained level/state: { "level_state" =>, "explanation" =>,
    # "source" =>, "at" => }. Appended to, never overwritten (FINAL REQ-018).
    attribute :progression_history, :type => DataType::Array, :default => []
    # Staff-only.
    attribute :gm_notes
    # "true"/"false" - see bnb_catalogue_entry.rb's note on why this isn't
    # DataType::Boolean.
    attribute :resolved, :default => "false"
    # The level_state held immediately before resolution/negation - restored
    # by SoulBnbApi.restore unless staff explicitly choose a different valid
    # state (FINAL REQ-020).
    attribute :preserved_level_state

    index :level_state

    def boon?
      catalogue_entry && catalogue_entry.boon?
    end

    def bane?
      catalogue_entry && catalogue_entry.bane?
    end
  end
end

module AresMUSH
  # Site-wide Boon/Bane catalogue definition (FINAL REQ-017). Unlike Aspects
  # and Skills (see character_aspect.rb), B&Bs ARE a real DB-backed
  # catalogue - FINAL requires "a unique numeric ID" (naturally satisfied by
  # Ohm's own auto-incrementing .id, no custom generator needed) and
  # SOUL_Design_Decisions.md DD-02 confirms catalogue entries are created
  # via in-game commands (+bnb/create), not seeded from config.
  #
  # Level/state modifiers (Minor +1, Major +2, Legendary +3, Negated none)
  # come from global config (game/config/soul.yml's bnb.level_definitions)
  # and apply uniformly to every catalogue entry. Epic is the one level
  # FINAL requires an "explicitly configured" per-entry effect for (REQ-017:
  # "the label alone SHALL NOT imply an uncapped modifier") - see
  # epic_modifier below.
  class BnbCatalogueEntry < Ohm::Model
    include ObjectModel

    attribute :tag
    # Case-insensitive lookup index, same convention as AresMUSH::Role's
    # name_upcase (engine/aresmush/models/find_by_name.rb) - Ohm has no
    # native unique-constraint mechanism, so tag uniqueness is enforced at
    # the SoulBnbApi.create_catalogue_entry call site (check-then-create),
    # matching how Role/Job-category uniqueness is handled elsewhere.
    attribute :tag_upcase
    attribute :name
    attribute :description
    # "boon" or "bane" (GL-07/GL-08) - distinct from category below. Not
    # explicitly itemized in FINAL REQ-017's field list, but required by
    # every mechanic that depends on it: the 2:1 chargen ratio (Addendum
    # §5), the separate Boon/Bane chargen limit tables, and GL-07/GL-08's
    # own definitions of the two as fundamentally different things.
    attribute :kind
    # Configurable grouping, independent of kind - default options are
    # Arcane and Mundane (CI-01, game/config/soul.yml's bnb.categories). A
    # Boon and a Bane can share a category.
    attribute :category

    # Plain "true"/"false" string attributes, not DataType::Boolean - its
    # cast (!!x) turns even the stored string "false" into true, since any
    # non-empty string is truthy in Ruby. Matches the verified convention
    # from Inklings' own Inkling#locked (compared via == "true").
    attribute :chargen_available, :default => "true"
    attribute :flag_for_review, :default => "false"
    attribute :modifier_eligible, :default => "false"

    # Only meaningful for the Epic level/state - see the class comment.
    # Plain (untyped) attribute; nil means "not configured for Epic," which
    # SoulBnbApi.level_modifier treats as an error if an entry is ever
    # actually granted at Epic without one set.
    attribute :epic_modifier

    attribute :skill_associations, :type => DataType::Array, :default => []
    # "true"/"false" - inactive entries are hidden from new-grant flows but
    # never deleted, preserving history for characters who already hold them.
    attribute :active, :default => "true"

    collection :character_entries, "AresMUSH::CharacterBnbEntry"

    index :tag_upcase
    index :category
    index :kind

    before_save :save_tag_upcase

    def save_tag_upcase
      self.tag_upcase = self.tag.to_s.upcase
    end

    def boon?
      kind.to_s.downcase == "boon"
    end

    def bane?
      kind.to_s.downcase == "bane"
    end
  end
end

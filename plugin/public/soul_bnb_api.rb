module AresMUSH
  # Boon & Bane catalogue and character-entry transitions (FINAL REQ-016
  # through REQ-022, Addendum §5). See docs/architecture/Data_Model.md for
  # the two-layer catalogue/instance split.
  class SoulBnbApi
    # --- Catalogue ---

    def self.create_catalogue_entry(name:, description:, kind:, tag:, enactor:, category: nil,
                                     epic_modifier: nil, chargen_available: true,
                                     flag_for_review: false, modifier_eligible: false,
                                     skill_associations: [])
      return { error: "You don't have permission to do that." } unless Soul.can_manage_soul?(enactor)
      return { error: "Kind must be 'boon' or 'bane'." } unless %w[boon bane].include?(kind.to_s)
      return { error: "Tag is required." } if tag.to_s.blank?
      return { error: "That tag is already in use." } if BnbCatalogueEntry.find_one(tag_upcase: tag.to_s.upcase)

      entry = BnbCatalogueEntry.create(
        tag: tag.to_s,
        name: name,
        description: description,
        kind: kind.to_s,
        category: category,
        epic_modifier: epic_modifier,
        chargen_available: chargen_available ? "true" : "false",
        flag_for_review: flag_for_review ? "true" : "false",
        modifier_eligible: modifier_eligible ? "true" : "false",
        skill_associations: skill_associations || []
      )
      { success: true, entry: entry }
    end

    # Accepts either a numeric catalogue ID or a tag (case-insensitive) -
    # matches FINAL REQ-022's "+bnb <id>" (numeric) and tag-based lookup.
    def self.get_catalogue_entry(id_or_tag)
      return nil if id_or_tag.to_s.blank?
      if id_or_tag.to_s =~ /\A\d+\z/
        BnbCatalogueEntry[id_or_tag.to_i]
      else
        BnbCatalogueEntry.find_one(tag_upcase: id_or_tag.to_s.upcase)
      end
    end

    def self.get_catalogue(kind: nil, category: nil, active_only: true)
      entries = BnbCatalogueEntry.all.to_a
      entries = entries.select { |e| e.active == "true" } if active_only
      entries = entries.select { |e| e.kind == kind.to_s } if kind
      entries = entries.select { |e| e.category == category } if category
      entries.sort_by { |e| e.name.to_s }
    end

    # Tag and name substring match (staff/admin global search, REQ-022).
    def self.search(query)
      return [] if query.to_s.blank?
      q = query.to_s.downcase
      BnbCatalogueEntry.all.to_a.select { |e| e.tag.to_s.downcase.include?(q) || e.name.to_s.downcase.include?(q) }
    end

    # Resolves a level/state's mechanical modifier: the global default from
    # game/config/soul.yml's bnb.level_definitions, except Epic, which SHALL
    # use an explicitly configured per-entry effect (FINAL REQ-017) - nil if
    # an Epic-level entry has none set, which callers should treat as an
    # error rather than silently defaulting to 0.
    def self.level_modifier(catalogue_entry, level_state)
      return 0 unless catalogue_entry
      level_state = level_state.to_s.downcase
      return catalogue_entry.epic_modifier ? catalogue_entry.epic_modifier.to_i : nil if level_state == "epic"

      definitions = Global.read_config("soul", "bnb", "level_definitions") || {}
      (definitions[level_state] || {})["modifier"].to_i
    end

    # --- Chargen / continuous ratio validation (FINAL REQ-019, Addendum §5) ---

    def self.boon_count(character)
      return 0 unless character
      character.character_bnb_entries.to_a.select { |e| e.boon? && e.resolved != "true" }.count
    end

    def self.bane_count(character)
      return 0 unless character
      character.character_bnb_entries.to_a.select { |e| e.bane? && e.resolved != "true" }.count
    end

    # The 2:1 ratio applies continuously - in chargen and post-chargen alike
    # (Addendum §5.1's own design rationale) - unlike the Resonance-level
    # count/level limits below, which are chargen-only.
    def self.ratio_satisfied_after_boon?(character)
      ratio = Global.read_config("soul", "bnb", "chargen_ratio") || 2
      rounding = Global.read_config("soul", "bnb", "ratio_rounding") || "floor"
      required = (boon_count(character) + 1).to_f / ratio
      required = case rounding
                 when "ceil" then required.ceil
                 when "round" then required.round
                 else required.floor
                 end
      bane_count(character) >= required
    end

    # Resonance-level chargen count/level limits (Addendum §5.2-§5.3) -
    # checked only when source is "chargen" (see .grant below); these
    # tables are explicitly framed as chargen limits, not lifetime caps.
    def self.validate_chargen_limits(character, catalogue_entry, level_state)
      resonance = SoulResonanceApi.get_resonance(character) || 0
      resonance_key = "r_#{resonance}".sub("-", "minus_")
      levels_config = Global.read_config("soul", "bnb", "resonance_levels") || {}
      limits = levels_config[resonance_key]
      return "No chargen B&B limits configured for Resonance #{resonance}." unless limits

      bucket = catalogue_entry.boon? ? "boons" : "banes"
      bucket_limits = limits[bucket] || {}
      current_count = catalogue_entry.boon? ? boon_count(character) : bane_count(character)

      max_count = bucket_limits["max_count"]
      if max_count && current_count + 1 > max_count
        return "Maximum #{bucket} at Resonance #{resonance} is #{max_count}."
      end

      level_state = level_state.to_s
      if %w[major legendary].include?(level_state)
        key = level_state == "major" ? "max_at_level_2" : "max_at_level_3"
        max_at_level = bucket_limits[key] || 0
        current_at_level = character.character_bnb_entries.to_a.count do |e|
          (catalogue_entry.boon? ? e.boon? : e.bane?) && e.level_state == level_state && e.resolved != "true"
        end
        return "Maximum #{bucket} at #{level_state.capitalize} for Resonance #{resonance} is #{max_at_level}." if current_at_level + 1 > max_at_level
      end

      nil
    end

    # --- Character entry transitions ---

    # source: "chargen", "[Inkling 234]"-style external references, "admin",
    # etc. Chargen-sourced grants are validated against the Resonance
    # tables; Boon grants of any source are validated against the
    # continuous 2:1 ratio (FINAL REQ-019).
    def self.grant(character, catalogue_ref, level_state:, source:, explanation: nil, enactor: nil)
      return { error: "Character not found" } unless character
      catalogue_entry = catalogue_ref.kind_of?(BnbCatalogueEntry) ? catalogue_ref : get_catalogue_entry(catalogue_ref)
      return { error: "Unknown Boon/Bane: #{catalogue_ref}" } unless catalogue_entry

      definitions = Global.read_config("soul", "bnb", "level_definitions") || {}
      return { error: "Unknown level/state: #{level_state}" } unless definitions.key?(level_state.to_s)

      if catalogue_entry.boon? && !ratio_satisfied_after_boon?(character)
        return { error: "Granting this Boon would violate the 2:1 Boon-to-Bane ratio - grant a Bane first." }
      end

      if source.to_s == "chargen"
        limit_error = validate_chargen_limits(character, catalogue_entry, level_state)
        return { error: limit_error } if limit_error
      end

      entry = CharacterBnbEntry.create(
        character: character,
        catalogue_entry: catalogue_entry,
        level_state: level_state.to_s,
        character_explanation: explanation,
        source: source.to_s,
        progression_history: [{
          "level_state" => level_state.to_s, "explanation" => explanation, "source" => source.to_s, "at" => Time.now.to_s
        }]
      )

      SoulNarrativeHistoryApi.create(
        character,
        event_type: "bnb_granted",
        narrative: "Gained #{catalogue_entry.name} (#{level_state.to_s.capitalize}).",
        soul_record: entry,
        external_reference: source.to_s =~ /\Ainkling:/ ? source.to_s : nil
      )

      Global.dispatcher.queue_event SoulBnbTransitionedEvent.new(
        character.id, entry.id, catalogue_entry.id, nil, level_state.to_s, source.to_s
      )

      { success: true, entry: entry }
    end

    def self.progress(entry_id, new_level_state, source:, explanation: nil, enactor: nil)
      entry = CharacterBnbEntry[entry_id]
      return { error: "B&B entry not found" } unless entry
      return { error: "This entry is resolved/negated - restore it first." } if entry.resolved == "true"

      definitions = Global.read_config("soul", "bnb", "level_definitions") || {}
      return { error: "Unknown level/state: #{new_level_state}" } unless definitions.key?(new_level_state.to_s)

      old_level = entry.level_state
      history = entry.progression_history || []
      history << { "level_state" => new_level_state.to_s, "explanation" => explanation, "source" => source.to_s, "at" => Time.now.to_s }
      entry.update(level_state: new_level_state.to_s, progression_history: history)

      SoulNarrativeHistoryApi.create(
        entry.character,
        event_type: "bnb_progressed",
        narrative: "#{entry.catalogue_entry.name} progressed to #{new_level_state.to_s.capitalize}.",
        soul_record: entry
      )

      Global.dispatcher.queue_event SoulBnbTransitionedEvent.new(
        entry.character.id, entry.id, entry.catalogue_entry.id, old_level, new_level_state.to_s, source.to_s
      )

      { success: true, entry: entry }
    end

    # Non-destructive (FINAL REQ-020): preserves the prior level and full
    # history. "Negated" for Boons, "Resolved" for Banes - same mechanic,
    # different label by convention only.
    def self.resolve(entry_id, reason:, enactor:)
      entry = CharacterBnbEntry[entry_id]
      return { error: "B&B entry not found" } unless entry
      return { error: "Already resolved/negated." } if entry.resolved == "true"

      entry.update(resolved: "true", preserved_level_state: entry.level_state)

      label = entry.boon? ? "Negated" : "Resolved"
      SoulNarrativeHistoryApi.create(
        entry.character,
        event_type: "bnb_resolved",
        narrative: "#{entry.catalogue_entry.name} #{label.downcase}: #{reason}",
        soul_record: entry
      )
      SoulAuditApi.create(
        action: "bnb_resolve", character: entry.character, actor: enactor, reason: reason,
        before_state: { "resolved" => "false" }, after_state: { "resolved" => "true" }
      )

      Global.dispatcher.queue_event SoulBnbTransitionedEvent.new(
        entry.character.id, entry.id, entry.catalogue_entry.id, entry.preserved_level_state, "resolved", "manual"
      )

      { success: true, entry: entry }
    end

    def self.restore(entry_id, enactor:)
      entry = CharacterBnbEntry[entry_id]
      return { error: "B&B entry not found" } unless entry
      return { error: "This entry is not currently resolved/negated." } unless entry.resolved == "true"

      entry.update(resolved: "false", level_state: entry.preserved_level_state || entry.level_state)

      SoulNarrativeHistoryApi.create(
        entry.character, event_type: "bnb_restored",
        narrative: "#{entry.catalogue_entry.name} restored.", soul_record: entry
      )

      { success: true, entry: entry }
    end

    # Destructive deletion (FINAL REQ-021): requires a reason and two
    # explicit confirmations (confirmations: 2), captures an audit
    # snapshot, and links a Narrative History correction. Resolution
    # (.resolve above) is the recommended alternative for ordinary play.
    def self.delete(entry_id, enactor:, confirmations:, reason:)
      return { error: "A reason is required to delete a B&B entry." } if reason.to_s.blank?
      if confirmations.to_i < 2
        return { error: "Deleting a B&B entry is destructive - resolving/negating it is recommended instead. To proceed anyway, confirm twice (confirmations: 2)." }
      end

      entry = CharacterBnbEntry[entry_id]
      return { error: "B&B entry not found" } unless entry

      audit = SoulAuditApi.create(
        action: "bnb_delete", character: entry.character, actor: enactor, reason: reason,
        before_state: entry.attributes, after_state: {}
      )
      SoulNarrativeHistoryApi.create(
        entry.character, event_type: "correction",
        narrative: "A Boon/Bane record (#{entry.catalogue_entry ? entry.catalogue_entry.name : 'unknown'}) was deleted by staff: #{reason}",
        audit_entry: audit
      )

      entry.delete
      { success: true }
    end

    # --- Character-facing views ---

    def self.get_character_entries(character)
      return [] unless character
      character.character_bnb_entries.to_a.sort_by { |e| e.catalogue_entry ? e.catalogue_entry.name.to_s : "" }
    end

    # Public-safe view: no character_explanation or gm_notes (FINAL REQ-018).
    def self.get_character_entry_public(character, entry_id)
      return nil unless character
      entry = character.character_bnb_entries.to_a.find { |e| e.id.to_s == entry_id.to_s }
      return nil unless entry

      {
        id: entry.id,
        catalogue_id: entry.catalogue_entry.id,
        tag: entry.catalogue_entry.tag,
        name: entry.catalogue_entry.name,
        level_state: entry.level_state,
        modifier: level_modifier(entry.catalogue_entry, entry.level_state),
        resolved: entry.resolved == "true"
      }
    end
  end
end

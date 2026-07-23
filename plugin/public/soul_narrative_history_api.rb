module AresMUSH
  # The character-facing Narrative History (FINAL REQ-024, GL-16). Other
  # SOUL APIs call .create when they perform a qualifying transition
  # (Resonance approval, a B&B transition, a Culmination) - it is not meant
  # to be created directly by commands or web handlers.
  class SoulNarrativeHistoryApi
    def self.create(character, event_type:, narrative:, visibility: "owner_and_staff",
                     soul_record: nil, external_reference: nil, correction_of: nil, audit_entry: nil)
      NarrativeHistoryEntry.create(
        character: character,
        event_type: event_type,
        narrative: narrative,
        visibility: visibility,
        soul_record_type: soul_record ? soul_record.class.name.split("::").last : nil,
        soul_record_id: soul_record ? soul_record.id : nil,
        external_reference: external_reference,
        correction_of_id: correction_of ? correction_of.id : nil,
        audit_entry_id: audit_entry ? audit_entry.id : nil,
        created_at: Time.now
      )
    end

    # Owner or authorized staff only (FINAL REQ-005). Returns an empty
    # array for anyone else rather than an error, matching the read-only,
    # fail-quiet convention other privacy-filtered reads use.
    def self.get_history(character, viewer, limit: 50)
      return [] unless character && viewer
      return [] unless viewer == character || Soul.can_manage_soul?(viewer)

      character.narrative_history_entries.to_a
        .sort_by { |e| e.created_at || Time.at(0) }
        .reverse
        .first(limit)
    end
  end
end

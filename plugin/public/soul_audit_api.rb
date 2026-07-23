module AresMUSH
  # The technical Audit log (FINAL REQ-006, GL-17) - staff-only. Other SOUL
  # APIs call .create for corrections, destructive operations, and
  # notable failures; it is not meant to be created directly by commands.
  class SoulAuditApi
    def self.create(action:, character: nil, actor: nil, reason: nil, source: nil,
                     before_state: {}, after_state: {}, error: nil)
      SoulAuditEntry.create(
        character: character,
        actor: actor,
        action: action,
        reason: reason,
        source: source,
        before_state: before_state || {},
        after_state: after_state || {},
        error: error,
        created_at: Time.now
      )
    end

    # Staff-only (FINAL REQ-036). Returns an empty array for anyone else.
    def self.get_audit(character, viewer, limit: 50)
      return [] unless character && viewer
      return [] unless Soul.can_manage_soul?(viewer)

      character.soul_audit_entries.to_a
        .sort_by { |e| e.created_at || Time.at(0) }
        .reverse
        .first(limit)
    end
  end
end

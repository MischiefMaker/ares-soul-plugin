module AresMUSH
  # Culminations: permanent story-milestone records (FINAL REQ-023, GL-15).
  # Staff approval required by default unless automation is explicitly
  # enabled (game/config/soul.yml's culminations.approval_required).
  class SoulCulminationApi
    # source: "staff", "inkling:234", "workflow:<name>", or another
    # plugin's stable identifier. Another plugin MAY call .propose but
    # SHALL NOT create an approved record directly - SOUL owns creation.
    def self.propose(character, title:, description:, source:, enactor: nil)
      return { error: "Character not found" } unless character
      return { error: "Title is required." } if title.to_s.blank?

      # Deterministic duplicate handling (FINAL REQ-023): the same source
      # reference (e.g. the same Inkling) SHALL NOT silently create more
      # than one Culmination.
      existing = character.culminations.to_a.find { |c| c.source == source.to_s && c.status != "denied" }
      return { success: true, culmination: existing, duplicate: true } if existing

      approval_required = Global.read_config("soul", "culminations", "approval_required")
      approval_required = true if approval_required.nil?

      culmination = Culmination.create(
        character: character,
        title: title,
        description: description,
        source: source.to_s,
        status: approval_required ? "proposed" : "approved",
        created_at: Time.now
      )

      if !approval_required
        culmination.update(approved_at: Time.now)
        create_approval_history(culmination)
      end

      { success: true, culmination: culmination }
    end

    def self.approve(culmination_id, enactor)
      return { error: "You don't have permission to do that." } unless Soul.can_manage_soul?(enactor)
      culmination = Culmination[culmination_id]
      return { error: "Culmination not found" } unless culmination
      return { error: "This Culmination is not awaiting approval." } unless culmination.status == "proposed"

      culmination.update(status: "approved", approved_by: enactor, approved_at: Time.now)
      create_approval_history(culmination)

      { success: true, culmination: culmination }
    end

    def self.deny(culmination_id, enactor, reason:)
      return { error: "You don't have permission to do that." } unless Soul.can_manage_soul?(enactor)
      culmination = Culmination[culmination_id]
      return { error: "Culmination not found" } unless culmination
      return { error: "This Culmination is not awaiting approval." } unless culmination.status == "proposed"

      log = culmination.correction_log || []
      log << { "action" => "denied", "actor" => enactor.name, "reason" => reason, "at" => Time.now.to_s }
      culmination.update(status: "denied", correction_log: log)

      { success: true, culmination: culmination }
    end

    # Revocation preserves the original record and appends a linked entry
    # rather than deleting or overwriting it (FINAL REQ-023).
    def self.revoke(culmination_id, enactor, reason:)
      return { error: "You don't have permission to do that." } unless Soul.can_manage_soul?(enactor)
      return { error: "A reason is required to revoke a Culmination." } if reason.to_s.blank?
      culmination = Culmination[culmination_id]
      return { error: "Culmination not found" } unless culmination
      return { error: "Only an approved Culmination can be revoked." } unless culmination.status == "approved"

      log = culmination.correction_log || []
      log << { "action" => "revoked", "actor" => enactor.name, "reason" => reason, "at" => Time.now.to_s }
      culmination.update(status: "revoked", correction_log: log)

      SoulNarrativeHistoryApi.create(
        culmination.character, event_type: "correction",
        narrative: "Culmination '#{culmination.title}' was revoked: #{reason}",
        soul_record: culmination, correction_of: find_approval_history(culmination)
      )
      SoulAuditApi.create(action: "culmination_revoke", character: culmination.character, actor: enactor, reason: reason)

      { success: true, culmination: culmination }
    end

    def self.correct(culmination_id, enactor, title: nil, description: nil, reason:)
      return { error: "You don't have permission to do that." } unless Soul.can_manage_soul?(enactor)
      return { error: "A reason is required to correct a Culmination." } if reason.to_s.blank?
      culmination = Culmination[culmination_id]
      return { error: "Culmination not found" } unless culmination

      log = culmination.correction_log || []
      log << {
        "action" => "corrected", "actor" => enactor.name, "reason" => reason, "at" => Time.now.to_s,
        "old_title" => culmination.title, "old_description" => culmination.description
      }
      culmination.update(
        title: title || culmination.title,
        description: description || culmination.description,
        correction_log: log
      )
      SoulAuditApi.create(action: "culmination_correct", character: culmination.character, actor: enactor, reason: reason)

      { success: true, culmination: culmination }
    end

    def self.get_culminations(character, status: nil)
      return [] unless character
      culminations = character.culminations.to_a
      culminations = culminations.select { |c| c.status == status.to_s } if status
      culminations.sort_by { |c| c.created_at || Time.at(0) }.reverse
    end

    def self.create_approval_history(culmination)
      SoulNarrativeHistoryApi.create(
        culmination.character,
        event_type: "culmination_approved",
        narrative: "Culmination achieved: #{culmination.title}",
        soul_record: culmination,
        external_reference: culmination.source =~ /\Ainkling:/ ? culmination.source : nil
      )
      Global.dispatcher.queue_event SoulCulminationApprovedEvent.new(
        culmination.character.id, culmination.id, culmination.source
      )
    end
    private_class_method :create_approval_history

    def self.find_approval_history(culmination)
      NarrativeHistoryEntry.find(soul_record_type: "Culmination", soul_record_id: culmination.id.to_s)
        .to_a.find { |e| e.event_type == "culmination_approved" }
    end
    private_class_method :find_approval_history
  end
end

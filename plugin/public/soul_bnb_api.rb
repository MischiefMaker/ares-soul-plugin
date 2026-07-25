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
      # Optional here, not required (corrected 2026-07-25 - see Bug_List.md
      # FR-011's correction note): skill_associations at the catalogue level
      # is only a *fixed default* for B&Bs that always affect the same
      # Skill(s) (e.g. Ceremonial Attunement -> Ceremonial Magic always).
      # Many B&Bs are "configurable per instance" (docs/reference/
      # Default_BnBs.md's own Cursed example) - the granter picks the
      # affected Skill(s) per character at grant time instead (see .grant's
      # associated_skills:), stored on CharacterBnbEntry, not here. An entry
      # with no fixed default is completely valid; .grant is where "must
      # have at least one Skill from somewhere" is actually enforced.
      unknown_skills = (skill_associations || []).reject { |key| SoulFrameworkApi.valid_skill_key?(key) }
      return { error: "Unknown Skill(s): #{unknown_skills.join(', ')}" } if unknown_skills.any?

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

    # The only editable field on an existing catalogue entry - added
    # specifically so a legacy entry created before the associated-Skill
    # requirement (2026-07-25) can be fixed in place rather than staff
    # needing to abandon its tag/history and create a replacement. Every
    # other catalogue field is create-time only by design (FINAL REQ-017's
    # catalogue entries are meant to be stable once granted to characters);
    # this is a narrow, deliberate exception because .grant now refuses any
    # entry with an empty list, and there was previously no way at all to
    # add one after the fact.
    def self.set_skill_associations(id_or_tag, skill_associations, enactor:)
      return { error: "You don't have permission to do that." } unless Soul.can_manage_soul?(enactor)
      entry = get_catalogue_entry(id_or_tag)
      return { error: "Unknown Boon/Bane: #{id_or_tag}" } unless entry
      return { error: "At least one associated Skill is required." } if (skill_associations || []).empty?
      unknown_skills = skill_associations.reject { |key| SoulFrameworkApi.valid_skill_key?(key) }
      return { error: "Unknown Skill(s): #{unknown_skills.join(', ')}" } if unknown_skills.any?

      entry.update(skill_associations: skill_associations)
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

    def self.get_catalogue(kind: nil, category: nil, active_only: true, chargen_available: nil)
      entries = BnbCatalogueEntry.all.to_a
      entries = entries.select { |e| e.active == "true" } if active_only
      entries = entries.select { |e| e.kind == kind.to_s } if kind
      entries = entries.select { |e| e.category == category } if category
      unless chargen_available.nil?
        expected = chargen_available ? "true" : "false"
        entries = entries.select { |e| e.chargen_available == expected }
      end
      entries.sort_by { |e| e.name.to_s }
    end

    # Tag and name substring match (staff/admin global search, REQ-022).
    def self.search(query)
      return [] if query.to_s.blank?
      q = query.to_s.downcase
      BnbCatalogueEntry.all.to_a.select { |e| e.tag.to_s.downcase.include?(q) || e.name.to_s.downcase.include?(q) }
    end

    # Paginated catalogue browse (2026-07-25 profile rework, FR-015) - the
    # web profile's "add a Boon/Bane" picker lists the whole active
    # catalogue, which .get_catalogue never needed to page before. Mirrors
    # Inklings' admin-page page/total_pages/total_count convention
    # (admin-inklings.js) rather than inventing a new shape.
    def self.get_catalogue_page(page: 1, per_page: 10, query: nil, kind: nil)
      entries = query.to_s.blank? ? get_catalogue(kind: kind) : search(query).select { |e| e.active == "true" }
      entries = entries.select { |e| e.kind == kind.to_s } if kind && !query.to_s.blank?
      total_count = entries.count
      total_pages = [(total_count.to_f / per_page).ceil, 1].max
      page = page.to_i.clamp(1, total_pages)
      paged = entries[(page - 1) * per_page, per_page] || []
      { entries: paged, page: page, total_pages: total_pages, total_count: total_count }
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

    # Whether the character's *current* allocation already satisfies the
    # continuous 2:1 ratio - for chargen/status readiness display (mischief
    # bug list item 12, 2026-07-25). Unlike .ratio_satisfied_after_boon?,
    # which checks a hypothetical one-more-Boon addition before granting,
    # this checks the ratio as it stands right now, with no pending grant.
    def self.ratio_currently_satisfied?(character)
      ratio = Global.read_config("soul", "bnb", "chargen_ratio") || 2
      rounding = Global.read_config("soul", "bnb", "ratio_rounding") || "floor"
      required = boon_count(character).to_f / ratio
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
    # associated_skills: the Skill(s) THIS grant affects, chosen by whoever
    # is granting it (staff, or the player themself via chargen) - the
    # correct place for this (2026-07-25 correction, see Bug_List.md
    # FR-011): many B&Bs are "configurable per instance" (Cursed affects
    # different Skills for different characters), not a fixed catalogue-
    # wide property. Falls back to the catalogue entry's own configured
    # skill_associations when omitted, for B&Bs that DO always affect the
    # same Skill(s) (e.g. Ceremonial Attunement). Either source is fine, but
    # at least one Skill has to come from somewhere - +roll's suggested-
    # candidates flow is keyed off CharacterBnbEntry#associated_skills, so a
    # grant with none would be invisible to it forever.
    def self.grant(character, catalogue_ref, level_state:, source:, explanation: nil, enactor: nil,
                    associated_skills: nil)
      return { error: "Character not found" } unless character
      catalogue_entry = catalogue_ref.kind_of?(BnbCatalogueEntry) ? catalogue_ref : get_catalogue_entry(catalogue_ref)
      return { error: "Unknown Boon/Bane: #{catalogue_ref}" } unless catalogue_entry

      effective_skills = associated_skills.presence || catalogue_entry.skill_associations || []
      if effective_skills.empty?
        return { error: "#{catalogue_entry.name} has no fixed Skill configured - specify at least one " \
          "associated Skill when granting it." }
      end
      unknown_skills = effective_skills.reject { |key| SoulFrameworkApi.valid_skill_key?(key) }
      return { error: "Unknown Skill(s): #{unknown_skills.join(', ')}" } if unknown_skills.any?

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
        associated_skills: effective_skills,
        source: source.to_s,
        progression_history: [{
          "level_state" => level_state.to_s, "explanation" => explanation, "source" => source.to_s, "at" => Time.now.to_s
        }]
      )

      # Chargen selections are provisional until approval (FINAL REQ-011:
      # "Incomplete or rejected chargen SHALL NOT create Narrative History";
      # rule 8 permits only "the feature-specific starting history entries
      # required" at approval). Deferred here and created once, for every
      # surviving chargen selection, by finalize_chargen_grants - called at
      # approval, mirroring SoulResonanceApi.lock_at_approval exactly. A
      # chargen-sourced grant reaching this method post-approval (should not
      # normally happen) still records normally rather than silently losing
      # the entry's history.
      unless source.to_s == "chargen" && !character.is_approved?
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
      end

      { success: true, entry: entry }
    end

    # Undo for a pre-approval chargen B&B pick (FINAL REQ-011 rule 6:
    # "Permit correction without losing editable work"). Deliberately
    # distinct from the destructive, staff-only .delete (2 confirmations,
    # reason, audit trail - designed for a permanent post-story record, not
    # routine chargen editing) and from .resolve/.restore (designed for a
    # narrative "this Boon got resolved" transition after the entry already
    # has real history). A chargen selection has neither yet - .grant defers
    # its history until approval (above) - so a clean hard delete here is
    # safe: nothing is orphaned, and nothing is silently lost.
    # Accepts either the character's own entry ID (as originally shown in
    # +soul/cg's status listing) or the catalogue entry's tag - added
    # 2026-07-25 after a real UX complaint: +soul/cg/bnb (add) already
    # accepts "id or tag" like every other B&B lookup in this project
    # (get_catalogue_entry), but drop only ever took a numeric ID, which is
    # the *character's own entry* ID (a different number space entirely
    # from the catalogue's own ID/tag) - confusing since it's the only
    # chargen command that doesn't take a tag. Tag lookup is scoped to this
    # character's own still-selected chargen entries (a chargen pick is
    # 1:1 with its catalogue entry, so the tag unambiguously identifies
    # which one to drop).
    def self.drop_chargen_selection(id_or_tag, character)
      entry = if id_or_tag.to_s =~ /\A\d+\z/
                CharacterBnbEntry[id_or_tag]
              else
                character.character_bnb_entries.to_a.find do |e|
                  e.source == "chargen" && e.catalogue_entry&.tag&.downcase == id_or_tag.to_s.downcase
                end
              end
      return { error: "B&B entry not found" } unless entry
      return { error: "That entry does not belong to you." } unless entry.character == character
      return { error: "Only chargen-selected entries can be dropped this way." } unless entry.source == "chargen"
      return { error: "Chargen selections can only be dropped before approval." } if character.is_approved?

      entry.delete
      { success: true }
    end

    # Called once, at approval, from the same custom_approval.rb hook that
    # already calls SoulResonanceApi.lock_at_approval (see
    # custom-install/custom_approval.snippet.rb) - creates the "starting
    # B&B" Narrative History entry .grant deferred for every chargen
    # selection that survived to approval (entries dropped pre-approval via
    # drop_chargen_selection were already deleted and never appear here). A
    # no-op for a character with no chargen-sourced entries.
    #
    # Safe to call on every approval, including a re-approval: skips any
    # entry that already has a "bnb_granted" Narrative History record
    # (mirroring find_approval_history's own soul_record lookup in
    # soul_culmination_api.rb), so re-approval never creates a duplicate.
    def self.finalize_chargen_grants(character)
      return unless character

      character.character_bnb_entries.to_a.select { |entry| entry.source == "chargen" }.each do |entry|
        next unless entry.catalogue_entry
        already_finalized = NarrativeHistoryEntry.find(
          soul_record_type: "CharacterBnbEntry", soul_record_id: entry.id.to_s
        ).to_a.any?
        next if already_finalized

        SoulNarrativeHistoryApi.create(
          character,
          event_type: "bnb_granted",
          narrative: "Gained #{entry.catalogue_entry.name} (#{entry.level_state.to_s.capitalize}).",
          soul_record: entry
        )

        Global.dispatcher.queue_event SoulBnbTransitionedEvent.new(
          character.id, entry.id, entry.catalogue_entry.id, nil, entry.level_state.to_s, "chargen"
        )
      end
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

    # --- Player-initiated requests (post-chargen, FR-015 2026-07-25) ---
    #
    # A player picking a Boon/Bane from their profile (or +bnb/request)
    # does NOT grant it directly - .grant stays staff-only everywhere else
    # in this codebase, and this is the first player-initiated path outside
    # chargen, so it gets the same staff oversight via a pending BnbRequest
    # that .approve_request/.deny_request resolve. Mirrors
    # SoulCulminationApi's propose/approve/deny shape.

    def self.request(character, catalogue_ref, explanation:, level_state: "minor", associated_skills: nil)
      return { error: "Character not found" } unless character
      catalogue_entry = catalogue_ref.kind_of?(BnbCatalogueEntry) ? catalogue_ref : get_catalogue_entry(catalogue_ref)
      return { error: "Unknown Boon/Bane: #{catalogue_ref}" } unless catalogue_entry
      return { error: "An explanation is required." } if explanation.to_s.blank?

      effective_skills = associated_skills.presence || catalogue_entry.skill_associations || []
      if effective_skills.empty?
        return { error: "#{catalogue_entry.name} has no fixed Skill configured - specify at least one " \
          "associated Skill when requesting it." }
      end
      unknown_skills = effective_skills.reject { |key| SoulFrameworkApi.valid_skill_key?(key) }
      return { error: "Unknown Skill(s): #{unknown_skills.join(', ')}" } if unknown_skills.any?

      definitions = Global.read_config("soul", "bnb", "level_definitions") || {}
      return { error: "Unknown level/state: #{level_state}" } unless definitions.key?(level_state.to_s)

      already_owned = character.character_bnb_entries.to_a.any? { |e| e.catalogue_entry == catalogue_entry }
      return { error: "You already have #{catalogue_entry.name}." } if already_owned
      already_pending = character.bnb_requests.to_a.any? do |r|
        r.catalogue_entry == catalogue_entry && r.status == "pending"
      end
      return { error: "You already have a pending request for #{catalogue_entry.name}." } if already_pending

      request = BnbRequest.create(
        character: character, catalogue_entry: catalogue_entry, level_state: level_state.to_s,
        associated_skills: effective_skills, player_explanation: explanation, created_at: Time.now
      )
      { success: true, request: request }
    end

    def self.approve_request(request_id, enactor)
      return { error: "You don't have permission to do that." } unless Soul.can_manage_soul?(enactor)
      request = BnbRequest[request_id]
      return { error: "Request not found" } unless request
      return { error: "This request is not pending." } unless request.status == "pending"

      result = grant(
        request.character, request.catalogue_entry, level_state: request.level_state,
        source: "[Player Request]", explanation: request.player_explanation, enactor: enactor,
        associated_skills: request.associated_skills
      )
      return result if result[:error]

      request.update(status: "approved", resolved_by: enactor, resolved_at: Time.now)
      { success: true, request: request, entry: result[:entry] }
    end

    def self.deny_request(request_id, enactor, reason:)
      return { error: "You don't have permission to do that." } unless Soul.can_manage_soul?(enactor)
      return { error: "A reason is required to deny a request." } if reason.to_s.blank?
      request = BnbRequest[request_id]
      return { error: "Request not found" } unless request
      return { error: "This request is not pending." } unless request.status == "pending"

      request.update(status: "denied", resolved_by: enactor, resolved_at: Time.now, staff_reason: reason)
      { success: true, request: request }
    end

    def self.get_requests(character: nil, status: nil)
      requests = character ? character.bnb_requests.to_a : BnbRequest.all.to_a
      requests = requests.select { |r| r.status == status.to_s } if status
      requests.sort_by { |r| r.created_at || Time.at(0) }.reverse
    end
  end
end

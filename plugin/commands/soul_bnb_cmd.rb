module AresMUSH
  module Soul
    class SoulBnbCmd
      include CommandHandler
      include TemplateFormatters

      # Two side-by-side columns (Boons/Banes) in a 78-char client width,
      # with a 2-space gutter between them (2026-07-26, live testing: "The
      # bnb catalogue is hard to read on the MUSH. Let's split it and space
      # it out a bit.").
      CATALOGUE_COLUMN_WIDTH = 38

      attr_accessor :reference, :name, :description, :kind, :tag, :entry_id,
                    :level, :explanation, :reason, :confirmations, :skill_associations, :request_id

      def parse_args
        raw = cmd.args.to_s
        case cmd.switch
        when "create"
          # +bnb/create <kind>/<tag>/<name>[/<skill1,skill2,...>]=<description>
          # The Skill segment is optional - only for B&Bs that always affect
          # the same fixed Skill(s). Most B&Bs are configurable per instance
          # and take their Skill(s) at +bnb/grant time instead.
          left, self.description = raw.split("=", 2)
          self.kind, self.tag, self.name, skills_raw = left.to_s.split("/", 4)
          self.skill_associations = skills_raw.to_s.split(",").map(&:strip).reject(&:blank?)
        when "skills"
          # +bnb/skills <id or tag>=<skill1,skill2,...>
          self.reference, skills_raw = raw.split("=", 2)
          self.skill_associations = skills_raw.to_s.split(",").map(&:strip).reject(&:blank?)
        when "grant"
          # +bnb/grant <character>/<id or tag>/<level>/<skill1,skill2,...>=<explanation>
          # <level> and the Skill segment are both optional - level defaults
          # to minor, Skills default to the catalogue entry's own fixed
          # Skill(s) if it has any.
          left, self.explanation = raw.split("=", 2)
          self.name, self.reference, self.level, skills_raw = left.to_s.split("/", 4)
          self.level ||= "minor"
          self.skill_associations = skills_raw.to_s.split(",").map(&:strip).reject(&:blank?)
        when "progress"
          left, self.level = raw.split("=", 2)
          self.name, id = left.to_s.split("/", 2)
          self.entry_id = integer_arg(id)
        when "delete"
          left, *tokens = raw.split("/")
          self.entry_id, self.reason = integer_arg(left), tokens.shift
          self.confirmations = tokens.count { |token| token.downcase == "confirm" }
        when "resolve"
          left, self.reason = raw.split("=", 2)
          self.name, id = left.to_s.split("/", 2)
          self.entry_id = integer_arg(id)
        when "restore"
          self.name, id = raw.split("/", 2)
          self.entry_id = integer_arg(id)
        when "detail"
          # Staff-only: +bnb/detail <character>[=<id or tag>]. Bare (no "=")
          # lists that character's own entries with explanations, same as a
          # bare "+bnb" does for yourself; with "=<id or tag>" shows one
          # entry in full, same as "+bnb <id or tag>" does for yourself.
          self.name, self.reference = raw.split("=", 2)
        when "request"
          # +bnb/request <id or tag>[/<level>][/<skill1,skill2,...>]=<explanation>
          # Player self-service (FR-015, 2026-07-25): unlike /grant, this
          # never creates a live entry directly - it creates a pending
          # BnbRequest for staff to /approve or /deny.
          left, self.explanation = raw.split("=", 2)
          self.reference, self.level, skills_raw = left.to_s.split("/", 3)
          self.level ||= "minor"
          self.skill_associations = skills_raw.to_s.split(",").map(&:strip).reject(&:blank?)
        when "approve"
          self.request_id = integer_arg(raw)
        when "deny"
          left, self.reason = raw.split("=", 2)
          self.request_id = integer_arg(left)
        else
          self.reference = raw
        end
      end

      def check_permission
        staff_switches = %w[search create skills grant progress delete resolve restore detail requests approve deny]
        return t('soul.permission_denied') if staff_switches.include?(cmd.switch) && !Soul.can_manage_soul?(enactor)
        return t('soul.permission_denied') if !staff_switches.include?(cmd.switch) && !Soul.can_play?(enactor)
        nil
      end

      def required_args
        case cmd.switch
        when "create"
          [ self.kind, self.tag, self.name, self.description ]
        when "skills"
          [ self.reference, self.skill_associations.presence ]
        when "grant"
          [ self.name, self.reference, self.explanation ]
        when "progress"
          [ self.name, self.entry_id, self.level ]
        when "delete"
          [ self.entry_id, self.reason ]
        when "resolve"
          [ self.name, self.entry_id, self.reason ]
        when "restore"
          [ self.name, self.entry_id ]
        when "here", "search"
          [ self.reference ]
        when "detail"
          # <id or tag> is optional here (see parse_args) - only the
          # character is required.
          [ self.name ]
        when "request"
          [ self.reference, self.explanation ]
        when "approve"
          [ self.request_id ]
        when "deny"
          [ self.request_id, self.reason ]
        else
          # A bare "+bnb" (nil switch, no reference) is valid - it lists
          # your own Boons and Banes (show_own_entries) rather than
          # looking up a specific catalogue entry.
          []
        end
      end

      def handle
        case cmd.switch
        when nil then show_entry
        when "here" then show_here
        when "search" then show_search
        when "catalogue" then show_catalogue
        when "create" then create_entry
        when "skills" then set_skills_entry
        when "grant" then with_character { |character| grant_entry(character) }
        when "progress" then with_character { |character| progress_entry(character) }
        when "delete" then delete_entry
        when "resolve" then with_character { |character| resolve_entry(character) }
        when "restore" then with_character { |character| restore_entry(character) }
        when "detail" then with_character { |character| show_detail_for(character) }
        when "request" then request_entry
        when "requests" then show_requests
        when "approve" then approve_request_entry
        when "deny" then deny_request_entry
        end
      end

      def show_entry
        return show_own_entries if self.reference.blank?
        show_entry_for(enactor, self.reference, label: t('soul.bnb_your_explanation'))
      end

      # A bare "+bnb" - the player's own Boons and Banes in full, including
      # their private explanation for each (owner-only; never shown in the
      # public catalogue/search/here views).
      def show_own_entries
        show_entries_for(enactor, whose: t('soul.bnb_your'))
      end

      # +bnb/detail <character>[=<id or tag>] - staff viewing another
      # character's own entries (or one entry) with explanations, the same
      # data a bare "+bnb"/"+bnb <id or tag>" shows that character
      # themselves. Staff previously had no MUSH way to see this at all.
      def show_detail_for(character)
        if self.reference.blank?
          show_entries_for(character, whose: t('soul.bnb_whose', name: character.name))
        else
          show_entry_for(character, self.reference,
            label: t('soul.bnb_whose_explanation', name: character.name))
        end
      end

      def show_entries_for(character, whose:)
        lines = SoulBnbApi.get_character_entries(character).map do |entry|
          next unless entry.catalogue_entry
          t('soul.bnb_own_line', color: Soul.bnb_kind_color(entry.catalogue_entry),
            id: entry.catalogue_entry.id, tag: entry.catalogue_entry.tag,
            name: entry.catalogue_entry.name, kind: entry.catalogue_entry.kind,
            level: entry.level_state,
            explanation: entry.character_explanation.blank? ? t('soul.none') : entry.character_explanation)
        end.compact
        client.emit BorderedListTemplate.new(
          lines.empty? ? [t('soul.none')] : lines, t('soul.bnb_own_title', whose: whose)
        ).render
      end

      def show_entry_for(character, reference, label:)
        catalogue = SoulBnbApi.get_catalogue_entry(reference)
        unless catalogue
          client.emit_failure t('soul.bnb_not_found')
          return
        end
        owned = SoulBnbApi.get_character_entries(character).find { |entry| entry.catalogue_entry == catalogue }
        explanation = owned ? owned.character_explanation : nil
        body = t('soul.bnb_detail', color: Soul.bnb_kind_color(catalogue), tag: catalogue.tag, kind: catalogue.kind,
          description: catalogue.description, label: label,
          explanation: explanation.blank? ? t('soul.none') : explanation)
        client.emit BorderedDisplayTemplate.new(
          body, t('soul.bnb_detail_title', id: catalogue.id, name: catalogue.name)
        ).render
      end

      def show_here
        scene = enactor_room && enactor_room.scene
        unless scene && scene.participants.include?(enactor)
          client.emit_failure t('soul.no_active_scene')
          return
        end
        catalogue = SoulBnbApi.get_catalogue_entry(self.reference)
        color = Soul.bnb_kind_color(catalogue)
        matches = scene.participants.map do |character|
          entry = SoulBnbApi.get_character_entries(character).find { |e| e.catalogue_entry == catalogue }
          next unless entry
          public_entry = SoulBnbApi.get_character_entry_public(character, entry.id)
          t('soul.bnb_scene_line', color: color, character: character.name,
            name: public_entry[:name], level: public_entry[:level_state])
        end.compact
        client.emit BorderedListTemplate.new(
          matches.empty? ? [t('soul.none')] : matches, t('soul.bnb_matches_title')
        ).render
      end

      def show_search
        render_catalogue SoulBnbApi.search(self.reference)
      end

      def show_catalogue
        render_catalogue SoulBnbApi.get_catalogue
      end

      def render_catalogue(entries)
        # Right-justified against the widest ID in the whole catalogue (not
        # per-column) so the "[" that follows lines up down both columns
        # (2026-07-26 live testing: "let's ljust the numbers so everything
        # lines up").
        id_width = entries.map { |entry| entry.id.to_s.length }.max || 1
        boons = entries.select(&:boon?).map { |entry| catalogue_entry_lines(entry, id_width) }
        banes = entries.select(&:bane?).map { |entry| catalogue_entry_lines(entry, id_width) }
        client.emit BorderedListTemplate.new(
          catalogue_columns(boons, banes), t('soul.bnb_catalogue_title')
        ).render
      end

      # Each entry renders as two column lines: the colored "#id [tag]
      # Name" header (green for Boons, red for Banes, cyan tag) and a
      # plain, truncated public description beneath it (2026-07-26 live
      # testing: "add some colour... In the catalogue, also include the
      # public description").
      def catalogue_entry_lines(entry, id_width)
        name_line = t('soul.bnb_catalogue_line', color: Soul.bnb_kind_color(entry),
          id: right(entry.id.to_s, id_width), tag: entry.tag, name: entry.name)
        [name_line, catalogue_description(entry.description)]
      end

      def catalogue_description(description)
        return "" if description.blank?
        return description if description.length <= CATALOGUE_COLUMN_WIDTH

        "#{truncate(description, CATALOGUE_COLUMN_WIDTH - 1)}…"
      end

      def catalogue_columns(boons, banes)
        header = "#{left("%xh%xg#{t('soul.bnb_catalogue_boons_header')}%xn", CATALOGUE_COLUMN_WIDTH)}  " \
          "#{left("%xh%xr#{t('soul.bnb_catalogue_banes_header')}%xn", CATALOGUE_COLUMN_WIDTH)}"
        divider = "#{'-' * CATALOGUE_COLUMN_WIDTH}  #{'-' * CATALOGUE_COLUMN_WIDTH}"
        return [header, divider, t('soul.none')] if boons.empty? && banes.empty?

        rows = [header, divider]
        [boons.length, banes.length].max.times do |i|
          boon_name, boon_desc = boons[i] || [nil, nil]
          bane_name, bane_desc = banes[i] || [nil, nil]
          rows << "#{left(boon_name, CATALOGUE_COLUMN_WIDTH)}  #{left(bane_name, CATALOGUE_COLUMN_WIDTH)}"
          rows << "#{left(boon_desc, CATALOGUE_COLUMN_WIDTH)}  #{left(bane_desc, CATALOGUE_COLUMN_WIDTH)}"
        end
        rows
      end

      def create_entry
        result = SoulBnbApi.create_catalogue_entry(name: self.name, description: self.description,
          kind: self.kind, tag: self.tag, enactor: enactor, skill_associations: self.skill_associations)
        emit_result result, 'soul.bnb_created'
      end

      def set_skills_entry
        result = SoulBnbApi.set_skill_associations(self.reference, self.skill_associations, enactor: enactor)
        emit_result result, 'soul.bnb_skills_set'
      end

      def grant_entry(character)
        result = SoulBnbApi.grant(character, self.reference, level_state: self.level,
          source: "admin", explanation: self.explanation, enactor: enactor,
          associated_skills: self.skill_associations.presence)
        emit_result result, 'soul.bnb_granted'
      end

      def progress_entry(character)
        entry = SoulBnbApi.get_character_entries(character).find { |item| item.id.to_s == self.entry_id.to_s }
        unless entry
          client.emit_failure t('soul.bnb_not_found')
          return
        end
        result = SoulBnbApi.progress(entry.id, self.level, source: "admin", enactor: enactor)
        emit_result result, 'soul.bnb_progressed'
      end

      def delete_entry
        result = SoulBnbApi.delete(self.entry_id, enactor: enactor,
          confirmations: self.confirmations, reason: self.reason)
        emit_result result, 'soul.bnb_deleted'
      end

      def resolve_entry(character)
        entry = SoulBnbApi.get_character_entries(character).find { |item| item.id.to_s == self.entry_id.to_s }
        unless entry
          client.emit_failure t('soul.bnb_not_found')
          return
        end
        result = SoulBnbApi.resolve(entry.id, reason: self.reason, enactor: enactor)
        emit_result result, 'soul.bnb_resolved'
      end

      def restore_entry(character)
        entry = SoulBnbApi.get_character_entries(character).find { |item| item.id.to_s == self.entry_id.to_s }
        unless entry
          client.emit_failure t('soul.bnb_not_found')
          return
        end
        result = SoulBnbApi.restore(entry.id, enactor: enactor)
        emit_result result, 'soul.bnb_restored'
      end

      def request_entry
        result = SoulBnbApi.request(enactor, self.reference, explanation: self.explanation,
          level_state: self.level, associated_skills: self.skill_associations.presence)
        emit_result result, 'soul.bnb_requested'
      end

      def show_requests
        requests = SoulBnbApi.get_requests(status: "pending")
        lines = requests.map do |req|
          t('soul.bnb_request_line', color: Soul.bnb_kind_color(req.catalogue_entry), id: req.id,
            character: req.character.name,
            name: req.catalogue_entry.name, tag: req.catalogue_entry.tag, level: req.level_state)
        end
        client.emit BorderedListTemplate.new(
          lines.empty? ? [t('soul.none')] : lines, t('soul.bnb_requests_title')
        ).render
      end

      def approve_request_entry
        result = SoulBnbApi.approve_request(self.request_id, enactor)
        emit_result result, 'soul.bnb_request_approved'
      end

      def deny_request_entry
        result = SoulBnbApi.deny_request(self.request_id, enactor, reason: self.reason)
        emit_result result, 'soul.bnb_request_denied'
      end

      def with_character(&block)
        ClassTargetFinder.with_a_character(self.name, client, enactor, &block)
      end

      def emit_result(result, key)
        result[:error] ? client.emit_failure(result[:error]) : client.emit_success(t(key))
      end
    end
  end
end

module AresMUSH
  class SoulBnbWebHandler
    def handle(request)
      error = Website.check_login(request)
      return error if error
      enactor = request.enactor

      staff_commands = %w[soulBnbCreate soulBnbSetSkills soulBnbGrant soulBnbProgress soulBnbAdjustLevel
                          soulBnbDelete soulBnbResolve soulBnbRestore soulBnbRequestApprove soulBnbRequestDeny
                          soulBnbRequestsList]
      if staff_commands.include?(request.cmd)
        return { error: t('soul.permission_denied') } unless Soul.can_manage_soul?(enactor)
      elsif !Soul.can_play?(enactor)
        return { error: t('soul.permission_denied') }
      end

      case request.cmd
      when "soulBnb"
        lookup(request)
      when "soulBnbHere"
        here(request)
      when "soulBnbCatalogue"
        result = SoulBnbApi.get_catalogue_page(
          page: request.args['page'] || 1, per_page: request.args['per_page'] || 10,
          query: request.args['query'], kind: request.args['kind']
        )
        result.merge(
          entries: result[:entries].map { |entry| serialize_catalogue(entry) },
          available_skills: SoulFrameworkApi.get_skills.map { |skill| { key: skill[:key], name: skill[:name] } }
        )
      when "soulBnbList"
        # Profile widget (2026-07-25 rework, FR-015) - character defaults to
        # the caller, but staff viewing another character's profile pass
        # that character explicitly, mirroring SoulSheetWebHandler's own
        # character arg. Private fields (explanation, pending/denied
        # requests) only go to the character themself or manage_soul staff -
        # same bar Sheet uses for its own bnb explanations.
        character = Character.find_one_by_name(request.args['character'] || enactor.name)
        return { error: t('soul.character_not_found') } unless character
        private_view = character == enactor || Soul.can_manage_soul?(enactor)
        return { error: t('soul.permission_denied') } unless private_view
        {
          entries: SoulBnbApi.get_character_entries(character).map { |entry| serialize_character_entry(entry, true) },
          # Approved requests are already reflected in entries above - only
          # surface ones still awaiting a decision or that were denied
          # (so the player knows why), not a duplicate of the live entry.
          requests: SoulBnbApi.get_requests(character: character).reject { |req| req.status == "approved" }
            .map { |req| serialize_request(req) }
        }
      when "soulBnbRequest"
        result = SoulBnbApi.request(enactor, request.args['catalogue_ref'],
          explanation: request.args['explanation'], level_state: request.args['level_state'] || "minor",
          associated_skills: request.args['associated_skills'].presence)
        result[:error] ? result : { success: true, request: serialize_request(result[:request]) }
      when "soulBnbRequestsList"
        status = request.args['status'].presence || "pending"
        { requests: SoulBnbApi.get_requests(status: status).map { |req| serialize_request(req) } }
      when "soulBnbRequestApprove"
        result = SoulBnbApi.approve_request(request.args['request_id'], enactor)
        result[:error] ? result : { success: true, request: serialize_request(result[:request]) }
      when "soulBnbRequestDeny"
        result = SoulBnbApi.deny_request(request.args['request_id'], enactor, reason: request.args['reason'])
        result[:error] ? result : { success: true, request: serialize_request(result[:request]) }
      when "soulBnbCreate"
        result = SoulBnbApi.create_catalogue_entry(
          name: request.args['name'], description: request.args['description'],
          kind: request.args['kind'], tag: request.args['tag'], enactor: enactor,
          epic_modifier: request.args['epic_modifier'],
          chargen_available: request.args['chargen_available'].nil? ||
            request.args['chargen_available'].to_s == "true",
          flag_for_review: request.args['flag_for_review'].to_s == "true",
          modifier_eligible: request.args['modifier_eligible'].to_s == "true",
          skill_associations: request.args['skill_associations'] || [])
        result[:error] ? result : { success: true, entry: serialize_catalogue(result[:entry]) }
      when "soulBnbSetSkills"
        result = SoulBnbApi.set_skill_associations(
          request.args['id_or_tag'], request.args['skill_associations'] || [], enactor: enactor
        )
        result[:error] ? result : { success: true, entry: serialize_catalogue(result[:entry]) }
      when "soulBnbGrant"
        character = Character.find_one_by_name(request.args['character'])
        level_state = request.args['level_state'].blank? ? "minor" : request.args['level_state']
        result = SoulBnbApi.grant(character, request.args['catalogue_ref'],
          level_state: level_state, source: "admin",
          explanation: request.args['explanation'], enactor: enactor,
          associated_skills: request.args['associated_skills'].presence)
        result[:error] ? result : { success: true, entry: serialize_character_entry(result[:entry], true) }
      when "soulBnbProgress"
        result = SoulBnbApi.progress(request.args['entry_id'], request.args['level_state'],
          source: "admin", explanation: request.args['explanation'], enactor: enactor)
        result[:error] ? result : { success: true, entry: serialize_character_entry(result[:entry], true) }
      when "soulBnbAdjustLevel"
        result = SoulBnbApi.progress_direction(request.args['entry_id'], request.args['direction'],
          source: "admin", explanation: request.args['explanation'], enactor: enactor)
        result[:error] ? result : { success: true, entry: serialize_character_entry(result[:entry], true) }
      when "soulBnbDelete"
        SoulBnbApi.delete(request.args['entry_id'], enactor: enactor,
          confirmations: request.args['confirmations'], reason: request.args['reason'])
      when "soulBnbResolve"
        result = SoulBnbApi.resolve(request.args['entry_id'], reason: request.args['reason'], enactor: enactor)
        result[:error] ? result : { success: true, entry: serialize_character_entry(result[:entry], true) }
      when "soulBnbRestore"
        result = SoulBnbApi.restore(request.args['entry_id'], enactor: enactor)
        result[:error] ? result : { success: true, entry: serialize_character_entry(result[:entry], true) }
      end
    end

    def here(request)
      scene = Scene[request.args['scene_id']]
      return { error: t('soul.no_active_scene') } unless scene && scene.participants.include?(request.enactor)

      catalogue = SoulBnbApi.get_catalogue_entry(request.args['reference'])
      matches = scene.participants.map do |character|
        entry = SoulBnbApi.get_character_entries(character).find { |e| e.catalogue_entry == catalogue }
        next unless entry
        public_entry = SoulBnbApi.get_character_entry_public(character, entry.id)
        { character: character.name, name: public_entry[:name], level_state: public_entry[:level_state] }
      end.compact
      { matches: matches }
    end

    def lookup(request)
      catalogue = SoulBnbApi.get_catalogue_entry(request.args['reference'])
      return { error: t('soul.bnb_not_found') } unless catalogue
      character = Character.find_one_by_name(request.args['character'] || request.enactor.name)
      owned = character && SoulBnbApi.get_character_entries(character).find { |entry| entry.catalogue_entry == catalogue }
      result = { catalogue: serialize_catalogue(catalogue) }
      if owned && (character == request.enactor || Soul.can_manage_soul?(request.enactor))
        result[:owned_entry] = serialize_character_entry(owned, true)
      end
      result
    end

    def serialize_catalogue(entry)
      {
        id: entry.id, tag: entry.tag, name: entry.name, description: entry.description,
        kind: entry.kind, epic_modifier: entry.epic_modifier,
        chargen_available: entry.chargen_available == "true",
        active: entry.active == "true",
        has_fixed_skills: entry.skill_associations.present?
      }
    end

    def serialize_character_entry(entry, private_fields)
      data = SoulBnbApi.get_character_entry_public(entry.character, entry.id)
      if private_fields
        data[:character] = entry.character.name
        data[:explanation] = entry.character_explanation
        data[:source] = entry.source
      end
      data
    end

    def serialize_request(request)
      {
        id: request.id,
        character: request.character.name,
        catalogue_id: request.catalogue_entry.id,
        tag: request.catalogue_entry.tag,
        name: request.catalogue_entry.name,
        kind: request.catalogue_entry.kind,
        level_state: request.level_state,
        explanation: request.player_explanation,
        status: request.status,
        staff_reason: request.staff_reason,
        created_at: request.created_at
      }
    end
  end
end

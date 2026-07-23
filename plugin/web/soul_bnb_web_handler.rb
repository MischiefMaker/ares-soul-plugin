module AresMUSH
  class SoulBnbWebHandler
    def handle(request)
      error = Website.check_login(request)
      return error if error
      enactor = request.enactor

      staff_commands = %w[soulBnbCreate soulBnbGrant soulBnbProgress soulBnbDelete soulBnbResolve soulBnbRestore]
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
        entries = request.args['query'].blank? ? SoulBnbApi.get_catalogue : SoulBnbApi.search(request.args['query'])
        { entries: entries.map { |entry| serialize_catalogue(entry) } }
      when "soulBnbCreate"
        result = SoulBnbApi.create_catalogue_entry(
          name: request.args['name'], description: request.args['description'],
          kind: request.args['kind'], tag: request.args['tag'], enactor: enactor,
          category: request.args['category'], epic_modifier: request.args['epic_modifier'],
          chargen_available: request.args['chargen_available'].nil? ||
            request.args['chargen_available'].to_s == "true",
          flag_for_review: request.args['flag_for_review'].to_s == "true",
          modifier_eligible: request.args['modifier_eligible'].to_s == "true",
          skill_associations: request.args['skill_associations'] || [])
        result[:error] ? result : { success: true, entry: serialize_catalogue(result[:entry]) }
      when "soulBnbGrant"
        character = Character.find_one_by_name(request.args['character'])
        result = SoulBnbApi.grant(character, request.args['catalogue_ref'],
          level_state: request.args['level_state'], source: "admin",
          explanation: request.args['explanation'], enactor: enactor)
        result[:error] ? result : { success: true, entry: serialize_character_entry(result[:entry], true) }
      when "soulBnbProgress"
        result = SoulBnbApi.progress(request.args['entry_id'], request.args['level_state'],
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
        kind: entry.kind, category: entry.category, epic_modifier: entry.epic_modifier,
        chargen_available: entry.chargen_available == "true",
        active: entry.active == "true"
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
  end
end

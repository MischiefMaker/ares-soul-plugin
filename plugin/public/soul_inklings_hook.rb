module AresMUSH
  # Two-step SOUL integration contract for approved Inklings outcomes
  # (FINAL REQ-038/REQ-039). Validation is read-only; application revalidates
  # current state and delegates every mutation to the owning SOUL service.
  class SoulInklingsHook
    OUTCOME_TYPES = %w[xp boon_progression bane_progression culmination].freeze

    def self.validate_outcome(outcome_type:, character:, proposed_transition:,
                              requester: nil, inkling_reference:)
      result = validate_current(
        outcome_type: outcome_type,
        character: character,
        proposed_transition: proposed_transition,
        requester_id: requester && requester.id,
        inkling_reference: inkling_reference
      )
      result[:error] ? { error: result[:error] } : result[:payload]
    end

    def self.apply_outcome(payload, source:)
      return { error: "Source is required." } if source.to_s.blank?

      data = stringify_hash(payload)
      character = Character[data["character_id"]]
      return { error: "Character not found." } unless character

      outcome_type = data["outcome_type"].to_s
      transition = stringify_hash(data["proposed_transition"])
      envelope_error = validate_envelope(outcome_type, data["inkling_reference"])
      return { error: envelope_error } if envelope_error
      if %w[boon_progression bane_progression].include?(outcome_type)
        definition = validate_bnb_definition(outcome_type, transition)
        return { error: definition[:error] } if definition[:error]
        duplicate = duplicate_bnb_result(outcome_type, character, transition, source)
        return duplicate if duplicate
      end

      validation = validate_current(
        outcome_type: outcome_type,
        character: character,
        proposed_transition: transition,
        requester_id: data["requester_id"],
        inkling_reference: data["inkling_reference"]
      )
      return { error: validation[:error] } if validation[:error]

      case outcome_type
      when "xp"
        apply_xp(character, validation[:payload], source)
      when "boon_progression", "bane_progression"
        apply_bnb(character, validation, source)
      when "culmination"
        apply_culmination(character, validation[:payload], source)
      end
    end

    def self.validate_current(outcome_type:, character:, proposed_transition:,
                              requester_id:, inkling_reference:)
      return { error: "Character not found." } unless character

      type = outcome_type.to_s
      envelope_error = validate_envelope(type, inkling_reference)
      return { error: envelope_error } if envelope_error

      transition = stringify_hash(proposed_transition)
      base = {
        "outcome_type" => type,
        "character_id" => character.id,
        "requester_id" => requester_id,
        "inkling_reference" => inkling_reference.to_s
      }

      case type
      when "xp"
        amount = integer_value(transition["amount"])
        return { error: "XP amount must be a positive integer." } unless amount && amount > 0
        { payload: base.merge("proposed_transition" => { "amount" => amount }) }
      when "culmination"
        title = transition["title"].to_s
        description = transition["description"].to_s
        return { error: "Culmination title is required." } if title.blank?
        return { error: "Culmination description is required." } if description.blank?
        {
          payload: base.merge(
            "proposed_transition" => {
              "title" => title,
              "description" => description
            }
          )
        }
      when "boon_progression", "bane_progression"
        validate_bnb(type, character, transition, base)
      end
    end
    private_class_method :validate_current

    def self.validate_bnb(outcome_type, character, transition, base)
      definition = validate_bnb_definition(outcome_type, transition)
      return definition if definition[:error]
      catalogue = definition[:catalogue]
      to_value = transition["to"].to_s
      to_key = definition[:to_key]

      from_value = transition["from"]
      entry = unresolved_entry(character, catalogue.id)
      if from_value.to_s.blank?
        return { error: "Character already owns this Boon/Bane." } if entry
        if catalogue.boon? && !SoulBnbApi.ratio_satisfied_after_boon?(character)
          return { error: "Granting this Boon would violate the configured Boon-to-Bane ratio." }
        end
      else
        return { error: "Character does not own an unresolved entry for this Boon/Bane." } unless entry
        unless entry.level_state.to_s.casecmp(from_value.to_s).zero?
          return {
            error: "Boon/Bane state changed: expected #{from_value}, currently #{entry.level_state}."
          }
        end
      end

      normalized_transition = {
        "catalogue_id" => catalogue.id.to_s,
        "from" => from_value,
        "to" => to_value
      }
      {
        payload: base.merge("proposed_transition" => normalized_transition),
        catalogue: catalogue,
        entry: entry,
        to_key: to_key
      }
    end
    private_class_method :validate_bnb

    def self.validate_envelope(outcome_type, inkling_reference)
      return "Unknown outcome type: #{outcome_type}" unless OUTCOME_TYPES.include?(outcome_type.to_s)
      return "Inkling reference is required." if inkling_reference.to_s.blank?
      nil
    end
    private_class_method :validate_envelope

    def self.validate_bnb_definition(outcome_type, transition)
      catalogue_ref = transition["catalogue_id"]
      catalogue = SoulBnbApi.get_catalogue_entry(catalogue_ref)
      return { error: "Unknown Boon/Bane: #{catalogue_ref}" } unless catalogue

      expected_kind = outcome_type == "boon_progression" ? "Boon" : "Bane"
      kind_matches = outcome_type == "boon_progression" ? catalogue.boon? : catalogue.bane?
      return { error: "Outcome type requires a #{expected_kind} catalogue entry." } unless kind_matches

      to_value = transition["to"].to_s
      to_key = configured_level_key(to_value)
      return { error: "Unknown level/state: #{to_value}" } unless to_key

      { catalogue: catalogue, to_key: to_key }
    end
    private_class_method :validate_bnb_definition

    def self.apply_xp(character, payload, source)
      amount = payload["proposed_transition"]["amount"]
      result = SoulXpApi.award(
        character,
        amount,
        source: source,
        idempotency_key: source,
        apply_catchup: true
      )
      return result if result[:error]

      references = {
        awarded: result[:awarded],
        base_award: result[:base_award],
        catchup_portion: result[:catchup_portion]
      }
      response = { success: true, soul_references: references }
      response[:duplicate] = true if result[:duplicate]
      response
    end
    private_class_method :apply_xp

    def self.apply_bnb(character, validation, source)
      payload = validation[:payload]
      transition = payload["proposed_transition"]
      result = if transition["from"].to_s.blank?
                 SoulBnbApi.grant(
                   character,
                   validation[:catalogue],
                   level_state: validation[:to_key],
                   source: source,
                   explanation: payload["inkling_reference"],
                   enactor: nil
                 )
               else
                 SoulBnbApi.progress(
                   validation[:entry].id,
                   validation[:to_key],
                   source: source,
                   explanation: payload["inkling_reference"],
                   enactor: nil
                 )
               end
      return result if result[:error]

      {
        success: true,
        soul_references: { character_bnb_entry_id: result[:entry].id }
      }
    end
    private_class_method :apply_bnb

    def self.apply_culmination(character, payload, source)
      transition = payload["proposed_transition"]
      result = SoulCulminationApi.propose(
        character,
        title: transition["title"],
        description: transition["description"],
        source: source,
        enactor: nil
      )
      return result if result[:error]

      response = {
        success: true,
        soul_references: { culmination_id: result[:culmination].id }
      }
      response[:duplicate] = true if result[:duplicate]
      response
    end
    private_class_method :apply_culmination

    def self.duplicate_bnb_result(outcome_type, character, transition, source)
      catalogue = SoulBnbApi.get_catalogue_entry(transition["catalogue_id"])
      return nil unless catalogue
      return nil if outcome_type == "boon_progression" && !catalogue.boon?
      return nil if outcome_type == "bane_progression" && !catalogue.bane?

      matching_entries = character.character_bnb_entries.to_a.select do |entry|
        entry.catalogue_entry && entry.catalogue_entry.id.to_s == catalogue.id.to_s
      end
      duplicate = if transition["from"].to_s.blank?
                    matching_entries.find { |entry| entry.source == source.to_s }
                  else
                    matching_entries.find do |entry|
                      (entry.progression_history || []).any? do |row|
                        stringify_hash(row)["source"] == source.to_s
                      end
                    end
                  end
      return nil unless duplicate

      {
        success: true,
        soul_references: { character_bnb_entry_id: duplicate.id },
        duplicate: true
      }
    end
    private_class_method :duplicate_bnb_result

    def self.unresolved_entry(character, catalogue_id)
      character.character_bnb_entries.to_a.find do |entry|
        entry.catalogue_entry &&
          entry.catalogue_entry.id.to_s == catalogue_id.to_s &&
          entry.resolved != "true"
      end
    end
    private_class_method :unresolved_entry

    def self.configured_level_key(value)
      definitions = Global.read_config("soul", "bnb", "level_definitions") || {}
      definitions.keys.find { |key| key.to_s.casecmp(value.to_s).zero? }&.to_s
    end
    private_class_method :configured_level_key

    def self.integer_value(value)
      return value if value.kind_of?(Integer)
      return nil unless value.to_s =~ /\A\d+\z/
      value.to_i
    end
    private_class_method :integer_value

    def self.stringify_hash(value)
      return {} unless value.respond_to?(:each)
      value.each_with_object({}) do |(key, item), hash|
        hash[key.to_s] = item.respond_to?(:each_pair) ? stringify_hash(item) : item
      end
    end
    private_class_method :stringify_hash
  end
end

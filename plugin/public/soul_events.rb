module AresMUSH
  # Fired via Global.dispatcher.queue_event (the real event mechanism -
  # confirmed against plugins/roles/public/roles_events.rb,
  # plugins/idle/public/idle_event.rb, and
  # plugins/chargen/public/char_approved_event.rb). Flat under AresMUSH,
  # not nested under Soul:: - confirmed real plugin-specific events
  # (RoleChangedEvent, SceneSharedEvent, etc.) are always defined this way,
  # never namespaced under their owning plugin's own module. This also
  # matters mechanically: AresMUSH::Dispatcher#on_event computes
  # event_name as event.class.to_s.gsub("AresMUSH::", ""), so a nested
  # class would produce "Soul::SoulBnbTransitionedEvent" instead of the
  # flat name every get_event_handler case/when expects to match against.
  #
  # Other plugins subscribe by returning a handler class from their own
  # get_event_handler for the event's class name, same as every other
  # AresMUSH event. NOT the Global.dispatcher.dispatch("name", *args)
  # pattern seen in Inklings' own dispatch_inkling_* methods - that method
  # doesn't exist on the real Dispatcher class (confirmed against
  # engine/aresmush/commands/dispatcher.rb), so those calls are silently
  # inert (guarded by a respond_to?(:dispatch) check that's always false).

  class SoulBnbTransitionedEvent
    attr_accessor :character_id, :entry_id, :catalogue_id, :old_level_state, :new_level_state, :source, :transitioned_at

    def initialize(character_id, entry_id, catalogue_id, old_level_state, new_level_state, source)
      self.character_id = character_id
      self.entry_id = entry_id
      self.catalogue_id = catalogue_id
      self.old_level_state = old_level_state
      self.new_level_state = new_level_state
      self.source = source
      self.transitioned_at = Time.now
    end
  end

  class SoulCulminationApprovedEvent
    attr_accessor :character_id, :culmination_id, :source, :approved_at

    def initialize(character_id, culmination_id, source)
      self.character_id = character_id
      self.culmination_id = culmination_id
      self.source = source
      self.approved_at = Time.now
    end
  end

  class SoulRollResolvedEvent
    attr_accessor :character_id, :roll_id, :skill_key, :final_result,
                  :degree_of_success, :extraordinary, :gm_assisted, :resolved_at

    def initialize(character_id, roll_id, skill_key, final_result,
                   degree_of_success, extraordinary, gm_assisted)
      self.character_id = character_id
      self.roll_id = roll_id
      self.skill_key = skill_key
      self.final_result = final_result
      self.degree_of_success = degree_of_success
      self.extraordinary = extraordinary
      self.gm_assisted = gm_assisted
      self.resolved_at = Time.now
    end
  end
end

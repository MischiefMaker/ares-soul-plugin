module AresMUSH
  module Soul
    class SceneSharedEventHandler
      def on_event(event)
        # SceneSharedEvent's only real attribute is .id (the scene's id) -
        # see plugins/scenes/public/scene_events.rb in the real AresMUSH
        # engine. There is no .scene_id.
        scene = Scene[event.id]
        return unless scene

        approved_ids = Chargen.approved_chars.map { |character| character.id.to_s }
        owner = scene.owner
        award_scene_character(scene, owner, "scene_sharer", "scene_sharer_award") if owner &&
          approved_ids.include?(owner.id.to_s)

        scene.participants.each do |character|
          next if owner && character.id.to_s == owner.id.to_s
          next unless approved_ids.include?(character.id.to_s)
          award_scene_character(scene, character, "scene_participant", "scene_participant_award")
        end
      end

      private

      def award_scene_character(scene, character, source, config_key)
        amount = Global.read_config("soul", "xp", config_key) || 0
        return if amount <= 0

        SoulXpApi.award(
          character,
          amount,
          source: "#{source}:#{scene.id}",
          idempotency_key: "#{source}:#{scene.id}:#{character.id}",
          apply_catchup: true
        )
      end
    end
  end
end

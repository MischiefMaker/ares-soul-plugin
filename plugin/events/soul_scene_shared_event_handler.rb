module AresMUSH
  module Soul
    class SceneSharedEventHandler
      # No separate "sharer" bonus (dropped 2026-07-26 at the project
      # owner's direction, live testing: "Sharing a scene only gave me a
      # participant XP" -> "Let's drop the scene share XP then."). The
      # real SceneSharedEvent only ever carries the scene's id, not who
      # ran +scene/share (plugins/scenes/helpers/actions.rb's
      # share_scene(enactor, scene) never forwards enactor into the
      # event) - the only usable proxy was Scene#owner (whoever originally
      # started the scene), but any participant can share it, so the
      # owner isn't reliably "the sharer" and the split rewarded the
      # wrong person as often as not. Every approved participant,
      # including the owner, now gets the same scene_participant_award.
      def on_event(event)
        # SceneSharedEvent's only real attribute is .id (the scene's id) -
        # see plugins/scenes/public/scene_events.rb in the real AresMUSH
        # engine. There is no .scene_id.
        scene = Scene[event.id]
        return unless scene

        approved_ids = Chargen.approved_chars.map { |character| character.id.to_s }
        scene.participants.each do |character|
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

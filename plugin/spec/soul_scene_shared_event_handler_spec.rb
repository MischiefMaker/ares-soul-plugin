require_relative 'spec_helper'

module AresMUSH
  describe Soul::SceneSharedEventHandler do
    it "awards every approved participant, including the owner, the same participant amount " \
      "(2026-07-26: the separate sharer bonus was dropped - the real event never says who " \
      "actually ran +scene/share, only Scene#owner, which isn't reliably the same person)" do
      owner = Fabricate(:character)
      participant = Fabricate(:character)
      scene = double(id: 12, owner: owner, participants: [owner, participant])
      allow(Scene).to receive(:[]).with(12).and_return(scene)
      allow(Chargen).to receive(:approved_chars).and_return([owner, participant])
      allow(Global).to receive(:read_config).with("soul", "xp", "scene_participant_award").and_return(1)
      allow(SoulXpApi).to receive(:award)

      # SceneSharedEvent's only real attribute is .id, not .scene_id - see
      # plugins/scenes/public/scene_events.rb in the real AresMUSH engine.
      subject.on_event(double(id: 12))

      expect(SoulXpApi).to have_received(:award).with(
        owner, 1, source: "scene_participant:12",
        idempotency_key: "scene_participant:12:#{owner.id}", apply_catchup: true
      )
      expect(SoulXpApi).to have_received(:award).with(
        participant, 1, source: "scene_participant:12",
        idempotency_key: "scene_participant:12:#{participant.id}", apply_catchup: true
      )
    end

    it "does not award unapproved participants" do
      owner = Fabricate(:character)
      scene = double(id: 12, owner: owner, participants: [owner])
      allow(Scene).to receive(:[]).and_return(scene)
      allow(Chargen).to receive(:approved_chars).and_return([])
      allow(SoulXpApi).to receive(:award)
      # SceneSharedEvent's only real attribute is .id, not .scene_id - see
      # plugins/scenes/public/scene_events.rb in the real AresMUSH engine.
      subject.on_event(double(id: 12))
      expect(SoulXpApi).not_to have_received(:award)
    end
  end
end

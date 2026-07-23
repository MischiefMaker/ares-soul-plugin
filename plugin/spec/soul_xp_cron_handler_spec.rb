require_relative 'spec_helper'

module AresMUSH
  describe Soul::XpCronHandler do
    it "reconciles multiple forum contributions to one weekly idempotency key" do
      character = Fabricate(:character)
      now = Time.new(2026, 7, 24, 12, 0, 0)
      post = double(author: character, created_at: now - 60)
      reply = double(author: character, created_at: now - 30)
      stub_const("AresMUSH::BbsPost", class_double("BbsPost", all: double(to_a: [post])))
      stub_const("AresMUSH::BbsReply", class_double("BbsReply", all: double(to_a: [reply])))
      allow(Chargen).to receive(:approved_chars).and_return([character])
      allow(Global).to receive(:read_config).and_call_original
      allow(Global).to receive(:read_config).with("soul", "xp", "forum_award").and_return(1)
      allow(Global).to receive(:read_config).with("soul", "xp", "weekly_award_cron").and_return("never")
      allow(Cron).to receive(:is_cron_match?).and_return(false)
      allow(SoulRollApi).to receive(:expire_stale_pending_rolls)
      allow(SoulXpApi).to receive(:award)

      subject.on_event(double(time: now))

      expect(SoulXpApi).to have_received(:award).twice
      expect(SoulXpApi).to have_received(:award).with(
        character, 1, source: "forum:2026-W30",
        idempotency_key: "forum:#{character.id}:2026-W30", apply_catchup: true
      ).twice
    end
  end
end

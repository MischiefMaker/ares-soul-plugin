require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulXpCmd do
    it "is registered for +xp" do
      cmd = double(root: "xp")
      expect(Soul.get_cmd_handler(nil, cmd, nil)).to eq(Soul::SoulXpCmd)
    end

    it "treats +xp/reverse as a staff operation" do
      command = double(switch: "reverse")
      allow(subject).to receive(:cmd).and_return(command)
      allow(subject).to receive(:enactor).and_return(Fabricate(:character))
      allow(Soul).to receive(:can_manage_soul?).and_return(false)
      expect(subject.check_permission).to be_present
    end

    it "allows players to use +xp/spend/aspect" do
      command = double(switch: "spend/aspect")
      allow(subject).to receive(:cmd).and_return(command)
      allow(subject).to receive(:enactor).and_return(Fabricate(:character))
      allow(Soul).to receive(:can_play?).and_return(true)
      expect(subject.check_permission).to be_nil
    end

    describe "#handle with an unrecognized switch" do
      it "reports invalid syntax instead of silently doing nothing (2026-07-25 bug report)" do
        # Real user reports: +xp/commit, +xp/spend/commit, and
        # +xp/spend/aspect/commit all "just do nothing" - none of these are
        # real switches (confirmation appends /confirm to the *arguments*,
        # not the switch), and #handle's case statement previously had no
        # else branch, so an unmatched switch produced zero output.
        command = double(switch: "spend/commit", root_plus_switch: "xp/spend/commit")
        client = double
        allow(subject).to receive(:cmd).and_return(command)
        allow(subject).to receive(:client).and_return(client)
        allow(subject).to receive(:t).with('dispatcher.invalid_syntax', cmd: "xp/spend/commit")
          .and_return("That is not the right command format. See `help xp/spend/commit`.")
        expect(client).to receive(:emit_failure).with(a_string_matching(/xp\/spend\/commit/))

        subject.handle
      end
    end

    describe "#confirm_syntax" do
      it "builds the exact repeatable command, appending /confirm to the arguments" do
        command = double(root_plus_switch: "xp/spend/aspect", args: "mind=1")
        allow(subject).to receive(:cmd).and_return(command)
        expect(subject.confirm_syntax).to eq("+xp/spend/aspect mind=1/confirm")
      end
    end

    describe "#spend_xp preview" do
      it "shows the exact confirm command rather than the ambiguous old wording" do
        character = Fabricate(:character)
        command = double(switch: "spend/aspect", root_plus_switch: "xp/spend/aspect", args: "mind=1")
        client = double
        allow(subject).to receive(:cmd).and_return(command)
        allow(subject).to receive(:client).and_return(client)
        allow(subject).to receive(:enactor).and_return(character)
        subject.skill, subject.amount, subject.confirmed = "mind", 1, false

        allow(SoulFrameworkApi).to receive(:get_aspect).with("mind").and_return(key: "mind", name: "Mind")
        allow(SoulCharacterApi).to receive(:get_aspect_rating).and_return(0)
        allow(SoulFrameworkApi).to receive(:aspect_max_rating).and_return(10)
        allow(SoulXpApi).to receive(:calculate_cost).and_return(20)
        allow(subject).to receive(:t).with('soul.xp_spend_title').and_return("XP Advancement Preview")
        allow(subject).to receive(:t)
          .with('soul.xp_spend_preview', trait: "Mind", target: 1, cost: 20,
            confirm_syntax: "+xp/spend/aspect mind=1/confirm")
          .and_return("Advance Mind to 1 for 20 XP. To confirm, type exactly: +xp/spend/aspect mind=1/confirm")
        expect(BorderedDisplayTemplate).to receive(:new).with(
          a_string_matching(%r{\+xp/spend/aspect mind=1/confirm}), anything
        ).and_return(double(render: "rendered"))
        allow(client).to receive(:emit)

        subject.spend_xp
      end
    end
  end
end

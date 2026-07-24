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
  end
end

require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulXpCmd do
    it "is registered for +xp" do
      cmd = double(root: "xp")
      expect(Soul.get_cmd_handler(nil, cmd, nil)).to eq(Soul::SoulXpCmd)
    end
  end
end

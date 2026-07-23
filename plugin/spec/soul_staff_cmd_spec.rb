require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulStaffCmd do
    it "is registered for +soul/framework" do
      cmd = double(root: "soul", switch: "framework")
      expect(Soul.get_cmd_handler(nil, cmd, nil)).to eq(Soul::SoulStaffCmd)
    end
  end
end

require_relative 'spec_helper'

module AresMUSH
  describe Soul::SoulChargenCmd do
    it "is registered for +chargen" do
      cmd = double(root: "chargen")
      expect(Soul.get_cmd_handler(nil, cmd, nil)).to eq(Soul::SoulChargenCmd)
    end
  end
end
